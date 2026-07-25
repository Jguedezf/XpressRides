-- ================================================================
--  XpressRides (Decarrerita) Sistemas de Base de Datos I
--  UNEG Prof. María Raquel Herrera E. · Junio 2026
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
--               'decarrerita' DESPUÉSS de cargar decarrerita.sql.
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
-- DDL no puede ir dentro de un TRANSACTION en MySQL cada ALTER/
-- CREATE INDEX / DROP TRIGGER hace commit implícito automático.
-- Se ejecutan con IF NOT EXISTS para que el script sea idempotente
-- tanto sobre una BD recién creada como sobre una BD existente.
-- ================================================================

-- 0.1 Ampliar ENUM notificacion.tipo con los valores que faltaban
--     'chofer_llego' notifica cuando el chofer llega al origen
--     'sin_chofer'   ya usado en Java (TripRejectionService) pero faltaba en la BD
ALTER TABLE notificacion
  MODIFY COLUMN tipo ENUM(
    'viaje_solicitado','chofer_asignado','chofer_en_camino',
    'chofer_llego','viaje_iniciado','viaje_completado','factura_emitida',
    'pago_recibido','recarga_acreditada','viaje_cancelado','sin_chofer'
  ) NOT NULL;

-- 0.2 Índice compuesto para el conteo del badge de notificaciones
--     Cubre: countByUser_IdAndReadFalse consultado cada 15 s por cada usuario activo
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
--     Cubre: GET /api/cliente/viaje-activo consultado cada 5 s durante un viaje
SET @existe = (SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE table_schema = DATABASE()
      AND table_name   = 'traslado'
      AND index_name   = 'idx_traslado_cliente_estado');
SET @sql = IF(@existe = 0,
    'CREATE INDEX idx_traslado_cliente_estado ON traslado(id_cliente, estado)',
    'SELECT ''idx_traslado_cliente_estado: ya existe, se omite''');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 0.4 Trigger actualizado: agrega notificación para estado 'chofer_llego'
--     El trigger original no cubría este estado y el cliente nunca recibía
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

-- ================================================================
-- LIMPIEZA TOTAL
-- ================================================================
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE notificacion;
TRUNCATE TABLE factura;
TRUNCATE TABLE pago_chofer;
TRUNCATE TABLE recarga_saldo;
TRUNCATE TABLE contacto_emergencia;
TRUNCATE TABLE evaluacion_psicologica;
TRUNCATE TABLE revision_vehiculo;
TRUNCATE TABLE vehiculo;
TRUNCATE TABLE incidente;
TRUNCATE TABLE traslado;
TRUNCATE TABLE cupon_cliente;
TRUNCATE TABLE cupon;
TRUNCATE TABLE token_revocado;
TRUNCATE TABLE cliente;
TRUNCATE TABLE chofer;
TRUNCATE TABLE personal_admin;
TRUNCATE TABLE usuario;
SET FOREIGN_KEY_CHECKS = 1;

INSERT INTO usuario (cedula, nombre, apellido, username, password_hash, email, telefono, rol) VALUES
('V-31783162', 'Ángel', 'Martínez', 'angelm', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'angelm@admin.com', '0426-1979320', 'personal_admin'),
('V-32015232', 'Freddy', 'Salazar', 'freddys', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'freddys@admin.com', '0426-4331483', 'personal_admin'),
('V-32417248', 'Eliuber', 'González', 'eliuberg', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'eliuberg@admin.com', '0412-8633836', 'personal_admin'),
('V-31757491', 'Manuel', 'Jaimes', 'manuelj', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'manuelj@admin.com', '0414-7502138', 'personal_admin'),
('V-14089807', 'Johanna', 'Guédez', 'johannag', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'johannag@admin.com', '0424-8905131', 'personal_admin'),
('V-26741146', 'Sofia', 'Castillo', 'scastillo0', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'scastillo0@test.ve', '0416-3264063', 'cliente'),
('V-33507370', 'Victoria', 'Rodriguez', 'vrodriguez1', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'vrodriguez1@test.ve', '0426-3903644', 'cliente'),
('V-19058936', 'Oscar', 'Molina', 'omolina2', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'omolina2@test.ve', '0424-1865812', 'cliente'),
('V-10447532', 'Patricia', 'Molina', 'pmolina3', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'pmolina3@test.ve', '0412-7338042', 'cliente'),
('V-30962967', 'Andres', 'Gutierrez', 'agutierrez4', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'agutierrez4@test.ve', '0424-9621144', 'cliente'),
('V-32605065', 'Camila', 'Soto', 'csoto5', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'csoto5@test.ve', '0414-5396709', 'cliente'),
('V-27991033', 'Andres', 'Gutierrez', 'agutierrez6', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'agutierrez6@test.ve', '0424-1354620', 'cliente'),
('V-32134005', 'Isabel', 'Lopez', 'ilopez7', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'ilopez7@test.ve', '0416-7729767', 'cliente'),
('V-28272011', 'Juan', 'Carrillo', 'jcarrillo8', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'jcarrillo8@test.ve', '0414-3397727', 'cliente'),
('V-16275899', 'Alejandro', 'Ramirez', 'aramirez9', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'aramirez9@test.ve', '0416-2506837', 'cliente'),
('V-15006424', 'Daniela', 'Aguilar', 'daguilar10', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'daguilar10@test.ve', '0414-6631315', 'cliente'),
('V-33499001', 'Victor', 'Morales', 'vmorales11', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'vmorales11@test.ve', '0416-3488087', 'cliente'),
('V-11586087', 'Juan', 'Gomez', 'jgomez12', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'jgomez12@test.ve', '0426-8434928', 'cliente'),
('V-10185936', 'Carmen', 'Diaz', 'cdiaz13', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'cdiaz13@test.ve', '0414-5434245', 'cliente'),
('V-26962344', 'Carmen', 'Gutierrez', 'cgutierrez14', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'cgutierrez14@test.ve', '0426-4211250', 'cliente'),
('V-12462305', 'Sofia', 'Muñoz', 'smuñoz15', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'smuñoz15@test.ve', '0426-4560936', 'cliente'),
('V-28733363', 'Diego', 'Navarrete', 'dnavarrete16', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'dnavarrete16@test.ve', '0412-2422908', 'cliente'),
('V-26460785', 'Monica', 'Perez', 'mperez17', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'mperez17@test.ve', '0426-9619107', 'cliente'),
('V-12640881', 'Alejandro', 'Castro', 'acastro18', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'acastro18@test.ve', '0424-5822658', 'cliente'),
('V-17407990', 'Isabel', 'Diaz', 'idiaz19', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'idiaz19@test.ve', '0412-1294585', 'cliente'),
('V-13863747', 'Isabel', 'Soto', 'isoto20', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'isoto20@test.ve', '0414-3573769', 'cliente'),
('V-15676135', 'Diana', 'Diaz', 'ddiaz21', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'ddiaz21@test.ve', '0424-7133810', 'cliente'),
('V-23326236', 'Gabriel', 'Flores', 'gflores22', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'gflores22@test.ve', '0412-4694667', 'cliente'),
('V-14524541', 'Carlos', 'Flores', 'cflores23', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'cflores23@test.ve', '0424-2234456', 'cliente'),
('V-23218428', 'Rafael', 'Castillo', 'rcastillo24', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'rcastillo24@test.ve', '0412-4307643', 'cliente'),
('V-34614273', 'Valentina', 'Gutierrez', 'vgutierrez25', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'vgutierrez25@test.ve', '0424-3834390', 'cliente'),
('V-10921675', 'Valeria', 'Navarro', 'vnavarro26', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'vnavarro26@test.ve', '0424-9442901', 'cliente'),
('V-15726636', 'Jorge', 'Ortiz', 'jortiz27', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'jortiz27@test.ve', '0414-1441802', 'cliente'),
('V-27408959', 'Javier', 'Vega', 'jvega28', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'jvega28@test.ve', '0416-2044023', 'cliente'),
('V-11012382', 'Pedro', 'Salazar', 'psalazar29', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'psalazar29@test.ve', '0426-1201204', 'cliente'),
('V-21092586', 'Luis', 'Cruz', 'lcruz30', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'lcruz30@test.ve', '0426-4697960', 'cliente'),
('V-33746464', 'Adriana', 'Suarez', 'asuarez31', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'asuarez31@test.ve', '0424-4362846', 'cliente'),
('V-26208950', 'Ricardo', 'Ruiz', 'rruiz32', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'rruiz32@test.ve', '0416-3265098', 'cliente'),
('V-20701675', 'Gabriel', 'Benitez', 'gbenitez33', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'gbenitez33@test.ve', '0416-2352071', 'cliente'),
('V-13763276', 'Victor', 'Gutierrez', 'vgutierrez34', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'vgutierrez34@test.ve', '0424-2451913', 'cliente'),
('V-22324998', 'Carlos', 'Carrillo', 'ccarrillo35', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'ccarrillo35@test.ve', '0416-6272083', 'cliente'),
('V-23734810', 'Emilio', 'Salazar', 'esalazar36', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'esalazar36@test.ve', '0424-4089414', 'cliente'),
('V-22299868', 'Gabriel', 'Morales', 'gmorales37', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'gmorales37@test.ve', '0416-3937084', 'cliente'),
('V-31404399', 'Ricardo', 'Navarro', 'rnavarro38', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'rnavarro38@test.ve', '0426-1185188', 'cliente'),
('V-30703472', 'Isabel', 'Fuentes', 'ifuentes39', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'ifuentes39@test.ve', '0412-6449590', 'cliente'),
('V-23866453', 'Juan', 'Castillo', 'jcastillo40', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'jcastillo40@test.ve', '0426-1730226', 'cliente'),
('V-22802354', 'Luis', 'Rojas', 'lrojas41', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'lrojas41@test.ve', '0412-2515869', 'cliente'),
('V-23213728', 'Emilio', 'Ramos', 'eramos42', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'eramos42@test.ve', '0412-3767568', 'cliente'),
('V-22560826', 'Carlos', 'Cruz', 'ccruz43', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'ccruz43@test.ve', '0414-1650565', 'cliente'),
('V-10343674', 'Alejandra', 'Salazar', 'asalazar44', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'asalazar44@test.ve', '0424-1377283', 'cliente'),
('V-21726321', 'Monica', 'Martinez', 'mmartinez45', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'mmartinez45@test.ve', '0412-8679084', 'cliente'),
('V-31981256', 'Valeria', 'Rodriguez', 'vrodriguez46', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'vrodriguez46@test.ve', '0424-1849038', 'cliente'),
('V-11432680', 'Victoria', 'Salazar', 'vsalazar47', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'vsalazar47@test.ve', '0416-5578647', 'cliente'),
('V-31238495', 'Rafael', 'Vega', 'rvega48', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'rvega48@test.ve', '0414-6189118', 'cliente'),
('V-14439370', 'Eduardo', 'Flores', 'eflores49', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'eflores49@test.ve', '0412-4271308', 'cliente'),
('V-31933673', 'Andrea', 'Gonzalez', 'agonzalez50', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'agonzalez50@test.ve', '0412-1457123', 'cliente'),
('V-34945320', 'Alejandro', 'Torres', 'atorres51', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'atorres51@test.ve', '0426-3186979', 'cliente'),
('V-33578357', 'Sofia', 'Benitez', 'sbenitez52', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'sbenitez52@test.ve', '0424-6896332', 'cliente'),
('V-33258768', 'Jesus', 'Mendoza', 'jmendoza53', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'jmendoza53@test.ve', '0416-3437418', 'cliente'),
('V-12926630', 'Lucia', 'Diaz', 'ldiaz54', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'ldiaz54@test.ve', '0416-2922987', 'cliente'),
('V-32394852', 'Alejandro', 'Gomez', 'agomez55', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'agomez55@test.ve', '0424-2011724', 'cliente'),
('V-16719751', 'Andres', 'Carrillo', 'acarrillo56', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'acarrillo56@test.ve', '0412-3088751', 'cliente'),
('V-21822284', 'Laura', 'Castro', 'lcastro57', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'lcastro57@test.ve', '0416-9670156', 'cliente'),
('V-21660399', 'Paola', 'Perez', 'pperez58', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'pperez58@test.ve', '0414-7920945', 'cliente'),
('V-26202890', 'Mariana', 'Reyes', 'mreyes59', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'mreyes59@test.ve', '0426-9104867', 'cliente'),
('V-32369045', 'Carmen', 'Navarro', 'cnavarroch0', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'cnavarroch0@test.ve', '0416-3108982', 'chofer'),
('V-20757265', 'Natalia', 'Fernandez', 'nfernandezch1', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'nfernandezch1@test.ve', '0424-9767544', 'chofer'),
('V-14906808', 'Victoria', 'Cortez', 'vcortezch2', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'vcortezch2@test.ve', '0414-2510346', 'chofer'),
('V-21411749', 'Hector', 'Castillo', 'hcastilloch3', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'hcastilloch3@test.ve', '0426-9474045', 'chofer'),
('V-15743896', 'Victoria', 'Reyes', 'vreyesch4', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'vreyesch4@test.ve', '0414-8044164', 'chofer'),
('V-13114547', 'Lucia', 'Campos', 'lcamposch5', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'lcamposch5@test.ve', '0412-4373576', 'chofer'),
('V-34858437', 'Patricia', 'Muñoz', 'pmuñozch6', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'pmuñozch6@test.ve', '0412-5647894', 'chofer'),
('V-10597691', 'Valentina', 'Morales', 'vmoralesch7', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'vmoralesch7@test.ve', '0412-7335343', 'chofer'),
('V-19076115', 'Victor', 'Carrillo', 'vcarrilloch8', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'vcarrilloch8@test.ve', '0424-7170473', 'chofer'),
('V-16937517', 'Roberto', 'Acosta', 'racostach9', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'racostach9@test.ve', '0414-8974001', 'chofer'),
('V-26282155', 'Ana', 'Muñoz', 'amuñozch10', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'amuñozch10@test.ve', '0414-1871961', 'chofer'),
('V-27766780', 'Emilio', 'Fernandez', 'efernandezch11', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'efernandezch11@test.ve', '0424-4296532', 'chofer'),
('V-11350076', 'Carlos', 'Campos', 'ccamposch12', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'ccamposch12@test.ve', '0426-1117521', 'chofer'),
('V-15755557', 'Carlos', 'Cruz', 'ccruzch13', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'ccruzch13@test.ve', '0412-3348634', 'chofer'),
('V-30899080', 'Javier', 'Chavez', 'jchavezch14', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'jchavezch14@test.ve', '0414-3400217', 'chofer'),
('V-12019681', 'Miguel', 'Salazar', 'msalazarch15', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'msalazarch15@test.ve', '0416-1427886', 'chofer'),
('V-10585424', 'Daniela', 'Torres', 'dtorresch16', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'dtorresch16@test.ve', '0426-7000696', 'chofer'),
('V-16447394', 'Valeria', 'Flores', 'vfloresch17', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'vfloresch17@test.ve', '0416-9131069', 'chofer'),
('V-27875474', 'Camila', 'Castro', 'ccastroch18', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'ccastroch18@test.ve', '0414-8671210', 'chofer'),
('V-30809647', 'Patricia', 'Castro', 'pcastroch19', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'pcastroch19@test.ve', '0424-5711180', 'chofer'),
('V-21145857', 'Andrea', 'Sanchez', 'asanchezch20', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'asanchezch20@test.ve', '0414-1687274', 'chofer'),
('V-28971584', 'Miguel', 'Gutierrez', 'mgutierrezch21', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'mgutierrezch21@test.ve', '0412-5301878', 'chofer'),
('V-27164783', 'Daniela', 'Salazar', 'dsalazarch22', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'dsalazarch22@test.ve', '0412-8922511', 'chofer'),
('V-34522551', 'Diego', 'Cruz', 'dcruzch23', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'dcruzch23@test.ve', '0414-4677521', 'chofer'),
('V-34088847', 'Monica', 'Fuentes', 'mfuentesch24', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'mfuentesch24@test.ve', '0426-1740425', 'chofer');

INSERT INTO personal_admin (id_usuario, super_admin, nivel_acceso) VALUES
(1, 1, 'TOTAL'),
(2, 1, 'TOTAL'),
(3, 1, 'TOTAL'),
(4, 1, 'TOTAL'),
(5, 1, 'TOTAL');

INSERT INTO cliente (id_usuario, saldo_usd, verificado) VALUES
(6, 90.51, 1),
(7, 50.47, 1),
(8, 54.09, 1),
(9, 92.03, 1),
(10, 8.72, 1),
(11, 15.92, 1),
(12, 80.35, 1),
(13, 59.94, 1),
(14, 16.16, 1),
(15, 82.46, 1),
(16, 62.33, 1),
(17, 59.24, 1),
(18, 73.51, 1),
(19, 99.7, 1),
(20, 99.58, 1),
(21, 63.8, 1),
(22, 72.74, 1),
(23, 25.46, 1),
(24, 51.38, 1),
(25, 50.51, 1),
(26, 39.36, 1),
(27, 14.39, 1),
(28, 78.39, 1),
(29, 12.07, 1),
(30, 28.39, 1),
(31, 89.71, 1),
(32, 27.88, 1),
(33, 17.2, 1),
(34, 6.35, 1),
(35, 39.56, 1),
(36, 83.1, 1),
(37, 96.0, 1),
(38, 83.13, 1),
(39, 17.52, 1),
(40, 47.88, 1),
(41, 49.22, 1),
(42, 36.18, 1),
(43, 66.02, 1),
(44, 73.68, 1),
(45, 64.03, 1),
(46, 51.83, 1),
(47, 57.7, 1),
(48, 40.18, 1),
(49, 83.82, 1),
(50, 75.42, 1),
(51, 50.57, 1),
(52, 31.64, 1),
(53, 90.24, 1),
(54, 31.64, 1),
(55, 37.57, 1),
(56, 13.75, 1),
(57, 77.92, 1),
(58, 56.46, 1),
(59, 43.43, 1),
(60, 76.52, 1),
(61, 18.14, 1),
(62, 93.43, 1),
(63, 70.52, 1),
(64, 26.73, 1),
(65, 67.75, 1);

INSERT INTO chofer (id_usuario, id_banco, id_zona_actual, numero_cuenta, saldo_acumulado_usd, habilitado, disponible) VALUES
(66, 5, 2, '01340000005231568369', 71.93, 1, 1),
(67, 2, 4, '01340000007107609071', 36.9, 1, 1),
(68, 5, 5, '01340000004775351833', 83.74, 1, 1),
(69, 4, 4, '01340000007550726542', 120.94, 1, 1),
(70, 2, 3, '01340000006320119842', 36.73, 1, 1),
(71, 3, 4, '01340000001280984753', 122.73, 1, 1),
(72, 3, 2, '01340000005523722364', 32.6, 1, 1),
(73, 2, 1, '01340000003610160455', 126.59, 1, 1),
(74, 3, 3, '01340000007884217939', 96.25, 1, 1),
(75, 5, 2, '01340000002288479887', 19.7, 1, 1),
(76, 4, 4, '01340000001947738125', 43.19, 1, 1),
(77, 4, 6, '01340000006517870023', 40.09, 1, 1),
(78, 5, 4, '01340000006900554331', 80.1, 1, 1),
(79, 1, 4, '01340000003289905860', 76.54, 1, 1),
(80, 1, 6, '01340000002584013566', 122.29, 1, 1),
(81, 5, 6, '01340000005075219433', 126.89, 1, 1),
(82, 1, 1, '01340000001863918602', 12.22, 1, 1),
(83, 5, 6, '01340000008368315841', 111.21, 1, 1),
(84, 2, 3, '01340000006264358557', 81.55, 1, 1),
(85, 4, 2, '01340000009196018722', 78.66, 1, 1),
(86, 1, 2, '01340000003266817018', 13.2, 1, 1),
(87, 3, 3, '01340000003872028913', 75.57, 1, 1),
(88, 1, 5, '01340000003261058148', 112.18, 1, 1),
(89, 2, 5, '01340000009628249707', 57.45, 1, 1),
(90, 1, 6, '01340000002514898787', 58.17, 1, 1);

INSERT INTO evaluacion_psicologica (id_chofer, tipo_test, fecha_evaluacion, estado, observaciones, evaluador_id) VALUES
(1, 'Test MMPI', '2026-01-29 11:56:52', 'aprobado', 'Sin observaciones', 5),
(2, 'Test MMPI', '2026-05-11 21:30:14', 'aprobado', 'Sin observaciones', 2),
(3, 'Test MMPI', '2026-02-01 09:37:24', 'aprobado', 'Sin observaciones', 2),
(4, 'Test MMPI', '2026-06-26 22:08:23', 'aprobado', 'Sin observaciones', 3),
(5, 'Test MMPI', '2026-04-07 01:14:23', 'aprobado', 'Sin observaciones', 1),
(6, 'Test MMPI', '2026-05-14 22:23:54', 'aprobado', 'Sin observaciones', 5),
(7, 'Test MMPI', '2026-05-31 12:01:41', 'aprobado', 'Sin observaciones', 5),
(8, 'Test MMPI', '2026-03-06 06:39:13', 'aprobado', 'Sin observaciones', 4),
(9, 'Test MMPI', '2026-07-16 19:31:28', 'aprobado', 'Sin observaciones', 1),
(10, 'Test MMPI', '2026-03-29 12:40:50', 'aprobado', 'Sin observaciones', 2),
(11, 'Test MMPI', '2026-05-19 15:26:33', 'aprobado', 'Sin observaciones', 1),
(12, 'Test MMPI', '2026-06-08 13:47:26', 'aprobado', 'Sin observaciones', 3),
(13, 'Test MMPI', '2026-02-05 13:44:12', 'aprobado', 'Sin observaciones', 4),
(14, 'Test MMPI', '2026-03-16 08:37:17', 'aprobado', 'Sin observaciones', 5),
(15, 'Test MMPI', '2026-06-14 01:15:57', 'aprobado', 'Sin observaciones', 4),
(16, 'Test MMPI', '2026-03-21 11:25:53', 'aprobado', 'Sin observaciones', 5),
(17, 'Test MMPI', '2026-05-31 14:42:10', 'aprobado', 'Sin observaciones', 2),
(18, 'Test MMPI', '2026-07-22 08:19:51', 'aprobado', 'Sin observaciones', 5),
(19, 'Test MMPI', '2026-06-05 20:57:40', 'aprobado', 'Sin observaciones', 2),
(20, 'Test MMPI', '2026-07-09 11:11:15', 'aprobado', 'Sin observaciones', 3),
(21, 'Test MMPI', '2026-07-14 10:58:13', 'aprobado', 'Sin observaciones', 3),
(22, 'Test MMPI', '2026-05-12 21:08:54', 'aprobado', 'Sin observaciones', 1),
(23, 'Test MMPI', '2026-04-17 05:17:56', 'aprobado', 'Sin observaciones', 1),
(24, 'Test MMPI', '2026-03-03 17:14:41', 'aprobado', 'Sin observaciones', 1),
(25, 'Test MMPI', '2026-04-22 04:52:16', 'aprobado', 'Sin observaciones', 5);

INSERT INTO vehiculo (id_chofer, placa, marca, modelo, anio, color, capacidad_pasajeros, activo) VALUES
(1, 'FRC294', 'Honda', 'Civic', 2022, 'Rojo', 4, 1),
(2, 'GCM860', 'Chevrolet', 'Cruze', 2022, 'Blanco', 4, 1),
(3, 'KRV142', 'Kia', 'Rio', 2014, 'Plata', 4, 1),
(4, 'YIE304', 'Mazda', 'Mazda6', 2023, 'Rojo', 4, 1),
(5, 'KYQ647', 'Kia', 'Forte', 2011, 'Negro', 4, 1),
(6, 'ZMX536', 'Honda', 'CR-V', 2013, 'Gris', 4, 1),
(7, 'ELY127', 'Toyota', 'Hilux', 2023, 'Gris', 4, 1),
(8, 'MKI862', 'Ford', 'Fiesta', 2014, 'Plata', 4, 1),
(9, 'YXB996', 'Chevrolet', 'Aveo', 2010, 'Plata', 4, 1),
(10, 'ADV550', 'Chevrolet', 'Aveo', 2014, 'Azul', 4, 1),
(11, 'PDV219', 'Chevrolet', 'Spark', 2014, 'Blanco', 4, 1),
(12, 'DNB691', 'Kia', 'Sportage', 2021, 'Gris', 4, 1),
(13, 'IPB682', 'Ford', 'Fiesta', 2009, 'Negro', 4, 1),
(14, 'JGJ945', 'Chevrolet', 'Optra', 2017, 'Negro', 4, 1),
(15, 'QXJ883', 'Chevrolet', 'Aveo', 2011, 'Plata', 4, 1),
(16, 'MRC228', 'Kia', 'Rio', 2008, 'Gris', 4, 1),
(17, 'EDS325', 'Mazda', 'Mazda3', 2023, 'Plata', 4, 1),
(18, 'PVL782', 'Nissan', 'Altima', 2020, 'Rojo', 4, 1),
(19, 'OKS198', 'Toyota', 'Yaris', 2019, 'Plata', 4, 1),
(20, 'IUP637', 'Nissan', 'Versa', 2017, 'Plata', 4, 1),
(21, 'FJE786', 'Ford', 'Fiesta', 2017, 'Plata', 4, 1),
(22, 'GTB036', 'Chevrolet', 'Cruze', 2013, 'Gris', 4, 1),
(23, 'INW898', 'Honda', 'Fit', 2018, 'Rojo', 4, 1),
(24, 'JZH105', 'Hyundai', 'Accent', 2016, 'Rojo', 4, 1),
(25, 'JCW564', 'Chevrolet', 'Spark', 2024, 'Rojo', 4, 1);

INSERT INTO revision_vehiculo (id_vehiculo, fecha_revision, estado, observaciones, revisor_id) VALUES
(1, '2026-06-18', 'aprobado', 'Buenas condiciones', 5),
(2, '2026-03-25', 'aprobado', 'Buenas condiciones', 1),
(3, '2026-02-07', 'aprobado', 'Buenas condiciones', 4),
(4, '2026-05-28', 'aprobado', 'Buenas condiciones', 5),
(5, '2026-03-11', 'aprobado', 'Buenas condiciones', 3),
(6, '2026-03-16', 'aprobado', 'Buenas condiciones', 4),
(7, '2026-07-15', 'aprobado', 'Buenas condiciones', 4),
(8, '2026-02-23', 'aprobado', 'Buenas condiciones', 3),
(9, '2026-06-17', 'aprobado', 'Buenas condiciones', 2),
(10, '2026-05-25', 'aprobado', 'Buenas condiciones', 5),
(11, '2026-02-22', 'aprobado', 'Buenas condiciones', 1),
(12, '2026-03-10', 'aprobado', 'Buenas condiciones', 3),
(13, '2026-05-14', 'aprobado', 'Buenas condiciones', 4),
(14, '2026-07-10', 'aprobado', 'Buenas condiciones', 3),
(15, '2026-02-04', 'aprobado', 'Buenas condiciones', 1),
(16, '2026-06-10', 'aprobado', 'Buenas condiciones', 1),
(17, '2026-07-05', 'aprobado', 'Buenas condiciones', 4),
(18, '2026-07-08', 'aprobado', 'Buenas condiciones', 5),
(19, '2026-07-03', 'aprobado', 'Buenas condiciones', 5),
(20, '2026-05-19', 'aprobado', 'Buenas condiciones', 3),
(21, '2026-04-17', 'aprobado', 'Buenas condiciones', 1),
(22, '2026-06-03', 'aprobado', 'Buenas condiciones', 2),
(23, '2026-03-24', 'aprobado', 'Buenas condiciones', 2),
(24, '2026-02-20', 'aprobado', 'Buenas condiciones', 5),
(25, '2026-05-24', 'aprobado', 'Buenas condiciones', 2);

INSERT INTO contacto_emergencia (id_chofer, nombre, parentesco, telefono) VALUES
(1, 'Maria Rodriguez', 'Madre', '0412-1895152'),
(1, 'Jose Rodriguez', 'Padre', '0426-3214794'),
(2, 'Maria Perez', 'Madre', '0412-8050371'),
(2, 'Jose Perez', 'Padre', '0412-8187968'),
(3, 'Maria Gonzalez', 'Madre', '0416-1189072'),
(3, 'Jose Gonzalez', 'Padre', '0424-7690086'),
(4, 'Maria Gomez', 'Madre', '0426-6470209'),
(4, 'Jose Gomez', 'Padre', '0424-2882452'),
(5, 'Maria Fernandez', 'Madre', '0414-2497346'),
(5, 'Jose Fernandez', 'Padre', '0426-5184987'),
(6, 'Maria Lopez', 'Madre', '0424-1322532'),
(6, 'Jose Lopez', 'Padre', '0416-9395969'),
(7, 'Maria Martinez', 'Madre', '0412-2089328'),
(7, 'Jose Martinez', 'Padre', '0416-4768196'),
(8, 'Maria Sanchez', 'Madre', '0412-1976229'),
(8, 'Jose Sanchez', 'Padre', '0424-5087078'),
(9, 'Maria Diaz', 'Madre', '0424-3057766'),
(9, 'Jose Diaz', 'Padre', '0414-9163463'),
(10, 'Maria Torres', 'Madre', '0416-2625797'),
(10, 'Jose Torres', 'Padre', '0412-2488914'),
(11, 'Maria Ramirez', 'Madre', '0414-9508582'),
(11, 'Jose Ramirez', 'Padre', '0414-2177431'),
(12, 'Maria Ruiz', 'Madre', '0424-9910171'),
(12, 'Jose Ruiz', 'Padre', '0426-8931295'),
(13, 'Maria Flores', 'Madre', '0426-5408867'),
(13, 'Jose Flores', 'Padre', '0426-9979172'),
(14, 'Maria Benitez', 'Madre', '0412-5838543'),
(14, 'Jose Benitez', 'Padre', '0412-2277699'),
(15, 'Maria Acosta', 'Madre', '0412-6449475'),
(15, 'Jose Acosta', 'Padre', '0424-5701072'),
(16, 'Maria Mendoza', 'Madre', '0412-9023532'),
(16, 'Jose Mendoza', 'Padre', '0414-6814608'),
(17, 'Maria Medina', 'Madre', '0416-8668502'),
(17, 'Jose Medina', 'Padre', '0414-5815127'),
(18, 'Maria Castillo', 'Madre', '0414-3515567'),
(18, 'Jose Castillo', 'Padre', '0424-1528916'),
(19, 'Maria Rojas', 'Madre', '0426-4257175'),
(19, 'Jose Rojas', 'Padre', '0416-8461796'),
(20, 'Maria Cruz', 'Madre', '0426-7475000'),
(20, 'Jose Cruz', 'Padre', '0424-6583096'),
(21, 'Maria Morales', 'Madre', '0426-9123728'),
(21, 'Jose Morales', 'Padre', '0424-1829849'),
(22, 'Maria Ortiz', 'Madre', '0412-4213959'),
(22, 'Jose Ortiz', 'Padre', '0424-9740886'),
(23, 'Maria Gutierrez', 'Madre', '0424-9236585'),
(23, 'Jose Gutierrez', 'Padre', '0412-2287281'),
(24, 'Maria Chavez', 'Madre', '0426-2059091'),
(24, 'Jose Chavez', 'Padre', '0414-6886961'),
(25, 'Maria Ramos', 'Madre', '0416-4715988'),
(25, 'Jose Ramos', 'Padre', '0426-8636543');

INSERT INTO traslado (id_cliente, id_chofer, id_zona_origen, id_zona_destino, origen_direccion, origen_lat, origen_lng, destino_direccion, destino_lat, destino_lng, estado, nro_pasajeros, fecha_solicitud, fecha_inicio, fecha_fin, tarifa_base_usd, costo_cliente_usd, monto_chofer_usd, calificacion_al_chofer, calificacion_al_cliente) VALUES
(24, 11, NULL, NULL, 'Direccion Origen 0', 8.247007, -62.588851, 'Direccion Destino 0', 8.237089, -62.675375, 'completado', 1, '2026-06-04 09:13:23', '2026-06-04 09:28:23', '2026-06-04 09:53:23', 5.41, 5.41, 4.06, 3, NULL),
(59, 10, NULL, NULL, 'Direccion Origen 1', 8.203335, -62.68501, 'Direccion Destino 1', 8.302591, -62.537001, 'completado', 1, '2026-07-09 23:19:36', '2026-07-09 23:27:36', '2026-07-10 00:10:36', 11.44, 11.44, 8.58, 4, NULL),
(15, 15, NULL, NULL, 'Direccion Origen 2', 8.288601, -62.675255, 'Direccion Destino 2', 8.236081, -62.545871, 'completado', 1, '2026-06-14 08:04:52', '2026-06-14 08:17:52', '2026-06-14 08:50:52', 9.61, 9.61, 7.21, 5, NULL),
(3, 5, NULL, NULL, 'Direccion Origen 3', 8.353461, -62.660698, 'Direccion Destino 3', 8.262944, -62.606296, 'completado', 1, '2026-05-31 21:02:05', '2026-05-31 21:13:05', '2026-05-31 21:44:05', 7.54, 7.54, 5.66, 5, NULL),
(11, 5, NULL, NULL, 'Direccion Origen 4', 8.302549, -62.669043, 'Direccion Destino 4', 8.356865, -62.589581, 'completado', 1, '2026-06-23 19:35:34', '2026-06-23 19:49:34', '2026-06-23 20:26:34', 7.43, 7.43, 5.57, 4, NULL),
(13, 8, NULL, NULL, 'Direccion Origen 5', 8.273136, -62.651611, 'Direccion Destino 5', 8.244733, -62.636057, 'completado', 1, '2026-06-27 19:32:34', '2026-06-27 19:42:34', '2026-06-27 20:14:34', 12.81, 12.81, 9.61, 5, NULL),
(47, 8, NULL, NULL, 'Direccion Origen 6', 8.20519, -62.636006, 'Direccion Destino 6', 8.231775, -62.640864, 'completado', 1, '2026-07-23 02:38:12', '2026-07-23 02:46:12', '2026-07-23 03:18:12', 6.12, 6.12, 4.59, 5, NULL),
(42, 12, NULL, NULL, 'Direccion Origen 7', 8.269573, -62.526143, 'Direccion Destino 7', 8.366086, -62.52804, 'completado', 1, '2026-06-27 08:48:00', '2026-06-27 09:02:00', '2026-06-27 09:22:00', 2.53, 2.53, 1.9, 4, NULL),
(11, 24, NULL, NULL, 'Direccion Origen 8', 8.29012, -62.541276, 'Direccion Destino 8', 8.338322, -62.656388, 'completado', 1, '2026-07-08 12:16:32', '2026-07-08 12:23:32', '2026-07-08 13:04:32', 7.73, 7.73, 5.8, 3, NULL),
(9, 20, NULL, NULL, 'Direccion Origen 9', 8.280522, -62.529809, 'Direccion Destino 9', 8.251566, -62.676375, 'cancelado', 1, '2026-06-04 04:28:45', NULL, NULL, 5.04, 5.04, 3.78, NULL, NULL),
(4, 19, NULL, NULL, 'Direccion Origen 10', 8.279388, -62.570346, 'Direccion Destino 10', 8.306927, -62.687846, 'completado', 1, '2026-05-28 05:28:15', '2026-05-28 05:43:15', '2026-05-28 06:07:15', 12.84, 12.84, 9.63, 5, NULL),
(47, NULL, NULL, NULL, 'Direccion Origen 11', 8.249644, -62.610642, 'Direccion Destino 11', 8.335234, -62.640541, 'cancelado', 1, '2026-06-17 13:26:32', NULL, NULL, 2.92, 2.92, 2.19, NULL, NULL),
(47, 4, NULL, NULL, 'Direccion Origen 12', 8.268674, -62.535101, 'Direccion Destino 12', 8.282817, -62.568947, 'completado', 1, '2026-06-08 09:52:17', '2026-06-08 09:58:17', '2026-06-08 10:22:17', 13.21, 13.21, 9.91, 3, NULL),
(9, 11, NULL, NULL, 'Direccion Origen 13', 8.36605, -62.609412, 'Direccion Destino 13', 8.329142, -62.645022, 'completado', 1, '2026-06-04 15:33:56', '2026-06-04 15:46:56', '2026-06-04 16:00:56', 9.13, 9.13, 6.85, 4, NULL),
(54, 23, NULL, NULL, 'Direccion Origen 14', 8.369996, -62.633155, 'Direccion Destino 14', 8.265937, -62.528007, 'completado', 1, '2026-06-22 18:10:32', '2026-06-22 18:25:32', '2026-06-22 18:45:32', 11.03, 11.03, 8.27, 4, NULL),
(28, 21, NULL, NULL, 'Direccion Origen 15', 8.382184, -62.690799, 'Direccion Destino 15', 8.243234, -62.582521, 'completado', 1, '2026-07-05 03:22:40', '2026-07-05 03:29:40', '2026-07-05 04:04:40', 8.12, 8.12, 6.09, 4, NULL),
(9, 18, NULL, NULL, 'Direccion Origen 16', 8.2564, -62.697874, 'Direccion Destino 16', 8.380984, -62.594595, 'completado', 1, '2026-07-08 19:42:50', '2026-07-08 19:49:50', '2026-07-08 20:11:50', 14.42, 14.42, 10.81, 5, NULL),
(12, 24, NULL, NULL, 'Direccion Origen 17', 8.252424, -62.567718, 'Direccion Destino 17', 8.333801, -62.651818, 'completado', 1, '2026-06-25 21:12:57', '2026-06-25 21:27:57', '2026-06-25 21:49:57', 7.32, 7.32, 5.49, 5, NULL),
(46, 9, NULL, NULL, 'Direccion Origen 18', 8.249614, -62.686265, 'Direccion Destino 18', 8.33414, -62.622122, 'en_progreso', 1, '2026-06-16 20:59:13', NULL, NULL, 4.11, 4.11, 3.08, NULL, NULL),
(55, 17, NULL, NULL, 'Direccion Origen 19', 8.28289, -62.686238, 'Direccion Destino 19', 8.38943, -62.619201, 'completado', 1, '2026-07-16 00:43:44', '2026-07-16 00:54:44', '2026-07-16 01:29:44', 4.62, 4.62, 3.46, 3, NULL),
(59, 13, NULL, NULL, 'Direccion Origen 20', 8.30509, -62.651546, 'Direccion Destino 20', 8.204591, -62.667518, 'completado', 1, '2026-06-27 06:58:10', '2026-06-27 07:05:10', '2026-06-27 07:47:10', 13.45, 13.45, 10.09, 5, NULL),
(34, 22, NULL, NULL, 'Direccion Origen 21', 8.222856, -62.516282, 'Direccion Destino 21', 8.247766, -62.617997, 'completado', 1, '2026-06-10 03:37:53', '2026-06-10 03:42:53', '2026-06-10 04:11:53', 12.59, 12.59, 9.44, 5, NULL),
(41, 23, NULL, NULL, 'Direccion Origen 22', 8.235288, -62.56919, 'Direccion Destino 22', 8.342562, -62.557875, 'completado', 1, '2026-06-21 16:45:27', '2026-06-21 16:53:27', '2026-06-21 17:13:27', 5.62, 5.62, 4.21, 5, NULL),
(7, 22, NULL, NULL, 'Direccion Origen 23', 8.370374, -62.635603, 'Direccion Destino 23', 8.365406, -62.62141, 'completado', 1, '2026-07-23 17:09:57', '2026-07-23 17:20:57', '2026-07-23 18:01:57', 14.68, 14.68, 11.01, 4, NULL),
(7, NULL, NULL, NULL, 'Direccion Origen 24', 8.242629, -62.626308, 'Direccion Destino 24', 8.281067, -62.612504, 'cancelado', 1, '2026-05-31 17:23:07', NULL, NULL, 6.95, 6.95, 5.21, NULL, NULL),
(10, 12, NULL, NULL, 'Direccion Origen 25', 8.270164, -62.688404, 'Direccion Destino 25', 8.274657, -62.672349, 'completado', 1, '2026-06-01 11:50:03', '2026-06-01 12:01:03', '2026-06-01 12:26:03', 8.96, 8.96, 6.72, 5, NULL),
(28, 6, NULL, NULL, 'Direccion Origen 26', 8.351229, -62.62402, 'Direccion Destino 26', 8.27923, -62.605914, 'en_progreso', 1, '2026-06-28 12:40:12', NULL, NULL, 9.12, 9.12, 6.84, NULL, NULL),
(40, 22, NULL, NULL, 'Direccion Origen 27', 8.372727, -62.653071, 'Direccion Destino 27', 8.211918, -62.695159, 'completado', 1, '2026-06-21 23:46:15', '2026-06-22 00:00:15', '2026-06-22 00:23:15', 13.5, 13.5, 10.12, 3, NULL),
(16, 18, NULL, NULL, 'Direccion Origen 28', 8.218612, -62.603522, 'Direccion Destino 28', 8.354063, -62.676589, 'completado', 1, '2026-06-08 23:49:26', '2026-06-08 23:55:26', '2026-06-09 00:37:26', 10.57, 10.57, 7.93, 3, NULL),
(19, 22, NULL, NULL, 'Direccion Origen 29', 8.38175, -62.618322, 'Direccion Destino 29', 8.245474, -62.653731, 'en_progreso', 1, '2026-06-25 14:33:26', NULL, NULL, 7.67, 7.67, 5.75, NULL, NULL),
(22, 5, NULL, NULL, 'Direccion Origen 30', 8.303784, -62.611103, 'Direccion Destino 30', 8.350058, -62.543618, 'completado', 1, '2026-06-13 08:05:22', '2026-06-13 08:18:22', '2026-06-13 09:01:22', 4.09, 4.09, 3.07, 3, NULL),
(48, 13, NULL, NULL, 'Direccion Origen 31', 8.263899, -62.539938, 'Direccion Destino 31', 8.362556, -62.592988, 'completado', 1, '2026-07-16 20:23:09', '2026-07-16 20:31:09', '2026-07-16 20:52:09', 3.02, 3.02, 2.27, 4, NULL),
(25, 1, NULL, NULL, 'Direccion Origen 32', 8.322511, -62.518015, 'Direccion Destino 32', 8.328082, -62.583565, 'completado', 1, '2026-06-09 14:38:53', '2026-06-09 14:47:53', '2026-06-09 15:16:53', 10.43, 10.43, 7.82, 3, NULL),
(44, 12, NULL, NULL, 'Direccion Origen 33', 8.211692, -62.555588, 'Direccion Destino 33', 8.216956, -62.50485, 'completado', 1, '2026-06-30 02:42:22', '2026-06-30 02:49:22', '2026-06-30 03:04:22', 14.42, 14.42, 10.81, 4, NULL),
(44, NULL, NULL, NULL, 'Direccion Origen 34', 8.355789, -62.531524, 'Direccion Destino 34', 8.343689, -62.563835, 'cancelado', 1, '2026-07-19 22:16:02', NULL, NULL, 9.31, 9.31, 6.98, NULL, NULL),
(40, 9, NULL, NULL, 'Direccion Origen 35', 8.290057, -62.617979, 'Direccion Destino 35', 8.324095, -62.667654, 'completado', 1, '2026-06-27 17:42:30', '2026-06-27 17:49:30', '2026-06-27 18:16:30', 4.07, 4.07, 3.05, 3, NULL),
(8, 4, NULL, NULL, 'Direccion Origen 36', 8.366086, -62.63092, 'Direccion Destino 36', 8.386622, -62.616124, 'completado', 1, '2026-07-19 09:41:13', '2026-07-19 09:47:13', '2026-07-19 10:32:13', 5.47, 5.47, 4.1, 4, NULL),
(46, 5, NULL, NULL, 'Direccion Origen 37', 8.364142, -62.660247, 'Direccion Destino 37', 8.379485, -62.590237, 'cancelado', 1, '2026-06-03 03:48:21', NULL, NULL, 12.19, 12.19, 9.14, NULL, NULL),
(43, 4, NULL, NULL, 'Direccion Origen 38', 8.278015, -62.655592, 'Direccion Destino 38', 8.353136, -62.550546, 'completado', 1, '2026-07-09 22:57:19', '2026-07-09 23:10:19', '2026-07-09 23:42:19', 10.16, 10.16, 7.62, 5, NULL),
(54, 19, NULL, NULL, 'Direccion Origen 39', 8.300928, -62.519489, 'Direccion Destino 39', 8.266173, -62.614371, 'completado', 1, '2026-07-23 12:51:09', '2026-07-23 12:57:09', '2026-07-23 13:34:09', 13.44, 13.44, 10.08, 5, NULL),
(42, 22, NULL, NULL, 'Direccion Origen 40', 8.27038, -62.566534, 'Direccion Destino 40', 8.32663, -62.500842, 'completado', 1, '2026-06-14 11:51:02', '2026-06-14 12:02:02', '2026-06-14 12:32:02', 4.02, 4.02, 3.01, 5, NULL),
(22, NULL, NULL, NULL, 'Direccion Origen 41', 8.378577, -62.676805, 'Direccion Destino 41', 8.379419, -62.509808, 'cancelado', 1, '2026-06-01 06:03:08', NULL, NULL, 12.77, 12.77, 9.58, NULL, NULL),
(16, 9, NULL, NULL, 'Direccion Origen 42', 8.28963, -62.552314, 'Direccion Destino 42', 8.261058, -62.574695, 'completado', 1, '2026-06-14 03:40:30', '2026-06-14 03:45:30', '2026-06-14 04:23:30', 10.51, 10.51, 7.88, 5, NULL),
(52, 24, NULL, NULL, 'Direccion Origen 43', 8.326113, -62.502578, 'Direccion Destino 43', 8.310807, -62.555016, 'completado', 1, '2026-07-11 17:06:14', '2026-07-11 17:15:14', '2026-07-11 17:44:14', 13.43, 13.43, 10.07, 5, NULL),
(30, 2, NULL, NULL, 'Direccion Origen 44', 8.248656, -62.57625, 'Direccion Destino 44', 8.235772, -62.586532, 'completado', 1, '2026-07-03 21:51:07', '2026-07-03 22:04:07', '2026-07-03 22:49:07', 3.0, 3.0, 2.25, 4, NULL),
(30, 19, NULL, NULL, 'Direccion Origen 45', 8.346484, -62.612209, 'Direccion Destino 45', 8.255927, -62.596477, 'en_progreso', 1, '2026-07-24 06:19:02', NULL, NULL, 4.23, 4.23, 3.17, NULL, NULL),
(40, 21, NULL, NULL, 'Direccion Origen 46', 8.275068, -62.572042, 'Direccion Destino 46', 8.291071, -62.552416, 'completado', 1, '2026-07-17 08:36:23', '2026-07-17 08:45:23', '2026-07-17 08:55:23', 4.02, 4.02, 3.01, 5, NULL),
(60, 20, NULL, NULL, 'Direccion Origen 47', 8.384493, -62.61903, 'Direccion Destino 47', 8.384978, -62.614337, 'completado', 1, '2026-06-04 12:18:26', '2026-06-04 12:31:26', '2026-06-04 12:46:26', 7.38, 7.38, 5.54, 5, NULL),
(4, 15, NULL, NULL, 'Direccion Origen 48', 8.298342, -62.602881, 'Direccion Destino 48', 8.36287, -62.62046, 'completado', 1, '2026-06-22 14:15:52', '2026-06-22 14:20:52', '2026-06-22 14:59:52', 14.58, 14.58, 10.94, 3, NULL),
(26, 21, NULL, NULL, 'Direccion Origen 49', 8.248286, -62.518612, 'Direccion Destino 49', 8.221507, -62.668562, 'completado', 1, '2026-07-15 17:01:21', '2026-07-15 17:13:21', '2026-07-15 17:48:21', 6.75, 6.75, 5.06, 4, NULL),
(39, 7, NULL, NULL, 'Direccion Origen 50', 8.258409, -62.58192, 'Direccion Destino 50', 8.317754, -62.62211, 'cancelado', 1, '2026-07-24 00:28:08', NULL, NULL, 6.05, 6.05, 4.54, NULL, NULL),
(27, 16, NULL, NULL, 'Direccion Origen 51', 8.227204, -62.594947, 'Direccion Destino 51', 8.276791, -62.505155, 'completado', 1, '2026-06-27 17:07:45', '2026-06-27 17:16:45', '2026-06-27 17:54:45', 12.59, 12.59, 9.44, 4, NULL),
(58, NULL, NULL, NULL, 'Direccion Origen 52', 8.356346, -62.581166, 'Direccion Destino 52', 8.309324, -62.564341, 'cancelado', 1, '2026-06-25 17:08:41', NULL, NULL, 13.35, 13.35, 10.01, NULL, NULL),
(40, 1, NULL, NULL, 'Direccion Origen 53', 8.229013, -62.632896, 'Direccion Destino 53', 8.217989, -62.556579, 'completado', 1, '2026-06-30 16:20:32', '2026-06-30 16:26:32', '2026-06-30 16:47:32', 6.21, 6.21, 4.66, 3, NULL),
(58, 10, NULL, NULL, 'Direccion Origen 54', 8.22811, -62.619518, 'Direccion Destino 54', 8.223959, -62.596678, 'completado', 1, '2026-06-06 19:34:36', '2026-06-06 19:41:36', '2026-06-06 20:24:36', 12.11, 12.11, 9.08, 3, NULL),
(42, 1, NULL, NULL, 'Direccion Origen 55', 8.345226, -62.650084, 'Direccion Destino 55', 8.382066, -62.665934, 'completado', 1, '2026-07-21 07:56:42', '2026-07-21 08:10:42', '2026-07-21 08:54:42', 9.73, 9.73, 7.3, 5, NULL),
(16, 18, NULL, NULL, 'Direccion Origen 56', 8.317078, -62.605725, 'Direccion Destino 56', 8.235975, -62.563052, 'completado', 1, '2026-06-06 00:28:06', '2026-06-06 00:40:06', '2026-06-06 01:01:06', 7.81, 7.81, 5.86, 3, NULL),
(46, 1, NULL, NULL, 'Direccion Origen 57', 8.33017, -62.609083, 'Direccion Destino 57', 8.343326, -62.642362, 'completado', 1, '2026-07-01 02:02:38', '2026-07-01 02:11:38', '2026-07-01 02:35:38', 10.66, 10.66, 8.0, 3, NULL),
(5, 22, NULL, NULL, 'Direccion Origen 58', 8.398889, -62.549463, 'Direccion Destino 58', 8.385416, -62.623483, 'completado', 1, '2026-06-19 05:35:36', '2026-06-19 05:47:36', '2026-06-19 06:25:36', 12.34, 12.34, 9.25, 5, NULL),
(8, 25, NULL, NULL, 'Direccion Origen 59', 8.202981, -62.560905, 'Direccion Destino 59', 8.359263, -62.572667, 'completado', 1, '2026-06-19 14:50:27', '2026-06-19 14:57:27', '2026-06-19 15:22:27', 9.3, 9.3, 6.98, 3, NULL),
(50, 16, NULL, NULL, 'Direccion Origen 60', 8.227018, -62.504483, 'Direccion Destino 60', 8.216589, -62.646981, 'completado', 1, '2026-06-27 06:06:22', '2026-06-27 06:12:22', '2026-06-27 06:28:22', 5.54, 5.54, 4.16, 5, NULL),
(34, 14, NULL, NULL, 'Direccion Origen 61', 8.396898, -62.562105, 'Direccion Destino 61', 8.331441, -62.612979, 'cancelado', 1, '2026-07-24 05:28:49', NULL, NULL, 12.74, 12.74, 9.55, NULL, NULL),
(5, 10, NULL, NULL, 'Direccion Origen 62', 8.377439, -62.513779, 'Direccion Destino 62', 8.219151, -62.667156, 'completado', 1, '2026-06-14 05:26:48', '2026-06-14 05:31:48', '2026-06-14 06:01:48', 4.91, 4.91, 3.68, 5, NULL),
(57, 6, NULL, NULL, 'Direccion Origen 63', 8.377349, -62.58109, 'Direccion Destino 63', 8.312442, -62.511644, 'cancelado', 1, '2026-07-20 02:45:41', NULL, NULL, 12.7, 12.7, 9.52, NULL, NULL),
(8, 5, NULL, NULL, 'Direccion Origen 64', 8.342157, -62.599965, 'Direccion Destino 64', 8.294227, -62.556359, 'completado', 1, '2026-06-01 08:28:16', '2026-06-01 08:42:16', '2026-06-01 09:13:16', 9.41, 9.41, 7.06, 4, NULL),
(27, 10, NULL, NULL, 'Direccion Origen 65', 8.223168, -62.614373, 'Direccion Destino 65', 8.256836, -62.548857, 'en_progreso', 1, '2026-06-29 05:10:45', NULL, NULL, 9.24, 9.24, 6.93, NULL, NULL),
(55, 1, NULL, NULL, 'Direccion Origen 66', 8.338602, -62.591846, 'Direccion Destino 66', 8.264895, -62.505958, 'completado', 1, '2026-07-12 12:31:39', '2026-07-12 12:36:39', '2026-07-12 13:03:39', 5.61, 5.61, 4.21, 5, NULL),
(57, 3, NULL, NULL, 'Direccion Origen 67', 8.312879, -62.668487, 'Direccion Destino 67', 8.253321, -62.511669, 'en_progreso', 1, '2026-07-19 22:46:11', NULL, NULL, 10.46, 10.46, 7.85, NULL, NULL),
(45, 10, NULL, NULL, 'Direccion Origen 68', 8.368574, -62.516536, 'Direccion Destino 68', 8.202476, -62.692879, 'completado', 1, '2026-07-05 04:49:43', '2026-07-05 04:56:43', '2026-07-05 05:24:43', 6.99, 6.99, 5.24, 4, NULL),
(54, 9, NULL, NULL, 'Direccion Origen 69', 8.335331, -62.585717, 'Direccion Destino 69', 8.297249, -62.64043, 'completado', 1, '2026-06-22 08:24:21', '2026-06-22 08:34:21', '2026-06-22 09:15:21', 8.42, 8.42, 6.31, 5, NULL),
(2, 2, NULL, NULL, 'Direccion Origen 70', 8.333993, -62.537379, 'Direccion Destino 70', 8.397502, -62.502509, 'completado', 1, '2026-07-07 21:23:10', '2026-07-07 21:37:10', '2026-07-07 22:18:10', 6.72, 6.72, 5.04, 4, NULL),
(56, 15, NULL, NULL, 'Direccion Origen 71', 8.385924, -62.687055, 'Direccion Destino 71', 8.375184, -62.523539, 'en_progreso', 1, '2026-07-14 15:49:02', NULL, NULL, 7.21, 7.21, 5.41, NULL, NULL),
(23, 6, NULL, NULL, 'Direccion Origen 72', 8.38542, -62.56312, 'Direccion Destino 72', 8.358736, -62.560461, 'en_progreso', 1, '2026-06-02 12:32:28', NULL, NULL, 9.65, 9.65, 7.24, NULL, NULL),
(55, 10, NULL, NULL, 'Direccion Origen 73', 8.352353, -62.635348, 'Direccion Destino 73', 8.256741, -62.570371, 'completado', 1, '2026-06-07 05:35:08', '2026-06-07 05:42:08', '2026-06-07 06:10:08', 7.56, 7.56, 5.67, 4, NULL),
(38, 9, NULL, NULL, 'Direccion Origen 74', 8.313949, -62.588111, 'Direccion Destino 74', 8.244429, -62.649685, 'cancelado', 1, '2026-05-30 00:51:25', NULL, NULL, 12.97, 12.97, 9.73, NULL, NULL),
(45, 24, NULL, NULL, 'Direccion Origen 75', 8.225915, -62.592398, 'Direccion Destino 75', 8.31187, -62.520656, 'en_progreso', 1, '2026-06-10 17:05:05', NULL, NULL, 8.06, 8.06, 6.04, NULL, NULL),
(3, NULL, NULL, NULL, 'Direccion Origen 76', 8.374031, -62.516662, 'Direccion Destino 76', 8.338108, -62.669291, 'cancelado', 1, '2026-06-10 11:32:49', NULL, NULL, 3.09, 3.09, 2.32, NULL, NULL),
(37, 2, NULL, NULL, 'Direccion Origen 77', 8.36092, -62.566604, 'Direccion Destino 77', 8.384315, -62.572223, 'completado', 1, '2026-06-30 17:50:07', '2026-06-30 17:56:07', '2026-06-30 18:22:07', 4.82, 4.82, 3.62, 3, NULL),
(39, 4, NULL, NULL, 'Direccion Origen 78', 8.258506, -62.549005, 'Direccion Destino 78', 8.259043, -62.589163, 'completado', 1, '2026-07-03 09:25:56', '2026-07-03 09:38:56', '2026-07-03 10:13:56', 14.04, 14.04, 10.53, 4, NULL),
(54, 16, NULL, NULL, 'Direccion Origen 79', 8.218041, -62.548898, 'Direccion Destino 79', 8.392822, -62.655818, 'cancelado', 1, '2026-06-19 04:49:19', NULL, NULL, 5.11, 5.11, 3.83, NULL, NULL),
(58, 12, NULL, NULL, 'Direccion Origen 80', 8.298983, -62.697315, 'Direccion Destino 80', 8.346054, -62.503474, 'completado', 1, '2026-06-03 07:45:01', '2026-06-03 07:50:01', '2026-06-03 08:19:01', 7.21, 7.21, 5.41, 5, NULL),
(8, NULL, NULL, NULL, 'Direccion Origen 81', 8.334507, -62.687505, 'Direccion Destino 81', 8.362687, -62.657359, 'cancelado', 1, '2026-07-24 20:41:41', NULL, NULL, 9.35, 9.35, 7.01, NULL, NULL),
(33, 12, NULL, NULL, 'Direccion Origen 82', 8.345054, -62.574963, 'Direccion Destino 82', 8.355284, -62.635878, 'completado', 1, '2026-07-17 00:05:11', '2026-07-17 00:10:11', '2026-07-17 00:32:11', 13.83, 13.83, 10.37, 3, NULL),
(17, 15, NULL, NULL, 'Direccion Origen 83', 8.370536, -62.609964, 'Direccion Destino 83', 8.284889, -62.666731, 'completado', 1, '2026-06-05 05:45:48', '2026-06-05 05:58:48', '2026-06-05 06:20:48', 13.55, 13.55, 10.16, 3, NULL),
(18, 24, NULL, NULL, 'Direccion Origen 84', 8.393429, -62.597522, 'Direccion Destino 84', 8.27212, -62.549278, 'completado', 1, '2026-07-21 03:42:08', '2026-07-21 03:50:08', '2026-07-21 04:16:08', 6.44, 6.44, 4.83, 5, NULL),
(57, 5, NULL, NULL, 'Direccion Origen 85', 8.274584, -62.528722, 'Direccion Destino 85', 8.228373, -62.630015, 'completado', 1, '2026-07-14 04:19:17', '2026-07-14 04:31:17', '2026-07-14 04:50:17', 11.76, 11.76, 8.82, 5, NULL),
(12, 4, NULL, NULL, 'Direccion Origen 86', 8.385714, -62.532508, 'Direccion Destino 86', 8.353959, -62.548734, 'completado', 1, '2026-07-04 09:23:08', '2026-07-04 09:30:08', '2026-07-04 09:47:08', 9.61, 9.61, 7.21, 5, NULL),
(36, 10, NULL, NULL, 'Direccion Origen 87', 8.227264, -62.596157, 'Direccion Destino 87', 8.258732, -62.522105, 'completado', 1, '2026-07-01 14:30:19', '2026-07-01 14:36:19', '2026-07-01 15:08:19', 8.72, 8.72, 6.54, 5, NULL),
(46, 16, NULL, NULL, 'Direccion Origen 88', 8.291142, -62.608569, 'Direccion Destino 88', 8.384551, -62.50707, 'completado', 1, '2026-06-29 18:32:14', '2026-06-29 18:47:14', '2026-06-29 19:22:14', 14.7, 14.7, 11.02, 4, NULL),
(28, 4, NULL, NULL, 'Direccion Origen 89', 8.398696, -62.656518, 'Direccion Destino 89', 8.227189, -62.557469, 'en_progreso', 1, '2026-07-25 02:11:49', NULL, NULL, 8.25, 8.25, 6.19, NULL, NULL),
(14, 8, NULL, NULL, 'Direccion Origen 90', 8.387637, -62.617359, 'Direccion Destino 90', 8.284094, -62.6244, 'completado', 1, '2026-06-30 09:41:03', '2026-06-30 09:51:03', '2026-06-30 10:20:03', 3.05, 3.05, 2.29, 3, NULL),
(4, NULL, NULL, NULL, 'Direccion Origen 91', 8.34381, -62.696729, 'Direccion Destino 91', 8.312825, -62.667171, 'cancelado', 1, '2026-05-28 22:39:57', NULL, NULL, 5.44, 5.44, 4.08, NULL, NULL),
(1, 2, NULL, NULL, 'Direccion Origen 92', 8.333236, -62.610026, 'Direccion Destino 92', 8.386745, -62.665295, 'en_progreso', 1, '2026-07-11 21:44:13', NULL, NULL, 3.32, 3.32, 2.49, NULL, NULL),
(47, 4, NULL, NULL, 'Direccion Origen 93', 8.28686, -62.536535, 'Direccion Destino 93', 8.272699, -62.64034, 'completado', 1, '2026-07-11 05:16:04', '2026-07-11 05:21:04', '2026-07-11 05:42:04', 7.12, 7.12, 5.34, 3, NULL),
(60, 8, NULL, NULL, 'Direccion Origen 94', 8.338337, -62.585768, 'Direccion Destino 94', 8.322423, -62.685224, 'completado', 1, '2026-06-25 17:18:10', '2026-06-25 17:28:10', '2026-06-25 17:44:10', 13.69, 13.69, 10.27, 3, NULL),
(25, 19, NULL, NULL, 'Direccion Origen 95', 8.327375, -62.63513, 'Direccion Destino 95', 8.225034, -62.535691, 'completado', 1, '2026-06-14 02:14:57', '2026-06-14 02:26:57', '2026-06-14 03:06:57', 11.92, 11.92, 8.94, 4, NULL),
(33, 6, NULL, NULL, 'Direccion Origen 96', 8.286422, -62.625998, 'Direccion Destino 96', 8.326709, -62.502407, 'completado', 1, '2026-05-30 22:57:12', '2026-05-30 23:08:12', '2026-05-30 23:35:12', 2.75, 2.75, 2.06, 5, NULL),
(21, 16, NULL, NULL, 'Direccion Origen 97', 8.321785, -62.657638, 'Direccion Destino 97', 8.323095, -62.663771, 'en_progreso', 1, '2026-06-21 22:11:58', NULL, NULL, 3.91, 3.91, 2.93, NULL, NULL),
(25, 14, NULL, NULL, 'Direccion Origen 98', 8.297761, -62.566748, 'Direccion Destino 98', 8.292447, -62.513164, 'completado', 1, '2026-06-21 19:17:21', '2026-06-21 19:28:21', '2026-06-21 20:01:21', 6.66, 6.66, 5.0, 4, NULL),
(36, 13, NULL, NULL, 'Direccion Origen 99', 8.369791, -62.522179, 'Direccion Destino 99', 8.263977, -62.642, 'completado', 1, '2026-06-25 20:47:46', '2026-06-25 20:59:46', '2026-06-25 21:14:46', 11.33, 11.33, 8.5, 4, NULL),
(15, 14, NULL, NULL, 'Direccion Origen 100', 8.275956, -62.569922, 'Direccion Destino 100', 8.37494, -62.640678, 'completado', 1, '2026-06-20 05:04:31', '2026-06-20 05:16:31', '2026-06-20 05:35:31', 14.8, 14.8, 11.1, 4, NULL),
(27, 17, NULL, NULL, 'Direccion Origen 101', 8.308653, -62.609673, 'Direccion Destino 101', 8.28342, -62.51828, 'completado', 1, '2026-06-15 15:38:47', '2026-06-15 15:52:47', '2026-06-15 16:07:47', 13.77, 13.77, 10.33, 3, NULL),
(49, NULL, NULL, NULL, 'Direccion Origen 102', 8.279514, -62.689338, 'Direccion Destino 102', 8.296006, -62.563021, 'cancelado', 1, '2026-07-05 21:40:47', NULL, NULL, 8.29, 8.29, 6.22, NULL, NULL),
(24, 21, NULL, NULL, 'Direccion Origen 103', 8.206943, -62.530904, 'Direccion Destino 103', 8.319183, -62.582237, 'cancelado', 1, '2026-06-10 06:27:57', NULL, NULL, 12.98, 12.98, 9.73, NULL, NULL),
(52, 5, NULL, NULL, 'Direccion Origen 104', 8.243545, -62.516897, 'Direccion Destino 104', 8.320733, -62.553837, 'completado', 1, '2026-07-02 17:22:00', '2026-07-02 17:31:00', '2026-07-02 17:55:00', 6.81, 6.81, 5.11, 4, NULL),
(20, 20, NULL, NULL, 'Direccion Origen 105', 8.352416, -62.615356, 'Direccion Destino 105', 8.256237, -62.620505, 'completado', 1, '2026-06-23 03:53:57', '2026-06-23 04:04:57', '2026-06-23 04:44:57', 8.77, 8.77, 6.58, 3, NULL),
(14, 8, NULL, NULL, 'Direccion Origen 106', 8.202215, -62.571391, 'Direccion Destino 106', 8.253773, -62.647165, 'completado', 1, '2026-06-06 11:28:49', '2026-06-06 11:43:49', '2026-06-06 12:28:49', 10.17, 10.17, 7.63, 3, NULL),
(55, 3, NULL, NULL, 'Direccion Origen 107', 8.278318, -62.565213, 'Direccion Destino 107', 8.203019, -62.567987, 'completado', 1, '2026-06-11 10:02:01', '2026-06-11 10:09:01', '2026-06-11 10:50:01', 10.15, 10.15, 7.61, 5, NULL),
(12, 24, NULL, NULL, 'Direccion Origen 108', 8.203758, -62.575465, 'Direccion Destino 108', 8.24168, -62.554088, 'completado', 1, '2026-07-08 14:38:58', '2026-07-08 14:45:58', '2026-07-08 15:30:58', 8.27, 8.27, 6.2, 5, NULL),
(25, 23, NULL, NULL, 'Direccion Origen 109', 8.232389, -62.660376, 'Direccion Destino 109', 8.201123, -62.697071, 'completado', 1, '2026-07-24 02:32:18', '2026-07-24 02:46:18', '2026-07-24 03:00:18', 14.95, 14.95, 11.21, 4, NULL),
(52, 19, NULL, NULL, 'Direccion Origen 110', 8.391179, -62.568098, 'Direccion Destino 110', 8.33372, -62.500379, 'completado', 1, '2026-06-28 15:00:11', '2026-06-28 15:07:11', '2026-06-28 15:32:11', 9.63, 9.63, 7.22, 3, NULL),
(4, 9, NULL, NULL, 'Direccion Origen 111', 8.341163, -62.667644, 'Direccion Destino 111', 8.315809, -62.609833, 'completado', 1, '2026-06-24 20:35:49', '2026-06-24 20:46:49', '2026-06-24 21:03:49', 4.24, 4.24, 3.18, 5, NULL),
(47, 10, NULL, NULL, 'Direccion Origen 112', 8.207979, -62.611335, 'Direccion Destino 112', 8.372918, -62.511771, 'completado', 1, '2026-06-07 03:54:21', '2026-06-07 04:05:21', '2026-06-07 04:26:21', 7.77, 7.77, 5.83, 3, NULL),
(29, 2, NULL, NULL, 'Direccion Origen 113', 8.327394, -62.647164, 'Direccion Destino 113', 8.302781, -62.620838, 'completado', 1, '2026-06-04 01:18:16', '2026-06-04 01:31:16', '2026-06-04 02:14:16', 4.71, 4.71, 3.53, 5, NULL),
(25, NULL, NULL, NULL, 'Direccion Origen 114', 8.332626, -62.549529, 'Direccion Destino 114', 8.378925, -62.568449, 'cancelado', 1, '2026-07-02 13:28:56', NULL, NULL, 2.71, 2.71, 2.03, NULL, NULL),
(59, 25, NULL, NULL, 'Direccion Origen 115', 8.253321, -62.564324, 'Direccion Destino 115', 8.382574, -62.656521, 'completado', 1, '2026-05-27 18:33:23', '2026-05-27 18:47:23', '2026-05-27 19:14:23', 12.26, 12.26, 9.2, 3, NULL),
(16, 18, NULL, NULL, 'Direccion Origen 116', 8.290398, -62.592742, 'Direccion Destino 116', 8.397236, -62.533479, 'completado', 1, '2026-06-12 03:50:46', '2026-06-12 03:56:46', '2026-06-12 04:28:46', 3.69, 3.69, 2.77, 3, NULL),
(17, 15, NULL, NULL, 'Direccion Origen 117', 8.26688, -62.652191, 'Direccion Destino 117', 8.205303, -62.572485, 'completado', 1, '2026-06-27 18:39:38', '2026-06-27 18:54:38', '2026-06-27 19:19:38', 13.72, 13.72, 10.29, 4, NULL),
(11, 12, NULL, NULL, 'Direccion Origen 118', 8.321537, -62.670122, 'Direccion Destino 118', 8.305638, -62.520329, 'completado', 1, '2026-07-11 05:41:23', '2026-07-11 05:55:23', '2026-07-11 06:27:23', 12.57, 12.57, 9.43, 5, NULL),
(14, 6, NULL, NULL, 'Direccion Origen 119', 8.2208, -62.657796, 'Direccion Destino 119', 8.24654, -62.607907, 'completado', 1, '2026-06-22 17:10:46', '2026-06-22 17:16:46', '2026-06-22 17:55:46', 13.33, 13.33, 10.0, 3, NULL),
(6, 15, NULL, NULL, 'Direccion Origen 120', 8.322663, -62.616461, 'Direccion Destino 120', 8.337003, -62.513712, 'completado', 1, '2026-07-02 00:54:24', '2026-07-02 01:09:24', '2026-07-02 01:34:24', 9.62, 9.62, 7.21, 4, NULL),
(2, 19, NULL, NULL, 'Direccion Origen 121', 8.21857, -62.692293, 'Direccion Destino 121', 8.366165, -62.666795, 'completado', 1, '2026-07-04 18:54:27', '2026-07-04 19:05:27', '2026-07-04 19:49:27', 4.99, 4.99, 3.74, 5, NULL),
(47, 7, NULL, NULL, 'Direccion Origen 122', 8.208715, -62.670715, 'Direccion Destino 122', 8.270704, -62.60966, 'completado', 1, '2026-06-20 18:43:22', '2026-06-20 18:53:22', '2026-06-20 19:33:22', 7.14, 7.14, 5.35, 5, NULL),
(52, 23, NULL, NULL, 'Direccion Origen 123', 8.322878, -62.598997, 'Direccion Destino 123', 8.202014, -62.551398, 'en_progreso', 1, '2026-06-09 07:36:29', NULL, NULL, 4.3, 4.3, 3.22, NULL, NULL),
(3, 15, NULL, NULL, 'Direccion Origen 124', 8.247215, -62.572797, 'Direccion Destino 124', 8.397788, -62.52985, 'completado', 1, '2026-07-12 16:13:57', '2026-07-12 16:25:57', '2026-07-12 17:03:57', 6.42, 6.42, 4.81, 5, NULL),
(43, 4, NULL, NULL, 'Direccion Origen 125', 8.335864, -62.550517, 'Direccion Destino 125', 8.375158, -62.625073, 'en_progreso', 1, '2026-06-30 20:38:21', NULL, NULL, 4.64, 4.64, 3.48, NULL, NULL),
(23, 22, NULL, NULL, 'Direccion Origen 126', 8.365602, -62.518883, 'Direccion Destino 126', 8.234803, -62.694207, 'completado', 1, '2026-07-13 20:12:28', '2026-07-13 20:20:28', '2026-07-13 20:42:28', 13.58, 13.58, 10.19, 3, NULL),
(20, 10, NULL, NULL, 'Direccion Origen 127', 8.309778, -62.525273, 'Direccion Destino 127', 8.30848, -62.520234, 'cancelado', 1, '2026-06-16 13:29:01', NULL, NULL, 11.41, 11.41, 8.56, NULL, NULL),
(48, 25, NULL, NULL, 'Direccion Origen 128', 8.304305, -62.585852, 'Direccion Destino 128', 8.267871, -62.520956, 'completado', 1, '2026-05-31 06:39:07', '2026-05-31 06:54:07', '2026-05-31 07:25:07', 14.74, 14.74, 11.05, 5, NULL),
(34, 4, NULL, NULL, 'Direccion Origen 129', 8.373917, -62.577562, 'Direccion Destino 129', 8.324723, -62.594723, 'completado', 1, '2026-07-10 08:35:58', '2026-07-10 08:45:58', '2026-07-10 08:56:58', 8.29, 8.29, 6.22, 3, NULL),
(54, 5, NULL, NULL, 'Direccion Origen 130', 8.340052, -62.51051, 'Direccion Destino 130', 8.277824, -62.547477, 'completado', 1, '2026-06-05 00:11:16', '2026-06-05 00:24:16', '2026-06-05 01:00:16', 14.98, 14.98, 11.23, 3, NULL),
(59, 7, NULL, NULL, 'Direccion Origen 131', 8.377394, -62.629184, 'Direccion Destino 131', 8.217517, -62.505996, 'cancelado', 1, '2026-05-28 19:58:36', NULL, NULL, 9.2, 9.2, 6.9, NULL, NULL),
(50, 15, NULL, NULL, 'Direccion Origen 132', 8.350918, -62.611949, 'Direccion Destino 132', 8.289294, -62.528277, 'completado', 1, '2026-07-18 09:59:53', '2026-07-18 10:07:53', '2026-07-18 10:43:53', 8.63, 8.63, 6.47, 3, NULL),
(40, NULL, NULL, NULL, 'Direccion Origen 133', 8.315096, -62.660192, 'Direccion Destino 133', 8.343853, -62.538253, 'cancelado', 1, '2026-07-02 20:37:47', NULL, NULL, 7.64, 7.64, 5.73, NULL, NULL),
(27, 7, NULL, NULL, 'Direccion Origen 134', 8.259505, -62.523952, 'Direccion Destino 134', 8.329811, -62.690126, 'en_progreso', 1, '2026-06-13 06:13:11', NULL, NULL, 5.24, 5.24, 3.93, NULL, NULL),
(7, 16, NULL, NULL, 'Direccion Origen 135', 8.288186, -62.670624, 'Direccion Destino 135', 8.36089, -62.589061, 'completado', 1, '2026-06-07 00:57:03', '2026-06-07 01:03:03', '2026-06-07 01:35:03', 10.88, 10.88, 8.16, 4, NULL),
(17, 16, NULL, NULL, 'Direccion Origen 136', 8.394289, -62.680541, 'Direccion Destino 136', 8.273565, -62.580448, 'completado', 1, '2026-06-16 22:19:18', '2026-06-16 22:33:18', '2026-06-16 22:54:18', 12.89, 12.89, 9.67, 3, NULL),
(27, 21, NULL, NULL, 'Direccion Origen 137', 8.396721, -62.675608, 'Direccion Destino 137', 8.338749, -62.538655, 'completado', 1, '2026-06-06 01:18:16', '2026-06-06 01:28:16', '2026-06-06 01:52:16', 12.81, 12.81, 9.61, 3, NULL),
(48, 17, NULL, NULL, 'Direccion Origen 138', 8.281839, -62.604064, 'Direccion Destino 138', 8.320095, -62.591717, 'completado', 1, '2026-06-04 17:00:30', '2026-06-04 17:15:30', '2026-06-04 17:45:30', 10.07, 10.07, 7.55, 3, NULL),
(21, 21, NULL, NULL, 'Direccion Origen 139', 8.384909, -62.601108, 'Direccion Destino 139', 8.246778, -62.612667, 'completado', 1, '2026-06-30 03:40:07', '2026-06-30 03:48:07', '2026-06-30 04:27:07', 7.26, 7.26, 5.45, 4, NULL),
(8, 13, NULL, NULL, 'Direccion Origen 140', 8.247709, -62.562524, 'Direccion Destino 140', 8.398364, -62.680321, 'completado', 1, '2026-06-25 04:24:26', '2026-06-25 04:30:26', '2026-06-25 05:05:26', 14.88, 14.88, 11.16, 5, NULL),
(8, 24, NULL, NULL, 'Direccion Origen 141', 8.340506, -62.509767, 'Direccion Destino 141', 8.330239, -62.536991, 'completado', 1, '2026-06-17 10:38:52', '2026-06-17 10:47:52', '2026-06-17 11:24:52', 10.21, 10.21, 7.66, 3, NULL),
(15, 8, NULL, NULL, 'Direccion Origen 142', 8.306692, -62.61984, 'Direccion Destino 142', 8.300189, -62.662269, 'completado', 1, '2026-06-21 19:39:46', '2026-06-21 19:48:46', '2026-06-21 20:12:46', 8.73, 8.73, 6.55, 5, NULL),
(4, 15, NULL, NULL, 'Direccion Origen 143', 8.216867, -62.500566, 'Direccion Destino 143', 8.351571, -62.590045, 'completado', 1, '2026-06-24 00:15:38', '2026-06-24 00:23:38', '2026-06-24 00:53:38', 9.53, 9.53, 7.15, 5, NULL),
(20, 2, NULL, NULL, 'Direccion Origen 144', 8.232336, -62.592932, 'Direccion Destino 144', 8.244325, -62.653123, 'en_progreso', 1, '2026-06-04 04:21:27', NULL, NULL, 12.24, 12.24, 9.18, NULL, NULL),
(55, 1, NULL, NULL, 'Direccion Origen 145', 8.347892, -62.518241, 'Direccion Destino 145', 8.377654, -62.575064, 'completado', 1, '2026-06-18 21:35:23', '2026-06-18 21:50:23', '2026-06-18 22:35:23', 7.48, 7.48, 5.61, 4, NULL),
(60, 16, NULL, NULL, 'Direccion Origen 146', 8.224574, -62.649461, 'Direccion Destino 146', 8.391539, -62.571003, 'completado', 1, '2026-07-04 05:46:09', '2026-07-04 05:55:09', '2026-07-04 06:11:09', 13.38, 13.38, 10.04, 3, NULL),
(8, 4, NULL, NULL, 'Direccion Origen 147', 8.349897, -62.60638, 'Direccion Destino 147', 8.328972, -62.664469, 'completado', 1, '2026-06-08 11:08:06', '2026-06-08 11:19:06', '2026-06-08 11:31:06', 6.64, 6.64, 4.98, 4, NULL),
(11, 18, NULL, NULL, 'Direccion Origen 148', 8.26638, -62.570468, 'Direccion Destino 148', 8.317023, -62.544046, 'completado', 1, '2026-07-24 06:54:23', '2026-07-24 07:01:23', '2026-07-24 07:35:23', 8.21, 8.21, 6.16, 5, NULL),
(53, NULL, NULL, NULL, 'Direccion Origen 149', 8.214838, -62.625473, 'Direccion Destino 149', 8.248396, -62.692082, 'cancelado', 1, '2026-06-25 23:17:30', NULL, NULL, 4.34, 4.34, 3.25, NULL, NULL),
(50, 16, NULL, NULL, 'Direccion Origen 150', 8.272853, -62.611085, 'Direccion Destino 150', 8.385615, -62.542731, 'en_progreso', 1, '2026-06-25 00:52:44', NULL, NULL, 14.22, 14.22, 10.67, NULL, NULL),
(27, 8, NULL, NULL, 'Direccion Origen 151', 8.388135, -62.626806, 'Direccion Destino 151', 8.334309, -62.54101, 'completado', 1, '2026-07-12 16:21:00', '2026-07-12 16:32:00', '2026-07-12 16:45:00', 11.75, 11.75, 8.81, 3, NULL),
(37, 6, NULL, NULL, 'Direccion Origen 152', 8.346739, -62.577581, 'Direccion Destino 152', 8.2003, -62.69699, 'en_progreso', 1, '2026-07-19 01:36:28', NULL, NULL, 12.39, 12.39, 9.29, NULL, NULL),
(25, 8, NULL, NULL, 'Direccion Origen 153', 8.264373, -62.625084, 'Direccion Destino 153', 8.329538, -62.536145, 'completado', 1, '2026-06-05 04:16:33', '2026-06-05 04:24:33', '2026-06-05 04:40:33', 9.98, 9.98, 7.49, 3, NULL),
(39, 9, NULL, NULL, 'Direccion Origen 154', 8.358531, -62.692507, 'Direccion Destino 154', 8.260922, -62.554385, 'completado', 1, '2026-06-16 15:36:12', '2026-06-16 15:44:12', '2026-06-16 16:23:12', 14.59, 14.59, 10.94, 4, NULL),
(50, 21, NULL, NULL, 'Direccion Origen 155', 8.394329, -62.65139, 'Direccion Destino 155', 8.353047, -62.666664, 'completado', 1, '2026-06-21 13:36:40', '2026-06-21 13:51:40', '2026-06-21 14:35:40', 11.93, 11.93, 8.95, 5, NULL),
(6, 10, NULL, NULL, 'Direccion Origen 156', 8.269128, -62.654, 'Direccion Destino 156', 8.25175, -62.562575, 'completado', 1, '2026-06-20 12:30:54', '2026-06-20 12:42:54', '2026-06-20 13:24:54', 2.94, 2.94, 2.21, 5, NULL),
(20, 22, NULL, NULL, 'Direccion Origen 157', 8.338553, -62.628646, 'Direccion Destino 157', 8.24766, -62.661706, 'completado', 1, '2026-06-14 05:10:10', '2026-06-14 05:18:10', '2026-06-14 05:49:10', 5.72, 5.72, 4.29, 3, NULL),
(3, 21, NULL, NULL, 'Direccion Origen 158', 8.380307, -62.661403, 'Direccion Destino 158', 8.208639, -62.64546, 'completado', 1, '2026-06-01 03:05:54', '2026-06-01 03:13:54', '2026-06-01 03:26:54', 10.92, 10.92, 8.19, 3, NULL),
(31, NULL, NULL, NULL, 'Direccion Origen 159', 8.258055, -62.568634, 'Direccion Destino 159', 8.256011, -62.69295, 'cancelado', 1, '2026-07-09 13:39:27', NULL, NULL, 2.73, 2.73, 2.05, NULL, NULL),
(1, 24, NULL, NULL, 'Direccion Origen 160', 8.270806, -62.680363, 'Direccion Destino 160', 8.321184, -62.682478, 'en_progreso', 1, '2026-06-16 09:49:49', NULL, NULL, 14.56, 14.56, 10.92, NULL, NULL),
(51, 20, NULL, NULL, 'Direccion Origen 161', 8.231726, -62.555599, 'Direccion Destino 161', 8.361778, -62.570899, 'completado', 1, '2026-06-20 05:22:05', '2026-06-20 05:28:05', '2026-06-20 06:13:05', 6.21, 6.21, 4.66, 4, NULL),
(12, 6, NULL, NULL, 'Direccion Origen 162', 8.356639, -62.612222, 'Direccion Destino 162', 8.388784, -62.58874, 'completado', 1, '2026-05-26 22:29:20', '2026-05-26 22:37:20', '2026-05-26 22:53:20', 13.13, 13.13, 9.85, 4, NULL),
(26, 23, NULL, NULL, 'Direccion Origen 163', 8.391328, -62.688838, 'Direccion Destino 163', 8.363466, -62.632767, 'completado', 1, '2026-07-02 13:09:47', '2026-07-02 13:24:47', '2026-07-02 13:56:47', 9.31, 9.31, 6.98, 4, NULL),
(17, 8, NULL, NULL, 'Direccion Origen 164', 8.340488, -62.552644, 'Direccion Destino 164', 8.259544, -62.574155, 'completado', 1, '2026-06-12 14:57:08', '2026-06-12 15:09:08', '2026-06-12 15:31:08', 12.18, 12.18, 9.13, 5, NULL),
(41, 1, NULL, NULL, 'Direccion Origen 165', 8.218939, -62.669962, 'Direccion Destino 165', 8.389976, -62.684445, 'en_progreso', 1, '2026-07-11 08:14:57', NULL, NULL, 2.79, 2.79, 2.09, NULL, NULL),
(27, 20, NULL, NULL, 'Direccion Origen 166', 8.225524, -62.6509, 'Direccion Destino 166', 8.24613, -62.615721, 'completado', 1, '2026-06-27 07:54:02', '2026-06-27 07:59:02', '2026-06-27 08:20:02', 2.73, 2.73, 2.05, 3, NULL),
(60, 6, NULL, NULL, 'Direccion Origen 167', 8.209097, -62.663035, 'Direccion Destino 167', 8.303159, -62.607693, 'completado', 1, '2026-06-25 09:09:19', '2026-06-25 09:17:19', '2026-06-25 09:57:19', 14.27, 14.27, 10.7, 5, NULL),
(54, 8, NULL, NULL, 'Direccion Origen 168', 8.391744, -62.680043, 'Direccion Destino 168', 8.235225, -62.683741, 'completado', 1, '2026-06-17 17:10:03', '2026-06-17 17:20:03', '2026-06-17 18:01:03', 14.36, 14.36, 10.77, 3, NULL),
(54, 14, NULL, NULL, 'Direccion Origen 169', 8.379412, -62.586877, 'Direccion Destino 169', 8.201808, -62.661214, 'en_progreso', 1, '2026-06-21 05:11:58', NULL, NULL, 11.69, 11.69, 8.77, NULL, NULL),
(8, 16, NULL, NULL, 'Direccion Origen 170', 8.211245, -62.559808, 'Direccion Destino 170', 8.364859, -62.530322, 'completado', 1, '2026-06-10 23:44:49', '2026-06-10 23:52:49', '2026-06-11 00:19:49', 3.33, 3.33, 2.5, 4, NULL),
(60, 25, NULL, NULL, 'Direccion Origen 171', 8.25341, -62.682382, 'Direccion Destino 171', 8.391675, -62.64325, 'completado', 1, '2026-06-27 04:15:31', '2026-06-27 04:27:31', '2026-06-27 04:55:31', 8.37, 8.37, 6.28, 4, NULL),
(45, 16, NULL, NULL, 'Direccion Origen 172', 8.276067, -62.670654, 'Direccion Destino 172', 8.300721, -62.542626, 'en_progreso', 1, '2026-07-20 05:11:30', NULL, NULL, 13.11, 13.11, 9.83, NULL, NULL),
(31, 13, NULL, NULL, 'Direccion Origen 173', 8.365698, -62.699049, 'Direccion Destino 173', 8.310876, -62.509885, 'completado', 1, '2026-07-01 07:43:14', '2026-07-01 07:57:14', '2026-07-01 08:22:14', 8.87, 8.87, 6.65, 5, NULL),
(1, 6, NULL, NULL, 'Direccion Origen 174', 8.365606, -62.600991, 'Direccion Destino 174', 8.240072, -62.636182, 'en_progreso', 1, '2026-07-02 15:40:56', NULL, NULL, 10.06, 10.06, 7.54, NULL, NULL),
(36, 24, NULL, NULL, 'Direccion Origen 175', 8.304875, -62.562964, 'Direccion Destino 175', 8.225206, -62.674603, 'completado', 1, '2026-07-19 12:39:35', '2026-07-19 12:53:35', '2026-07-19 13:08:35', 5.77, 5.77, 4.33, 4, NULL),
(25, 24, NULL, NULL, 'Direccion Origen 176', 8.280482, -62.596488, 'Direccion Destino 176', 8.385854, -62.678405, 'en_progreso', 1, '2026-05-31 19:12:45', NULL, NULL, 4.16, 4.16, 3.12, NULL, NULL),
(30, NULL, NULL, NULL, 'Direccion Origen 177', 8.291439, -62.560175, 'Direccion Destino 177', 8.290084, -62.684905, 'cancelado', 1, '2026-06-15 01:13:48', NULL, NULL, 7.81, 7.81, 5.86, NULL, NULL),
(41, 3, NULL, NULL, 'Direccion Origen 178', 8.359696, -62.57785, 'Direccion Destino 178', 8.365473, -62.61424, 'completado', 1, '2026-06-12 04:07:55', '2026-06-12 04:14:55', '2026-06-12 04:41:55', 5.03, 5.03, 3.77, 3, NULL),
(39, 23, NULL, NULL, 'Direccion Origen 179', 8.289373, -62.541077, 'Direccion Destino 179', 8.361333, -62.523443, 'en_progreso', 1, '2026-07-16 14:33:55', NULL, NULL, 11.83, 11.83, 8.87, NULL, NULL),
(3, 7, NULL, NULL, 'Direccion Origen 180', 8.313672, -62.535111, 'Direccion Destino 180', 8.203582, -62.696214, 'en_progreso', 1, '2026-06-09 16:11:29', NULL, NULL, 9.61, 9.61, 7.21, NULL, NULL),
(26, 9, NULL, NULL, 'Direccion Origen 181', 8.318629, -62.697587, 'Direccion Destino 181', 8.249258, -62.573116, 'completado', 1, '2026-06-19 23:04:46', '2026-06-19 23:17:46', '2026-06-20 00:02:46', 9.54, 9.54, 7.15, 5, NULL),
(6, 16, NULL, NULL, 'Direccion Origen 182', 8.385295, -62.609639, 'Direccion Destino 182', 8.291569, -62.56183, 'completado', 1, '2026-06-07 07:05:12', '2026-06-07 07:18:12', '2026-06-07 07:41:12', 12.98, 12.98, 9.73, 4, NULL),
(16, 3, NULL, NULL, 'Direccion Origen 183', 8.338519, -62.591947, 'Direccion Destino 183', 8.278989, -62.61321, 'en_progreso', 1, '2026-06-06 19:47:07', NULL, NULL, 11.2, 11.2, 8.4, NULL, NULL),
(30, 16, NULL, NULL, 'Direccion Origen 184', 8.383195, -62.557906, 'Direccion Destino 184', 8.209778, -62.642732, 'completado', 1, '2026-06-02 01:51:43', '2026-06-02 02:02:43', '2026-06-02 02:38:43', 14.01, 14.01, 10.51, 5, NULL),
(21, 17, NULL, NULL, 'Direccion Origen 185', 8.26452, -62.636342, 'Direccion Destino 185', 8.311749, -62.536288, 'cancelado', 1, '2026-06-02 06:35:23', NULL, NULL, 10.99, 10.99, 8.24, NULL, NULL),
(16, 25, NULL, NULL, 'Direccion Origen 186', 8.367144, -62.586754, 'Direccion Destino 186', 8.229316, -62.626879, 'en_progreso', 1, '2026-07-06 19:07:54', NULL, NULL, 14.8, 14.8, 11.1, NULL, NULL),
(38, 23, NULL, NULL, 'Direccion Origen 187', 8.202441, -62.696141, 'Direccion Destino 187', 8.303324, -62.500264, 'en_progreso', 1, '2026-06-03 06:24:57', NULL, NULL, 4.77, 4.77, 3.58, NULL, NULL),
(59, 11, NULL, NULL, 'Direccion Origen 188', 8.242126, -62.613928, 'Direccion Destino 188', 8.362296, -62.538354, 'completado', 1, '2026-06-26 13:42:12', '2026-06-26 13:50:12', '2026-06-26 14:16:12', 7.63, 7.63, 5.72, 3, NULL),
(14, 24, NULL, NULL, 'Direccion Origen 189', 8.248345, -62.688046, 'Direccion Destino 189', 8.315025, -62.63139, 'completado', 1, '2026-07-16 13:26:03', '2026-07-16 13:33:03', '2026-07-16 13:52:03', 6.01, 6.01, 4.51, 3, NULL),
(57, 1, NULL, NULL, 'Direccion Origen 190', 8.246867, -62.588557, 'Direccion Destino 190', 8.380178, -62.598719, 'cancelado', 1, '2026-07-23 03:46:50', NULL, NULL, 14.89, 14.89, 11.17, NULL, NULL),
(15, 4, NULL, NULL, 'Direccion Origen 191', 8.326378, -62.675013, 'Direccion Destino 191', 8.398833, -62.542148, 'completado', 1, '2026-07-02 23:25:43', '2026-07-02 23:30:43', '2026-07-03 00:12:43', 10.43, 10.43, 7.82, 3, NULL),
(23, 15, NULL, NULL, 'Direccion Origen 192', 8.328219, -62.578957, 'Direccion Destino 192', 8.368605, -62.690356, 'completado', 1, '2026-06-02 13:38:44', '2026-06-02 13:49:44', '2026-06-02 14:23:44', 6.72, 6.72, 5.04, 5, NULL),
(52, 16, NULL, NULL, 'Direccion Origen 193', 8.345241, -62.522183, 'Direccion Destino 193', 8.392009, -62.504085, 'completado', 1, '2026-07-14 20:35:20', '2026-07-14 20:41:20', '2026-07-14 21:20:20', 4.16, 4.16, 3.12, 5, NULL),
(1, 8, NULL, NULL, 'Direccion Origen 194', 8.257114, -62.596141, 'Direccion Destino 194', 8.327241, -62.660186, 'completado', 1, '2026-07-19 04:04:43', '2026-07-19 04:15:43', '2026-07-19 04:29:43', 4.45, 4.45, 3.34, 4, NULL),
(32, 19, NULL, NULL, 'Direccion Origen 195', 8.270678, -62.56864, 'Direccion Destino 195', 8.234574, -62.607599, 'completado', 1, '2026-06-08 04:02:52', '2026-06-08 04:17:52', '2026-06-08 04:46:52', 5.83, 5.83, 4.37, 5, NULL),
(16, 20, NULL, NULL, 'Direccion Origen 196', 8.258208, -62.523931, 'Direccion Destino 196', 8.218071, -62.622901, 'completado', 1, '2026-07-10 04:59:44', '2026-07-10 05:10:44', '2026-07-10 05:30:44', 4.78, 4.78, 3.58, 3, NULL),
(59, 16, NULL, NULL, 'Direccion Origen 197', 8.338826, -62.630666, 'Direccion Destino 197', 8.294599, -62.513334, 'completado', 1, '2026-05-28 15:58:56', '2026-05-28 16:06:56', '2026-05-28 16:16:56', 7.26, 7.26, 5.45, 5, NULL),
(31, 8, NULL, NULL, 'Direccion Origen 198', 8.319774, -62.542624, 'Direccion Destino 198', 8.240247, -62.539573, 'completado', 1, '2026-06-11 21:21:23', '2026-06-11 21:34:23', '2026-06-11 22:04:23', 9.46, 9.46, 7.1, 5, NULL),
(5, 25, NULL, NULL, 'Direccion Origen 199', 8.242207, -62.694136, 'Direccion Destino 199', 8.220716, -62.675935, 'completado', 1, '2026-06-08 15:23:47', '2026-06-08 15:36:47', '2026-06-08 15:51:47', 7.13, 7.13, 5.35, 3, NULL),
(42, 16, NULL, NULL, 'Direccion Origen 200', 8.261319, -62.505936, 'Direccion Destino 200', 8.251902, -62.512228, 'completado', 1, '2026-06-24 05:29:35', '2026-06-24 05:35:35', '2026-06-24 05:52:35', 5.43, 5.43, 4.07, 5, NULL),
(20, 12, NULL, NULL, 'Direccion Origen 201', 8.33918, -62.530907, 'Direccion Destino 201', 8.357109, -62.610716, 'completado', 1, '2026-07-13 01:41:48', '2026-07-13 01:55:48', '2026-07-13 02:11:48', 7.42, 7.42, 5.56, 5, NULL),
(32, 21, NULL, NULL, 'Direccion Origen 202', 8.211339, -62.509628, 'Direccion Destino 202', 8.220515, -62.507557, 'completado', 1, '2026-06-22 01:20:37', '2026-06-22 01:35:37', '2026-06-22 02:07:37', 5.8, 5.8, 4.35, 5, NULL),
(32, 11, NULL, NULL, 'Direccion Origen 203', 8.245105, -62.697264, 'Direccion Destino 203', 8.337019, -62.698981, 'completado', 1, '2026-07-15 02:36:36', '2026-07-15 02:45:36', '2026-07-15 03:22:36', 8.87, 8.87, 6.65, 5, NULL),
(33, 6, NULL, NULL, 'Direccion Origen 204', 8.273431, -62.65911, 'Direccion Destino 204', 8.217249, -62.58854, 'completado', 1, '2026-07-08 15:18:18', '2026-07-08 15:27:18', '2026-07-08 16:03:18', 11.11, 11.11, 8.33, 5, NULL),
(18, 25, NULL, NULL, 'Direccion Origen 205', 8.202864, -62.675266, 'Direccion Destino 205', 8.340515, -62.526867, 'completado', 1, '2026-07-06 05:56:18', '2026-07-06 06:06:18', '2026-07-06 06:50:18', 13.74, 13.74, 10.3, 5, NULL),
(27, NULL, NULL, NULL, 'Direccion Origen 206', 8.346372, -62.686925, 'Direccion Destino 206', 8.309829, -62.655093, 'cancelado', 1, '2026-05-28 03:24:14', NULL, NULL, 3.93, 3.93, 2.95, NULL, NULL),
(13, 14, NULL, NULL, 'Direccion Origen 207', 8.222065, -62.589104, 'Direccion Destino 207', 8.315375, -62.623704, 'completado', 1, '2026-07-22 11:43:43', '2026-07-22 11:52:43', '2026-07-22 12:31:43', 10.74, 10.74, 8.05, 4, NULL),
(50, 7, NULL, NULL, 'Direccion Origen 208', 8.26276, -62.541224, 'Direccion Destino 208', 8.28056, -62.547517, 'en_progreso', 1, '2026-06-07 16:38:26', NULL, NULL, 9.2, 9.2, 6.9, NULL, NULL),
(11, 10, NULL, NULL, 'Direccion Origen 209', 8.321251, -62.583622, 'Direccion Destino 209', 8.219439, -62.612383, 'completado', 1, '2026-07-19 01:14:47', '2026-07-19 01:21:47', '2026-07-19 01:45:47', 2.6, 2.6, 1.95, 4, NULL),
(41, NULL, NULL, NULL, 'Direccion Origen 210', 8.228811, -62.689476, 'Direccion Destino 210', 8.352765, -62.644456, 'cancelado', 1, '2026-07-22 07:10:01', NULL, NULL, 3.14, 3.14, 2.35, NULL, NULL),
(12, 11, NULL, NULL, 'Direccion Origen 211', 8.372505, -62.640837, 'Direccion Destino 211', 8.32076, -62.641209, 'completado', 1, '2026-07-21 11:19:10', '2026-07-21 11:25:10', '2026-07-21 12:02:10', 6.67, 6.67, 5.0, 4, NULL),
(38, 13, NULL, NULL, 'Direccion Origen 212', 8.316868, -62.613769, 'Direccion Destino 212', 8.377251, -62.51962, 'completado', 1, '2026-07-05 12:16:28', '2026-07-05 12:26:28', '2026-07-05 12:44:28', 5.32, 5.32, 3.99, 4, NULL),
(25, 1, NULL, NULL, 'Direccion Origen 213', 8.298234, -62.632339, 'Direccion Destino 213', 8.321541, -62.672569, 'en_progreso', 1, '2026-05-30 17:28:02', NULL, NULL, 9.52, 9.52, 7.14, NULL, NULL),
(27, 25, NULL, NULL, 'Direccion Origen 214', 8.385539, -62.574667, 'Direccion Destino 214', 8.344367, -62.638733, 'completado', 1, '2026-06-17 22:12:07', '2026-06-17 22:25:07', '2026-06-17 22:50:07', 10.47, 10.47, 7.85, 5, NULL),
(25, 21, NULL, NULL, 'Direccion Origen 215', 8.320181, -62.522862, 'Direccion Destino 215', 8.272365, -62.591928, 'completado', 1, '2026-07-08 05:25:36', '2026-07-08 05:37:36', '2026-07-08 06:22:36', 6.02, 6.02, 4.51, 4, NULL),
(33, 12, NULL, NULL, 'Direccion Origen 216', 8.272414, -62.555047, 'Direccion Destino 216', 8.228647, -62.510935, 'completado', 1, '2026-06-11 01:13:55', '2026-06-11 01:27:55', '2026-06-11 01:54:55', 5.72, 5.72, 4.29, 3, NULL),
(35, 6, NULL, NULL, 'Direccion Origen 217', 8.396395, -62.645133, 'Direccion Destino 217', 8.218972, -62.511695, 'completado', 1, '2026-07-06 20:10:36', '2026-07-06 20:21:36', '2026-07-06 20:41:36', 3.98, 3.98, 2.98, 4, NULL),
(19, 14, NULL, NULL, 'Direccion Origen 218', 8.385749, -62.590795, 'Direccion Destino 218', 8.28138, -62.6828, 'en_progreso', 1, '2026-06-19 05:48:56', NULL, NULL, 5.3, 5.3, 3.97, NULL, NULL),
(26, NULL, NULL, NULL, 'Direccion Origen 219', 8.284621, -62.689069, 'Direccion Destino 219', 8.25879, -62.678392, 'cancelado', 1, '2026-06-22 08:47:54', NULL, NULL, 11.13, 11.13, 8.35, NULL, NULL),
(4, 24, NULL, NULL, 'Direccion Origen 220', 8.280866, -62.560635, 'Direccion Destino 220', 8.262792, -62.553769, 'en_progreso', 1, '2026-07-20 04:43:09', NULL, NULL, 7.69, 7.69, 5.77, NULL, NULL),
(6, 19, NULL, NULL, 'Direccion Origen 221', 8.361889, -62.502736, 'Direccion Destino 221', 8.243937, -62.672138, 'completado', 1, '2026-06-17 15:44:46', '2026-06-17 15:53:46', '2026-06-17 16:32:46', 4.59, 4.59, 3.44, 4, NULL),
(48, 24, NULL, NULL, 'Direccion Origen 222', 8.353709, -62.605473, 'Direccion Destino 222', 8.241309, -62.521774, 'completado', 1, '2026-06-17 08:31:41', '2026-06-17 08:39:41', '2026-06-17 09:06:41', 9.39, 9.39, 7.04, 3, NULL),
(50, 13, NULL, NULL, 'Direccion Origen 223', 8.392242, -62.50147, 'Direccion Destino 223', 8.28834, -62.65153, 'en_progreso', 1, '2026-06-21 00:09:31', NULL, NULL, 5.35, 5.35, 4.01, NULL, NULL),
(42, 6, NULL, NULL, 'Direccion Origen 224', 8.36711, -62.556293, 'Direccion Destino 224', 8.241799, -62.614903, 'completado', 1, '2026-07-03 22:47:56', '2026-07-03 23:00:56', '2026-07-03 23:45:56', 4.8, 4.8, 3.6, 4, NULL),
(57, 3, NULL, NULL, 'Direccion Origen 225', 8.210033, -62.628066, 'Direccion Destino 225', 8.292458, -62.645276, 'completado', 1, '2026-07-16 06:55:45', '2026-07-16 07:06:45', '2026-07-16 07:46:45', 10.22, 10.22, 7.67, 4, NULL),
(13, 15, NULL, NULL, 'Direccion Origen 226', 8.398074, -62.653907, 'Direccion Destino 226', 8.250663, -62.549335, 'completado', 1, '2026-06-13 20:38:46', '2026-06-13 20:51:46', '2026-06-13 21:07:46', 14.28, 14.28, 10.71, 3, NULL),
(46, 19, NULL, NULL, 'Direccion Origen 227', 8.29389, -62.693654, 'Direccion Destino 227', 8.370231, -62.551894, 'en_progreso', 1, '2026-07-16 22:52:20', NULL, NULL, 3.15, 3.15, 2.36, NULL, NULL),
(2, 14, NULL, NULL, 'Direccion Origen 228', 8.342312, -62.566693, 'Direccion Destino 228', 8.292585, -62.596215, 'completado', 1, '2026-07-19 11:35:43', '2026-07-19 11:44:43', '2026-07-19 12:21:43', 4.89, 4.89, 3.67, 5, NULL),
(36, 1, NULL, NULL, 'Direccion Origen 229', 8.335626, -62.679023, 'Direccion Destino 229', 8.247149, -62.627574, 'completado', 1, '2026-06-05 18:19:11', '2026-06-05 18:34:11', '2026-06-05 19:04:11', 9.61, 9.61, 7.21, 5, NULL),
(45, 12, NULL, NULL, 'Direccion Origen 230', 8.386328, -62.690952, 'Direccion Destino 230', 8.392147, -62.694164, 'completado', 1, '2026-06-14 14:35:03', '2026-06-14 14:49:03', '2026-06-14 15:15:03', 12.87, 12.87, 9.65, 3, NULL),
(51, NULL, NULL, NULL, 'Direccion Origen 231', 8.348148, -62.683331, 'Direccion Destino 231', 8.256009, -62.549475, 'cancelado', 1, '2026-06-25 11:46:07', NULL, NULL, 8.53, 8.53, 6.4, NULL, NULL),
(11, 5, NULL, NULL, 'Direccion Origen 232', 8.250934, -62.511769, 'Direccion Destino 232', 8.321754, -62.571865, 'completado', 1, '2026-07-24 03:21:58', '2026-07-24 03:33:58', '2026-07-24 04:06:58', 13.83, 13.83, 10.37, 5, NULL),
(56, 10, NULL, NULL, 'Direccion Origen 233', 8.274577, -62.698192, 'Direccion Destino 233', 8.201273, -62.576924, 'cancelado', 1, '2026-06-28 22:10:01', NULL, NULL, 5.56, 5.56, 4.17, NULL, NULL),
(20, 5, NULL, NULL, 'Direccion Origen 234', 8.207153, -62.56518, 'Direccion Destino 234', 8.260699, -62.514861, 'en_progreso', 1, '2026-06-11 11:44:26', NULL, NULL, 6.16, 6.16, 4.62, NULL, NULL),
(10, 23, NULL, NULL, 'Direccion Origen 235', 8.383904, -62.650547, 'Direccion Destino 235', 8.22348, -62.561426, 'completado', 1, '2026-07-23 14:03:48', '2026-07-23 14:16:48', '2026-07-23 14:45:48', 7.29, 7.29, 5.47, 3, NULL),
(10, 19, NULL, NULL, 'Direccion Origen 236', 8.364187, -62.64484, 'Direccion Destino 236', 8.294769, -62.615918, 'cancelado', 1, '2026-06-23 02:54:36', NULL, NULL, 11.68, 11.68, 8.76, NULL, NULL),
(39, 19, NULL, NULL, 'Direccion Origen 237', 8.31943, -62.574309, 'Direccion Destino 237', 8.321881, -62.524618, 'cancelado', 1, '2026-05-27 18:23:09', NULL, NULL, 6.14, 6.14, 4.6, NULL, NULL),
(49, 17, NULL, NULL, 'Direccion Origen 238', 8.272923, -62.640062, 'Direccion Destino 238', 8.361001, -62.619899, 'completado', 1, '2026-07-13 06:20:56', '2026-07-13 06:32:56', '2026-07-13 07:15:56', 9.23, 9.23, 6.92, 5, NULL),
(32, 1, NULL, NULL, 'Direccion Origen 239', 8.362959, -62.585968, 'Direccion Destino 239', 8.389695, -62.591016, 'completado', 1, '2026-07-09 08:51:57', '2026-07-09 09:01:57', '2026-07-09 09:30:57', 2.67, 2.67, 2.0, 3, NULL),
(10, NULL, NULL, NULL, 'Direccion Origen 240', 8.241923, -62.671638, 'Direccion Destino 240', 8.268257, -62.661774, 'cancelado', 1, '2026-06-16 10:12:10', NULL, NULL, 11.23, 11.23, 8.42, NULL, NULL),
(40, 16, NULL, NULL, 'Direccion Origen 241', 8.207021, -62.504212, 'Direccion Destino 241', 8.318494, -62.637593, 'completado', 1, '2026-07-15 12:27:30', '2026-07-15 12:38:30', '2026-07-15 13:05:30', 6.06, 6.06, 4.54, 4, NULL),
(59, 4, NULL, NULL, 'Direccion Origen 242', 8.268441, -62.631269, 'Direccion Destino 242', 8.277854, -62.51872, 'completado', 1, '2026-06-28 14:31:51', '2026-06-28 14:46:51', '2026-06-28 15:03:51', 10.92, 10.92, 8.19, 3, NULL),
(53, 5, NULL, NULL, 'Direccion Origen 243', 8.224493, -62.656872, 'Direccion Destino 243', 8.36431, -62.558354, 'completado', 1, '2026-06-27 13:09:55', '2026-06-27 13:20:55', '2026-06-27 14:00:55', 7.87, 7.87, 5.9, 4, NULL),
(45, 23, NULL, NULL, 'Direccion Origen 244', 8.222072, -62.649117, 'Direccion Destino 244', 8.382964, -62.654044, 'completado', 1, '2026-07-09 11:42:59', '2026-07-09 11:55:59', '2026-07-09 12:13:59', 3.57, 3.57, 2.68, 3, NULL),
(4, 21, NULL, NULL, 'Direccion Origen 245', 8.377363, -62.567363, 'Direccion Destino 245', 8.311215, -62.593829, 'completado', 1, '2026-07-05 03:54:52', '2026-07-05 04:04:52', '2026-07-05 04:42:52', 3.3, 3.3, 2.47, 5, NULL),
(46, 1, NULL, NULL, 'Direccion Origen 246', 8.362142, -62.528551, 'Direccion Destino 246', 8.287876, -62.622617, 'en_progreso', 1, '2026-06-29 15:31:47', NULL, NULL, 2.97, 2.97, 2.23, NULL, NULL),
(8, 2, NULL, NULL, 'Direccion Origen 247', 8.232616, -62.519176, 'Direccion Destino 247', 8.204898, -62.540505, 'completado', 1, '2026-07-17 10:33:55', '2026-07-17 10:39:55', '2026-07-17 11:21:55', 8.11, 8.11, 6.08, 3, NULL),
(2, 14, NULL, NULL, 'Direccion Origen 248', 8.219164, -62.691106, 'Direccion Destino 248', 8.210755, -62.646782, 'completado', 1, '2026-07-03 10:19:08', '2026-07-03 10:31:08', '2026-07-03 11:15:08', 8.52, 8.52, 6.39, 5, NULL),
(3, 11, NULL, NULL, 'Direccion Origen 249', 8.363208, -62.681757, 'Direccion Destino 249', 8.301679, -62.631838, 'completado', 1, '2026-07-10 17:13:23', '2026-07-10 17:20:23', '2026-07-10 18:01:23', 5.06, 5.06, 3.79, 5, NULL),
(42, 23, NULL, NULL, 'Direccion Origen 250', 8.240624, -62.644548, 'Direccion Destino 250', 8.353552, -62.680083, 'completado', 1, '2026-05-28 00:45:20', '2026-05-28 00:52:20', '2026-05-28 01:24:20', 14.9, 14.9, 11.18, 5, NULL),
(45, 25, NULL, NULL, 'Direccion Origen 251', 8.233797, -62.580381, 'Direccion Destino 251', 8.266554, -62.623534, 'completado', 1, '2026-07-16 14:31:38', '2026-07-16 14:45:38', '2026-07-16 15:14:38', 8.77, 8.77, 6.58, 3, NULL),
(19, 2, NULL, NULL, 'Direccion Origen 252', 8.356988, -62.507655, 'Direccion Destino 252', 8.247243, -62.513921, 'cancelado', 1, '2026-06-13 06:20:00', NULL, NULL, 12.31, 12.31, 9.23, NULL, NULL),
(14, NULL, NULL, NULL, 'Direccion Origen 253', 8.211996, -62.553511, 'Direccion Destino 253', 8.366831, -62.505106, 'cancelado', 1, '2026-06-24 01:47:09', NULL, NULL, 11.33, 11.33, 8.5, NULL, NULL),
(21, 17, NULL, NULL, 'Direccion Origen 254', 8.342892, -62.528912, 'Direccion Destino 254', 8.26806, -62.611989, 'completado', 1, '2026-06-12 11:13:57', '2026-06-12 11:21:57', '2026-06-12 11:39:57', 13.7, 13.7, 10.27, 3, NULL),
(49, 19, NULL, NULL, 'Direccion Origen 255', 8.39113, -62.620358, 'Direccion Destino 255', 8.316153, -62.547405, 'cancelado', 1, '2026-07-21 07:25:08', NULL, NULL, 9.77, 9.77, 7.33, NULL, NULL),
(15, 19, NULL, NULL, 'Direccion Origen 256', 8.241521, -62.59168, 'Direccion Destino 256', 8.282726, -62.671644, 'completado', 1, '2026-06-27 07:42:31', '2026-06-27 07:53:31', '2026-06-27 08:13:31', 6.57, 6.57, 4.93, 5, NULL),
(11, 12, NULL, NULL, 'Direccion Origen 257', 8.265595, -62.529027, 'Direccion Destino 257', 8.266251, -62.630113, 'completado', 1, '2026-06-25 13:14:16', '2026-06-25 13:19:16', '2026-06-25 13:37:16', 3.25, 3.25, 2.44, 3, NULL),
(33, 2, NULL, NULL, 'Direccion Origen 258', 8.237777, -62.661934, 'Direccion Destino 258', 8.304766, -62.510617, 'completado', 1, '2026-06-19 18:41:36', '2026-06-19 18:56:36', '2026-06-19 19:38:36', 3.47, 3.47, 2.6, 5, NULL),
(12, 12, NULL, NULL, 'Direccion Origen 259', 8.326143, -62.557419, 'Direccion Destino 259', 8.350053, -62.594703, 'completado', 1, '2026-07-19 19:34:55', '2026-07-19 19:44:55', '2026-07-19 20:29:55', 8.54, 8.54, 6.4, 5, NULL),
(35, 12, NULL, NULL, 'Direccion Origen 260', 8.318606, -62.507435, 'Direccion Destino 260', 8.274718, -62.599481, 'completado', 1, '2026-06-17 18:50:13', '2026-06-17 18:57:13', '2026-06-17 19:30:13', 5.06, 5.06, 3.79, 5, NULL),
(4, 6, NULL, NULL, 'Direccion Origen 261', 8.338865, -62.502971, 'Direccion Destino 261', 8.291715, -62.681393, 'completado', 1, '2026-05-27 21:11:50', '2026-05-27 21:17:50', '2026-05-27 21:40:50', 3.24, 3.24, 2.43, 3, NULL),
(17, 14, NULL, NULL, 'Direccion Origen 262', 8.275937, -62.642694, 'Direccion Destino 262', 8.229879, -62.511531, 'cancelado', 1, '2026-06-30 15:41:13', NULL, NULL, 12.14, 12.14, 9.11, NULL, NULL),
(43, 18, NULL, NULL, 'Direccion Origen 263', 8.328032, -62.653143, 'Direccion Destino 263', 8.348179, -62.515425, 'completado', 1, '2026-06-27 20:16:50', '2026-06-27 20:29:50', '2026-06-27 21:11:50', 9.27, 9.27, 6.95, 4, NULL),
(9, 11, NULL, NULL, 'Direccion Origen 264', 8.269955, -62.522, 'Direccion Destino 264', 8.399834, -62.678505, 'cancelado', 1, '2026-06-16 00:12:11', NULL, NULL, 8.61, 8.61, 6.46, NULL, NULL),
(29, 15, NULL, NULL, 'Direccion Origen 265', 8.201857, -62.519241, 'Direccion Destino 265', 8.310813, -62.509319, 'completado', 1, '2026-06-30 05:13:40', '2026-06-30 05:24:40', '2026-06-30 06:05:40', 10.17, 10.17, 7.63, 3, NULL),
(53, 15, NULL, NULL, 'Direccion Origen 266', 8.220242, -62.653706, 'Direccion Destino 266', 8.264297, -62.532221, 'en_progreso', 1, '2026-07-09 14:48:01', NULL, NULL, 7.99, 7.99, 5.99, NULL, NULL),
(54, 6, NULL, NULL, 'Direccion Origen 267', 8.362201, -62.578492, 'Direccion Destino 267', 8.382886, -62.621351, 'completado', 1, '2026-07-19 22:47:24', '2026-07-19 23:02:24', '2026-07-19 23:24:24', 3.22, 3.22, 2.42, 5, NULL),
(11, NULL, NULL, NULL, 'Direccion Origen 268', 8.334076, -62.540054, 'Direccion Destino 268', 8.384823, -62.696269, 'cancelado', 1, '2026-07-14 15:13:58', NULL, NULL, 5.35, 5.35, 4.01, NULL, NULL),
(53, 20, NULL, NULL, 'Direccion Origen 269', 8.295754, -62.525491, 'Direccion Destino 269', 8.22924, -62.649608, 'completado', 1, '2026-07-15 23:15:45', '2026-07-15 23:22:45', '2026-07-15 23:42:45', 12.18, 12.18, 9.13, 5, NULL),
(10, 5, NULL, NULL, 'Direccion Origen 270', 8.25225, -62.566435, 'Direccion Destino 270', 8.217286, -62.553138, 'completado', 1, '2026-06-08 13:35:54', '2026-06-08 13:49:54', '2026-06-08 14:19:54', 3.93, 3.93, 2.95, 4, NULL),
(24, 4, NULL, NULL, 'Direccion Origen 271', 8.263521, -62.67955, 'Direccion Destino 271', 8.209152, -62.556347, 'cancelado', 1, '2026-06-18 05:03:35', NULL, NULL, 10.95, 10.95, 8.21, NULL, NULL),
(38, 16, NULL, NULL, 'Direccion Origen 272', 8.201571, -62.624395, 'Direccion Destino 272', 8.211034, -62.622369, 'completado', 1, '2026-06-20 05:32:43', '2026-06-20 05:43:43', '2026-06-20 06:01:43', 12.88, 12.88, 9.66, 4, NULL),
(14, 25, NULL, NULL, 'Direccion Origen 273', 8.333299, -62.647859, 'Direccion Destino 273', 8.302212, -62.674858, 'en_progreso', 1, '2026-06-17 16:09:49', NULL, NULL, 14.53, 14.53, 10.9, NULL, NULL),
(27, 16, NULL, NULL, 'Direccion Origen 274', 8.209232, -62.541976, 'Direccion Destino 274', 8.316333, -62.689197, 'cancelado', 1, '2026-06-24 17:29:51', NULL, NULL, 3.55, 3.55, 2.66, NULL, NULL),
(15, NULL, NULL, NULL, 'Direccion Origen 275', 8.368518, -62.669299, 'Direccion Destino 275', 8.340138, -62.639102, 'cancelado', 1, '2026-06-10 15:05:20', NULL, NULL, 6.37, 6.37, 4.78, NULL, NULL),
(39, 20, NULL, NULL, 'Direccion Origen 276', 8.29831, -62.627904, 'Direccion Destino 276', 8.353591, -62.579837, 'completado', 1, '2026-06-21 23:06:15', '2026-06-21 23:14:15', '2026-06-21 23:26:15', 7.1, 7.1, 5.32, 4, NULL),
(57, 23, NULL, NULL, 'Direccion Origen 277', 8.305139, -62.509491, 'Direccion Destino 277', 8.324631, -62.596424, 'en_progreso', 1, '2026-06-08 13:16:41', NULL, NULL, 3.71, 3.71, 2.78, NULL, NULL),
(40, 23, NULL, NULL, 'Direccion Origen 278', 8.247222, -62.638262, 'Direccion Destino 278', 8.260621, -62.514322, 'completado', 1, '2026-07-18 07:21:23', '2026-07-18 07:27:23', '2026-07-18 08:11:23', 11.63, 11.63, 8.72, 5, NULL),
(23, 13, NULL, NULL, 'Direccion Origen 279', 8.217108, -62.57414, 'Direccion Destino 279', 8.385973, -62.611956, 'completado', 1, '2026-07-23 12:15:28', '2026-07-23 12:29:28', '2026-07-23 12:45:28', 9.16, 9.16, 6.87, 3, NULL),
(22, 6, NULL, NULL, 'Direccion Origen 280', 8.213705, -62.543309, 'Direccion Destino 280', 8.357745, -62.612359, 'completado', 1, '2026-07-09 18:15:16', '2026-07-09 18:22:16', '2026-07-09 18:37:16', 2.79, 2.79, 2.09, 4, NULL),
(17, 17, NULL, NULL, 'Direccion Origen 281', 8.233855, -62.618542, 'Direccion Destino 281', 8.372439, -62.692194, 'completado', 1, '2026-06-07 17:49:35', '2026-06-07 17:59:35', '2026-06-07 18:24:35', 5.37, 5.37, 4.03, 5, NULL),
(16, 15, NULL, NULL, 'Direccion Origen 282', 8.210027, -62.564465, 'Direccion Destino 282', 8.25453, -62.686623, 'completado', 1, '2026-05-30 09:41:05', '2026-05-30 09:48:05', '2026-05-30 10:26:05', 7.36, 7.36, 5.52, 5, NULL),
(35, 18, NULL, NULL, 'Direccion Origen 283', 8.216101, -62.564046, 'Direccion Destino 283', 8.352072, -62.620259, 'completado', 1, '2026-06-26 00:27:26', '2026-06-26 00:42:26', '2026-06-26 00:59:26', 13.49, 13.49, 10.12, 3, NULL),
(4, 11, NULL, NULL, 'Direccion Origen 284', 8.392695, -62.526343, 'Direccion Destino 284', 8.221693, -62.611468, 'completado', 1, '2026-06-15 15:22:38', '2026-06-15 15:36:38', '2026-06-15 16:18:38', 5.58, 5.58, 4.19, 3, NULL),
(13, 5, NULL, NULL, 'Direccion Origen 285', 8.214841, -62.522352, 'Direccion Destino 285', 8.277208, -62.555681, 'cancelado', 1, '2026-06-23 21:58:56', NULL, NULL, 7.77, 7.77, 5.83, NULL, NULL),
(55, 5, NULL, NULL, 'Direccion Origen 286', 8.207853, -62.614511, 'Direccion Destino 286', 8.339396, -62.665438, 'completado', 1, '2026-06-08 18:18:26', '2026-06-08 18:23:26', '2026-06-08 18:42:26', 13.71, 13.71, 10.28, 3, NULL),
(18, 5, NULL, NULL, 'Direccion Origen 287', 8.37742, -62.676642, 'Direccion Destino 287', 8.29426, -62.679682, 'en_progreso', 1, '2026-07-08 03:17:09', NULL, NULL, 9.1, 9.1, 6.82, NULL, NULL),
(11, 8, NULL, NULL, 'Direccion Origen 288', 8.261017, -62.675688, 'Direccion Destino 288', 8.279104, -62.613036, 'completado', 1, '2026-06-18 00:53:41', '2026-06-18 01:04:41', '2026-06-18 01:18:41', 5.16, 5.16, 3.87, 4, NULL),
(19, 15, NULL, NULL, 'Direccion Origen 289', 8.240197, -62.595597, 'Direccion Destino 289', 8.349931, -62.660757, 'en_progreso', 1, '2026-07-10 15:53:02', NULL, NULL, 8.84, 8.84, 6.63, NULL, NULL),
(34, 16, NULL, NULL, 'Direccion Origen 290', 8.292183, -62.587895, 'Direccion Destino 290', 8.256308, -62.553977, 'completado', 1, '2026-06-03 00:37:19', '2026-06-03 00:45:19', '2026-06-03 01:27:19', 3.34, 3.34, 2.5, 4, NULL),
(6, 2, NULL, NULL, 'Direccion Origen 291', 8.302331, -62.563689, 'Direccion Destino 291', 8.293798, -62.572297, 'completado', 1, '2026-07-08 00:45:16', '2026-07-08 00:54:16', '2026-07-08 01:15:16', 11.43, 11.43, 8.57, 4, NULL),
(11, NULL, NULL, NULL, 'Direccion Origen 292', 8.34869, -62.548469, 'Direccion Destino 292', 8.291696, -62.589123, 'cancelado', 1, '2026-06-24 14:44:07', NULL, NULL, 5.64, 5.64, 4.23, NULL, NULL),
(40, NULL, NULL, NULL, 'Direccion Origen 293', 8.329828, -62.669919, 'Direccion Destino 293', 8.248599, -62.684884, 'cancelado', 1, '2026-07-11 15:46:31', NULL, NULL, 10.2, 10.2, 7.65, NULL, NULL),
(54, 22, NULL, NULL, 'Direccion Origen 294', 8.360188, -62.528184, 'Direccion Destino 294', 8.353512, -62.622742, 'completado', 1, '2026-07-09 03:39:01', '2026-07-09 03:54:01', '2026-07-09 04:06:01', 3.04, 3.04, 2.28, 5, NULL),
(8, 22, NULL, NULL, 'Direccion Origen 295', 8.206058, -62.604705, 'Direccion Destino 295', 8.385063, -62.699022, 'completado', 1, '2026-07-07 07:13:17', '2026-07-07 07:22:17', '2026-07-07 07:59:17', 8.62, 8.62, 6.46, 3, NULL),
(40, 6, NULL, NULL, 'Direccion Origen 296', 8.275343, -62.514206, 'Direccion Destino 296', 8.273913, -62.586786, 'completado', 1, '2026-07-11 01:34:06', '2026-07-11 01:42:06', '2026-07-11 02:08:06', 13.47, 13.47, 10.1, 5, NULL),
(36, 2, NULL, NULL, 'Direccion Origen 297', 8.348412, -62.608106, 'Direccion Destino 297', 8.34819, -62.52969, 'completado', 1, '2026-06-26 16:23:43', '2026-06-26 16:30:43', '2026-06-26 17:11:43', 14.76, 14.76, 11.07, 3, NULL),
(59, 16, NULL, NULL, 'Direccion Origen 298', 8.396893, -62.612802, 'Direccion Destino 298', 8.204323, -62.568444, 'en_progreso', 1, '2026-07-09 02:49:33', NULL, NULL, 2.87, 2.87, 2.15, NULL, NULL),
(22, 22, NULL, NULL, 'Direccion Origen 299', 8.201164, -62.634011, 'Direccion Destino 299', 8.293249, -62.686128, 'completado', 1, '2026-07-08 12:09:39', '2026-07-08 12:14:39', '2026-07-08 12:32:39', 12.18, 12.18, 9.13, 5, NULL);
