-- ================================================================
--  XpressRides (Decarrerita) — Sistemas de Base de Datos I
--  UNEG · Prof. María Raquel Herrera E. · Junio 2026
--  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
--          Manuel Jaimes · Ángel Martínez
-- ================================================================
--  Archivo:     datos_prueba.sql
--  Módulo:      Datos semilla (seed data) para pruebas
--  Descripción: Inserta un escenario completo y funcional para
--               probar el flujo de solicitud de traslado:
--               1 chofer totalmente habilitado (con evaluación
--               psicológica aprobada, revisión vehicular aprobada,
--               vehículo activo y 2 contactos de emergencia) y
--               1 cliente estudiante con saldo disponible.
--
--               Es idempotente: puede ejecutarse múltiples veces
--               sin generar duplicados (limpia datos previos de
--               prueba antes de insertar). Usa transacción para
--               garantizar consistencia y resuelve los IDs por
--               nombre para no depender de valores fijos.
--
--  Uso:         Ejecutar completo en MySQL Workbench sobre la BD
--               'decarrerita' DESPUÉS de cargar decarrerita.sql.
--               Seleccionar (Ctrl+A) y ejecutar (rayo).
--
--  Versión:     1.3.0
--  Fecha:       28/06/2026
-- ================================================================

USE decarrerita;

-- FIX Error 1175: Desactiva safe update mode de MySQL Workbench
SET SQL_SAFE_UPDATES = 0;

-- ================================================================
-- BLOQUE 0: ACTUALIZACIONES DE ESQUEMA (DDL)
-- DDL no puede ir dentro de un TRANSACTION en MySQL — cada ALTER/
-- CREATE INDEX / DROP TRIGGER hace commit implícito automático.
-- Se ejecutan con IF NOT EXISTS para que el script sea idempotente
-- tanto sobre una BD recién creada como sobre una BD existente.
-- ================================================================

-- 0.1 Ampliar ENUM notificacion.tipo con los valores que faltaban
--     'chofer_llego' → notificación cuando el chofer llega al origen
--     'sin_chofer'   → ya usado en Java (TripRejectionService) pero faltaba en la BD
ALTER TABLE notificacion
  MODIFY COLUMN tipo ENUM(
    'viaje_solicitado','chofer_asignado','chofer_en_camino',
    'chofer_llego','viaje_iniciado','viaje_completado','factura_emitida',
    'pago_recibido','recarga_acreditada','viaje_cancelado','sin_chofer'
  ) NOT NULL;

-- 0.2 Índice compuesto para el conteo del badge de notificaciones
--     Cubre: countByUser_IdAndReadFalse — consultado cada 15 s por cada usuario activo
--     Se verifica en information_schema.STATISTICS antes de crear para que el
--     script sea idempotente en cualquier versión de MySQL
SET @existe = (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE table_schema = DATABASE()
      AND table_name   = 'notificacion'
      AND index_name   = 'idx_notif_usuario_leida');
SET @sql = IF(@existe = 0,
    'CREATE INDEX idx_notif_usuario_leida ON notificacion(id_usuario, leida)',
    'SELECT ''idx_notif_usuario_leida: ya existe, se omite''');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 0.3 Índice compuesto para el polling de viaje activo del cliente
--     Cubre: GET /api/cliente/viaje-activo — consultado cada 5 s durante un viaje
SET @existe = (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE table_schema = DATABASE()
      AND table_name   = 'traslado'
      AND index_name   = 'idx_traslado_cliente_estado');
SET @sql = IF(@existe = 0,
    'CREATE INDEX idx_traslado_cliente_estado ON traslado(id_cliente, estado)',
    'SELECT ''idx_traslado_cliente_estado: ya existe, se omite''');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 0.4 Trigger actualizado: agrega notificación para estado 'chofer_llego'
--     El trigger original no cubría este estado — el cliente nunca recibía
--     aviso cuando el chofer llegaba al punto de recogida.
DROP TRIGGER IF EXISTS trg_traslado_eventos;

DELIMITER $$

CREATE TRIGGER trg_traslado_eventos
AFTER UPDATE ON traslado
FOR EACH ROW
BEGIN
  DECLARE v_id_usuario_cliente INT;
  DECLARE v_id_usuario_chofer  INT;

  SELECT u.id INTO v_id_usuario_cliente
    FROM cliente cl JOIN usuario u ON cl.id_usuario = u.id
    WHERE cl.id = NEW.id_cliente;

  SELECT u.id INTO v_id_usuario_chofer
    FROM chofer ch JOIN usuario u ON ch.id_usuario = u.id
    WHERE ch.id = NEW.id_chofer;

  IF NEW.estado = 'aceptado' AND OLD.estado <> 'aceptado' THEN
    INSERT INTO notificacion (id_usuario, id_traslado, tipo, mensaje)
    VALUES (v_id_usuario_cliente, NEW.id, 'chofer_asignado',
      'Tu chofer fue asignado y va en camino hacia tu ubicación.');
  END IF;

  IF NEW.estado = 'en_camino' AND OLD.estado <> 'en_camino' THEN
    INSERT INTO notificacion (id_usuario, id_traslado, tipo, mensaje)
    VALUES (v_id_usuario_cliente, NEW.id, 'chofer_en_camino',
      'Tu chofer está en camino al punto de recogida.');
  END IF;

  IF NEW.estado = 'chofer_llego' AND OLD.estado <> 'chofer_llego' THEN
    INSERT INTO notificacion (id_usuario, id_traslado, tipo, mensaje)
    VALUES (v_id_usuario_cliente, NEW.id, 'chofer_llego',
      'Tu chofer llegó al punto de recogida. ¡Está esperándote!');
  END IF;

  IF NEW.estado = 'en_progreso' AND OLD.estado <> 'en_progreso' THEN
    INSERT INTO notificacion (id_usuario, id_traslado, tipo, mensaje)
    VALUES (v_id_usuario_cliente, NEW.id, 'viaje_iniciado',
      'Tu viaje ha comenzado. ¡Buen viaje!');
  END IF;

  IF NEW.estado = 'completado' AND OLD.estado <> 'completado' THEN

    INSERT INTO factura (
      id_traslado, nro_documento, nro_control, serie,
      razon_social, rif_cedula, direccion_fiscal,
      igtf_porcentaje, igtf_monto_usd
    )
    SELECT
      NEW.id,
      CONCAT('FAC-', LPAD(NEW.id, 8, '0')),
      CONCAT('00-', LPAD(NEW.id, 8, '0')),
      'A',
      CONCAT(u.nombre, ' ', u.apellido),
      u.cedula,
      'Ciudad Guayana, Venezuela',
      3.00,
      ROUND(NEW.costo_cliente_usd * 0.03, 2)
    FROM cliente cl
    JOIN usuario u ON cl.id_usuario = u.id
    WHERE cl.id = NEW.id_cliente;

    INSERT INTO notificacion (id_usuario, id_traslado, tipo, mensaje)
    VALUES (v_id_usuario_cliente, NEW.id, 'viaje_completado',
      CONCAT('Viaje completado. Total: $', NEW.costo_cliente_usd, ' USD. Califica tu experiencia.'));

    INSERT INTO notificacion (id_usuario, id_traslado, tipo, mensaje)
    VALUES (v_id_usuario_cliente, NEW.id, 'factura_emitida',
      'Tu factura electrónica fue generada y está disponible para descarga.');

    INSERT INTO notificacion (id_usuario, id_traslado, tipo, mensaje)
    VALUES (v_id_usuario_chofer, NEW.id, 'viaje_completado',
      CONCAT('Viaje completado. Ganaste: $', NEW.monto_chofer_usd, ' USD.'));

  END IF;

  IF NEW.estado = 'cancelado' AND OLD.estado <> 'cancelado' THEN
    INSERT INTO notificacion (id_usuario, id_traslado, tipo, mensaje)
    VALUES (v_id_usuario_cliente, NEW.id, 'viaje_cancelado',
      CONCAT('Tu viaje fue cancelado. Motivo: ', IFNULL(NEW.motivo_cancelacion, 'No especificado')));

    IF v_id_usuario_chofer IS NOT NULL THEN
      INSERT INTO notificacion (id_usuario, id_traslado, tipo, mensaje)
      VALUES (v_id_usuario_chofer, NEW.id, 'viaje_cancelado',
        'El viaje asignado fue cancelado.');
    END IF;
  END IF;

END$$

DELIMITER ;

-- ================================================================
START TRANSACTION;

-- ----------------------------------------------------------------
-- LIMPIEZA PREVIA — dentro de la transacción para permitir ROLLBACK.
-- Solo elimina los usuarios de prueba (carlosr, laurap), nunca el
-- usuario administrador base del sistema.
-- ----------------------------------------------------------------
SET FOREIGN_KEY_CHECKS = 0;

-- Limpiar historial previo vinculado a los usuarios de prueba
-- (notificaciones, facturas, traslados, recargas) antes de recrearlos.
DELETE FROM notificacion
  WHERE id_usuario IN (SELECT id FROM usuario WHERE username IN ('carlosr', 'laurap'));

DELETE FROM factura
  WHERE id_traslado IN (
    SELECT id FROM (
      SELECT t.id FROM traslado t
      JOIN cliente cl ON t.id_cliente = cl.id
      JOIN usuario u  ON cl.id_usuario = u.id
      WHERE u.username = 'laurap'
    ) AS tmp_fac
  );

DELETE FROM traslado
  WHERE id_cliente IN (
    SELECT id FROM (
      SELECT cl.id FROM cliente cl
      JOIN usuario u ON cl.id_usuario = u.id
      WHERE u.username = 'laurap'
    ) AS tmp_tra_cl
  )
  OR id_chofer IN (
    SELECT id FROM (
      SELECT c.id FROM chofer c
      JOIN usuario u ON c.id_usuario = u.id
      WHERE u.username = 'carlosr'
    ) AS tmp_tra_ch
  );

DELETE FROM recarga_saldo
  WHERE id_cliente IN (
    SELECT id FROM (
      SELECT cl.id FROM cliente cl
      JOIN usuario u ON cl.id_usuario = u.id
      WHERE u.username = 'laurap'
    ) AS tmp_rec
  );

DELETE FROM contacto_emergencia
  WHERE id_chofer IN (
    SELECT id FROM (
      SELECT c.id FROM chofer c
      JOIN usuario u ON c.id_usuario = u.id
      WHERE u.username = 'carlosr'
    ) AS tmp
  );

DELETE FROM evaluacion_psicologica
  WHERE id_chofer IN (
    SELECT id FROM (
      SELECT c.id FROM chofer c
      JOIN usuario u ON c.id_usuario = u.id
      WHERE u.username = 'carlosr'
    ) AS tmp
  );

DELETE FROM revision_vehiculo
  WHERE id_vehiculo IN (
    SELECT id FROM (
      SELECT v.id FROM vehiculo v
      JOIN chofer c ON v.id_chofer = c.id
      JOIN usuario u ON c.id_usuario = u.id
      WHERE u.username = 'carlosr'
    ) AS tmp
  );

DELETE FROM vehiculo
  WHERE id_chofer IN (
    SELECT id FROM (
      SELECT c.id FROM chofer c
      JOIN usuario u ON c.id_usuario = u.id
      WHERE u.username = 'carlosr'
    ) AS tmp
  );

DELETE FROM chofer
  WHERE id_usuario IN (
    SELECT id FROM (SELECT id FROM usuario WHERE username = 'carlosr') AS tmp
  );

DELETE FROM cliente
  WHERE id_usuario IN (
    SELECT id FROM (SELECT id FROM usuario WHERE username = 'laurap') AS tmp
  );

DELETE FROM usuario WHERE username IN ('carlosr', 'laurap');

-- Eliminar las tasas BCV de prueba para poder re-insertarlas sin error de duplicado
DELETE FROM tasa_bcv WHERE fecha_vigencia IN ('2026-06-22', '2026-06-25', '2026-06-26');

SET FOREIGN_KEY_CHECKS = 1;

-- ----------------------------------------------------------------
-- RESOLUCIÓN DE IDs POR NOMBRE — evita depender de valores fijos.
-- El campo id_admin referencia a personal_admin(id), por eso primero
-- se asegura que el administrador base exista en esa tabla.
-- ----------------------------------------------------------------
SET @id_usuario_admin = (
  SELECT id FROM usuario
  WHERE rol IN ('admin', 'administrador', 'Administrador')
  LIMIT 1
);

INSERT INTO personal_admin (id_usuario, cargo)
VALUES (@id_usuario_admin, 'Administrador General')
ON DUPLICATE KEY UPDATE cargo = VALUES(cargo);

SET @id_admin = (
  SELECT id FROM personal_admin WHERE id_usuario = @id_usuario_admin
);

SET @id_banco = (SELECT id FROM banco WHERE nombre LIKE '%Venezuela%' LIMIT 1);
SET @id_zona  = (SELECT id FROM zona  WHERE nombre LIKE '%Alta Vista Norte%' LIMIT 1);

-- Zonas para los traslados históricos
SET @id_zona_alta_vista_norte = (SELECT id FROM zona WHERE nombre = 'Alta Vista Norte'    LIMIT 1);
SET @id_zona_alta_vista_sur   = (SELECT id FROM zona WHERE nombre = 'Alta Vista Sur'      LIMIT 1);
SET @id_zona_centro_civico    = (SELECT id FROM zona WHERE nombre = 'Centro Cívico'       LIMIT 1);
SET @id_zona_castillito       = (SELECT id FROM zona WHERE nombre = 'Castillito'          LIMIT 1);
SET @id_zona_orinokia_mall    = (SELECT id FROM zona WHERE nombre = 'Orinokia Mall'       LIMIT 1);
SET @id_zona_uneg_atlantico   = (SELECT id FROM zona WHERE nombre = 'UNEG Sede Atlántico' LIMIT 1);
SET @id_zona_los_helechos     = (SELECT id FROM zona WHERE nombre = 'Los Helechos'        LIMIT 1);
SET @id_zona_parque_cachamay  = (SELECT id FROM zona WHERE nombre = 'Parque Cachamay'     LIMIT 1);

-- ----------------------------------------------------------------
-- DIAGNÓSTICO — confirma que ninguna variable quedó en NULL.
-- Si alguna sale NULL, hacer ROLLBACK y revisar el dato faltante.
-- ----------------------------------------------------------------
SELECT
  @id_usuario_admin AS id_usuario_admin,
  @id_admin         AS id_admin,
  @id_banco         AS id_banco,
  @id_zona          AS id_zona;

-- ----------------------------------------------------------------
-- USUARIO CHOFER + módulo operativo completo
-- ----------------------------------------------------------------
INSERT INTO usuario (cedula, nombre, apellido, username, password_hash,
                     email, telefono, rol)
VALUES ('V15234567', 'Carlos', 'Rodríguez', 'carlosr',
        '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i',
        'carlos.rodriguez@test.ve', '0414-5234567', 'chofer');
SET @id_usuario_chofer = LAST_INSERT_ID();

INSERT INTO chofer (id_usuario, id_banco, id_zona_actual, numero_cuenta,
                    saldo_acumulado_usd, habilitado, disponible)
VALUES (@id_usuario_chofer, @id_banco, @id_zona,
        '01020123456789012345', 0.00, 1, 1);
SET @id_chofer = LAST_INSERT_ID();

INSERT INTO vehiculo (id_chofer, placa, marca, modelo,
                      anio_fabricacion, color, activo)
VALUES (@id_chofer, 'AB123CD', 'Toyota', 'Corolla', 2020, 'Blanco', 1);
SET @id_vehiculo = LAST_INSERT_ID();

-- Fechas dinámicas: siempre dentro del último año (3 meses atrás)
INSERT INTO evaluacion_psicologica (id_chofer, id_admin, calificacion,
                                     fecha_eval, observacion)
VALUES (@id_chofer, @id_admin, 85.00,
        DATE_SUB(CURDATE(), INTERVAL 3 MONTH),
        'Evaluación aprobada sin observaciones.');

INSERT INTO revision_vehiculo (id_vehiculo, id_admin, calificacion,
                                fecha_revision, observacion)
VALUES (@id_vehiculo, @id_admin, 90.00,
        DATE_SUB(CURDATE(), INTERVAL 3 MONTH),
        'Vehículo en óptimas condiciones.');

INSERT INTO contacto_emergencia (id_chofer, nombre, telefono, parentesco)
VALUES
    (@id_chofer, 'Ana Rodríguez',   '0414-5234568', 'Esposa'),
    (@id_chofer, 'Pedro Rodríguez', '0414-5234569', 'Padre');

-- ----------------------------------------------------------------
-- USUARIO CLIENTE ESTUDIANTE con saldo
-- primer_viaje_usado = 0 para que aplique el beneficio de primer viaje
-- ----------------------------------------------------------------
INSERT INTO usuario (cedula, nombre, apellido, username, password_hash,
                     email, telefono, rol)
VALUES ('V20123456', 'Laura', 'Pérez', 'laurap',
        '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i',
        'laura.perez@test.ve', '0416-1234567', 'cliente');
SET @id_usuario_cliente = LAST_INSERT_ID();

INSERT INTO cliente (id_usuario, saldo_usd, es_estudiante, primer_viaje_usado)
VALUES (@id_usuario_cliente, 20.00, 1, 0);

-- ----------------------------------------------------------------
-- TASA BCV — necesaria para calcular tarifa y mostrar precio en VES
-- ----------------------------------------------------------------
INSERT INTO tasa_bcv (fecha_vigencia, tasa_ves, registrado_por) VALUES ('2026-06-22', 620.00, @id_admin);
INSERT INTO tasa_bcv (fecha_vigencia, tasa_ves, registrado_por) VALUES ('2026-06-25', 621.52, @id_admin);
INSERT INTO tasa_bcv (fecha_vigencia, tasa_ves, registrado_por) VALUES ('2026-06-26', 622.21, @id_admin);

-- ================================================================
-- SECCIÓN HISTORIAL — viajes y recargas de prueba
-- Permite que el historial del cliente y el panel del chofer
-- tengan datos reales para las pruebas del equipo.
-- ================================================================

-- IDs de los usuarios recién insertados
SET @id_cliente_laurap   = (SELECT cl.id FROM cliente cl JOIN usuario u ON cl.id_usuario = u.id WHERE u.username = 'laurap');
SET @id_usuario_laurap   = (SELECT id FROM usuario WHERE username = 'laurap');
SET @id_chofer_carlosr   = (SELECT c.id  FROM chofer  c JOIN usuario u ON c.id_usuario  = u.id WHERE u.username = 'carlosr');
SET @id_usuario_carlosr  = (SELECT id FROM usuario WHERE username = 'carlosr');
SET @id_vehiculo_carlosr = (SELECT v.id FROM vehiculo v JOIN chofer c ON v.id_chofer = c.id JOIN usuario u ON c.id_usuario = u.id WHERE u.username = 'carlosr' LIMIT 1);

-- IDs de las tasas BCV recién insertadas
SET @id_tasa_620 = (SELECT id FROM tasa_bcv WHERE tasa_ves = 620.00 LIMIT 1);
SET @id_tasa_621 = (SELECT id FROM tasa_bcv WHERE tasa_ves = 621.52 LIMIT 1);
SET @id_tasa_622 = (SELECT id FROM tasa_bcv WHERE tasa_ves = 622.21 LIMIT 1);

-- ----------------------------------------------------------------
-- RECARGAS DE SALDO — laurap (3 recargas históricas)
-- ----------------------------------------------------------------

-- Recarga 1: VES, hace 7 días, tasa 620.00 → $10.00 USD
INSERT INTO recarga_saldo (id_cliente, id_banco, id_tasa, monto_usd, monto_ves,
                            referencia, fecha_hora, moneda_pago, igtf_porcentaje, igtf_monto_usd)
VALUES (@id_cliente_laurap, @id_banco, @id_tasa_620,
        10.00, 6200.00, 'TRF-2026061901',
        DATE_SUB(NOW(), INTERVAL 7 DAY), 'VES', 0.00, 0.00);

-- Recarga 2: VES, hace 4 días, tasa 621.52 → $15.00 USD
INSERT INTO recarga_saldo (id_cliente, id_banco, id_tasa, monto_usd, monto_ves,
                            referencia, fecha_hora, moneda_pago, igtf_porcentaje, igtf_monto_usd)
VALUES (@id_cliente_laurap, @id_banco, @id_tasa_621,
        15.00, 9322.80, 'TRF-2026062201',
        DATE_SUB(NOW(), INTERVAL 4 DAY), 'VES', 0.00, 0.00);

-- Recarga 3: USD directo, hace 2 días, IGTF 3% → $20.00 USD
INSERT INTO recarga_saldo (id_cliente, id_banco, id_tasa, monto_usd, monto_ves,
                            referencia, fecha_hora, moneda_pago, igtf_porcentaje, igtf_monto_usd)
VALUES (@id_cliente_laurap, NULL, @id_tasa_622,
        20.00, 12444.20, 'USD-2026062401',
        DATE_SUB(NOW(), INTERVAL 2 DAY), 'USD', 3.00, 0.60);

-- Notificaciones de las 3 recargas
INSERT INTO notificacion (id_usuario, tipo, mensaje, leida, fecha_hora) VALUES
  (@id_usuario_laurap, 'recarga_acreditada',
   'Recarga acreditada: $10.00 USD (Bs 6.200,00) procesada exitosamente.',
   1, DATE_SUB(NOW(), INTERVAL 7 DAY)),
  (@id_usuario_laurap, 'recarga_acreditada',
   'Recarga acreditada: $15.00 USD (Bs 9.322,80) procesada exitosamente.',
   1, DATE_SUB(NOW(), INTERVAL 4 DAY)),
  (@id_usuario_laurap, 'recarga_acreditada',
   'Recarga acreditada: $20.00 USD procesada exitosamente.',
   0, DATE_SUB(NOW(), INTERVAL 2 DAY));

-- ----------------------------------------------------------------
-- VIAJE 1 — COMPLETADO (hace 6 días)
-- Alta Vista Norte → Centro Cívico | PRIMER VIAJE GRATIS
-- El cliente paga $0.00; la empresa subsidia 70% al chofer.
-- ----------------------------------------------------------------
INSERT INTO traslado (
  id_cliente, id_chofer, id_vehiculo,
  id_zona_origen, id_zona_destino, id_tasa,
  nro_pasajeros, distancia_km,
  tarifa_base_usd, recargo_horario_usd, factor_hora_pico,
  descuento_usd, costo_cliente_usd, monto_chofer_usd, monto_empresa_usd, costo_cliente_ves,
  estado, calificacion_estrellas, comentario_cliente,
  intentos_asignacion, rechazos,
  fecha_solicitud, fecha_aceptacion, fecha_inicio, fecha_fin, duracion_minutos
) VALUES (
  @id_cliente_laurap, @id_chofer_carlosr, @id_vehiculo_carlosr,
  @id_zona_alta_vista_norte, @id_zona_centro_civico, @id_tasa_620,
  1, 2.20,
  1.00, 0.00, 1.00,
  1.99, 0.00, 1.39, -1.39, 0.00,
  'completado', 5, 'Excelente primer viaje, muy amable el chofer.',
  1, 0,
  DATE_SUB(NOW(), INTERVAL 6 DAY),
  DATE_ADD(DATE_SUB(NOW(), INTERVAL 6 DAY), INTERVAL 3  MINUTE),
  DATE_ADD(DATE_SUB(NOW(), INTERVAL 6 DAY), INTERVAL 8  MINUTE),
  DATE_ADD(DATE_SUB(NOW(), INTERVAL 6 DAY), INTERVAL 15 MINUTE),
  7
);
SET @id_viaje1 = LAST_INSERT_ID();

-- Factura viaje 1 (monto $0, IGTF $0)
INSERT INTO factura (id_traslado, nro_documento, nro_control, serie,
                     razon_social, rif_cedula, direccion_fiscal,
                     igtf_porcentaje, igtf_monto_usd)
SELECT @id_viaje1,
  CONCAT('FAC-', LPAD(@id_viaje1, 8, '0')),
  CONCAT('00-',  LPAD(@id_viaje1, 8, '0')),
  'A',
  CONCAT(u.nombre, ' ', u.apellido), u.cedula,
  'Ciudad Guayana, Venezuela',
  3.00, 0.00
FROM cliente cl JOIN usuario u ON cl.id_usuario = u.id WHERE cl.id = @id_cliente_laurap;

-- Notificaciones viaje 1
INSERT INTO notificacion (id_usuario, id_traslado, tipo, mensaje, leida, fecha_hora) VALUES
  (@id_usuario_laurap, @id_viaje1, 'chofer_asignado',
   'Tu chofer fue asignado y va en camino hacia tu ubicación.',
   1, DATE_ADD(DATE_SUB(NOW(), INTERVAL 6 DAY), INTERVAL 2  MINUTE)),
  (@id_usuario_laurap, @id_viaje1, 'viaje_completado',
   'Viaje completado. Total: $0.00 USD (primer viaje gratis). ¡Califica tu experiencia!',
   1, DATE_ADD(DATE_SUB(NOW(), INTERVAL 6 DAY), INTERVAL 15 MINUTE)),
  (@id_usuario_laurap, @id_viaje1, 'factura_emitida',
   'Tu factura electrónica fue generada y está disponible.',
   1, DATE_ADD(DATE_SUB(NOW(), INTERVAL 6 DAY), INTERVAL 16 MINUTE)),
  (@id_usuario_carlosr, @id_viaje1, 'viaje_completado',
   'Viaje completado. Ganaste: $1.39 USD.',
   1, DATE_ADD(DATE_SUB(NOW(), INTERVAL 6 DAY), INTERVAL 15 MINUTE));

-- ----------------------------------------------------------------
-- VIAJE 2 — COMPLETADO (hace 3 días)
-- Alta Vista Norte → UNEG Sede Atlántico | DESCUENTO ESTUDIANTE 30%
-- ----------------------------------------------------------------
INSERT INTO traslado (
  id_cliente, id_chofer, id_vehiculo,
  id_zona_origen, id_zona_destino, id_tasa,
  nro_pasajeros, distancia_km,
  tarifa_base_usd, recargo_horario_usd, factor_hora_pico,
  descuento_usd, costo_cliente_usd, monto_chofer_usd, monto_empresa_usd, costo_cliente_ves,
  estado, calificacion_estrellas, comentario_cliente,
  intentos_asignacion, rechazos,
  fecha_solicitud, fecha_aceptacion, fecha_inicio, fecha_fin, duracion_minutos
) VALUES (
  @id_cliente_laurap, @id_chofer_carlosr, @id_vehiculo_carlosr,
  @id_zona_alta_vista_norte, @id_zona_uneg_atlantico, @id_tasa_621,
  1, 6.50,
  1.00, 0.00, 1.00,
  1.18, 2.75, 2.75, 0.00, 1709.18,
  'completado', 5, 'Muy buen servicio, llegué a tiempo a clases.',
  1, 0,
  DATE_SUB(NOW(), INTERVAL 3 DAY),
  DATE_ADD(DATE_SUB(NOW(), INTERVAL 3 DAY), INTERVAL 4  MINUTE),
  DATE_ADD(DATE_SUB(NOW(), INTERVAL 3 DAY), INTERVAL 10 MINUTE),
  DATE_ADD(DATE_SUB(NOW(), INTERVAL 3 DAY), INTERVAL 25 MINUTE),
  15
);
SET @id_viaje2 = LAST_INSERT_ID();

-- Factura viaje 2
INSERT INTO factura (id_traslado, nro_documento, nro_control, serie,
                     razon_social, rif_cedula, direccion_fiscal,
                     igtf_porcentaje, igtf_monto_usd)
SELECT @id_viaje2,
  CONCAT('FAC-', LPAD(@id_viaje2, 8, '0')),
  CONCAT('00-',  LPAD(@id_viaje2, 8, '0')),
  'A',
  CONCAT(u.nombre, ' ', u.apellido), u.cedula,
  'Ciudad Guayana, Venezuela',
  3.00, ROUND(2.75 * 0.03, 2)
FROM cliente cl JOIN usuario u ON cl.id_usuario = u.id WHERE cl.id = @id_cliente_laurap;

-- Notificaciones viaje 2
INSERT INTO notificacion (id_usuario, id_traslado, tipo, mensaje, leida, fecha_hora) VALUES
  (@id_usuario_laurap, @id_viaje2, 'chofer_asignado',
   'Tu chofer fue asignado y va en camino hacia tu ubicación.',
   1, DATE_ADD(DATE_SUB(NOW(), INTERVAL 3 DAY), INTERVAL 3  MINUTE)),
  (@id_usuario_laurap, @id_viaje2, 'viaje_completado',
   'Viaje completado. Total: $2.75 USD. ¡Califica tu experiencia!',
   1, DATE_ADD(DATE_SUB(NOW(), INTERVAL 3 DAY), INTERVAL 25 MINUTE)),
  (@id_usuario_laurap, @id_viaje2, 'factura_emitida',
   'Tu factura electrónica fue generada y está disponible.',
   1, DATE_ADD(DATE_SUB(NOW(), INTERVAL 3 DAY), INTERVAL 26 MINUTE)),
  (@id_usuario_carlosr, @id_viaje2, 'viaje_completado',
   'Viaje completado. Ganaste: $2.75 USD.',
   1, DATE_ADD(DATE_SUB(NOW(), INTERVAL 3 DAY), INTERVAL 25 MINUTE));

-- ----------------------------------------------------------------
-- VIAJE 3 — CANCELADO POR CLIENTE (ayer)
-- Castillito → Orinokia Mall | Cancelado en estado solicitado
-- Sin impacto financiero (montos en cero).
-- ----------------------------------------------------------------
INSERT INTO traslado (
  id_cliente, id_chofer, id_vehiculo,
  id_zona_origen, id_zona_destino, id_tasa,
  nro_pasajeros, distancia_km,
  tarifa_base_usd, recargo_horario_usd, factor_hora_pico,
  descuento_usd, costo_cliente_usd, monto_chofer_usd, monto_empresa_usd, costo_cliente_ves,
  estado, cancelado_por, motivo_cancelacion,
  intentos_asignacion, rechazos,
  fecha_solicitud
) VALUES (
  @id_cliente_laurap, @id_chofer_carlosr, @id_vehiculo_carlosr,
  @id_zona_castillito, @id_zona_orinokia_mall, @id_tasa_622,
  1, 4.80,
  1.00, 0.00, 1.00,
  0.00, 0.00, 0.00, 0.00, 0.00,
  'cancelado', 'cliente', 'Cambié de planes.',
  1, 0,
  DATE_SUB(NOW(), INTERVAL 1 DAY)
);
SET @id_viaje3 = LAST_INSERT_ID();

INSERT INTO notificacion (id_usuario, id_traslado, tipo, mensaje, leida, fecha_hora) VALUES
  (@id_usuario_laurap, @id_viaje3, 'viaje_cancelado',
   'Tu viaje fue cancelado. Motivo: Cambié de planes.',
   1, DATE_SUB(NOW(), INTERVAL 1 DAY));

-- ----------------------------------------------------------------
-- VIAJE 4 — COMPLETADO (hace 5 días) — segunda ruta de carlosr
-- Castillito → Parque Cachamay | Sin descuentos
-- ----------------------------------------------------------------
INSERT INTO traslado (
  id_cliente, id_chofer, id_vehiculo,
  id_zona_origen, id_zona_destino, id_tasa,
  nro_pasajeros, distancia_km,
  tarifa_base_usd, recargo_horario_usd, factor_hora_pico,
  descuento_usd, costo_cliente_usd, monto_chofer_usd, monto_empresa_usd, costo_cliente_ves,
  estado,
  intentos_asignacion, rechazos,
  fecha_solicitud, fecha_aceptacion, fecha_inicio, fecha_fin, duracion_minutos
) VALUES (
  @id_cliente_laurap, @id_chofer_carlosr, @id_vehiculo_carlosr,
  @id_zona_castillito, @id_zona_parque_cachamay, @id_tasa_620,
  1, 2.50,
  1.00, 0.00, 1.00,
  0.00, 2.13, 1.49, 0.64, 1320.60,
  'completado',
  1, 0,
  DATE_SUB(NOW(), INTERVAL 5 DAY),
  DATE_ADD(DATE_SUB(NOW(), INTERVAL 5 DAY), INTERVAL 5  MINUTE),
  DATE_ADD(DATE_SUB(NOW(), INTERVAL 5 DAY), INTERVAL 9  MINUTE),
  DATE_ADD(DATE_SUB(NOW(), INTERVAL 5 DAY), INTERVAL 17 MINUTE),
  8
);
SET @id_viaje4 = LAST_INSERT_ID();

-- Factura viaje 4
INSERT INTO factura (id_traslado, nro_documento, nro_control, serie,
                     razon_social, rif_cedula, direccion_fiscal,
                     igtf_porcentaje, igtf_monto_usd)
SELECT @id_viaje4,
  CONCAT('FAC-', LPAD(@id_viaje4, 8, '0')),
  CONCAT('00-',  LPAD(@id_viaje4, 8, '0')),
  'A',
  CONCAT(u.nombre, ' ', u.apellido), u.cedula,
  'Ciudad Guayana, Venezuela',
  3.00, ROUND(2.13 * 0.03, 2)
FROM cliente cl JOIN usuario u ON cl.id_usuario = u.id WHERE cl.id = @id_cliente_laurap;

INSERT INTO notificacion (id_usuario, id_traslado, tipo, mensaje, leida, fecha_hora) VALUES
  (@id_usuario_carlosr, @id_viaje4, 'viaje_completado',
   'Viaje completado. Ganaste: $1.49 USD.',
   1, DATE_ADD(DATE_SUB(NOW(), INTERVAL 5 DAY), INTERVAL 17 MINUTE));

-- ----------------------------------------------------------------
-- VIAJE 5 — ACTIVO EN ESTADO "aceptado" (hace 30 minutos)
-- Alta Vista Sur → Los Helechos | Simulación para el panel del chofer
-- IMPORTANTE: cambiar a completado antes de hacer la prueba punta a punta.
-- ----------------------------------------------------------------
INSERT INTO traslado (
  id_cliente, id_chofer, id_vehiculo,
  id_zona_origen, id_zona_destino, id_tasa,
  nro_pasajeros, distancia_km,
  tarifa_base_usd, recargo_horario_usd, factor_hora_pico,
  descuento_usd, costo_cliente_usd, monto_chofer_usd, monto_empresa_usd, costo_cliente_ves,
  estado,
  intentos_asignacion, rechazos,
  fecha_solicitud, fecha_aceptacion
) VALUES (
  @id_cliente_laurap, @id_chofer_carlosr, @id_vehiculo_carlosr,
  @id_zona_alta_vista_sur, @id_zona_los_helechos, @id_tasa_622,
  1, 3.20,
  1.00, 0.00, 1.00,
  0.00, 2.44, 1.71, 0.73, 1518.19,
  'aceptado',
  1, 0,
  DATE_SUB(NOW(), INTERVAL 30 MINUTE),
  DATE_SUB(NOW(), INTERVAL 25 MINUTE)
);
SET @id_viaje5 = LAST_INSERT_ID();

INSERT INTO notificacion (id_usuario, id_traslado, tipo, mensaje, leida, fecha_hora) VALUES
  (@id_usuario_laurap, @id_viaje5, 'chofer_asignado',
   'Tu chofer fue asignado y va en camino hacia tu ubicación.',
   0, DATE_SUB(NOW(), INTERVAL 25 MINUTE));

-- ----------------------------------------------------------------
-- ACTUALIZAR SALDOS — reflejar las transacciones del historial
-- laurap: $20 iniciales + $45 recargas − $0 (gratis) − $2.75 − $0 (cancelado) − $2.13 = $60.12
-- carlosr: viaje1 $1.39 + viaje2 $2.75 + viaje4 $1.49 = $5.63
-- ----------------------------------------------------------------
UPDATE cliente SET saldo_usd = 60.12, primer_viaje_usado = 1 WHERE id = @id_cliente_laurap;
UPDATE chofer   SET saldo_acumulado_usd = 5.63               WHERE id = @id_chofer_carlosr;

COMMIT;

-- Restaurar el modo seguro de Workbench
SET SQL_SAFE_UPDATES = 1;

-- ================================================================
-- VERIFICACIÓN ESPECÍFICA — muestra solo los registros de prueba
-- creados por este script, con sus campos relevantes.
-- ================================================================
SELECT 'CHOFER' AS entidad, u.username, u.nombre, u.apellido,
       c.habilitado, c.disponible, c.saldo_acumulado_usd
FROM usuario u
JOIN chofer c ON c.id_usuario = u.id
WHERE u.username = 'carlosr';

SELECT 'VEHICULO' AS entidad, v.placa, v.marca, v.modelo, v.anio_fabricacion
FROM vehiculo v
JOIN chofer c ON v.id_chofer = c.id
JOIN usuario u ON c.id_usuario = u.id
WHERE u.username = 'carlosr';

SELECT 'EVALUACION' AS entidad, ep.calificacion, ep.fecha_eval, ep.aprobado
FROM evaluacion_psicologica ep
JOIN chofer c ON ep.id_chofer = c.id
JOIN usuario u ON c.id_usuario = u.id
WHERE u.username = 'carlosr';

SELECT 'REVISION' AS entidad, rv.calificacion, rv.fecha_revision, rv.apto
FROM revision_vehiculo rv
JOIN vehiculo v ON rv.id_vehiculo = v.id
JOIN chofer c ON v.id_chofer = c.id
JOIN usuario u ON c.id_usuario = u.id
WHERE u.username = 'carlosr';

SELECT 'CONTACTOS' AS entidad, ce.nombre, ce.telefono, ce.parentesco
FROM contacto_emergencia ce
JOIN chofer c ON ce.id_chofer = c.id
JOIN usuario u ON c.id_usuario = u.id
WHERE u.username = 'carlosr';

SELECT 'CLIENTE' AS entidad, u.username, cl.saldo_usd, cl.es_estudiante, cl.primer_viaje_usado
FROM usuario u
JOIN cliente cl ON cl.id_usuario = u.id
WHERE u.username = 'laurap';

-- Verificaciones del historial insertado
SELECT 'RECARGAS_LAURAP' AS entidad,
       r.referencia, r.monto_usd, r.monto_ves, r.moneda_pago, r.fecha_hora
FROM recarga_saldo r
JOIN cliente cl ON r.id_cliente = cl.id
JOIN usuario  u  ON cl.id_usuario = u.id
WHERE u.username = 'laurap'
ORDER BY r.fecha_hora;

SELECT 'TRASLADOS' AS entidad,
       t.id, t.estado, t.distancia_km,
       t.costo_cliente_usd, t.monto_chofer_usd,
       t.calificacion_estrellas, t.fecha_solicitud
FROM traslado t
JOIN cliente cl ON t.id_cliente = cl.id
JOIN usuario  u  ON cl.id_usuario = u.id
WHERE u.username = 'laurap'
ORDER BY t.fecha_solicitud;

SELECT 'FACTURAS' AS entidad,
       f.nro_documento, f.igtf_porcentaje, f.igtf_monto_usd, f.razon_social
FROM factura f
JOIN traslado t  ON f.id_traslado = t.id
JOIN cliente  cl ON t.id_cliente  = cl.id
JOIN usuario  u  ON cl.id_usuario = u.id
WHERE u.username = 'laurap'
ORDER BY f.id;

SELECT 'NOTIF_LAURAP' AS entidad, n.tipo, n.leida, n.fecha_hora
FROM notificacion n
JOIN usuario u ON n.id_usuario = u.id
WHERE u.username = 'laurap'
ORDER BY n.fecha_hora;

SELECT 'SALDO_CARLOSR' AS entidad,
       u.username, c.saldo_acumulado_usd, c.habilitado, c.disponible
FROM chofer c JOIN usuario u ON c.id_usuario = u.id
WHERE u.username = 'carlosr';

-- ================================================================
-- SECCIÓN ÁNGEL — Datos de Prueba · Panel Administrativo
-- Usuarios adicionales: 2 personal_admin + 3 choferes en estados
-- distintos + 2 clientes. Contraseña igual a carlosr y laurap.
-- ================================================================

SET SQL_SAFE_UPDATES = 0;

-- ----------------------------------------------------------------
-- LIMPIEZA PREVIA — solo los usuarios de esta sección
-- ----------------------------------------------------------------
SET FOREIGN_KEY_CHECKS = 0;

DELETE FROM evaluacion_psicologica
  WHERE id_chofer IN (
    SELECT id FROM (
      SELECT c.id FROM chofer c JOIN usuario u ON c.id_usuario = u.id
      WHERE u.username IN ('miguelch', 'robertoch', 'anach')
    ) AS tmp);

DELETE FROM revision_vehiculo
  WHERE id_vehiculo IN (
    SELECT id FROM (
      SELECT v.id FROM vehiculo v
      JOIN chofer c ON v.id_chofer = c.id
      JOIN usuario u ON c.id_usuario = u.id
      WHERE u.username IN ('miguelch', 'robertoch', 'anach')
    ) AS tmp);

DELETE FROM contacto_emergencia
  WHERE id_chofer IN (
    SELECT id FROM (
      SELECT c.id FROM chofer c JOIN usuario u ON c.id_usuario = u.id
      WHERE u.username IN ('miguelch', 'robertoch', 'anach')
    ) AS tmp);

DELETE FROM vehiculo
  WHERE id_chofer IN (
    SELECT id FROM (
      SELECT c.id FROM chofer c JOIN usuario u ON c.id_usuario = u.id
      WHERE u.username IN ('miguelch', 'robertoch', 'anach')
    ) AS tmp);

DELETE FROM chofer
  WHERE id_usuario IN (
    SELECT id FROM (SELECT id FROM usuario
      WHERE username IN ('miguelch', 'robertoch', 'anach')) AS tmp);

DELETE FROM cliente
  WHERE id_usuario IN (
    SELECT id FROM (SELECT id FROM usuario
      WHERE username IN ('josecl', 'marycl')) AS tmp);

DELETE FROM personal_admin
  WHERE id_usuario IN (
    SELECT id FROM (SELECT id FROM usuario
      WHERE username IN ('luisapa', 'pedrop')) AS tmp);

DELETE FROM usuario
  WHERE username IN ('miguelch', 'robertoch', 'anach', 'josecl', 'marycl', 'luisapa', 'pedrop');

SET FOREIGN_KEY_CHECKS = 1;

-- ----------------------------------------------------------------
-- PERSONAL ADMINISTRATIVO — para loguear con rol personal_admin
-- ----------------------------------------------------------------
SET @hash_angel = '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i';

INSERT INTO usuario (cedula, nombre, apellido, username, password_hash, email, telefono, rol) VALUES
('V-20000001', 'Luisa', 'Padrón',  'luisapa', @hash_angel, 'luisapa@test.ve', '0414-2000001', 'personal_admin'),
('V-20000002', 'Pedro', 'Paredes', 'pedrop',  @hash_angel, 'pedrop@test.ve',  '0416-2000002', 'personal_admin');

SET @u_luisapa = (SELECT id FROM usuario WHERE username = 'luisapa');
SET @u_pedrop  = (SELECT id FROM usuario WHERE username = 'pedrop');

INSERT INTO personal_admin (id_usuario, cargo) VALUES
(@u_luisapa, 'Coordinador de Choferes'),
(@u_pedrop,  'Analista de Reportes');

SET @pa_luisa = (SELECT id FROM personal_admin WHERE id_usuario = @u_luisapa);
SET @pa_pedro = (SELECT id FROM personal_admin WHERE id_usuario = @u_pedrop);

-- ----------------------------------------------------------------
-- CHOFER A — HABILITADO (evaluación + revisión aprobadas)
-- Aparece en GET /api/admin/choferes como habilitado=true
-- ----------------------------------------------------------------
INSERT INTO usuario (cedula, nombre, apellido, username, password_hash, email, telefono, rol) VALUES
('V-20000003', 'Miguel', 'Torres', 'miguelch', @hash_angel, 'miguelch@test.ve', '0424-2000003', 'chofer');
SET @u_miguel = LAST_INSERT_ID();

INSERT INTO chofer (id_usuario, id_banco, id_zona_actual, numero_cuenta,
                    saldo_acumulado_usd, habilitado, disponible)
VALUES (@u_miguel, @id_banco, @id_zona, '01020000000000000011', 42.00, 1, 1);
SET @ch_miguel = LAST_INSERT_ID();

INSERT INTO vehiculo (id_chofer, placa, marca, modelo, anio_fabricacion, color, activo)
VALUES (@ch_miguel, 'EF456GH', 'Chevrolet', 'Aveo', 2018, 'Gris', 1);
SET @v_miguel = LAST_INSERT_ID();

INSERT INTO evaluacion_psicologica (id_chofer, id_admin, calificacion, fecha_eval, observacion)
VALUES (@ch_miguel, @pa_luisa, 80.00,
        DATE_SUB(CURDATE(), INTERVAL 2 MONTH), 'Aprobado sin observaciones.');

INSERT INTO revision_vehiculo (id_vehiculo, id_admin, calificacion, fecha_revision, observacion)
VALUES (@v_miguel, @pa_pedro, 88.00,
        DATE_SUB(CURDATE(), INTERVAL 2 MONTH), 'Vehículo en buenas condiciones.');

INSERT INTO contacto_emergencia (id_chofer, nombre, telefono, parentesco)
VALUES (@ch_miguel, 'Carmen Torres', '0414-2000010', 'Madre');

-- ----------------------------------------------------------------
-- CHOFER B — EN PROCESO (psico aprobada, sin revisión vehicular)
-- habilitado permanece 0 hasta que tenga revisión aprobada
-- ----------------------------------------------------------------
INSERT INTO usuario (cedula, nombre, apellido, username, password_hash, email, telefono, rol) VALUES
('V-20000004', 'Roberto', 'Díaz', 'robertoch', @hash_angel, 'robertoch@test.ve', '0426-2000004', 'chofer');
SET @u_roberto = LAST_INSERT_ID();

INSERT INTO chofer (id_usuario, id_banco, id_zona_actual, numero_cuenta,
                    saldo_acumulado_usd, habilitado, disponible)
VALUES (@u_roberto, @id_banco, @id_zona, '01020000000000000022', 0.00, 0, 0);
SET @ch_roberto = LAST_INSERT_ID();

INSERT INTO vehiculo (id_chofer, placa, marca, modelo, anio_fabricacion, color, activo)
VALUES (@ch_roberto, 'IJ789KL', 'Ford', 'Fiesta', 2017, 'Azul', 1);

INSERT INTO evaluacion_psicologica (id_chofer, id_admin, calificacion, fecha_eval, observacion)
VALUES (@ch_roberto, @pa_luisa, 75.00,
        DATE_SUB(CURDATE(), INTERVAL 1 MONTH), 'Aprobado. Pendiente revisión vehicular.');
-- Sin revisión vehicular → habilitado = 0

-- ----------------------------------------------------------------
-- CHOFER C — SIN HABILITAR (recién registrado, sin nada)
-- ----------------------------------------------------------------
INSERT INTO usuario (cedula, nombre, apellido, username, password_hash, email, telefono, rol) VALUES
('V-20000005', 'Ana', 'Gómez', 'anach', @hash_angel, 'anach@test.ve', '0412-2000005', 'chofer');
SET @u_ana = LAST_INSERT_ID();

INSERT INTO chofer (id_usuario, id_banco, id_zona_actual, numero_cuenta,
                    saldo_acumulado_usd, habilitado, disponible)
VALUES (@u_ana, @id_banco, @id_zona, '01020000000000000033', 0.00, 0, 0);
-- Sin vehículo ni evaluaciones — debe aparecer como pendiente en el panel

-- ----------------------------------------------------------------
-- CLIENTES ADICIONALES
-- ----------------------------------------------------------------
INSERT INTO usuario (cedula, nombre, apellido, username, password_hash, email, telefono, rol) VALUES
('V-20000006', 'José',  'Ramírez', 'josecl', @hash_angel, 'josecl@test.ve', '0416-2000006', 'cliente'),
('V-20000007', 'María', 'Blanco',  'marycl', @hash_angel, 'marycl@test.ve',  '0414-2000007', 'cliente');

SET @u_jose = (SELECT id FROM usuario WHERE username = 'josecl');
SET @u_mary = (SELECT id FROM usuario WHERE username = 'marycl');

INSERT INTO cliente (id_usuario, saldo_usd, es_estudiante, primer_viaje_usado) VALUES
(@u_jose, 15.00, 0, 0),
(@u_mary,  5.50, 1, 0);

-- ----------------------------------------------------------------
-- VERIFICACIÓN — panel de Ángel
-- ----------------------------------------------------------------
SELECT 'PERSONAL_ADMIN' AS entidad, u.username, pa.cargo
FROM personal_admin pa JOIN usuario u ON pa.id_usuario = u.id
WHERE u.username IN ('luisapa', 'pedrop');

SELECT 'CHOFERES' AS entidad, u.username, u.nombre,
       c.habilitado, c.disponible, c.saldo_acumulado_usd
FROM chofer c JOIN usuario u ON c.id_usuario = u.id
WHERE u.username IN ('miguelch', 'robertoch', 'anach')
ORDER BY c.habilitado DESC;

SELECT 'CLIENTES' AS entidad, u.username, u.nombre,
       cl.saldo_usd, cl.es_estudiante, cl.primer_viaje_usado
FROM cliente cl JOIN usuario u ON cl.id_usuario = u.id
WHERE u.username IN ('josecl', 'marycl');

SET SQL_SAFE_UPDATES = 1;