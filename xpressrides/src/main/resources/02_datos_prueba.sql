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

-- 0.4 Triggers actualizados: notificaciones de inserción y actualización de traslados
DROP TRIGGER IF EXISTS trg_traslado_insert_notificacion;

DELIMITER $$

CREATE TRIGGER trg_traslado_insert_notificacion
AFTER INSERT ON traslado
FOR EACH ROW
BEGIN
  DECLARE v_id_usuario_chofer INT;

  IF NEW.estado = 'solicitado' AND NEW.id_chofer IS NOT NULL THEN
    SELECT u.id INTO v_id_usuario_chofer
      FROM chofer ch JOIN usuario u ON ch.id_usuario = u.id
     WHERE ch.id = NEW.id_chofer;

    IF v_id_usuario_chofer IS NOT NULL THEN
      INSERT INTO notificacion (id_usuario, id_traslado, tipo, mensaje)
      VALUES (v_id_usuario_chofer, NEW.id, 'viaje_solicitado',
        'Tienes una nueva solicitud de viaje.');
    END IF;
  END IF;
END$$

DELIMITER ;

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

  IF NEW.estado = 'solicitado' AND NEW.id_chofer IS NOT NULL AND (OLD.id_chofer IS NULL OR OLD.id_chofer <> NEW.id_chofer) AND v_id_usuario_chofer IS NOT NULL THEN
    INSERT INTO notificacion (id_usuario, id_traslado, tipo, mensaje)
    VALUES (v_id_usuario_chofer, NEW.id, 'viaje_solicitado',
      'Tienes una nueva solicitud de viaje.');
  END IF;

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
TRUNCATE TABLE tasa_bcv;
TRUNCATE TABLE cupon_cliente;
TRUNCATE TABLE cupon;
TRUNCATE TABLE token_revocado;
TRUNCATE TABLE cliente;
TRUNCATE TABLE chofer;
TRUNCATE TABLE personal_admin;
TRUNCATE TABLE usuario;
SET FOREIGN_KEY_CHECKS = 1;

INSERT INTO usuario (cedula, nombre, apellido, username, password_hash, email, telefono, rol) VALUES
('V-31783162', 'Ángel', 'Martínez', 'angelm', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'angelm@admin.com', '0426-1979320', 'administrador'),
('V-32015232', 'Freddy', 'Salazar', 'freddys', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'freddys@admin.com', '0426-4331483', 'administrador'),
('V-32417248', 'Eliuber', 'González', 'eliuberg', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'eliuberg@admin.com', '0412-8633836', 'administrador'),
('V-31757491', 'Manuel', 'Jaimes', 'manuelj', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'manuelj@admin.com', '0414-7502138', 'administrador'),
('V-14089807', 'Johanna', 'Guédez', 'johannag', '$2a$10$SeAgMoDqTfHmtpDSpSmkteZTMNqT/LSyOOc7tzVkr1Mhhqge3aq5i', 'johannag@admin.com', '0424-8905131', 'administrador'),
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

INSERT INTO personal_admin (id_usuario, cargo) VALUES
(1, 'Administrador del Sistema'),
(2, 'Administrador del Sistema'),
(3, 'Administrador del Sistema'),
(4, 'Administrador del Sistema'),
(5, 'Administrador del Sistema');

INSERT INTO cliente (id_usuario, saldo_usd, es_estudiante, codigo_referido) VALUES
(6, 90.51, 1, 'REF0000006'),
(7, 50.47, 1, 'REF0000007'),
(8, 54.09, 1, 'REF0000008'),
(9, 92.03, 1, 'REF0000009'),
(10, 8.72, 1, 'REF0000010'),
(11, 15.92, 1, 'REF0000011'),
(12, 80.35, 1, 'REF0000012'),
(13, 59.94, 1, 'REF0000013'),
(14, 16.16, 1, 'REF0000014'),
(15, 82.46, 1, 'REF0000015'),
(16, 62.33, 1, 'REF0000016'),
(17, 59.24, 1, 'REF0000017'),
(18, 73.51, 1, 'REF0000018'),
(19, 99.7, 1, 'REF0000019'),
(20, 99.58, 1, 'REF0000020'),
(21, 63.8, 1, 'REF0000021'),
(22, 72.74, 1, 'REF0000022'),
(23, 25.46, 1, 'REF0000023'),
(24, 51.38, 1, 'REF0000024'),
(25, 50.51, 1, 'REF0000025'),
(26, 39.36, 1, 'REF0000026'),
(27, 14.39, 1, 'REF0000027'),
(28, 78.39, 1, 'REF0000028'),
(29, 12.07, 1, 'REF0000029'),
(30, 28.39, 1, 'REF0000030'),
(31, 89.71, 1, 'REF0000031'),
(32, 27.88, 1, 'REF0000032'),
(33, 17.2, 1, 'REF0000033'),
(34, 6.35, 1, 'REF0000034'),
(35, 39.56, 1, 'REF0000035'),
(36, 83.1, 1, 'REF0000036'),
(37, 96.0, 1, 'REF0000037'),
(38, 83.13, 1, 'REF0000038'),
(39, 17.52, 1, 'REF0000039'),
(40, 47.88, 1, 'REF0000040'),
(41, 49.22, 1, 'REF0000041'),
(42, 36.18, 1, 'REF0000042'),
(43, 66.02, 1, 'REF0000043'),
(44, 73.68, 1, 'REF0000044'),
(45, 64.03, 1, 'REF0000045'),
(46, 51.83, 1, 'REF0000046'),
(47, 57.7, 1, 'REF0000047'),
(48, 40.18, 1, 'REF0000048'),
(49, 83.82, 1, 'REF0000049'),
(50, 75.42, 1, 'REF0000050'),
(51, 50.57, 1, 'REF0000051'),
(52, 31.64, 1, 'REF0000052'),
(53, 90.24, 1, 'REF0000053'),
(54, 31.64, 1, 'REF0000054'),
(55, 37.57, 1, 'REF0000055'),
(56, 13.75, 1, 'REF0000056'),
(57, 77.92, 1, 'REF0000057'),
(58, 56.46, 1, 'REF0000058'),
(59, 43.43, 1, 'REF0000059'),
(60, 76.52, 1, 'REF0000060'),
(61, 18.14, 1, 'REF0000061'),
(62, 93.43, 1, 'REF0000062'),
(63, 70.52, 1, 'REF0000063'),
(64, 26.73, 1, 'REF0000064'),
(65, 67.75, 1, 'REF0000065');

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

INSERT INTO evaluacion_psicologica (id_chofer, id_admin, calificacion, fecha_eval, observacion) VALUES
(1, 5, 85.00, '2026-01-29', 'Sin observaciones'),
(2, 2, 85.00, '2026-05-11', 'Sin observaciones'),
(3, 2, 85.00, '2026-02-01', 'Sin observaciones'),
(4, 3, 85.00, '2026-06-26', 'Sin observaciones'),
(5, 1, 85.00, '2026-04-07', 'Sin observaciones'),
(6, 5, 85.00, '2026-05-14', 'Sin observaciones'),
(7, 5, 85.00, '2026-05-31', 'Sin observaciones'),
(8, 4, 85.00, '2026-03-06', 'Sin observaciones'),
(9, 1, 85.00, '2026-07-16', 'Sin observaciones'),
(10, 2, 85.00, '2026-03-29', 'Sin observaciones'),
(11, 1, 85.00, '2026-05-19', 'Sin observaciones'),
(12, 3, 85.00, '2026-06-08', 'Sin observaciones'),
(13, 4, 85.00, '2026-02-05', 'Sin observaciones'),
(14, 5, 85.00, '2026-03-16', 'Sin observaciones'),
(15, 4, 85.00, '2026-06-14', 'Sin observaciones'),
(16, 5, 85.00, '2026-03-21', 'Sin observaciones'),
(17, 2, 85.00, '2026-05-31', 'Sin observaciones'),
(18, 5, 85.00, '2026-07-22', 'Sin observaciones'),
(19, 2, 85.00, '2026-06-05', 'Sin observaciones'),
(20, 3, 85.00, '2026-07-09', 'Sin observaciones'),
(21, 3, 85.00, '2026-07-14', 'Sin observaciones'),
(22, 1, 85.00, '2026-05-12', 'Sin observaciones'),
(23, 1, 85.00, '2026-04-17', 'Sin observaciones'),
(24, 1, 85.00, '2026-03-03', 'Sin observaciones'),
(25, 5, 85.00, '2026-04-22', 'Sin observaciones');

INSERT INTO vehiculo (id_chofer, placa, marca, modelo, anio_fabricacion, color, activo) VALUES
(1, 'FRC294', 'Honda', 'Civic', 2022, 'Rojo', 1),
(2, 'GCM860', 'Chevrolet', 'Cruze', 2022, 'Blanco', 1),
(3, 'KRV142', 'Kia', 'Rio', 2014, 'Plata', 1),
(4, 'YIE304', 'Mazda', 'Mazda6', 2023, 'Rojo', 1),
(5, 'KYQ647', 'Kia', 'Forte', 2011, 'Negro', 1),
(6, 'ZMX536', 'Honda', 'CR-V', 2013, 'Gris', 1),
(7, 'ELY127', 'Toyota', 'Hilux', 2023, 'Gris', 1),
(8, 'MKI862', 'Ford', 'Fiesta', 2014, 'Plata', 1),
(9, 'YXB996', 'Chevrolet', 'Aveo', 2010, 'Plata', 1),
(10, 'ADV550', 'Chevrolet', 'Aveo', 2014, 'Azul', 1),
(11, 'PDV219', 'Chevrolet', 'Spark', 2014, 'Blanco', 1),
(12, 'DNB691', 'Kia', 'Sportage', 2021, 'Gris', 1),
(13, 'IPB682', 'Ford', 'Fiesta', 2009, 'Negro', 1),
(14, 'JGJ945', 'Chevrolet', 'Optra', 2017, 'Negro', 1),
(15, 'QXJ883', 'Chevrolet', 'Aveo', 2011, 'Plata', 1),
(16, 'MRC228', 'Kia', 'Rio', 2008, 'Gris', 1),
(17, 'EDS325', 'Mazda', 'Mazda3', 2023, 'Plata', 1),
(18, 'PVL782', 'Nissan', 'Altima', 2020, 'Rojo', 1),
(19, 'OKS198', 'Toyota', 'Yaris', 2019, 'Plata', 1),
(20, 'IUP637', 'Nissan', 'Versa', 2017, 'Plata', 1),
(21, 'FJE786', 'Ford', 'Fiesta', 2017, 'Plata', 1),
(22, 'GTB036', 'Chevrolet', 'Cruze', 2013, 'Gris', 1),
(23, 'INW898', 'Honda', 'Fit', 2018, 'Rojo', 1),
(24, 'JZH105', 'Hyundai', 'Accent', 2016, 'Rojo', 1),
(25, 'JCW564', 'Chevrolet', 'Spark', 2024, 'Rojo', 1);

INSERT INTO revision_vehiculo (id_vehiculo, id_admin, calificacion, fecha_revision, observacion) VALUES
(1, 5, 85.00, '2026-06-18', 'Buenas condiciones'),
(2, 1, 85.00, '2026-03-25', 'Buenas condiciones'),
(3, 4, 85.00, '2026-02-07', 'Buenas condiciones'),
(4, 5, 85.00, '2026-05-28', 'Buenas condiciones'),
(5, 3, 85.00, '2026-03-11', 'Buenas condiciones'),
(6, 4, 85.00, '2026-03-16', 'Buenas condiciones'),
(7, 4, 85.00, '2026-07-15', 'Buenas condiciones'),
(8, 3, 85.00, '2026-02-23', 'Buenas condiciones'),
(9, 2, 85.00, '2026-06-17', 'Buenas condiciones'),
(10, 5, 85.00, '2026-05-25', 'Buenas condiciones'),
(11, 1, 85.00, '2026-02-22', 'Buenas condiciones'),
(12, 3, 85.00, '2026-03-10', 'Buenas condiciones'),
(13, 4, 85.00, '2026-05-14', 'Buenas condiciones'),
(14, 3, 85.00, '2026-07-10', 'Buenas condiciones'),
(15, 1, 85.00, '2026-02-04', 'Buenas condiciones'),
(16, 1, 85.00, '2026-06-10', 'Buenas condiciones'),
(17, 4, 85.00, '2026-07-05', 'Buenas condiciones'),
(18, 5, 85.00, '2026-07-08', 'Buenas condiciones'),
(19, 5, 85.00, '2026-07-03', 'Buenas condiciones'),
(20, 3, 85.00, '2026-05-19', 'Buenas condiciones'),
(21, 1, 85.00, '2026-04-17', 'Buenas condiciones'),
(22, 2, 85.00, '2026-06-03', 'Buenas condiciones'),
(23, 2, 85.00, '2026-03-24', 'Buenas condiciones'),
(24, 5, 85.00, '2026-02-20', 'Buenas condiciones'),
(25, 2, 85.00, '2026-05-24', 'Buenas condiciones');

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

INSERT INTO tasa_bcv (id, fecha_vigencia, tasa_ves, registrado_por) VALUES (1, '2026-01-01', 36.50, 1);

INSERT INTO traslado (
  id_cliente, id_chofer, id_vehiculo, id_zona_origen, id_zona_destino, id_tasa, id_cupon_cliente,
  nro_pasajeros, distancia_km, tarifa_base_usd, recargo_horario_usd, factor_hora_pico, descuento_usd,
  costo_cliente_usd, monto_chofer_usd, monto_empresa_usd, costo_cliente_ves, estado,
  calificacion_estrellas, fecha_solicitud, fecha_asignacion_actual, fecha_aceptacion, fecha_inicio, fecha_fin
) VALUES
(24, 11, 1, 1, 2, 1, NULL, 1, 5.0, 5.41, 0.0, 1.0, 0.0, 5.41, 4.06, 1.35, 197.47, 'completado', 3, '2026-06-04 09:13:23', '2026-06-04 09:13:23', '2026-06-04 09:13:23', '2026-06-04 09:28:23', '2026-06-04 09:53:23'),
(59, 10, 1, 1, 2, 1, NULL, 1, 5.0, 11.44, 0.0, 1.0, 0.0, 11.44, 8.58, 2.86, 417.56, 'completado', 4, '2026-07-09 23:19:36', '2026-07-09 23:19:36', '2026-07-09 23:19:36', '2026-07-09 23:27:36', '2026-07-10 00:10:36'),
(15, 15, 1, 1, 2, 1, NULL, 1, 5.0, 9.61, 0.0, 1.0, 0.0, 9.61, 7.21, 2.4, 350.76, 'completado', 5, '2026-06-14 08:04:52', '2026-06-14 08:04:52', '2026-06-14 08:04:52', '2026-06-14 08:17:52', '2026-06-14 08:50:52'),
(3, 5, 1, 1, 2, 1, NULL, 1, 5.0, 7.54, 0.0, 1.0, 0.0, 7.54, 5.66, 1.88, 275.21, 'completado', 5, '2026-05-31 21:02:05', '2026-05-31 21:02:05', '2026-05-31 21:02:05', '2026-05-31 21:13:05', '2026-05-31 21:44:05'),
(11, 5, 1, 1, 2, 1, NULL, 1, 5.0, 7.43, 0.0, 1.0, 0.0, 7.43, 5.57, 1.86, 271.19, 'completado', 4, '2026-06-23 19:35:34', '2026-06-23 19:35:34', '2026-06-23 19:35:34', '2026-06-23 19:49:34', '2026-06-23 20:26:34'),
(13, 8, 1, 1, 2, 1, NULL, 1, 5.0, 12.81, 0.0, 1.0, 0.0, 12.81, 9.61, 3.2, 467.56, 'completado', 5, '2026-06-27 19:32:34', '2026-06-27 19:32:34', '2026-06-27 19:32:34', '2026-06-27 19:42:34', '2026-06-27 20:14:34'),
(47, 8, 1, 1, 2, 1, NULL, 1, 5.0, 6.12, 0.0, 1.0, 0.0, 6.12, 4.59, 1.53, 223.38, 'completado', 5, '2026-07-23 02:38:12', '2026-07-23 02:38:12', '2026-07-23 02:38:12', '2026-07-23 02:46:12', '2026-07-23 03:18:12'),
(42, 12, 1, 1, 2, 1, NULL, 1, 5.0, 2.53, 0.0, 1.0, 0.0, 2.53, 1.9, 0.63, 92.34, 'completado', 4, '2026-06-27 08:48:00', '2026-06-27 08:48:00', '2026-06-27 08:48:00', '2026-06-27 09:02:00', '2026-06-27 09:22:00'),
(11, 24, 1, 1, 2, 1, NULL, 1, 5.0, 7.73, 0.0, 1.0, 0.0, 7.73, 5.8, 1.93, 282.15, 'completado', 3, '2026-07-08 12:16:32', '2026-07-08 12:16:32', '2026-07-08 12:16:32', '2026-07-08 12:23:32', '2026-07-08 13:04:32'),
(9, 20, 1, 1, 2, 1, NULL, 1, 5.0, 5.04, 0.0, 1.0, 0.0, 5.04, 3.78, 1.26, 183.96, 'cancelado', NULL, '2026-06-04 04:28:45', '2026-06-04 04:28:45', '2026-06-04 04:28:45', NULL, NULL),
(4, 19, 1, 1, 2, 1, NULL, 1, 5.0, 12.84, 0.0, 1.0, 0.0, 12.84, 9.63, 3.21, 468.66, 'completado', 5, '2026-05-28 05:28:15', '2026-05-28 05:28:15', '2026-05-28 05:28:15', '2026-05-28 05:43:15', '2026-05-28 06:07:15'),
(47, 1, 1, 1, 2, 1, NULL, 1, 5.0, 2.92, 0.0, 1.0, 0.0, 2.92, 2.19, 0.73, 106.58, 'cancelado', NULL, '2026-06-17 13:26:32', '2026-06-17 13:26:32', '2026-06-17 13:26:32', NULL, NULL),
(47, 4, 1, 1, 2, 1, NULL, 1, 5.0, 13.21, 0.0, 1.0, 0.0, 13.21, 9.91, 3.3, 482.17, 'completado', 3, '2026-06-08 09:52:17', '2026-06-08 09:52:17', '2026-06-08 09:52:17', '2026-06-08 09:58:17', '2026-06-08 10:22:17'),
(9, 11, 1, 1, 2, 1, NULL, 1, 5.0, 9.13, 0.0, 1.0, 0.0, 9.13, 6.85, 2.28, 333.25, 'completado', 4, '2026-06-04 15:33:56', '2026-06-04 15:33:56', '2026-06-04 15:33:56', '2026-06-04 15:46:56', '2026-06-04 16:00:56'),
(54, 23, 1, 1, 2, 1, NULL, 1, 5.0, 11.03, 0.0, 1.0, 0.0, 11.03, 8.27, 2.76, 402.59, 'completado', 4, '2026-06-22 18:10:32', '2026-06-22 18:10:32', '2026-06-22 18:10:32', '2026-06-22 18:25:32', '2026-06-22 18:45:32'),
(28, 21, 1, 1, 2, 1, NULL, 1, 5.0, 8.12, 0.0, 1.0, 0.0, 8.12, 6.09, 2.03, 296.38, 'completado', 4, '2026-07-05 03:22:40', '2026-07-05 03:22:40', '2026-07-05 03:22:40', '2026-07-05 03:29:40', '2026-07-05 04:04:40'),
(9, 18, 1, 1, 2, 1, NULL, 1, 5.0, 14.42, 0.0, 1.0, 0.0, 14.42, 10.81, 3.61, 526.33, 'completado', 5, '2026-07-08 19:42:50', '2026-07-08 19:42:50', '2026-07-08 19:42:50', '2026-07-08 19:49:50', '2026-07-08 20:11:50'),
(12, 24, 1, 1, 2, 1, NULL, 1, 5.0, 7.32, 0.0, 1.0, 0.0, 7.32, 5.49, 1.83, 267.18, 'completado', 5, '2026-06-25 21:12:57', '2026-06-25 21:12:57', '2026-06-25 21:12:57', '2026-06-25 21:27:57', '2026-06-25 21:49:57'),
(46, 9, 1, 1, 2, 1, NULL, 1, 5.0, 4.11, 0.0, 1.0, 0.0, 4.11, 3.08, 1.03, 150.02, 'completado', 3, '2026-06-16 20:59:13', '2026-06-16 20:59:13', '2026-06-16 20:59:13', '2026-06-16 21:08:13', '2026-06-16 21:51:13'),
(55, 17, 1, 1, 2, 1, NULL, 1, 5.0, 4.62, 0.0, 1.0, 0.0, 4.62, 3.46, 1.16, 168.63, 'completado', 3, '2026-07-16 00:43:44', '2026-07-16 00:43:44', '2026-07-16 00:43:44', '2026-07-16 00:54:44', '2026-07-16 01:29:44'),
(59, 13, 1, 1, 2, 1, NULL, 1, 5.0, 13.45, 0.0, 1.0, 0.0, 13.45, 10.09, 3.36, 490.92, 'completado', 5, '2026-06-27 06:58:10', '2026-06-27 06:58:10', '2026-06-27 06:58:10', '2026-06-27 07:05:10', '2026-06-27 07:47:10'),
(34, 22, 1, 1, 2, 1, NULL, 1, 5.0, 12.59, 0.0, 1.0, 0.0, 12.59, 9.44, 3.15, 459.53, 'completado', 5, '2026-06-10 03:37:53', '2026-06-10 03:37:53', '2026-06-10 03:37:53', '2026-06-10 03:42:53', '2026-06-10 04:11:53'),
(41, 23, 1, 1, 2, 1, NULL, 1, 5.0, 5.62, 0.0, 1.0, 0.0, 5.62, 4.21, 1.41, 205.13, 'completado', 5, '2026-06-21 16:45:27', '2026-06-21 16:45:27', '2026-06-21 16:45:27', '2026-06-21 16:53:27', '2026-06-21 17:13:27'),
(7, 22, 1, 1, 2, 1, NULL, 1, 5.0, 14.68, 0.0, 1.0, 0.0, 14.68, 11.01, 3.67, 535.82, 'completado', 4, '2026-07-23 17:09:57', '2026-07-23 17:09:57', '2026-07-23 17:09:57', '2026-07-23 17:20:57', '2026-07-23 18:01:57'),
(7, 1, 1, 1, 2, 1, NULL, 1, 5.0, 6.95, 0.0, 1.0, 0.0, 6.95, 5.21, 1.74, 253.68, 'cancelado', NULL, '2026-05-31 17:23:07', '2026-05-31 17:23:07', '2026-05-31 17:23:07', NULL, NULL),
(10, 12, 1, 1, 2, 1, NULL, 1, 5.0, 8.96, 0.0, 1.0, 0.0, 8.96, 6.72, 2.24, 327.04, 'completado', 5, '2026-06-01 11:50:03', '2026-06-01 11:50:03', '2026-06-01 11:50:03', '2026-06-01 12:01:03', '2026-06-01 12:26:03'),
(28, 6, 1, 1, 2, 1, NULL, 1, 5.0, 9.12, 0.0, 1.0, 0.0, 9.12, 6.84, 2.28, 332.88, 'completado', 4, '2026-06-28 12:40:12', '2026-06-28 12:40:12', '2026-06-28 12:40:12', '2026-06-28 12:48:12', '2026-06-28 13:10:12'),
(40, 22, 1, 1, 2, 1, NULL, 1, 5.0, 13.5, 0.0, 1.0, 0.0, 13.5, 10.12, 3.38, 492.75, 'completado', 3, '2026-06-21 23:46:15', '2026-06-21 23:46:15', '2026-06-21 23:46:15', '2026-06-22 00:00:15', '2026-06-22 00:23:15'),
(16, 18, 1, 1, 2, 1, NULL, 1, 5.0, 10.57, 0.0, 1.0, 0.0, 10.57, 7.93, 2.64, 385.81, 'completado', 3, '2026-06-08 23:49:26', '2026-06-08 23:49:26', '2026-06-08 23:49:26', '2026-06-08 23:55:26', '2026-06-09 00:37:26'),
(19, 22, 1, 1, 2, 1, NULL, 1, 5.0, 7.67, 0.0, 1.0, 0.0, 7.67, 5.75, 1.92, 279.95, 'completado', 5, '2026-06-25 14:33:26', '2026-06-25 14:33:26', '2026-06-25 14:33:26', '2026-06-25 14:42:26', '2026-06-25 15:27:26'),
(22, 5, 1, 1, 2, 1, NULL, 1, 5.0, 4.09, 0.0, 1.0, 0.0, 4.09, 3.07, 1.02, 149.28, 'completado', 3, '2026-06-13 08:05:22', '2026-06-13 08:05:22', '2026-06-13 08:05:22', '2026-06-13 08:18:22', '2026-06-13 09:01:22'),
(48, 13, 1, 1, 2, 1, NULL, 1, 5.0, 3.02, 0.0, 1.0, 0.0, 3.02, 2.27, 0.75, 110.23, 'completado', 4, '2026-07-16 20:23:09', '2026-07-16 20:23:09', '2026-07-16 20:23:09', '2026-07-16 20:31:09', '2026-07-16 20:52:09'),
(25, 1, 1, 1, 2, 1, NULL, 1, 5.0, 10.43, 0.0, 1.0, 0.0, 10.43, 7.82, 2.61, 380.69, 'completado', 3, '2026-06-09 14:38:53', '2026-06-09 14:38:53', '2026-06-09 14:38:53', '2026-06-09 14:47:53', '2026-06-09 15:16:53'),
(44, 12, 1, 1, 2, 1, NULL, 1, 5.0, 14.42, 0.0, 1.0, 0.0, 14.42, 10.81, 3.61, 526.33, 'completado', 4, '2026-06-30 02:42:22', '2026-06-30 02:42:22', '2026-06-30 02:42:22', '2026-06-30 02:49:22', '2026-06-30 03:04:22'),
(44, 1, 1, 1, 2, 1, NULL, 1, 5.0, 9.31, 0.0, 1.0, 0.0, 9.31, 6.98, 2.33, 339.81, 'cancelado', NULL, '2026-07-19 22:16:02', '2026-07-19 22:16:02', '2026-07-19 22:16:02', NULL, NULL),
(40, 9, 1, 1, 2, 1, NULL, 1, 5.0, 4.07, 0.0, 1.0, 0.0, 4.07, 3.05, 1.02, 148.56, 'completado', 3, '2026-06-27 17:42:30', '2026-06-27 17:42:30', '2026-06-27 17:42:30', '2026-06-27 17:49:30', '2026-06-27 18:16:30'),
(8, 4, 1, 1, 2, 1, NULL, 1, 5.0, 5.47, 0.0, 1.0, 0.0, 5.47, 4.1, 1.37, 199.66, 'completado', 4, '2026-07-19 09:41:13', '2026-07-19 09:41:13', '2026-07-19 09:41:13', '2026-07-19 09:47:13', '2026-07-19 10:32:13'),
(46, 5, 1, 1, 2, 1, NULL, 1, 5.0, 12.19, 0.0, 1.0, 0.0, 12.19, 9.14, 3.05, 444.94, 'cancelado', NULL, '2026-06-03 03:48:21', '2026-06-03 03:48:21', '2026-06-03 03:48:21', NULL, NULL),
(43, 4, 1, 1, 2, 1, NULL, 1, 5.0, 10.16, 0.0, 1.0, 0.0, 10.16, 7.62, 2.54, 370.84, 'completado', 5, '2026-07-09 22:57:19', '2026-07-09 22:57:19', '2026-07-09 22:57:19', '2026-07-09 23:10:19', '2026-07-09 23:42:19'),
(54, 19, 1, 1, 2, 1, NULL, 1, 5.0, 13.44, 0.0, 1.0, 0.0, 13.44, 10.08, 3.36, 490.56, 'completado', 5, '2026-07-23 12:51:09', '2026-07-23 12:51:09', '2026-07-23 12:51:09', '2026-07-23 12:57:09', '2026-07-23 13:34:09'),
(42, 22, 1, 1, 2, 1, NULL, 1, 5.0, 4.02, 0.0, 1.0, 0.0, 4.02, 3.01, 1.01, 146.73, 'completado', 5, '2026-06-14 11:51:02', '2026-06-14 11:51:02', '2026-06-14 11:51:02', '2026-06-14 12:02:02', '2026-06-14 12:32:02'),
(22, 1, 1, 1, 2, 1, NULL, 1, 5.0, 12.77, 0.0, 1.0, 0.0, 12.77, 9.58, 3.19, 466.1, 'cancelado', NULL, '2026-06-01 06:03:08', '2026-06-01 06:03:08', '2026-06-01 06:03:08', NULL, NULL),
(16, 9, 1, 1, 2, 1, NULL, 1, 5.0, 10.51, 0.0, 1.0, 0.0, 10.51, 7.88, 2.63, 383.62, 'completado', 5, '2026-06-14 03:40:30', '2026-06-14 03:40:30', '2026-06-14 03:40:30', '2026-06-14 03:45:30', '2026-06-14 04:23:30'),
(52, 24, 1, 1, 2, 1, NULL, 1, 5.0, 13.43, 0.0, 1.0, 0.0, 13.43, 10.07, 3.36, 490.19, 'completado', 5, '2026-07-11 17:06:14', '2026-07-11 17:06:14', '2026-07-11 17:06:14', '2026-07-11 17:15:14', '2026-07-11 17:44:14'),
(30, 2, 1, 1, 2, 1, NULL, 1, 5.0, 3.0, 0.0, 1.0, 0.0, 3.0, 2.25, 0.75, 109.5, 'completado', 4, '2026-07-03 21:51:07', '2026-07-03 21:51:07', '2026-07-03 21:51:07', '2026-07-03 22:04:07', '2026-07-03 22:49:07'),
(30, 19, 1, 1, 2, 1, NULL, 1, 5.0, 4.23, 0.0, 1.0, 0.0, 4.23, 3.17, 1.06, 154.4, 'completado', 5, '2026-07-24 06:19:02', '2026-07-24 06:19:02', '2026-07-24 06:19:02', '2026-07-24 06:30:02', '2026-07-24 07:03:02'),
(40, 21, 1, 1, 2, 1, NULL, 1, 5.0, 4.02, 0.0, 1.0, 0.0, 4.02, 3.01, 1.01, 146.73, 'completado', 5, '2026-07-17 08:36:23', '2026-07-17 08:36:23', '2026-07-17 08:36:23', '2026-07-17 08:45:23', '2026-07-17 08:55:23'),
(60, 20, 1, 1, 2, 1, NULL, 1, 5.0, 7.38, 0.0, 1.0, 0.0, 7.38, 5.54, 1.84, 269.37, 'completado', 5, '2026-06-04 12:18:26', '2026-06-04 12:18:26', '2026-06-04 12:18:26', '2026-06-04 12:31:26', '2026-06-04 12:46:26'),
(4, 15, 1, 1, 2, 1, NULL, 1, 5.0, 14.58, 0.0, 1.0, 0.0, 14.58, 10.94, 3.64, 532.17, 'completado', 3, '2026-06-22 14:15:52', '2026-06-22 14:15:52', '2026-06-22 14:15:52', '2026-06-22 14:20:52', '2026-06-22 14:59:52'),
(26, 21, 1, 1, 2, 1, NULL, 1, 5.0, 6.75, 0.0, 1.0, 0.0, 6.75, 5.06, 1.69, 246.38, 'completado', 4, '2026-07-15 17:01:21', '2026-07-15 17:01:21', '2026-07-15 17:01:21', '2026-07-15 17:13:21', '2026-07-15 17:48:21'),
(39, 7, 1, 1, 2, 1, NULL, 1, 5.0, 6.05, 0.0, 1.0, 0.0, 6.05, 4.54, 1.51, 220.82, 'cancelado', NULL, '2026-07-24 00:28:08', '2026-07-24 00:28:08', '2026-07-24 00:28:08', NULL, NULL),
(27, 16, 1, 1, 2, 1, NULL, 1, 5.0, 12.59, 0.0, 1.0, 0.0, 12.59, 9.44, 3.15, 459.53, 'completado', 4, '2026-06-27 17:07:45', '2026-06-27 17:07:45', '2026-06-27 17:07:45', '2026-06-27 17:16:45', '2026-06-27 17:54:45'),
(58, 1, 1, 1, 2, 1, NULL, 1, 5.0, 13.35, 0.0, 1.0, 0.0, 13.35, 10.01, 3.34, 487.27, 'cancelado', NULL, '2026-06-25 17:08:41', '2026-06-25 17:08:41', '2026-06-25 17:08:41', NULL, NULL),
(40, 1, 1, 1, 2, 1, NULL, 1, 5.0, 6.21, 0.0, 1.0, 0.0, 6.21, 4.66, 1.55, 226.66, 'completado', 3, '2026-06-30 16:20:32', '2026-06-30 16:20:32', '2026-06-30 16:20:32', '2026-06-30 16:26:32', '2026-06-30 16:47:32'),
(58, 10, 1, 1, 2, 1, NULL, 1, 5.0, 12.11, 0.0, 1.0, 0.0, 12.11, 9.08, 3.03, 442.01, 'completado', 3, '2026-06-06 19:34:36', '2026-06-06 19:34:36', '2026-06-06 19:34:36', '2026-06-06 19:41:36', '2026-06-06 20:24:36'),
(42, 1, 1, 1, 2, 1, NULL, 1, 5.0, 9.73, 0.0, 1.0, 0.0, 9.73, 7.3, 2.43, 355.15, 'completado', 5, '2026-07-21 07:56:42', '2026-07-21 07:56:42', '2026-07-21 07:56:42', '2026-07-21 08:10:42', '2026-07-21 08:54:42'),
(16, 18, 1, 1, 2, 1, NULL, 1, 5.0, 7.81, 0.0, 1.0, 0.0, 7.81, 5.86, 1.95, 285.06, 'completado', 3, '2026-06-06 00:28:06', '2026-06-06 00:28:06', '2026-06-06 00:28:06', '2026-06-06 00:40:06', '2026-06-06 01:01:06'),
(46, 1, 1, 1, 2, 1, NULL, 1, 5.0, 10.66, 0.0, 1.0, 0.0, 10.66, 8.0, 2.66, 389.09, 'completado', 3, '2026-07-01 02:02:38', '2026-07-01 02:02:38', '2026-07-01 02:02:38', '2026-07-01 02:11:38', '2026-07-01 02:35:38'),
(5, 22, 1, 1, 2, 1, NULL, 1, 5.0, 12.34, 0.0, 1.0, 0.0, 12.34, 9.25, 3.09, 450.41, 'completado', 5, '2026-06-19 05:35:36', '2026-06-19 05:35:36', '2026-06-19 05:35:36', '2026-06-19 05:47:36', '2026-06-19 06:25:36'),
(8, 25, 1, 1, 2, 1, NULL, 1, 5.0, 9.3, 0.0, 1.0, 0.0, 9.3, 6.98, 2.32, 339.45, 'completado', 3, '2026-06-19 14:50:27', '2026-06-19 14:50:27', '2026-06-19 14:50:27', '2026-06-19 14:57:27', '2026-06-19 15:22:27'),
(50, 16, 1, 1, 2, 1, NULL, 1, 5.0, 5.54, 0.0, 1.0, 0.0, 5.54, 4.16, 1.38, 202.21, 'completado', 5, '2026-06-27 06:06:22', '2026-06-27 06:06:22', '2026-06-27 06:06:22', '2026-06-27 06:12:22', '2026-06-27 06:28:22'),
(34, 14, 1, 1, 2, 1, NULL, 1, 5.0, 12.74, 0.0, 1.0, 0.0, 12.74, 9.55, 3.19, 465.01, 'cancelado', NULL, '2026-07-24 05:28:49', '2026-07-24 05:28:49', '2026-07-24 05:28:49', NULL, NULL),
(5, 10, 1, 1, 2, 1, NULL, 1, 5.0, 4.91, 0.0, 1.0, 0.0, 4.91, 3.68, 1.23, 179.22, 'completado', 5, '2026-06-14 05:26:48', '2026-06-14 05:26:48', '2026-06-14 05:26:48', '2026-06-14 05:31:48', '2026-06-14 06:01:48'),
(57, 6, 1, 1, 2, 1, NULL, 1, 5.0, 12.7, 0.0, 1.0, 0.0, 12.7, 9.52, 3.18, 463.55, 'cancelado', NULL, '2026-07-20 02:45:41', '2026-07-20 02:45:41', '2026-07-20 02:45:41', NULL, NULL),
(8, 5, 1, 1, 2, 1, NULL, 1, 5.0, 9.41, 0.0, 1.0, 0.0, 9.41, 7.06, 2.35, 343.47, 'completado', 4, '2026-06-01 08:28:16', '2026-06-01 08:28:16', '2026-06-01 08:28:16', '2026-06-01 08:42:16', '2026-06-01 09:13:16'),
(27, 10, 1, 1, 2, 1, NULL, 1, 5.0, 9.24, 0.0, 1.0, 0.0, 9.24, 6.93, 2.31, 337.26, 'completado', 5, '2026-06-29 05:10:45', '2026-06-29 05:10:45', '2026-06-29 05:10:45', '2026-06-29 05:20:45', '2026-06-29 05:49:45'),
(55, 1, 1, 1, 2, 1, NULL, 1, 5.0, 5.61, 0.0, 1.0, 0.0, 5.61, 4.21, 1.4, 204.77, 'completado', 5, '2026-07-12 12:31:39', '2026-07-12 12:31:39', '2026-07-12 12:31:39', '2026-07-12 12:36:39', '2026-07-12 13:03:39'),
(57, 3, 1, 1, 2, 1, NULL, 1, 5.0, 10.46, 0.0, 1.0, 0.0, 10.46, 7.85, 2.61, 381.79, 'completado', 5, '2026-07-19 22:46:11', '2026-07-19 22:46:11', '2026-07-19 22:46:11', '2026-07-19 22:59:11', '2026-07-19 23:33:11'),
(45, 10, 1, 1, 2, 1, NULL, 1, 5.0, 6.99, 0.0, 1.0, 0.0, 6.99, 5.24, 1.75, 255.14, 'completado', 4, '2026-07-05 04:49:43', '2026-07-05 04:49:43', '2026-07-05 04:49:43', '2026-07-05 04:56:43', '2026-07-05 05:24:43'),
(54, 9, 1, 1, 2, 1, NULL, 1, 5.0, 8.42, 0.0, 1.0, 0.0, 8.42, 6.31, 2.11, 307.33, 'completado', 5, '2026-06-22 08:24:21', '2026-06-22 08:24:21', '2026-06-22 08:24:21', '2026-06-22 08:34:21', '2026-06-22 09:15:21'),
(2, 2, 1, 1, 2, 1, NULL, 1, 5.0, 6.72, 0.0, 1.0, 0.0, 6.72, 5.04, 1.68, 245.28, 'completado', 4, '2026-07-07 21:23:10', '2026-07-07 21:23:10', '2026-07-07 21:23:10', '2026-07-07 21:37:10', '2026-07-07 22:18:10'),
(56, 15, 1, 1, 2, 1, NULL, 1, 5.0, 7.21, 0.0, 1.0, 0.0, 7.21, 5.41, 1.8, 263.17, 'completado', 4, '2026-07-14 15:49:02', '2026-07-14 15:49:02', '2026-07-14 15:49:02', '2026-07-14 16:04:02', '2026-07-14 16:28:02'),
(23, 6, 1, 1, 2, 1, NULL, 1, 5.0, 9.65, 0.0, 1.0, 0.0, 9.65, 7.24, 2.41, 352.23, 'completado', 4, '2026-06-02 12:32:28', '2026-06-02 12:32:28', '2026-06-02 12:32:28', '2026-06-02 12:42:28', '2026-06-02 13:04:28'),
(55, 10, 1, 1, 2, 1, NULL, 1, 5.0, 7.56, 0.0, 1.0, 0.0, 7.56, 5.67, 1.89, 275.94, 'completado', 4, '2026-06-07 05:35:08', '2026-06-07 05:35:08', '2026-06-07 05:35:08', '2026-06-07 05:42:08', '2026-06-07 06:10:08'),
(38, 9, 1, 1, 2, 1, NULL, 1, 5.0, 12.97, 0.0, 1.0, 0.0, 12.97, 9.73, 3.24, 473.41, 'cancelado', NULL, '2026-05-30 00:51:25', '2026-05-30 00:51:25', '2026-05-30 00:51:25', NULL, NULL),
(45, 24, 1, 1, 2, 1, NULL, 1, 5.0, 8.06, 0.0, 1.0, 0.0, 8.06, 6.04, 2.02, 294.19, 'completado', 3, '2026-06-10 17:05:05', '2026-06-10 17:05:05', '2026-06-10 17:05:05', '2026-06-10 17:18:05', '2026-06-10 18:03:05'),
(3, 1, 1, 1, 2, 1, NULL, 1, 5.0, 3.09, 0.0, 1.0, 0.0, 3.09, 2.32, 0.77, 112.78, 'cancelado', NULL, '2026-06-10 11:32:49', '2026-06-10 11:32:49', '2026-06-10 11:32:49', NULL, NULL),
(37, 2, 1, 1, 2, 1, NULL, 1, 5.0, 4.82, 0.0, 1.0, 0.0, 4.82, 3.62, 1.2, 175.93, 'completado', 3, '2026-06-30 17:50:07', '2026-06-30 17:50:07', '2026-06-30 17:50:07', '2026-06-30 17:56:07', '2026-06-30 18:22:07'),
(39, 4, 1, 1, 2, 1, NULL, 1, 5.0, 14.04, 0.0, 1.0, 0.0, 14.04, 10.53, 3.51, 512.46, 'completado', 4, '2026-07-03 09:25:56', '2026-07-03 09:25:56', '2026-07-03 09:25:56', '2026-07-03 09:38:56', '2026-07-03 10:13:56'),
(54, 16, 1, 1, 2, 1, NULL, 1, 5.0, 5.11, 0.0, 1.0, 0.0, 5.11, 3.83, 1.28, 186.52, 'cancelado', NULL, '2026-06-19 04:49:19', '2026-06-19 04:49:19', '2026-06-19 04:49:19', NULL, NULL),
(58, 12, 1, 1, 2, 1, NULL, 1, 5.0, 7.21, 0.0, 1.0, 0.0, 7.21, 5.41, 1.8, 263.17, 'completado', 5, '2026-06-03 07:45:01', '2026-06-03 07:45:01', '2026-06-03 07:45:01', '2026-06-03 07:50:01', '2026-06-03 08:19:01'),
(8, 1, 1, 1, 2, 1, NULL, 1, 5.0, 9.35, 0.0, 1.0, 0.0, 9.35, 7.01, 2.34, 341.27, 'cancelado', NULL, '2026-07-24 20:41:41', '2026-07-24 20:41:41', '2026-07-24 20:41:41', NULL, NULL),
(33, 12, 1, 1, 2, 1, NULL, 1, 5.0, 13.83, 0.0, 1.0, 0.0, 13.83, 10.37, 3.46, 504.8, 'completado', 3, '2026-07-17 00:05:11', '2026-07-17 00:05:11', '2026-07-17 00:05:11', '2026-07-17 00:10:11', '2026-07-17 00:32:11'),
(17, 15, 1, 1, 2, 1, NULL, 1, 5.0, 13.55, 0.0, 1.0, 0.0, 13.55, 10.16, 3.39, 494.58, 'completado', 3, '2026-06-05 05:45:48', '2026-06-05 05:45:48', '2026-06-05 05:45:48', '2026-06-05 05:58:48', '2026-06-05 06:20:48'),
(18, 24, 1, 1, 2, 1, NULL, 1, 5.0, 6.44, 0.0, 1.0, 0.0, 6.44, 4.83, 1.61, 235.06, 'completado', 5, '2026-07-21 03:42:08', '2026-07-21 03:42:08', '2026-07-21 03:42:08', '2026-07-21 03:50:08', '2026-07-21 04:16:08'),
(57, 5, 1, 1, 2, 1, NULL, 1, 5.0, 11.76, 0.0, 1.0, 0.0, 11.76, 8.82, 2.94, 429.24, 'completado', 5, '2026-07-14 04:19:17', '2026-07-14 04:19:17', '2026-07-14 04:19:17', '2026-07-14 04:31:17', '2026-07-14 04:50:17'),
(12, 4, 1, 1, 2, 1, NULL, 1, 5.0, 9.61, 0.0, 1.0, 0.0, 9.61, 7.21, 2.4, 350.76, 'completado', 5, '2026-07-04 09:23:08', '2026-07-04 09:23:08', '2026-07-04 09:23:08', '2026-07-04 09:30:08', '2026-07-04 09:47:08'),
(36, 10, 1, 1, 2, 1, NULL, 1, 5.0, 8.72, 0.0, 1.0, 0.0, 8.72, 6.54, 2.18, 318.28, 'completado', 5, '2026-07-01 14:30:19', '2026-07-01 14:30:19', '2026-07-01 14:30:19', '2026-07-01 14:36:19', '2026-07-01 15:08:19'),
(46, 16, 1, 1, 2, 1, NULL, 1, 5.0, 14.7, 0.0, 1.0, 0.0, 14.7, 11.02, 3.68, 536.55, 'completado', 4, '2026-06-29 18:32:14', '2026-06-29 18:32:14', '2026-06-29 18:32:14', '2026-06-29 18:47:14', '2026-06-29 19:22:14'),
(28, 4, 1, 1, 2, 1, NULL, 1, 5.0, 8.25, 0.0, 1.0, 0.0, 8.25, 6.19, 2.06, 301.12, 'completado', 4, '2026-07-25 02:11:49', '2026-07-25 02:11:49', '2026-07-25 02:11:49', '2026-07-25 02:25:49', '2026-07-25 02:56:49'),
(14, 8, 1, 1, 2, 1, NULL, 1, 5.0, 3.05, 0.0, 1.0, 0.0, 3.05, 2.29, 0.76, 111.32, 'completado', 3, '2026-06-30 09:41:03', '2026-06-30 09:41:03', '2026-06-30 09:41:03', '2026-06-30 09:51:03', '2026-06-30 10:20:03'),
(4, 1, 1, 1, 2, 1, NULL, 1, 5.0, 5.44, 0.0, 1.0, 0.0, 5.44, 4.08, 1.36, 198.56, 'cancelado', NULL, '2026-05-28 22:39:57', '2026-05-28 22:39:57', '2026-05-28 22:39:57', NULL, NULL),
(1, 2, 1, 1, 2, 1, NULL, 1, 5.0, 3.32, 0.0, 1.0, 0.0, 3.32, 2.49, 0.83, 121.18, 'completado', 4, '2026-07-11 21:44:13', '2026-07-11 21:44:13', '2026-07-11 21:44:13', '2026-07-11 21:52:13', '2026-07-11 22:33:13'),
(47, 4, 1, 1, 2, 1, NULL, 1, 5.0, 7.12, 0.0, 1.0, 0.0, 7.12, 5.34, 1.78, 259.88, 'completado', 3, '2026-07-11 05:16:04', '2026-07-11 05:16:04', '2026-07-11 05:16:04', '2026-07-11 05:21:04', '2026-07-11 05:42:04'),
(60, 8, 1, 1, 2, 1, NULL, 1, 5.0, 13.69, 0.0, 1.0, 0.0, 13.69, 10.27, 3.42, 499.69, 'completado', 3, '2026-06-25 17:18:10', '2026-06-25 17:18:10', '2026-06-25 17:18:10', '2026-06-25 17:28:10', '2026-06-25 17:44:10'),
(25, 19, 1, 1, 2, 1, NULL, 1, 5.0, 11.92, 0.0, 1.0, 0.0, 11.92, 8.94, 2.98, 435.08, 'completado', 4, '2026-06-14 02:14:57', '2026-06-14 02:14:57', '2026-06-14 02:14:57', '2026-06-14 02:26:57', '2026-06-14 03:06:57'),
(33, 6, 1, 1, 2, 1, NULL, 1, 5.0, 2.75, 0.0, 1.0, 0.0, 2.75, 2.06, 0.69, 100.38, 'completado', 5, '2026-05-30 22:57:12', '2026-05-30 22:57:12', '2026-05-30 22:57:12', '2026-05-30 23:08:12', '2026-05-30 23:35:12'),
(21, 16, 1, 1, 2, 1, NULL, 1, 5.0, 3.91, 0.0, 1.0, 0.0, 3.91, 2.93, 0.98, 142.72, 'completado', 4, '2026-06-21 22:11:58', '2026-06-21 22:11:58', '2026-06-21 22:11:58', '2026-06-21 22:25:58', '2026-06-21 22:59:58'),
(25, 14, 1, 1, 2, 1, NULL, 1, 5.0, 6.66, 0.0, 1.0, 0.0, 6.66, 5.0, 1.66, 243.09, 'completado', 4, '2026-06-21 19:17:21', '2026-06-21 19:17:21', '2026-06-21 19:17:21', '2026-06-21 19:28:21', '2026-06-21 20:01:21'),
(36, 13, 1, 1, 2, 1, NULL, 1, 5.0, 11.33, 0.0, 1.0, 0.0, 11.33, 8.5, 2.83, 413.55, 'completado', 4, '2026-06-25 20:47:46', '2026-06-25 20:47:46', '2026-06-25 20:47:46', '2026-06-25 20:59:46', '2026-06-25 21:14:46'),
(15, 14, 1, 1, 2, 1, NULL, 1, 5.0, 14.8, 0.0, 1.0, 0.0, 14.8, 11.1, 3.7, 540.2, 'completado', 4, '2026-06-20 05:04:31', '2026-06-20 05:04:31', '2026-06-20 05:04:31', '2026-06-20 05:16:31', '2026-06-20 05:35:31'),
(27, 17, 1, 1, 2, 1, NULL, 1, 5.0, 13.77, 0.0, 1.0, 0.0, 13.77, 10.33, 3.44, 502.6, 'completado', 3, '2026-06-15 15:38:47', '2026-06-15 15:38:47', '2026-06-15 15:38:47', '2026-06-15 15:52:47', '2026-06-15 16:07:47'),
(49, 1, 1, 1, 2, 1, NULL, 1, 5.0, 8.29, 0.0, 1.0, 0.0, 8.29, 6.22, 2.07, 302.58, 'cancelado', NULL, '2026-07-05 21:40:47', '2026-07-05 21:40:47', '2026-07-05 21:40:47', NULL, NULL),
(24, 21, 1, 1, 2, 1, NULL, 1, 5.0, 12.98, 0.0, 1.0, 0.0, 12.98, 9.73, 3.25, 473.77, 'cancelado', NULL, '2026-06-10 06:27:57', '2026-06-10 06:27:57', '2026-06-10 06:27:57', NULL, NULL),
(52, 5, 1, 1, 2, 1, NULL, 1, 5.0, 6.81, 0.0, 1.0, 0.0, 6.81, 5.11, 1.7, 248.56, 'completado', 4, '2026-07-02 17:22:00', '2026-07-02 17:22:00', '2026-07-02 17:22:00', '2026-07-02 17:31:00', '2026-07-02 17:55:00'),
(20, 20, 1, 1, 2, 1, NULL, 1, 5.0, 8.77, 0.0, 1.0, 0.0, 8.77, 6.58, 2.19, 320.1, 'completado', 3, '2026-06-23 03:53:57', '2026-06-23 03:53:57', '2026-06-23 03:53:57', '2026-06-23 04:04:57', '2026-06-23 04:44:57'),
(14, 8, 1, 1, 2, 1, NULL, 1, 5.0, 10.17, 0.0, 1.0, 0.0, 10.17, 7.63, 2.54, 371.2, 'completado', 3, '2026-06-06 11:28:49', '2026-06-06 11:28:49', '2026-06-06 11:28:49', '2026-06-06 11:43:49', '2026-06-06 12:28:49'),
(55, 3, 1, 1, 2, 1, NULL, 1, 5.0, 10.15, 0.0, 1.0, 0.0, 10.15, 7.61, 2.54, 370.48, 'completado', 5, '2026-06-11 10:02:01', '2026-06-11 10:02:01', '2026-06-11 10:02:01', '2026-06-11 10:09:01', '2026-06-11 10:50:01'),
(12, 24, 1, 1, 2, 1, NULL, 1, 5.0, 8.27, 0.0, 1.0, 0.0, 8.27, 6.2, 2.07, 301.85, 'completado', 5, '2026-07-08 14:38:58', '2026-07-08 14:38:58', '2026-07-08 14:38:58', '2026-07-08 14:45:58', '2026-07-08 15:30:58'),
(25, 23, 1, 1, 2, 1, NULL, 1, 5.0, 14.95, 0.0, 1.0, 0.0, 14.95, 11.21, 3.74, 545.67, 'completado', 4, '2026-07-24 02:32:18', '2026-07-24 02:32:18', '2026-07-24 02:32:18', '2026-07-24 02:46:18', '2026-07-24 03:00:18'),
(52, 19, 1, 1, 2, 1, NULL, 1, 5.0, 9.63, 0.0, 1.0, 0.0, 9.63, 7.22, 2.41, 351.5, 'completado', 3, '2026-06-28 15:00:11', '2026-06-28 15:00:11', '2026-06-28 15:00:11', '2026-06-28 15:07:11', '2026-06-28 15:32:11'),
(4, 9, 1, 1, 2, 1, NULL, 1, 5.0, 4.24, 0.0, 1.0, 0.0, 4.24, 3.18, 1.06, 154.76, 'completado', 5, '2026-06-24 20:35:49', '2026-06-24 20:35:49', '2026-06-24 20:35:49', '2026-06-24 20:46:49', '2026-06-24 21:03:49'),
(47, 10, 1, 1, 2, 1, NULL, 1, 5.0, 7.77, 0.0, 1.0, 0.0, 7.77, 5.83, 1.94, 283.6, 'completado', 3, '2026-06-07 03:54:21', '2026-06-07 03:54:21', '2026-06-07 03:54:21', '2026-06-07 04:05:21', '2026-06-07 04:26:21'),
(29, 2, 1, 1, 2, 1, NULL, 1, 5.0, 4.71, 0.0, 1.0, 0.0, 4.71, 3.53, 1.18, 171.91, 'completado', 5, '2026-06-04 01:18:16', '2026-06-04 01:18:16', '2026-06-04 01:18:16', '2026-06-04 01:31:16', '2026-06-04 02:14:16'),
(25, 1, 1, 1, 2, 1, NULL, 1, 5.0, 2.71, 0.0, 1.0, 0.0, 2.71, 2.03, 0.68, 98.91, 'cancelado', NULL, '2026-07-02 13:28:56', '2026-07-02 13:28:56', '2026-07-02 13:28:56', NULL, NULL),
(59, 25, 1, 1, 2, 1, NULL, 1, 5.0, 12.26, 0.0, 1.0, 0.0, 12.26, 9.2, 3.06, 447.49, 'completado', 3, '2026-05-27 18:33:23', '2026-05-27 18:33:23', '2026-05-27 18:33:23', '2026-05-27 18:47:23', '2026-05-27 19:14:23'),
(16, 18, 1, 1, 2, 1, NULL, 1, 5.0, 3.69, 0.0, 1.0, 0.0, 3.69, 2.77, 0.92, 134.69, 'completado', 3, '2026-06-12 03:50:46', '2026-06-12 03:50:46', '2026-06-12 03:50:46', '2026-06-12 03:56:46', '2026-06-12 04:28:46'),
(17, 15, 1, 1, 2, 1, NULL, 1, 5.0, 13.72, 0.0, 1.0, 0.0, 13.72, 10.29, 3.43, 500.78, 'completado', 4, '2026-06-27 18:39:38', '2026-06-27 18:39:38', '2026-06-27 18:39:38', '2026-06-27 18:54:38', '2026-06-27 19:19:38'),
(11, 12, 1, 1, 2, 1, NULL, 1, 5.0, 12.57, 0.0, 1.0, 0.0, 12.57, 9.43, 3.14, 458.81, 'completado', 5, '2026-07-11 05:41:23', '2026-07-11 05:41:23', '2026-07-11 05:41:23', '2026-07-11 05:55:23', '2026-07-11 06:27:23'),
(14, 6, 1, 1, 2, 1, NULL, 1, 5.0, 13.33, 0.0, 1.0, 0.0, 13.33, 10.0, 3.33, 486.55, 'completado', 3, '2026-06-22 17:10:46', '2026-06-22 17:10:46', '2026-06-22 17:10:46', '2026-06-22 17:16:46', '2026-06-22 17:55:46'),
(6, 15, 1, 1, 2, 1, NULL, 1, 5.0, 9.62, 0.0, 1.0, 0.0, 9.62, 7.21, 2.41, 351.13, 'completado', 4, '2026-07-02 00:54:24', '2026-07-02 00:54:24', '2026-07-02 00:54:24', '2026-07-02 01:09:24', '2026-07-02 01:34:24'),
(2, 19, 1, 1, 2, 1, NULL, 1, 5.0, 4.99, 0.0, 1.0, 0.0, 4.99, 3.74, 1.25, 182.14, 'completado', 5, '2026-07-04 18:54:27', '2026-07-04 18:54:27', '2026-07-04 18:54:27', '2026-07-04 19:05:27', '2026-07-04 19:49:27'),
(47, 7, 1, 1, 2, 1, NULL, 1, 5.0, 7.14, 0.0, 1.0, 0.0, 7.14, 5.35, 1.79, 260.61, 'completado', 5, '2026-06-20 18:43:22', '2026-06-20 18:43:22', '2026-06-20 18:43:22', '2026-06-20 18:53:22', '2026-06-20 19:33:22'),
(52, 23, 1, 1, 2, 1, NULL, 1, 5.0, 4.3, 0.0, 1.0, 0.0, 4.3, 3.22, 1.08, 156.95, 'completado', 3, '2026-06-09 07:36:29', '2026-06-09 07:36:29', '2026-06-09 07:36:29', '2026-06-09 07:51:29', '2026-06-09 08:12:29'),
(3, 15, 1, 1, 2, 1, NULL, 1, 5.0, 6.42, 0.0, 1.0, 0.0, 6.42, 4.81, 1.61, 234.33, 'completado', 5, '2026-07-12 16:13:57', '2026-07-12 16:13:57', '2026-07-12 16:13:57', '2026-07-12 16:25:57', '2026-07-12 17:03:57'),
(43, 4, 1, 1, 2, 1, NULL, 1, 5.0, 4.64, 0.0, 1.0, 0.0, 4.64, 3.48, 1.16, 169.36, 'completado', 3, '2026-06-30 20:38:21', '2026-06-30 20:38:21', '2026-06-30 20:38:21', '2026-06-30 20:53:21', '2026-06-30 21:19:21'),
(23, 22, 1, 1, 2, 1, NULL, 1, 5.0, 13.58, 0.0, 1.0, 0.0, 13.58, 10.19, 3.39, 495.67, 'completado', 3, '2026-07-13 20:12:28', '2026-07-13 20:12:28', '2026-07-13 20:12:28', '2026-07-13 20:20:28', '2026-07-13 20:42:28'),
(20, 10, 1, 1, 2, 1, NULL, 1, 5.0, 11.41, 0.0, 1.0, 0.0, 11.41, 8.56, 2.85, 416.47, 'cancelado', NULL, '2026-06-16 13:29:01', '2026-06-16 13:29:01', '2026-06-16 13:29:01', NULL, NULL),
(48, 25, 1, 1, 2, 1, NULL, 1, 5.0, 14.74, 0.0, 1.0, 0.0, 14.74, 11.05, 3.69, 538.01, 'completado', 5, '2026-05-31 06:39:07', '2026-05-31 06:39:07', '2026-05-31 06:39:07', '2026-05-31 06:54:07', '2026-05-31 07:25:07'),
(34, 4, 1, 1, 2, 1, NULL, 1, 5.0, 8.29, 0.0, 1.0, 0.0, 8.29, 6.22, 2.07, 302.58, 'completado', 3, '2026-07-10 08:35:58', '2026-07-10 08:35:58', '2026-07-10 08:35:58', '2026-07-10 08:45:58', '2026-07-10 08:56:58'),
(54, 5, 1, 1, 2, 1, NULL, 1, 5.0, 14.98, 0.0, 1.0, 0.0, 14.98, 11.23, 3.75, 546.77, 'completado', 3, '2026-06-05 00:11:16', '2026-06-05 00:11:16', '2026-06-05 00:11:16', '2026-06-05 00:24:16', '2026-06-05 01:00:16'),
(59, 7, 1, 1, 2, 1, NULL, 1, 5.0, 9.2, 0.0, 1.0, 0.0, 9.2, 6.9, 2.3, 335.8, 'cancelado', NULL, '2026-05-28 19:58:36', '2026-05-28 19:58:36', '2026-05-28 19:58:36', NULL, NULL),
(50, 15, 1, 1, 2, 1, NULL, 1, 5.0, 8.63, 0.0, 1.0, 0.0, 8.63, 6.47, 2.16, 315.0, 'completado', 3, '2026-07-18 09:59:53', '2026-07-18 09:59:53', '2026-07-18 09:59:53', '2026-07-18 10:07:53', '2026-07-18 10:43:53'),
(40, 1, 1, 1, 2, 1, NULL, 1, 5.0, 7.64, 0.0, 1.0, 0.0, 7.64, 5.73, 1.91, 278.86, 'cancelado', NULL, '2026-07-02 20:37:47', '2026-07-02 20:37:47', '2026-07-02 20:37:47', NULL, NULL),
(27, 7, 1, 1, 2, 1, NULL, 1, 5.0, 5.24, 0.0, 1.0, 0.0, 5.24, 3.93, 1.31, 191.26, 'completado', 5, '2026-06-13 06:13:11', '2026-06-13 06:13:11', '2026-06-13 06:13:11', '2026-06-13 06:25:11', '2026-06-13 07:10:11'),
(7, 16, 1, 1, 2, 1, NULL, 1, 5.0, 10.88, 0.0, 1.0, 0.0, 10.88, 8.16, 2.72, 397.12, 'completado', 4, '2026-06-07 00:57:03', '2026-06-07 00:57:03', '2026-06-07 00:57:03', '2026-06-07 01:03:03', '2026-06-07 01:35:03'),
(17, 16, 1, 1, 2, 1, NULL, 1, 5.0, 12.89, 0.0, 1.0, 0.0, 12.89, 9.67, 3.22, 470.49, 'completado', 3, '2026-06-16 22:19:18', '2026-06-16 22:19:18', '2026-06-16 22:19:18', '2026-06-16 22:33:18', '2026-06-16 22:54:18'),
(27, 21, 1, 1, 2, 1, NULL, 1, 5.0, 12.81, 0.0, 1.0, 0.0, 12.81, 9.61, 3.2, 467.56, 'completado', 3, '2026-06-06 01:18:16', '2026-06-06 01:18:16', '2026-06-06 01:18:16', '2026-06-06 01:28:16', '2026-06-06 01:52:16'),
(48, 17, 1, 1, 2, 1, NULL, 1, 5.0, 10.07, 0.0, 1.0, 0.0, 10.07, 7.55, 2.52, 367.56, 'completado', 3, '2026-06-04 17:00:30', '2026-06-04 17:00:30', '2026-06-04 17:00:30', '2026-06-04 17:15:30', '2026-06-04 17:45:30'),
(21, 21, 1, 1, 2, 1, NULL, 1, 5.0, 7.26, 0.0, 1.0, 0.0, 7.26, 5.45, 1.81, 264.99, 'completado', 4, '2026-06-30 03:40:07', '2026-06-30 03:40:07', '2026-06-30 03:40:07', '2026-06-30 03:48:07', '2026-06-30 04:27:07'),
(8, 13, 1, 1, 2, 1, NULL, 1, 5.0, 14.88, 0.0, 1.0, 0.0, 14.88, 11.16, 3.72, 543.12, 'completado', 5, '2026-06-25 04:24:26', '2026-06-25 04:24:26', '2026-06-25 04:24:26', '2026-06-25 04:30:26', '2026-06-25 05:05:26'),
(8, 24, 1, 1, 2, 1, NULL, 1, 5.0, 10.21, 0.0, 1.0, 0.0, 10.21, 7.66, 2.55, 372.67, 'completado', 3, '2026-06-17 10:38:52', '2026-06-17 10:38:52', '2026-06-17 10:38:52', '2026-06-17 10:47:52', '2026-06-17 11:24:52'),
(15, 8, 1, 1, 2, 1, NULL, 1, 5.0, 8.73, 0.0, 1.0, 0.0, 8.73, 6.55, 2.18, 318.65, 'completado', 5, '2026-06-21 19:39:46', '2026-06-21 19:39:46', '2026-06-21 19:39:46', '2026-06-21 19:48:46', '2026-06-21 20:12:46'),
(4, 15, 1, 1, 2, 1, NULL, 1, 5.0, 9.53, 0.0, 1.0, 0.0, 9.53, 7.15, 2.38, 347.84, 'completado', 5, '2026-06-24 00:15:38', '2026-06-24 00:15:38', '2026-06-24 00:15:38', '2026-06-24 00:23:38', '2026-06-24 00:53:38'),
(20, 2, 1, 1, 2, 1, NULL, 1, 5.0, 12.24, 0.0, 1.0, 0.0, 12.24, 9.18, 3.06, 446.76, 'completado', 5, '2026-06-04 04:21:27', '2026-06-04 04:21:27', '2026-06-04 04:21:27', '2026-06-04 04:33:27', '2026-06-04 04:56:27'),
(55, 1, 1, 1, 2, 1, NULL, 1, 5.0, 7.48, 0.0, 1.0, 0.0, 7.48, 5.61, 1.87, 273.02, 'completado', 4, '2026-06-18 21:35:23', '2026-06-18 21:35:23', '2026-06-18 21:35:23', '2026-06-18 21:50:23', '2026-06-18 22:35:23'),
(60, 16, 1, 1, 2, 1, NULL, 1, 5.0, 13.38, 0.0, 1.0, 0.0, 13.38, 10.04, 3.34, 488.37, 'completado', 3, '2026-07-04 05:46:09', '2026-07-04 05:46:09', '2026-07-04 05:46:09', '2026-07-04 05:55:09', '2026-07-04 06:11:09'),
(8, 4, 1, 1, 2, 1, NULL, 1, 5.0, 6.64, 0.0, 1.0, 0.0, 6.64, 4.98, 1.66, 242.36, 'completado', 4, '2026-06-08 11:08:06', '2026-06-08 11:08:06', '2026-06-08 11:08:06', '2026-06-08 11:19:06', '2026-06-08 11:31:06'),
(11, 18, 1, 1, 2, 1, NULL, 1, 5.0, 8.21, 0.0, 1.0, 0.0, 8.21, 6.16, 2.05, 299.67, 'completado', 5, '2026-07-24 06:54:23', '2026-07-24 06:54:23', '2026-07-24 06:54:23', '2026-07-24 07:01:23', '2026-07-24 07:35:23'),
(53, 1, 1, 1, 2, 1, NULL, 1, 5.0, 4.34, 0.0, 1.0, 0.0, 4.34, 3.25, 1.09, 158.41, 'cancelado', NULL, '2026-06-25 23:17:30', '2026-06-25 23:17:30', '2026-06-25 23:17:30', NULL, NULL),
(50, 16, 1, 1, 2, 1, NULL, 1, 5.0, 14.22, 0.0, 1.0, 0.0, 14.22, 10.67, 3.55, 519.03, 'completado', 5, '2026-06-25 00:52:44', '2026-06-25 00:52:44', '2026-06-25 00:52:44', '2026-06-25 01:01:44', '2026-06-25 01:38:44'),
(27, 8, 1, 1, 2, 1, NULL, 1, 5.0, 11.75, 0.0, 1.0, 0.0, 11.75, 8.81, 2.94, 428.88, 'completado', 3, '2026-07-12 16:21:00', '2026-07-12 16:21:00', '2026-07-12 16:21:00', '2026-07-12 16:32:00', '2026-07-12 16:45:00'),
(37, 6, 1, 1, 2, 1, NULL, 1, 5.0, 12.39, 0.0, 1.0, 0.0, 12.39, 9.29, 3.1, 452.24, 'completado', 3, '2026-07-19 01:36:28', '2026-07-19 01:36:28', '2026-07-19 01:36:28', '2026-07-19 01:51:28', '2026-07-19 02:28:28'),
(25, 8, 1, 1, 2, 1, NULL, 1, 5.0, 9.98, 0.0, 1.0, 0.0, 9.98, 7.49, 2.49, 364.27, 'completado', 3, '2026-06-05 04:16:33', '2026-06-05 04:16:33', '2026-06-05 04:16:33', '2026-06-05 04:24:33', '2026-06-05 04:40:33'),
(39, 9, 1, 1, 2, 1, NULL, 1, 5.0, 14.59, 0.0, 1.0, 0.0, 14.59, 10.94, 3.65, 532.53, 'completado', 4, '2026-06-16 15:36:12', '2026-06-16 15:36:12', '2026-06-16 15:36:12', '2026-06-16 15:44:12', '2026-06-16 16:23:12'),
(50, 21, 1, 1, 2, 1, NULL, 1, 5.0, 11.93, 0.0, 1.0, 0.0, 11.93, 8.95, 2.98, 435.44, 'completado', 5, '2026-06-21 13:36:40', '2026-06-21 13:36:40', '2026-06-21 13:36:40', '2026-06-21 13:51:40', '2026-06-21 14:35:40'),
(6, 10, 1, 1, 2, 1, NULL, 1, 5.0, 2.94, 0.0, 1.0, 0.0, 2.94, 2.21, 0.73, 107.31, 'completado', 5, '2026-06-20 12:30:54', '2026-06-20 12:30:54', '2026-06-20 12:30:54', '2026-06-20 12:42:54', '2026-06-20 13:24:54'),
(20, 22, 1, 1, 2, 1, NULL, 1, 5.0, 5.72, 0.0, 1.0, 0.0, 5.72, 4.29, 1.43, 208.78, 'completado', 3, '2026-06-14 05:10:10', '2026-06-14 05:10:10', '2026-06-14 05:10:10', '2026-06-14 05:18:10', '2026-06-14 05:49:10'),
(3, 21, 1, 1, 2, 1, NULL, 1, 5.0, 10.92, 0.0, 1.0, 0.0, 10.92, 8.19, 2.73, 398.58, 'completado', 3, '2026-06-01 03:05:54', '2026-06-01 03:05:54', '2026-06-01 03:05:54', '2026-06-01 03:13:54', '2026-06-01 03:26:54'),
(31, 1, 1, 1, 2, 1, NULL, 1, 5.0, 2.73, 0.0, 1.0, 0.0, 2.73, 2.05, 0.68, 99.64, 'cancelado', NULL, '2026-07-09 13:39:27', '2026-07-09 13:39:27', '2026-07-09 13:39:27', NULL, NULL),
(1, 24, 1, 1, 2, 1, NULL, 1, 5.0, 14.56, 0.0, 1.0, 0.0, 14.56, 10.92, 3.64, 531.44, 'completado', 5, '2026-06-16 09:49:49', '2026-06-16 09:49:49', '2026-06-16 09:49:49', '2026-06-16 10:01:49', '2026-06-16 10:39:49'),
(51, 20, 1, 1, 2, 1, NULL, 1, 5.0, 6.21, 0.0, 1.0, 0.0, 6.21, 4.66, 1.55, 226.66, 'completado', 4, '2026-06-20 05:22:05', '2026-06-20 05:22:05', '2026-06-20 05:22:05', '2026-06-20 05:28:05', '2026-06-20 06:13:05'),
(12, 6, 1, 1, 2, 1, NULL, 1, 5.0, 13.13, 0.0, 1.0, 0.0, 13.13, 9.85, 3.28, 479.25, 'completado', 4, '2026-05-26 22:29:20', '2026-05-26 22:29:20', '2026-05-26 22:29:20', '2026-05-26 22:37:20', '2026-05-26 22:53:20'),
(26, 23, 1, 1, 2, 1, NULL, 1, 5.0, 9.31, 0.0, 1.0, 0.0, 9.31, 6.98, 2.33, 339.81, 'completado', 4, '2026-07-02 13:09:47', '2026-07-02 13:09:47', '2026-07-02 13:09:47', '2026-07-02 13:24:47', '2026-07-02 13:56:47'),
(17, 8, 1, 1, 2, 1, NULL, 1, 5.0, 12.18, 0.0, 1.0, 0.0, 12.18, 9.13, 3.05, 444.57, 'completado', 5, '2026-06-12 14:57:08', '2026-06-12 14:57:08', '2026-06-12 14:57:08', '2026-06-12 15:09:08', '2026-06-12 15:31:08'),
(41, 1, 1, 1, 2, 1, NULL, 1, 5.0, 2.79, 0.0, 1.0, 0.0, 2.79, 2.09, 0.7, 101.84, 'completado', 4, '2026-07-11 08:14:57', '2026-07-11 08:14:57', '2026-07-11 08:14:57', '2026-07-11 08:22:57', '2026-07-11 08:49:57'),
(27, 20, 1, 1, 2, 1, NULL, 1, 5.0, 2.73, 0.0, 1.0, 0.0, 2.73, 2.05, 0.68, 99.64, 'completado', 3, '2026-06-27 07:54:02', '2026-06-27 07:54:02', '2026-06-27 07:54:02', '2026-06-27 07:59:02', '2026-06-27 08:20:02'),
(60, 6, 1, 1, 2, 1, NULL, 1, 5.0, 14.27, 0.0, 1.0, 0.0, 14.27, 10.7, 3.57, 520.86, 'completado', 5, '2026-06-25 09:09:19', '2026-06-25 09:09:19', '2026-06-25 09:09:19', '2026-06-25 09:17:19', '2026-06-25 09:57:19'),
(54, 8, 1, 1, 2, 1, NULL, 1, 5.0, 14.36, 0.0, 1.0, 0.0, 14.36, 10.77, 3.59, 524.14, 'completado', 3, '2026-06-17 17:10:03', '2026-06-17 17:10:03', '2026-06-17 17:10:03', '2026-06-17 17:20:03', '2026-06-17 18:01:03'),
(54, 14, 1, 1, 2, 1, NULL, 1, 5.0, 11.69, 0.0, 1.0, 0.0, 11.69, 8.77, 2.92, 426.69, 'completado', 3, '2026-06-21 05:11:58', '2026-06-21 05:11:58', '2026-06-21 05:11:58', '2026-06-21 05:21:58', '2026-06-21 06:04:58'),
(8, 16, 1, 1, 2, 1, NULL, 1, 5.0, 3.33, 0.0, 1.0, 0.0, 3.33, 2.5, 0.83, 121.55, 'completado', 4, '2026-06-10 23:44:49', '2026-06-10 23:44:49', '2026-06-10 23:44:49', '2026-06-10 23:52:49', '2026-06-11 00:19:49'),
(60, 25, 1, 1, 2, 1, NULL, 1, 5.0, 8.37, 0.0, 1.0, 0.0, 8.37, 6.28, 2.09, 305.5, 'completado', 4, '2026-06-27 04:15:31', '2026-06-27 04:15:31', '2026-06-27 04:15:31', '2026-06-27 04:27:31', '2026-06-27 04:55:31'),
(45, 16, 1, 1, 2, 1, NULL, 1, 5.0, 13.11, 0.0, 1.0, 0.0, 13.11, 9.83, 3.28, 478.51, 'completado', 5, '2026-07-20 05:11:30', '2026-07-20 05:11:30', '2026-07-20 05:11:30', '2026-07-20 05:26:30', '2026-07-20 05:58:30'),
(31, 13, 1, 1, 2, 1, NULL, 1, 5.0, 8.87, 0.0, 1.0, 0.0, 8.87, 6.65, 2.22, 323.75, 'completado', 5, '2026-07-01 07:43:14', '2026-07-01 07:43:14', '2026-07-01 07:43:14', '2026-07-01 07:57:14', '2026-07-01 08:22:14'),
(1, 6, 1, 1, 2, 1, NULL, 1, 5.0, 10.06, 0.0, 1.0, 0.0, 10.06, 7.54, 2.52, 367.19, 'completado', 4, '2026-07-02 15:40:56', '2026-07-02 15:40:56', '2026-07-02 15:40:56', '2026-07-02 15:51:56', '2026-07-02 16:36:56'),
(36, 24, 1, 1, 2, 1, NULL, 1, 5.0, 5.77, 0.0, 1.0, 0.0, 5.77, 4.33, 1.44, 210.6, 'completado', 4, '2026-07-19 12:39:35', '2026-07-19 12:39:35', '2026-07-19 12:39:35', '2026-07-19 12:53:35', '2026-07-19 13:08:35'),
(25, 24, 1, 1, 2, 1, NULL, 1, 5.0, 4.16, 0.0, 1.0, 0.0, 4.16, 3.12, 1.04, 151.84, 'completado', 3, '2026-05-31 19:12:45', '2026-05-31 19:12:45', '2026-05-31 19:12:45', '2026-05-31 19:27:45', '2026-05-31 20:11:45'),
(30, 1, 1, 1, 2, 1, NULL, 1, 5.0, 7.81, 0.0, 1.0, 0.0, 7.81, 5.86, 1.95, 285.06, 'cancelado', NULL, '2026-06-15 01:13:48', '2026-06-15 01:13:48', '2026-06-15 01:13:48', NULL, NULL),
(41, 3, 1, 1, 2, 1, NULL, 1, 5.0, 5.03, 0.0, 1.0, 0.0, 5.03, 3.77, 1.26, 183.59, 'completado', 3, '2026-06-12 04:07:55', '2026-06-12 04:07:55', '2026-06-12 04:07:55', '2026-06-12 04:14:55', '2026-06-12 04:41:55'),
(39, 23, 1, 1, 2, 1, NULL, 1, 5.0, 11.83, 0.0, 1.0, 0.0, 11.83, 8.87, 2.96, 431.8, 'completado', 4, '2026-07-16 14:33:55', '2026-07-16 14:33:55', '2026-07-16 14:33:55', '2026-07-16 14:46:55', '2026-07-16 15:31:55'),
(3, 7, 1, 1, 2, 1, NULL, 1, 5.0, 9.61, 0.0, 1.0, 0.0, 9.61, 7.21, 2.4, 350.76, 'completado', 4, '2026-06-09 16:11:29', '2026-06-09 16:11:29', '2026-06-09 16:11:29', '2026-06-09 16:25:29', '2026-06-09 16:57:29'),
(26, 9, 1, 1, 2, 1, NULL, 1, 5.0, 9.54, 0.0, 1.0, 0.0, 9.54, 7.15, 2.39, 348.21, 'completado', 5, '2026-06-19 23:04:46', '2026-06-19 23:04:46', '2026-06-19 23:04:46', '2026-06-19 23:17:46', '2026-06-20 00:02:46'),
(6, 16, 1, 1, 2, 1, NULL, 1, 5.0, 12.98, 0.0, 1.0, 0.0, 12.98, 9.73, 3.25, 473.77, 'completado', 4, '2026-06-07 07:05:12', '2026-06-07 07:05:12', '2026-06-07 07:05:12', '2026-06-07 07:18:12', '2026-06-07 07:41:12'),
(16, 3, 1, 1, 2, 1, NULL, 1, 5.0, 11.2, 0.0, 1.0, 0.0, 11.2, 8.4, 2.8, 408.8, 'completado', 4, '2026-06-06 19:47:07', '2026-06-06 19:47:07', '2026-06-06 19:47:07', '2026-06-06 20:02:07', '2026-06-06 20:26:07'),
(30, 16, 1, 1, 2, 1, NULL, 1, 5.0, 14.01, 0.0, 1.0, 0.0, 14.01, 10.51, 3.5, 511.37, 'completado', 5, '2026-06-02 01:51:43', '2026-06-02 01:51:43', '2026-06-02 01:51:43', '2026-06-02 02:02:43', '2026-06-02 02:38:43'),
(21, 17, 1, 1, 2, 1, NULL, 1, 5.0, 10.99, 0.0, 1.0, 0.0, 10.99, 8.24, 2.75, 401.13, 'cancelado', NULL, '2026-06-02 06:35:23', '2026-06-02 06:35:23', '2026-06-02 06:35:23', NULL, NULL),
(16, 25, 1, 1, 2, 1, NULL, 1, 5.0, 14.8, 0.0, 1.0, 0.0, 14.8, 11.1, 3.7, 540.2, 'completado', 4, '2026-07-06 19:07:54', '2026-07-06 19:07:54', '2026-07-06 19:07:54', '2026-07-06 19:16:54', '2026-07-06 19:45:54'),
(38, 23, 1, 1, 2, 1, NULL, 1, 5.0, 4.77, 0.0, 1.0, 0.0, 4.77, 3.58, 1.19, 174.1, 'completado', 3, '2026-06-03 06:24:57', '2026-06-03 06:24:57', '2026-06-03 06:24:57', '2026-06-03 06:34:57', '2026-06-03 07:15:57'),
(59, 11, 1, 1, 2, 1, NULL, 1, 5.0, 7.63, 0.0, 1.0, 0.0, 7.63, 5.72, 1.91, 278.5, 'completado', 3, '2026-06-26 13:42:12', '2026-06-26 13:42:12', '2026-06-26 13:42:12', '2026-06-26 13:50:12', '2026-06-26 14:16:12'),
(14, 24, 1, 1, 2, 1, NULL, 1, 5.0, 6.01, 0.0, 1.0, 0.0, 6.01, 4.51, 1.5, 219.36, 'completado', 3, '2026-07-16 13:26:03', '2026-07-16 13:26:03', '2026-07-16 13:26:03', '2026-07-16 13:33:03', '2026-07-16 13:52:03'),
(57, 1, 1, 1, 2, 1, NULL, 1, 5.0, 14.89, 0.0, 1.0, 0.0, 14.89, 11.17, 3.72, 543.49, 'cancelado', NULL, '2026-07-23 03:46:50', '2026-07-23 03:46:50', '2026-07-23 03:46:50', NULL, NULL),
(15, 4, 1, 1, 2, 1, NULL, 1, 5.0, 10.43, 0.0, 1.0, 0.0, 10.43, 7.82, 2.61, 380.69, 'completado', 3, '2026-07-02 23:25:43', '2026-07-02 23:25:43', '2026-07-02 23:25:43', '2026-07-02 23:30:43', '2026-07-03 00:12:43'),
(23, 15, 1, 1, 2, 1, NULL, 1, 5.0, 6.72, 0.0, 1.0, 0.0, 6.72, 5.04, 1.68, 245.28, 'completado', 5, '2026-06-02 13:38:44', '2026-06-02 13:38:44', '2026-06-02 13:38:44', '2026-06-02 13:49:44', '2026-06-02 14:23:44'),
(52, 16, 1, 1, 2, 1, NULL, 1, 5.0, 4.16, 0.0, 1.0, 0.0, 4.16, 3.12, 1.04, 151.84, 'completado', 5, '2026-07-14 20:35:20', '2026-07-14 20:35:20', '2026-07-14 20:35:20', '2026-07-14 20:41:20', '2026-07-14 21:20:20'),
(1, 8, 1, 1, 2, 1, NULL, 1, 5.0, 4.45, 0.0, 1.0, 0.0, 4.45, 3.34, 1.11, 162.43, 'completado', 4, '2026-07-19 04:04:43', '2026-07-19 04:04:43', '2026-07-19 04:04:43', '2026-07-19 04:15:43', '2026-07-19 04:29:43'),
(32, 19, 1, 1, 2, 1, NULL, 1, 5.0, 5.83, 0.0, 1.0, 0.0, 5.83, 4.37, 1.46, 212.8, 'completado', 5, '2026-06-08 04:02:52', '2026-06-08 04:02:52', '2026-06-08 04:02:52', '2026-06-08 04:17:52', '2026-06-08 04:46:52'),
(16, 20, 1, 1, 2, 1, NULL, 1, 5.0, 4.78, 0.0, 1.0, 0.0, 4.78, 3.58, 1.2, 174.47, 'completado', 3, '2026-07-10 04:59:44', '2026-07-10 04:59:44', '2026-07-10 04:59:44', '2026-07-10 05:10:44', '2026-07-10 05:30:44'),
(59, 16, 1, 1, 2, 1, NULL, 1, 5.0, 7.26, 0.0, 1.0, 0.0, 7.26, 5.45, 1.81, 264.99, 'completado', 5, '2026-05-28 15:58:56', '2026-05-28 15:58:56', '2026-05-28 15:58:56', '2026-05-28 16:06:56', '2026-05-28 16:16:56'),
(31, 8, 1, 1, 2, 1, NULL, 1, 5.0, 9.46, 0.0, 1.0, 0.0, 9.46, 7.1, 2.36, 345.29, 'completado', 5, '2026-06-11 21:21:23', '2026-06-11 21:21:23', '2026-06-11 21:21:23', '2026-06-11 21:34:23', '2026-06-11 22:04:23'),
(5, 25, 1, 1, 2, 1, NULL, 1, 5.0, 7.13, 0.0, 1.0, 0.0, 7.13, 5.35, 1.78, 260.25, 'completado', 3, '2026-06-08 15:23:47', '2026-06-08 15:23:47', '2026-06-08 15:23:47', '2026-06-08 15:36:47', '2026-06-08 15:51:47'),
(42, 16, 1, 1, 2, 1, NULL, 1, 5.0, 5.43, 0.0, 1.0, 0.0, 5.43, 4.07, 1.36, 198.19, 'completado', 5, '2026-06-24 05:29:35', '2026-06-24 05:29:35', '2026-06-24 05:29:35', '2026-06-24 05:35:35', '2026-06-24 05:52:35'),
(20, 12, 1, 1, 2, 1, NULL, 1, 5.0, 7.42, 0.0, 1.0, 0.0, 7.42, 5.56, 1.86, 270.83, 'completado', 5, '2026-07-13 01:41:48', '2026-07-13 01:41:48', '2026-07-13 01:41:48', '2026-07-13 01:55:48', '2026-07-13 02:11:48'),
(32, 21, 1, 1, 2, 1, NULL, 1, 5.0, 5.8, 0.0, 1.0, 0.0, 5.8, 4.35, 1.45, 211.7, 'completado', 5, '2026-06-22 01:20:37', '2026-06-22 01:20:37', '2026-06-22 01:20:37', '2026-06-22 01:35:37', '2026-06-22 02:07:37'),
(32, 11, 1, 1, 2, 1, NULL, 1, 5.0, 8.87, 0.0, 1.0, 0.0, 8.87, 6.65, 2.22, 323.75, 'completado', 5, '2026-07-15 02:36:36', '2026-07-15 02:36:36', '2026-07-15 02:36:36', '2026-07-15 02:45:36', '2026-07-15 03:22:36'),
(33, 6, 1, 1, 2, 1, NULL, 1, 5.0, 11.11, 0.0, 1.0, 0.0, 11.11, 8.33, 2.78, 405.51, 'completado', 5, '2026-07-08 15:18:18', '2026-07-08 15:18:18', '2026-07-08 15:18:18', '2026-07-08 15:27:18', '2026-07-08 16:03:18'),
(18, 25, 1, 1, 2, 1, NULL, 1, 5.0, 13.74, 0.0, 1.0, 0.0, 13.74, 10.3, 3.44, 501.51, 'completado', 5, '2026-07-06 05:56:18', '2026-07-06 05:56:18', '2026-07-06 05:56:18', '2026-07-06 06:06:18', '2026-07-06 06:50:18'),
(27, 1, 1, 1, 2, 1, NULL, 1, 5.0, 3.93, 0.0, 1.0, 0.0, 3.93, 2.95, 0.98, 143.44, 'cancelado', NULL, '2026-05-28 03:24:14', '2026-05-28 03:24:14', '2026-05-28 03:24:14', NULL, NULL),
(13, 14, 1, 1, 2, 1, NULL, 1, 5.0, 10.74, 0.0, 1.0, 0.0, 10.74, 8.05, 2.69, 392.01, 'completado', 4, '2026-07-22 11:43:43', '2026-07-22 11:43:43', '2026-07-22 11:43:43', '2026-07-22 11:52:43', '2026-07-22 12:31:43'),
(50, 7, 1, 1, 2, 1, NULL, 1, 5.0, 9.2, 0.0, 1.0, 0.0, 9.2, 6.9, 2.3, 335.8, 'completado', 4, '2026-06-07 16:38:26', '2026-06-07 16:38:26', '2026-06-07 16:38:26', '2026-06-07 16:53:26', '2026-06-07 17:14:26'),
(11, 10, 1, 1, 2, 1, NULL, 1, 5.0, 2.6, 0.0, 1.0, 0.0, 2.6, 1.95, 0.65, 94.9, 'completado', 4, '2026-07-19 01:14:47', '2026-07-19 01:14:47', '2026-07-19 01:14:47', '2026-07-19 01:21:47', '2026-07-19 01:45:47'),
(41, 1, 1, 1, 2, 1, NULL, 1, 5.0, 3.14, 0.0, 1.0, 0.0, 3.14, 2.35, 0.79, 114.61, 'cancelado', NULL, '2026-07-22 07:10:01', '2026-07-22 07:10:01', '2026-07-22 07:10:01', NULL, NULL),
(12, 11, 1, 1, 2, 1, NULL, 1, 5.0, 6.67, 0.0, 1.0, 0.0, 6.67, 5.0, 1.67, 243.45, 'completado', 4, '2026-07-21 11:19:10', '2026-07-21 11:19:10', '2026-07-21 11:19:10', '2026-07-21 11:25:10', '2026-07-21 12:02:10'),
(38, 13, 1, 1, 2, 1, NULL, 1, 5.0, 5.32, 0.0, 1.0, 0.0, 5.32, 3.99, 1.33, 194.18, 'completado', 4, '2026-07-05 12:16:28', '2026-07-05 12:16:28', '2026-07-05 12:16:28', '2026-07-05 12:26:28', '2026-07-05 12:44:28'),
(25, 1, 1, 1, 2, 1, NULL, 1, 5.0, 9.52, 0.0, 1.0, 0.0, 9.52, 7.14, 2.38, 347.48, 'completado', 5, '2026-05-30 17:28:02', '2026-05-30 17:28:02', '2026-05-30 17:28:02', '2026-05-30 17:39:02', '2026-05-30 18:03:02'),
(27, 25, 1, 1, 2, 1, NULL, 1, 5.0, 10.47, 0.0, 1.0, 0.0, 10.47, 7.85, 2.62, 382.16, 'completado', 5, '2026-06-17 22:12:07', '2026-06-17 22:12:07', '2026-06-17 22:12:07', '2026-06-17 22:25:07', '2026-06-17 22:50:07'),
(25, 21, 1, 1, 2, 1, NULL, 1, 5.0, 6.02, 0.0, 1.0, 0.0, 6.02, 4.51, 1.51, 219.73, 'completado', 4, '2026-07-08 05:25:36', '2026-07-08 05:25:36', '2026-07-08 05:25:36', '2026-07-08 05:37:36', '2026-07-08 06:22:36'),
(33, 12, 1, 1, 2, 1, NULL, 1, 5.0, 5.72, 0.0, 1.0, 0.0, 5.72, 4.29, 1.43, 208.78, 'completado', 3, '2026-06-11 01:13:55', '2026-06-11 01:13:55', '2026-06-11 01:13:55', '2026-06-11 01:27:55', '2026-06-11 01:54:55'),
(35, 6, 1, 1, 2, 1, NULL, 1, 5.0, 3.98, 0.0, 1.0, 0.0, 3.98, 2.98, 1.0, 145.27, 'completado', 4, '2026-07-06 20:10:36', '2026-07-06 20:10:36', '2026-07-06 20:10:36', '2026-07-06 20:21:36', '2026-07-06 20:41:36'),
(19, 14, 1, 1, 2, 1, NULL, 1, 5.0, 5.3, 0.0, 1.0, 0.0, 5.3, 3.97, 1.33, 193.45, 'completado', 4, '2026-06-19 05:48:56', '2026-06-19 05:48:56', '2026-06-19 05:48:56', '2026-06-19 06:03:56', '2026-06-19 06:25:56'),
(26, 1, 1, 1, 2, 1, NULL, 1, 5.0, 11.13, 0.0, 1.0, 0.0, 11.13, 8.35, 2.78, 406.25, 'cancelado', NULL, '2026-06-22 08:47:54', '2026-06-22 08:47:54', '2026-06-22 08:47:54', NULL, NULL),
(4, 24, 1, 1, 2, 1, NULL, 1, 5.0, 7.69, 0.0, 1.0, 0.0, 7.69, 5.77, 1.92, 280.69, 'completado', 4, '2026-07-20 04:43:09', '2026-07-20 04:43:09', '2026-07-20 04:43:09', '2026-07-20 04:57:09', '2026-07-20 05:37:09'),
(6, 19, 1, 1, 2, 1, NULL, 1, 5.0, 4.59, 0.0, 1.0, 0.0, 4.59, 3.44, 1.15, 167.53, 'completado', 4, '2026-06-17 15:44:46', '2026-06-17 15:44:46', '2026-06-17 15:44:46', '2026-06-17 15:53:46', '2026-06-17 16:32:46'),
(48, 24, 1, 1, 2, 1, NULL, 1, 5.0, 9.39, 0.0, 1.0, 0.0, 9.39, 7.04, 2.35, 342.74, 'completado', 3, '2026-06-17 08:31:41', '2026-06-17 08:31:41', '2026-06-17 08:31:41', '2026-06-17 08:39:41', '2026-06-17 09:06:41'),
(50, 13, 1, 1, 2, 1, NULL, 1, 5.0, 5.35, 0.0, 1.0, 0.0, 5.35, 4.01, 1.34, 195.27, 'completado', 4, '2026-06-21 00:09:31', '2026-06-21 00:09:31', '2026-06-21 00:09:31', '2026-06-21 00:19:31', '2026-06-21 00:42:31'),
(42, 6, 1, 1, 2, 1, NULL, 1, 5.0, 4.8, 0.0, 1.0, 0.0, 4.8, 3.6, 1.2, 175.2, 'completado', 4, '2026-07-03 22:47:56', '2026-07-03 22:47:56', '2026-07-03 22:47:56', '2026-07-03 23:00:56', '2026-07-03 23:45:56'),
(57, 3, 1, 1, 2, 1, NULL, 1, 5.0, 10.22, 0.0, 1.0, 0.0, 10.22, 7.67, 2.55, 373.03, 'completado', 4, '2026-07-16 06:55:45', '2026-07-16 06:55:45', '2026-07-16 06:55:45', '2026-07-16 07:06:45', '2026-07-16 07:46:45'),
(13, 15, 1, 1, 2, 1, NULL, 1, 5.0, 14.28, 0.0, 1.0, 0.0, 14.28, 10.71, 3.57, 521.22, 'completado', 3, '2026-06-13 20:38:46', '2026-06-13 20:38:46', '2026-06-13 20:38:46', '2026-06-13 20:51:46', '2026-06-13 21:07:46'),
(46, 19, 1, 1, 2, 1, NULL, 1, 5.0, 3.15, 0.0, 1.0, 0.0, 3.15, 2.36, 0.79, 114.97, 'completado', 5, '2026-07-16 22:52:20', '2026-07-16 22:52:20', '2026-07-16 22:52:20', '2026-07-16 23:02:20', '2026-07-16 23:44:20'),
(2, 14, 1, 1, 2, 1, NULL, 1, 5.0, 4.89, 0.0, 1.0, 0.0, 4.89, 3.67, 1.22, 178.48, 'completado', 5, '2026-07-19 11:35:43', '2026-07-19 11:35:43', '2026-07-19 11:35:43', '2026-07-19 11:44:43', '2026-07-19 12:21:43'),
(36, 1, 1, 1, 2, 1, NULL, 1, 5.0, 9.61, 0.0, 1.0, 0.0, 9.61, 7.21, 2.4, 350.76, 'completado', 5, '2026-06-05 18:19:11', '2026-06-05 18:19:11', '2026-06-05 18:19:11', '2026-06-05 18:34:11', '2026-06-05 19:04:11'),
(45, 12, 1, 1, 2, 1, NULL, 1, 5.0, 12.87, 0.0, 1.0, 0.0, 12.87, 9.65, 3.22, 469.75, 'completado', 3, '2026-06-14 14:35:03', '2026-06-14 14:35:03', '2026-06-14 14:35:03', '2026-06-14 14:49:03', '2026-06-14 15:15:03'),
(51, 1, 1, 1, 2, 1, NULL, 1, 5.0, 8.53, 0.0, 1.0, 0.0, 8.53, 6.4, 2.13, 311.34, 'cancelado', NULL, '2026-06-25 11:46:07', '2026-06-25 11:46:07', '2026-06-25 11:46:07', NULL, NULL),
(11, 5, 1, 1, 2, 1, NULL, 1, 5.0, 13.83, 0.0, 1.0, 0.0, 13.83, 10.37, 3.46, 504.8, 'completado', 5, '2026-07-24 03:21:58', '2026-07-24 03:21:58', '2026-07-24 03:21:58', '2026-07-24 03:33:58', '2026-07-24 04:06:58'),
(56, 10, 1, 1, 2, 1, NULL, 1, 5.0, 5.56, 0.0, 1.0, 0.0, 5.56, 4.17, 1.39, 202.94, 'cancelado', NULL, '2026-06-28 22:10:01', '2026-06-28 22:10:01', '2026-06-28 22:10:01', NULL, NULL),
(20, 5, 1, 1, 2, 1, NULL, 1, 5.0, 6.16, 0.0, 1.0, 0.0, 6.16, 4.62, 1.54, 224.84, 'completado', 5, '2026-06-11 11:44:26', '2026-06-11 11:44:26', '2026-06-11 11:44:26', '2026-06-11 11:58:26', '2026-06-11 12:22:26'),
(10, 23, 1, 1, 2, 1, NULL, 1, 5.0, 7.29, 0.0, 1.0, 0.0, 7.29, 5.47, 1.82, 266.08, 'completado', 3, '2026-07-23 14:03:48', '2026-07-23 14:03:48', '2026-07-23 14:03:48', '2026-07-23 14:16:48', '2026-07-23 14:45:48'),
(10, 19, 1, 1, 2, 1, NULL, 1, 5.0, 11.68, 0.0, 1.0, 0.0, 11.68, 8.76, 2.92, 426.32, 'cancelado', NULL, '2026-06-23 02:54:36', '2026-06-23 02:54:36', '2026-06-23 02:54:36', NULL, NULL),
(39, 19, 1, 1, 2, 1, NULL, 1, 5.0, 6.14, 0.0, 1.0, 0.0, 6.14, 4.6, 1.54, 224.11, 'cancelado', NULL, '2026-05-27 18:23:09', '2026-05-27 18:23:09', '2026-05-27 18:23:09', NULL, NULL),
(49, 17, 1, 1, 2, 1, NULL, 1, 5.0, 9.23, 0.0, 1.0, 0.0, 9.23, 6.92, 2.31, 336.9, 'completado', 5, '2026-07-13 06:20:56', '2026-07-13 06:20:56', '2026-07-13 06:20:56', '2026-07-13 06:32:56', '2026-07-13 07:15:56'),
(32, 1, 1, 1, 2, 1, NULL, 1, 5.0, 2.67, 0.0, 1.0, 0.0, 2.67, 2.0, 0.67, 97.45, 'completado', 3, '2026-07-09 08:51:57', '2026-07-09 08:51:57', '2026-07-09 08:51:57', '2026-07-09 09:01:57', '2026-07-09 09:30:57'),
(10, 1, 1, 1, 2, 1, NULL, 1, 5.0, 11.23, 0.0, 1.0, 0.0, 11.23, 8.42, 2.81, 409.9, 'cancelado', NULL, '2026-06-16 10:12:10', '2026-06-16 10:12:10', '2026-06-16 10:12:10', NULL, NULL),
(40, 16, 1, 1, 2, 1, NULL, 1, 5.0, 6.06, 0.0, 1.0, 0.0, 6.06, 4.54, 1.52, 221.19, 'completado', 4, '2026-07-15 12:27:30', '2026-07-15 12:27:30', '2026-07-15 12:27:30', '2026-07-15 12:38:30', '2026-07-15 13:05:30'),
(59, 4, 1, 1, 2, 1, NULL, 1, 5.0, 10.92, 0.0, 1.0, 0.0, 10.92, 8.19, 2.73, 398.58, 'completado', 3, '2026-06-28 14:31:51', '2026-06-28 14:31:51', '2026-06-28 14:31:51', '2026-06-28 14:46:51', '2026-06-28 15:03:51'),
(53, 5, 1, 1, 2, 1, NULL, 1, 5.0, 7.87, 0.0, 1.0, 0.0, 7.87, 5.9, 1.97, 287.25, 'completado', 4, '2026-06-27 13:09:55', '2026-06-27 13:09:55', '2026-06-27 13:09:55', '2026-06-27 13:20:55', '2026-06-27 14:00:55'),
(45, 23, 1, 1, 2, 1, NULL, 1, 5.0, 3.57, 0.0, 1.0, 0.0, 3.57, 2.68, 0.89, 130.31, 'completado', 3, '2026-07-09 11:42:59', '2026-07-09 11:42:59', '2026-07-09 11:42:59', '2026-07-09 11:55:59', '2026-07-09 12:13:59'),
(4, 21, 1, 1, 2, 1, NULL, 1, 5.0, 3.3, 0.0, 1.0, 0.0, 3.3, 2.47, 0.83, 120.45, 'completado', 5, '2026-07-05 03:54:52', '2026-07-05 03:54:52', '2026-07-05 03:54:52', '2026-07-05 04:04:52', '2026-07-05 04:42:52'),
(46, 1, 1, 1, 2, 1, NULL, 1, 5.0, 2.97, 0.0, 1.0, 0.0, 2.97, 2.23, 0.74, 108.41, 'completado', 5, '2026-06-29 15:31:47', '2026-06-29 15:31:47', '2026-06-29 15:31:47', '2026-06-29 15:43:47', '2026-06-29 16:15:47'),
(8, 2, 1, 1, 2, 1, NULL, 1, 5.0, 8.11, 0.0, 1.0, 0.0, 8.11, 6.08, 2.03, 296.01, 'completado', 3, '2026-07-17 10:33:55', '2026-07-17 10:33:55', '2026-07-17 10:33:55', '2026-07-17 10:39:55', '2026-07-17 11:21:55'),
(2, 14, 1, 1, 2, 1, NULL, 1, 5.0, 8.52, 0.0, 1.0, 0.0, 8.52, 6.39, 2.13, 310.98, 'completado', 5, '2026-07-03 10:19:08', '2026-07-03 10:19:08', '2026-07-03 10:19:08', '2026-07-03 10:31:08', '2026-07-03 11:15:08'),
(3, 11, 1, 1, 2, 1, NULL, 1, 5.0, 5.06, 0.0, 1.0, 0.0, 5.06, 3.79, 1.27, 184.69, 'completado', 5, '2026-07-10 17:13:23', '2026-07-10 17:13:23', '2026-07-10 17:13:23', '2026-07-10 17:20:23', '2026-07-10 18:01:23'),
(42, 23, 1, 1, 2, 1, NULL, 1, 5.0, 14.9, 0.0, 1.0, 0.0, 14.9, 11.18, 3.72, 543.85, 'completado', 5, '2026-05-28 00:45:20', '2026-05-28 00:45:20', '2026-05-28 00:45:20', '2026-05-28 00:52:20', '2026-05-28 01:24:20'),
(45, 25, 1, 1, 2, 1, NULL, 1, 5.0, 8.77, 0.0, 1.0, 0.0, 8.77, 6.58, 2.19, 320.1, 'completado', 3, '2026-07-16 14:31:38', '2026-07-16 14:31:38', '2026-07-16 14:31:38', '2026-07-16 14:45:38', '2026-07-16 15:14:38'),
(19, 2, 1, 1, 2, 1, NULL, 1, 5.0, 12.31, 0.0, 1.0, 0.0, 12.31, 9.23, 3.08, 449.31, 'cancelado', NULL, '2026-06-13 06:20:00', '2026-06-13 06:20:00', '2026-06-13 06:20:00', NULL, NULL),
(14, 1, 1, 1, 2, 1, NULL, 1, 5.0, 11.33, 0.0, 1.0, 0.0, 11.33, 8.5, 2.83, 413.55, 'cancelado', NULL, '2026-06-24 01:47:09', '2026-06-24 01:47:09', '2026-06-24 01:47:09', NULL, NULL),
(21, 17, 1, 1, 2, 1, NULL, 1, 5.0, 13.7, 0.0, 1.0, 0.0, 13.7, 10.27, 3.43, 500.05, 'completado', 3, '2026-06-12 11:13:57', '2026-06-12 11:13:57', '2026-06-12 11:13:57', '2026-06-12 11:21:57', '2026-06-12 11:39:57'),
(49, 19, 1, 1, 2, 1, NULL, 1, 5.0, 9.77, 0.0, 1.0, 0.0, 9.77, 7.33, 2.44, 356.6, 'cancelado', NULL, '2026-07-21 07:25:08', '2026-07-21 07:25:08', '2026-07-21 07:25:08', NULL, NULL),
(15, 19, 1, 1, 2, 1, NULL, 1, 5.0, 6.57, 0.0, 1.0, 0.0, 6.57, 4.93, 1.64, 239.81, 'completado', 5, '2026-06-27 07:42:31', '2026-06-27 07:42:31', '2026-06-27 07:42:31', '2026-06-27 07:53:31', '2026-06-27 08:13:31'),
(11, 12, 1, 1, 2, 1, NULL, 1, 5.0, 3.25, 0.0, 1.0, 0.0, 3.25, 2.44, 0.81, 118.62, 'completado', 3, '2026-06-25 13:14:16', '2026-06-25 13:14:16', '2026-06-25 13:14:16', '2026-06-25 13:19:16', '2026-06-25 13:37:16'),
(33, 2, 1, 1, 2, 1, NULL, 1, 5.0, 3.47, 0.0, 1.0, 0.0, 3.47, 2.6, 0.87, 126.66, 'completado', 5, '2026-06-19 18:41:36', '2026-06-19 18:41:36', '2026-06-19 18:41:36', '2026-06-19 18:56:36', '2026-06-19 19:38:36'),
(12, 12, 1, 1, 2, 1, NULL, 1, 5.0, 8.54, 0.0, 1.0, 0.0, 8.54, 6.4, 2.14, 311.71, 'completado', 5, '2026-07-19 19:34:55', '2026-07-19 19:34:55', '2026-07-19 19:34:55', '2026-07-19 19:44:55', '2026-07-19 20:29:55'),
(35, 12, 1, 1, 2, 1, NULL, 1, 5.0, 5.06, 0.0, 1.0, 0.0, 5.06, 3.79, 1.27, 184.69, 'completado', 5, '2026-06-17 18:50:13', '2026-06-17 18:50:13', '2026-06-17 18:50:13', '2026-06-17 18:57:13', '2026-06-17 19:30:13'),
(4, 6, 1, 1, 2, 1, NULL, 1, 5.0, 3.24, 0.0, 1.0, 0.0, 3.24, 2.43, 0.81, 118.26, 'completado', 3, '2026-05-27 21:11:50', '2026-05-27 21:11:50', '2026-05-27 21:11:50', '2026-05-27 21:17:50', '2026-05-27 21:40:50'),
(17, 14, 1, 1, 2, 1, NULL, 1, 5.0, 12.14, 0.0, 1.0, 0.0, 12.14, 9.11, 3.03, 443.11, 'cancelado', NULL, '2026-06-30 15:41:13', '2026-06-30 15:41:13', '2026-06-30 15:41:13', NULL, NULL),
(43, 18, 1, 1, 2, 1, NULL, 1, 5.0, 9.27, 0.0, 1.0, 0.0, 9.27, 6.95, 2.32, 338.35, 'completado', 4, '2026-06-27 20:16:50', '2026-06-27 20:16:50', '2026-06-27 20:16:50', '2026-06-27 20:29:50', '2026-06-27 21:11:50'),
(9, 11, 1, 1, 2, 1, NULL, 1, 5.0, 8.61, 0.0, 1.0, 0.0, 8.61, 6.46, 2.15, 314.26, 'cancelado', NULL, '2026-06-16 00:12:11', '2026-06-16 00:12:11', '2026-06-16 00:12:11', NULL, NULL),
(29, 15, 1, 1, 2, 1, NULL, 1, 5.0, 10.17, 0.0, 1.0, 0.0, 10.17, 7.63, 2.54, 371.2, 'completado', 3, '2026-06-30 05:13:40', '2026-06-30 05:13:40', '2026-06-30 05:13:40', '2026-06-30 05:24:40', '2026-06-30 06:05:40'),
(53, 15, 1, 1, 2, 1, NULL, 1, 5.0, 7.99, 0.0, 1.0, 0.0, 7.99, 5.99, 2.0, 291.63, 'completado', 5, '2026-07-09 14:48:01', '2026-07-09 14:48:01', '2026-07-09 14:48:01', '2026-07-09 14:56:01', '2026-07-09 15:37:01'),
(54, 6, 1, 1, 2, 1, NULL, 1, 5.0, 3.22, 0.0, 1.0, 0.0, 3.22, 2.42, 0.8, 117.53, 'completado', 5, '2026-07-19 22:47:24', '2026-07-19 22:47:24', '2026-07-19 22:47:24', '2026-07-19 23:02:24', '2026-07-19 23:24:24'),
(11, 1, 1, 1, 2, 1, NULL, 1, 5.0, 5.35, 0.0, 1.0, 0.0, 5.35, 4.01, 1.34, 195.27, 'cancelado', NULL, '2026-07-14 15:13:58', '2026-07-14 15:13:58', '2026-07-14 15:13:58', NULL, NULL),
(53, 20, 1, 1, 2, 1, NULL, 1, 5.0, 12.18, 0.0, 1.0, 0.0, 12.18, 9.13, 3.05, 444.57, 'completado', 5, '2026-07-15 23:15:45', '2026-07-15 23:15:45', '2026-07-15 23:15:45', '2026-07-15 23:22:45', '2026-07-15 23:42:45'),
(10, 5, 1, 1, 2, 1, NULL, 1, 5.0, 3.93, 0.0, 1.0, 0.0, 3.93, 2.95, 0.98, 143.44, 'completado', 4, '2026-06-08 13:35:54', '2026-06-08 13:35:54', '2026-06-08 13:35:54', '2026-06-08 13:49:54', '2026-06-08 14:19:54'),
(24, 4, 1, 1, 2, 1, NULL, 1, 5.0, 10.95, 0.0, 1.0, 0.0, 10.95, 8.21, 2.74, 399.67, 'cancelado', NULL, '2026-06-18 05:03:35', '2026-06-18 05:03:35', '2026-06-18 05:03:35', NULL, NULL),
(38, 16, 1, 1, 2, 1, NULL, 1, 5.0, 12.88, 0.0, 1.0, 0.0, 12.88, 9.66, 3.22, 470.12, 'completado', 4, '2026-06-20 05:32:43', '2026-06-20 05:32:43', '2026-06-20 05:32:43', '2026-06-20 05:43:43', '2026-06-20 06:01:43'),
(14, 25, 1, 1, 2, 1, NULL, 1, 5.0, 14.53, 0.0, 1.0, 0.0, 14.53, 10.9, 3.63, 530.35, 'completado', 4, '2026-06-17 16:09:49', '2026-06-17 16:09:49', '2026-06-17 16:09:49', '2026-06-17 16:23:49', '2026-06-17 17:02:49'),
(27, 16, 1, 1, 2, 1, NULL, 1, 5.0, 3.55, 0.0, 1.0, 0.0, 3.55, 2.66, 0.89, 129.57, 'cancelado', NULL, '2026-06-24 17:29:51', '2026-06-24 17:29:51', '2026-06-24 17:29:51', NULL, NULL),
(15, 1, 1, 1, 2, 1, NULL, 1, 5.0, 6.37, 0.0, 1.0, 0.0, 6.37, 4.78, 1.59, 232.5, 'cancelado', NULL, '2026-06-10 15:05:20', '2026-06-10 15:05:20', '2026-06-10 15:05:20', NULL, NULL),
(39, 20, 1, 1, 2, 1, NULL, 1, 5.0, 7.1, 0.0, 1.0, 0.0, 7.1, 5.32, 1.78, 259.15, 'completado', 4, '2026-06-21 23:06:15', '2026-06-21 23:06:15', '2026-06-21 23:06:15', '2026-06-21 23:14:15', '2026-06-21 23:26:15'),
(57, 23, 1, 1, 2, 1, NULL, 1, 5.0, 3.71, 0.0, 1.0, 0.0, 3.71, 2.78, 0.93, 135.41, 'completado', 4, '2026-06-08 13:16:41', '2026-06-08 13:16:41', '2026-06-08 13:16:41', '2026-06-08 13:24:41', '2026-06-08 13:50:41'),
(40, 23, 1, 1, 2, 1, NULL, 1, 5.0, 11.63, 0.0, 1.0, 0.0, 11.63, 8.72, 2.91, 424.5, 'completado', 5, '2026-07-18 07:21:23', '2026-07-18 07:21:23', '2026-07-18 07:21:23', '2026-07-18 07:27:23', '2026-07-18 08:11:23'),
(23, 13, 1, 1, 2, 1, NULL, 1, 5.0, 9.16, 0.0, 1.0, 0.0, 9.16, 6.87, 2.29, 334.34, 'completado', 3, '2026-07-23 12:15:28', '2026-07-23 12:15:28', '2026-07-23 12:15:28', '2026-07-23 12:29:28', '2026-07-23 12:45:28'),
(22, 6, 1, 1, 2, 1, NULL, 1, 5.0, 2.79, 0.0, 1.0, 0.0, 2.79, 2.09, 0.7, 101.84, 'completado', 4, '2026-07-09 18:15:16', '2026-07-09 18:15:16', '2026-07-09 18:15:16', '2026-07-09 18:22:16', '2026-07-09 18:37:16'),
(17, 17, 1, 1, 2, 1, NULL, 1, 5.0, 5.37, 0.0, 1.0, 0.0, 5.37, 4.03, 1.34, 196.0, 'completado', 5, '2026-06-07 17:49:35', '2026-06-07 17:49:35', '2026-06-07 17:49:35', '2026-06-07 17:59:35', '2026-06-07 18:24:35'),
(16, 15, 1, 1, 2, 1, NULL, 1, 5.0, 7.36, 0.0, 1.0, 0.0, 7.36, 5.52, 1.84, 268.64, 'completado', 5, '2026-05-30 09:41:05', '2026-05-30 09:41:05', '2026-05-30 09:41:05', '2026-05-30 09:48:05', '2026-05-30 10:26:05'),
(35, 18, 1, 1, 2, 1, NULL, 1, 5.0, 13.49, 0.0, 1.0, 0.0, 13.49, 10.12, 3.37, 492.38, 'completado', 3, '2026-06-26 00:27:26', '2026-06-26 00:27:26', '2026-06-26 00:27:26', '2026-06-26 00:42:26', '2026-06-26 00:59:26'),
(4, 11, 1, 1, 2, 1, NULL, 1, 5.0, 5.58, 0.0, 1.0, 0.0, 5.58, 4.19, 1.39, 203.67, 'completado', 3, '2026-06-15 15:22:38', '2026-06-15 15:22:38', '2026-06-15 15:22:38', '2026-06-15 15:36:38', '2026-06-15 16:18:38'),
(13, 5, 1, 1, 2, 1, NULL, 1, 5.0, 7.77, 0.0, 1.0, 0.0, 7.77, 5.83, 1.94, 283.6, 'cancelado', NULL, '2026-06-23 21:58:56', '2026-06-23 21:58:56', '2026-06-23 21:58:56', NULL, NULL),
(55, 5, 1, 1, 2, 1, NULL, 1, 5.0, 13.71, 0.0, 1.0, 0.0, 13.71, 10.28, 3.43, 500.42, 'completado', 3, '2026-06-08 18:18:26', '2026-06-08 18:18:26', '2026-06-08 18:18:26', '2026-06-08 18:23:26', '2026-06-08 18:42:26'),
(18, 5, 1, 1, 2, 1, NULL, 1, 5.0, 9.1, 0.0, 1.0, 0.0, 9.1, 6.82, 2.28, 332.15, 'completado', 5, '2026-07-08 03:17:09', '2026-07-08 03:17:09', '2026-07-08 03:17:09', '2026-07-08 03:27:09', '2026-07-08 03:48:09'),
(11, 8, 1, 1, 2, 1, NULL, 1, 5.0, 5.16, 0.0, 1.0, 0.0, 5.16, 3.87, 1.29, 188.34, 'completado', 4, '2026-06-18 00:53:41', '2026-06-18 00:53:41', '2026-06-18 00:53:41', '2026-06-18 01:04:41', '2026-06-18 01:18:41'),
(19, 15, 1, 1, 2, 1, NULL, 1, 5.0, 8.84, 0.0, 1.0, 0.0, 8.84, 6.63, 2.21, 322.66, 'completado', 4, '2026-07-10 15:53:02', '2026-07-10 15:53:02', '2026-07-10 15:53:02', '2026-07-10 16:02:02', '2026-07-10 16:38:02'),
(34, 16, 1, 1, 2, 1, NULL, 1, 5.0, 3.34, 0.0, 1.0, 0.0, 3.34, 2.5, 0.84, 121.91, 'completado', 4, '2026-06-03 00:37:19', '2026-06-03 00:37:19', '2026-06-03 00:37:19', '2026-06-03 00:45:19', '2026-06-03 01:27:19'),
(6, 2, 1, 1, 2, 1, NULL, 1, 5.0, 11.43, 0.0, 1.0, 0.0, 11.43, 8.57, 2.86, 417.19, 'completado', 4, '2026-07-08 00:45:16', '2026-07-08 00:45:16', '2026-07-08 00:45:16', '2026-07-08 00:54:16', '2026-07-08 01:15:16'),
(11, 1, 1, 1, 2, 1, NULL, 1, 5.0, 5.64, 0.0, 1.0, 0.0, 5.64, 4.23, 1.41, 205.86, 'cancelado', NULL, '2026-06-24 14:44:07', '2026-06-24 14:44:07', '2026-06-24 14:44:07', NULL, NULL),
(40, 1, 1, 1, 2, 1, NULL, 1, 5.0, 10.2, 0.0, 1.0, 0.0, 10.2, 7.65, 2.55, 372.3, 'cancelado', NULL, '2026-07-11 15:46:31', '2026-07-11 15:46:31', '2026-07-11 15:46:31', NULL, NULL),
(54, 22, 1, 1, 2, 1, NULL, 1, 5.0, 3.04, 0.0, 1.0, 0.0, 3.04, 2.28, 0.76, 110.96, 'completado', 5, '2026-07-09 03:39:01', '2026-07-09 03:39:01', '2026-07-09 03:39:01', '2026-07-09 03:54:01', '2026-07-09 04:06:01'),
(8, 22, 1, 1, 2, 1, NULL, 1, 5.0, 8.62, 0.0, 1.0, 0.0, 8.62, 6.46, 2.16, 314.63, 'completado', 3, '2026-07-07 07:13:17', '2026-07-07 07:13:17', '2026-07-07 07:13:17', '2026-07-07 07:22:17', '2026-07-07 07:59:17'),
(40, 6, 1, 1, 2, 1, NULL, 1, 5.0, 13.47, 0.0, 1.0, 0.0, 13.47, 10.1, 3.37, 491.66, 'completado', 5, '2026-07-11 01:34:06', '2026-07-11 01:34:06', '2026-07-11 01:34:06', '2026-07-11 01:42:06', '2026-07-11 02:08:06'),
(36, 2, 1, 1, 2, 1, NULL, 1, 5.0, 14.76, 0.0, 1.0, 0.0, 14.76, 11.07, 3.69, 538.74, 'completado', 3, '2026-06-26 16:23:43', '2026-06-26 16:23:43', '2026-06-26 16:23:43', '2026-06-26 16:30:43', '2026-06-26 17:11:43'),
(59, 16, 1, 1, 2, 1, NULL, 1, 5.0, 2.87, 0.0, 1.0, 0.0, 2.87, 2.15, 0.72, 104.76, 'completado', 5, '2026-07-09 02:49:33', '2026-07-09 02:49:33', '2026-07-09 02:49:33', '2026-07-09 03:02:33', '2026-07-09 03:24:33'),
(22, 22, 1, 1, 2, 1, NULL, 1, 5.0, 12.18, 0.0, 1.0, 0.0, 12.18, 9.13, 3.05, 444.57, 'completado', 5, '2026-07-08 12:09:39', '2026-07-08 12:09:39', '2026-07-08 12:09:39', '2026-07-08 12:14:39', '2026-07-08 12:32:39');

-- Generar facturas para todos los traslados completados de prueba
INSERT INTO factura (
  id_traslado, nro_documento, nro_control, serie,
  razon_social, rif_cedula, direccion_fiscal,
  igtf_porcentaje, igtf_monto_usd
)
SELECT
  t.id,
  CONCAT('FAC-', LPAD(t.id, 8, '0')),
  CONCAT('00-', LPAD(t.id, 8, '0')),
  'A',
  CONCAT(u.nombre, ' ', u.apellido),
  u.cedula,
  'Ciudad Guayana, Venezuela',
  3.00,
  ROUND(t.costo_cliente_usd * 0.03, 2)
FROM traslado t
JOIN cliente cl ON t.id_cliente = cl.id
JOIN usuario u ON cl.id_usuario = u.id
WHERE t.estado = 'completado';


-- Fix: Marcar primer viaje como usado para los clientes que ya tienen viajes en el historial
UPDATE cliente SET primer_viaje_usado = 1 WHERE id IN (SELECT DISTINCT id_cliente FROM traslado);
