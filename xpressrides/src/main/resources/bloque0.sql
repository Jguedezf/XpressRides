-- ================================================================
--  XpressRides (Decarrerita) â€” Sistemas de Base de Datos I
--  UNEG Â· Prof. MarÃ­a Raquel Herrera E. Â· Junio 2026
--  Equipo: Johanna GuÃ©dez Â· Eliuber GonzÃ¡lez Â· Freddy Salazar
--          Manuel Jaimes Â· Ãngel MartÃ­nez
-- ================================================================
--  Archivo:     datos_prueba.sql
--  MÃ³dulo:      Datos semilla (seed data) para pruebas
--  DescripciÃ³n: Inserta un escenario completo y funcional para
--               probar el flujo de solicitud de traslado:
--               1 chofer totalmente habilitado (con evaluaciÃ³n
--               psicolÃ³gica aprobada, revisiÃ³n vehicular aprobada,
--               vehÃ­culo activo y 2 contactos de emergencia) y
--               1 cliente estudiante con saldo disponible.
--
--               Es idempotente: puede ejecutarse mÃºltiples veces
--               sin generar duplicados (limpia datos previos de
--               prueba antes de insertar). Usa transacciÃ³n para
--               garantizar consistencia y resuelve los IDs por
--               nombre para no depender de valores fijos.
--
--  Uso:         Ejecutar completo en MySQL Workbench sobre la BD
--               'decarrerita' DESPUÃ‰S de cargar decarrerita.sql.
--               Seleccionar (Ctrl+A) y ejecutar (rayo).
--
--  VersiÃ³n:     1.3.0
--  Fecha:       28/06/2026
-- ================================================================

USE decarrerita;

-- FIX Error 1175: Desactiva safe update mode de MySQL Workbench
SET SQL_SAFE_UPDATES = 0;

-- ================================================================
-- BLOQUE 0: ACTUALIZACIONES DE ESQUEMA (DDL)
-- DDL no puede ir dentro de un TRANSACTION en MySQL â€” cada ALTER/
-- CREATE INDEX / DROP TRIGGER hace commit implÃ­cito automÃ¡tico.
-- Se ejecutan con IF NOT EXISTS para que el script sea idempotente
-- tanto sobre una BD reciÃ©n creada como sobre una BD existente.
-- ================================================================

-- 0.1 Ampliar ENUM notificacion.tipo con los valores que faltaban
--     'chofer_llego' â†’ notificaciÃ³n cuando el chofer llega al origen
--     'sin_chofer'   â†’ ya usado en Java (TripRejectionService) pero faltaba en la BD
ALTER TABLE notificacion
  MODIFY COLUMN tipo ENUM(
    'viaje_solicitado','chofer_asignado','chofer_en_camino',
    'chofer_llego','viaje_iniciado','viaje_completado','factura_emitida',
    'pago_recibido','recarga_acreditada','viaje_cancelado','sin_chofer'
  ) NOT NULL;

-- 0.2 Ãndice compuesto para el conteo del badge de notificaciones
--     Cubre: countByUser_IdAndReadFalse â€” consultado cada 15 s por cada usuario activo
--     Se verifica en information_schema.STATISTICS antes de crear para que el
--     script sea idempotente en cualquier versiÃ³n de MySQL
SET @existe = (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE table_schema = DATABASE()
      AND table_name   = 'notificacion'
      AND index_name   = 'idx_notif_usuario_leida');
SET @sql = IF(@existe = 0,
    'CREATE INDEX idx_notif_usuario_leida ON notificacion(id_usuario, leida)',
    'SELECT ''idx_notif_usuario_leida: ya existe, se omite''');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 0.3 Ãndice compuesto para el polling de viaje activo del cliente
--     Cubre: GET /api/cliente/viaje-activo â€” consultado cada 5 s durante un viaje
SET @existe = (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE table_schema = DATABASE()
      AND table_name   = 'traslado'
      AND index_name   = 'idx_traslado_cliente_estado');
SET @sql = IF(@existe = 0,
    'CREATE INDEX idx_traslado_cliente_estado ON traslado(id_cliente, estado)',
    'SELECT ''idx_traslado_cliente_estado: ya existe, se omite''');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 0.4 Trigger actualizado: agrega notificaciÃ³n para estado 'chofer_llego'
--     El trigger original no cubrÃ­a este estado â€” el cliente nunca recibÃ­a
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
      'Tu chofer fue asignado y va en camino hacia tu ubicaciÃ³n.');
  END IF;

  IF NEW.estado = 'en_camino' AND OLD.estado <> 'en_camino' THEN
    INSERT INTO notificacion (id_usuario, id_traslado, tipo, mensaje)
    VALUES (v_id_usuario_cliente, NEW.id, 'chofer_en_camino',
      'Tu chofer estÃ¡ en camino al punto de recogida.');
  END IF;

  IF NEW.estado = 'chofer_llego' AND OLD.estado <> 'chofer_llego' THEN
    INSERT INTO notificacion (id_usuario, id_traslado, tipo, mensaje)
    VALUES (v_id_usuario_cliente, NEW.id, 'chofer_llego',
      'Tu chofer llegÃ³ al punto de recogida. Â¡EstÃ¡ esperÃ¡ndote!');
  END IF;

  IF NEW.estado = 'en_progreso' AND OLD.estado <> 'en_progreso' THEN
    INSERT INTO notificacion (id_usuario, id_traslado, tipo, mensaje)
    VALUES (v_id_usuario_cliente, NEW.id, 'viaje_iniciado',
      'Tu viaje ha comenzado. Â¡Buen viaje!');
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
      'Tu factura electrÃ³nica fue generada y estÃ¡ disponible para descarga.');

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
