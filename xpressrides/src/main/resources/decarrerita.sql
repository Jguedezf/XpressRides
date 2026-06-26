-- ================================================================
--  XpressRides (Decarrerita)
--  Script SQL FINAL — Versión para modelador (Reverse Engineer)
--  Base de Datos I · UNEG · Prof. María Raquel Herrera E.
--  MySQL 8.0
--  Fecha: Junio 2026
-- ================================================================

DROP DATABASE IF EXISTS decarrerita;
CREATE DATABASE decarrerita
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE decarrerita;

-- ================================================================
-- BLOQUE 1: CATÁLOGOS BASE
-- ================================================================

CREATE TABLE banco (
  id          INT           AUTO_INCREMENT PRIMARY KEY,
  nombre      VARCHAR(100)  NOT NULL,
  codigo_bcv  VARCHAR(10)   NOT NULL UNIQUE,
  activo      TINYINT(1)    NOT NULL DEFAULT 1,
  creado_en   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_banco_nombre CHECK (CHAR_LENGTH(TRIM(nombre)) >= 3)
);

CREATE TABLE zona (
  id         INT            AUTO_INCREMENT PRIMARY KEY,
  nombre     VARCHAR(80)    NOT NULL UNIQUE,
  parroquia  VARCHAR(80)    NOT NULL,
  latitud    DECIMAL(10,7)  NOT NULL,
  longitud   DECIMAL(10,7)  NOT NULL,
  activo     TINYINT(1)     NOT NULL DEFAULT 1,
  creado_en  TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ================================================================
-- BLOQUE 2: USUARIOS Y ROLES (herencia por tabla separada)
-- ================================================================

CREATE TABLE usuario (
  id            INT           AUTO_INCREMENT PRIMARY KEY,
  cedula        VARCHAR(15)   NOT NULL UNIQUE,
  nombre        VARCHAR(80)   NOT NULL,
  apellido      VARCHAR(80)   NOT NULL,
  username      VARCHAR(50)   NOT NULL UNIQUE,
  password_hash VARCHAR(255)  NOT NULL,
  email         VARCHAR(120)  NOT NULL UNIQUE,
  telefono      VARCHAR(20)   NOT NULL,
  rol           ENUM('administrador','personal_admin','chofer','cliente') NOT NULL,
  activo        TINYINT(1)    NOT NULL DEFAULT 1,
  creado_en     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_email CHECK (email LIKE '%@%.%')
);

CREATE TABLE tasa_bcv (
  id              INT           AUTO_INCREMENT PRIMARY KEY,
  fecha_vigencia  DATE          NOT NULL UNIQUE,
  tasa_ves        DECIMAL(14,4) NOT NULL,
  registrado_por  INT           NOT NULL,
  creado_en       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_tasa_positiva CHECK (tasa_ves > 0),
  CONSTRAINT fk_tasa_registrador FOREIGN KEY (registrado_por) REFERENCES usuario(id)
);

CREATE TABLE cliente (
  id                 INT           AUTO_INCREMENT PRIMARY KEY,
  id_usuario         INT           NOT NULL UNIQUE,
  saldo_usd          DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  es_estudiante      TINYINT(1)    NOT NULL DEFAULT 0,
  primer_viaje_usado TINYINT(1)    NOT NULL DEFAULT 0,
  creado_en          TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_saldo_cliente CHECK (saldo_usd >= 0),
  CONSTRAINT fk_cliente_usuario FOREIGN KEY (id_usuario) REFERENCES usuario(id) ON DELETE CASCADE
);

CREATE TABLE chofer (
  id                  INT           AUTO_INCREMENT PRIMARY KEY,
  id_usuario          INT           NOT NULL UNIQUE,
  id_banco            INT           NOT NULL,
  id_zona_actual      INT           NULL,
  numero_cuenta       VARCHAR(20)   NOT NULL,
  saldo_acumulado_usd DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  habilitado          TINYINT(1)    NOT NULL DEFAULT 0,
  disponible          TINYINT(1)    NOT NULL DEFAULT 0,
  creado_en           TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_saldo_chofer CHECK (saldo_acumulado_usd >= 0),
  CONSTRAINT fk_chofer_usuario FOREIGN KEY (id_usuario)     REFERENCES usuario(id) ON DELETE CASCADE,
  CONSTRAINT fk_chofer_banco   FOREIGN KEY (id_banco)       REFERENCES banco(id),
  CONSTRAINT fk_chofer_zona    FOREIGN KEY (id_zona_actual) REFERENCES zona(id)
);

CREATE TABLE personal_admin (
  id         INT          AUTO_INCREMENT PRIMARY KEY,
  id_usuario INT          NOT NULL UNIQUE,
  cargo      VARCHAR(80)  NOT NULL DEFAULT 'Empleado Administrativo',
  creado_en  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_admin_usuario FOREIGN KEY (id_usuario) REFERENCES usuario(id) ON DELETE CASCADE
);

-- ================================================================
-- BLOQUE 3: MÓDULO OPERATIVO DEL CHOFER
-- ================================================================

CREATE TABLE contacto_emergencia (
  id         INT          AUTO_INCREMENT PRIMARY KEY,
  id_chofer  INT          NOT NULL,
  nombre     VARCHAR(120) NOT NULL,
  telefono   VARCHAR(20)  NOT NULL,
  parentesco VARCHAR(50)  NOT NULL,
  creado_en  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_contacto_chofer FOREIGN KEY (id_chofer) REFERENCES chofer(id) ON DELETE CASCADE
);

CREATE TABLE vehiculo (
  id               INT          AUTO_INCREMENT PRIMARY KEY,
  id_chofer        INT          NOT NULL,
  placa            VARCHAR(15)  NOT NULL UNIQUE,
  marca            VARCHAR(50)  NOT NULL,
  modelo           VARCHAR(50)  NOT NULL,
  anio_fabricacion YEAR         NOT NULL,
  color            VARCHAR(30)  NOT NULL,
  activo           TINYINT(1)   NOT NULL DEFAULT 1,
  creado_en        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_vehiculo_chofer FOREIGN KEY (id_chofer) REFERENCES chofer(id) ON DELETE CASCADE
);

CREATE TABLE evaluacion_psicologica (
  id           INT           AUTO_INCREMENT PRIMARY KEY,
  id_chofer    INT           NOT NULL,
  id_admin     INT           NOT NULL,
  calificacion DECIMAL(5,2)  NOT NULL,
  fecha_eval   DATE          NOT NULL,
  observacion  VARCHAR(255)  NULL,
  aprobado     TINYINT(1)    GENERATED ALWAYS AS (calificacion >= 73) STORED,
  creado_en    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_cal_psi    CHECK (calificacion BETWEEN 0 AND 100),
  CONSTRAINT fk_evalpsi_chofer FOREIGN KEY (id_chofer) REFERENCES chofer(id),
  CONSTRAINT fk_evalpsi_admin  FOREIGN KEY (id_admin)  REFERENCES personal_admin(id)
);

CREATE TABLE revision_vehiculo (
  id               INT           AUTO_INCREMENT PRIMARY KEY,
  id_vehiculo      INT           NOT NULL,
  id_admin         INT           NOT NULL,
  calificacion     DECIMAL(5,2)  NOT NULL,
  fecha_revision   DATE          NOT NULL,
  observacion      VARCHAR(255)  NULL,
  proxima_revision DATE          GENERATED ALWAYS AS
                   (DATE_ADD(fecha_revision, INTERVAL 1 YEAR)) STORED,
  apto             TINYINT(1)    GENERATED ALWAYS AS (calificacion >= 65) STORED,
  creado_en        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_cal_rev      CHECK (calificacion BETWEEN 0 AND 100),
  CONSTRAINT fk_revision_vehiculo FOREIGN KEY (id_vehiculo) REFERENCES vehiculo(id),
  CONSTRAINT fk_revision_admin    FOREIGN KEY (id_admin)    REFERENCES personal_admin(id)
);

-- ================================================================
-- BLOQUE 4: CUPONES (valor agregado)
-- ================================================================

CREATE TABLE cupon (
  id               INT           AUTO_INCREMENT PRIMARY KEY,
  codigo           VARCHAR(30)   NOT NULL UNIQUE,
  tipo             ENUM('bienvenida','estudiante','promocional') NOT NULL,
  descuento_usd    DECIMAL(8,2)  NOT NULL DEFAULT 0.00,
  distancia_max_km INT           NULL,
  activo           TINYINT(1)    NOT NULL DEFAULT 1,
  creado_en        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_descuento CHECK (descuento_usd >= 0)
);

CREATE TABLE cupon_cliente (
  id          INT       AUTO_INCREMENT PRIMARY KEY,
  id_cupon    INT       NOT NULL,
  id_cliente  INT       NOT NULL,
  usado       TINYINT(1) NOT NULL DEFAULT 0,
  fecha_uso   DATETIME  NULL,
  creado_en   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_cupon_cliente  UNIQUE (id_cupon, id_cliente),
  CONSTRAINT fk_cuponcli_cupon   FOREIGN KEY (id_cupon)   REFERENCES cupon(id),
  CONSTRAINT fk_cuponcli_cliente FOREIGN KEY (id_cliente) REFERENCES cliente(id)
);

-- ================================================================
-- BLOQUE 5: OPERACIÓN CENTRAL
-- ================================================================

CREATE TABLE recarga_saldo (
  id               INT               AUTO_INCREMENT PRIMARY KEY,
  id_cliente       INT               NOT NULL,
  id_banco         INT               NULL,
  id_tasa          INT               NOT NULL,
  monto_usd        DECIMAL(10,2)     NOT NULL,
  monto_ves        DECIMAL(18,2)     NOT NULL,
  referencia       VARCHAR(50)       NOT NULL UNIQUE,
  fecha_hora       DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
  moneda_pago      ENUM('VES','USD') NOT NULL DEFAULT 'VES',
  igtf_porcentaje  DECIMAL(5,2)      NOT NULL DEFAULT 0.00,
  igtf_monto_usd   DECIMAL(10,2)     NOT NULL DEFAULT 0.00,
  CONSTRAINT chk_monto_recarga  CHECK (monto_usd > 0 AND monto_ves > 0),
  CONSTRAINT chk_banco_en_ves   CHECK (moneda_pago = 'USD' OR id_banco IS NOT NULL),
  CONSTRAINT fk_recarga_cliente FOREIGN KEY (id_cliente) REFERENCES cliente(id),
  CONSTRAINT fk_recarga_banco   FOREIGN KEY (id_banco)   REFERENCES banco(id),
  CONSTRAINT fk_recarga_tasa    FOREIGN KEY (id_tasa)    REFERENCES tasa_bcv(id)
);

CREATE TABLE traslado (
  id                    INT           AUTO_INCREMENT PRIMARY KEY,
  id_cliente            INT           NOT NULL,
  id_chofer             INT           NOT NULL,
  id_vehiculo           INT           NOT NULL,
  id_zona_origen        INT           NOT NULL,
  id_zona_destino       INT           NOT NULL,
  id_tasa               INT           NOT NULL,
  id_cupon_cliente      INT           NULL,

  -- Pasajeros
  nro_pasajeros         INT           NOT NULL DEFAULT 1,

  -- Cálculo de distancia y tarifa
  distancia_km          DECIMAL(8,2)  NOT NULL,
  tarifa_base_usd       DECIMAL(10,2) NOT NULL,
  recargo_horario_usd   DECIMAL(8,2)  NOT NULL DEFAULT 0.00,
  factor_hora_pico      DECIMAL(4,2)  NOT NULL DEFAULT 1.00,
  descuento_usd         DECIMAL(8,2)  NOT NULL DEFAULT 0.00,

  -- Montos finales
  costo_cliente_usd     DECIMAL(10,2) NOT NULL,
  monto_chofer_usd      DECIMAL(10,2) NOT NULL,
  monto_empresa_usd     DECIMAL(10,2) NOT NULL,
  costo_cliente_ves     DECIMAL(18,2) NOT NULL,

  -- Estado y cancelación
  estado                ENUM('solicitado','aceptado','en_camino',
                             'chofer_llego','en_progreso',
                             'completado','cancelado') NOT NULL DEFAULT 'solicitado',
  cancelado_por         ENUM('cliente','chofer','empresa') NULL,
  motivo_cancelacion    VARCHAR(200)  NULL,

  -- Calificación del cliente
  calificacion_estrellas INT          NULL,
  comentario_cliente    VARCHAR(255)  NULL,

  -- Tiempos del viaje
  intentos_asignacion   INT           NOT NULL DEFAULT 1,
  rechazos              INT           NOT NULL DEFAULT 0,
  eta_minutos           INT           NULL,
  fecha_solicitud       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_aceptacion      DATETIME      NULL,
  fecha_inicio          DATETIME      NULL,
  fecha_fin             DATETIME      NULL,
  duracion_minutos      INT           NULL,

  CONSTRAINT chk_pasajeros     CHECK (nro_pasajeros BETWEEN 1 AND 3),
  CONSTRAINT chk_zonas_dist    CHECK (id_zona_origen <> id_zona_destino),
  CONSTRAINT chk_estrellas     CHECK (calificacion_estrellas BETWEEN 1 AND 5),
  CONSTRAINT chk_montos_ok     CHECK (costo_cliente_usd >= 0 AND monto_chofer_usd >= 0),
  CONSTRAINT fk_traslado_cliente  FOREIGN KEY (id_cliente)       REFERENCES cliente(id),
  CONSTRAINT fk_traslado_chofer   FOREIGN KEY (id_chofer)        REFERENCES chofer(id),
  CONSTRAINT fk_traslado_vehiculo FOREIGN KEY (id_vehiculo)      REFERENCES vehiculo(id),
  CONSTRAINT fk_traslado_origen   FOREIGN KEY (id_zona_origen)   REFERENCES zona(id),
  CONSTRAINT fk_traslado_destino  FOREIGN KEY (id_zona_destino)  REFERENCES zona(id),
  CONSTRAINT fk_traslado_tasa     FOREIGN KEY (id_tasa)          REFERENCES tasa_bcv(id),
  CONSTRAINT fk_traslado_cupon    FOREIGN KEY (id_cupon_cliente) REFERENCES cupon_cliente(id)
);

CREATE TABLE pago_chofer (
  id          INT           AUTO_INCREMENT PRIMARY KEY,
  id_chofer   INT           NOT NULL,
  id_admin    INT           NOT NULL,
  id_banco    INT           NOT NULL,
  monto_usd   DECIMAL(10,2) NOT NULL,
  monto_ves   DECIMAL(18,2) NOT NULL,
  referencia  VARCHAR(50)   NOT NULL UNIQUE,
  fecha_hora  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_monto_pago CHECK (monto_usd > 0),
  CONSTRAINT fk_pago_chofer FOREIGN KEY (id_chofer) REFERENCES chofer(id),
  CONSTRAINT fk_pago_admin  FOREIGN KEY (id_admin)  REFERENCES personal_admin(id),
  CONSTRAINT fk_pago_banco  FOREIGN KEY (id_banco)  REFERENCES banco(id)
);

-- ----------------------------------------------------------------
-- Tabla factura: comprobante fiscal generado automáticamente al
-- completar cada traslado. Los montos (USD, VES, tasa BCV) NO se
-- duplican aquí: se consultan directamente desde traslado mediante
-- la relación id_traslado, evitando redundancia de datos.
-- El nombre/cédula del cliente tampoco se duplica: ya existen en
-- la tabla usuario y se consultan mediante traslado -> cliente -> usuario.
-- Campos como razon_social y direccion_fiscal SÍ se almacenan aparte,
-- porque pueden diferir de los datos de registro del usuario (p. ej.
-- el cliente factura a nombre de otra persona o con otra dirección).
-- ----------------------------------------------------------------
CREATE TABLE factura (
  id                  INT           AUTO_INCREMENT PRIMARY KEY,
  id_traslado         INT           NOT NULL UNIQUE,
  nro_documento       VARCHAR(20)   NOT NULL UNIQUE,
  nro_control         VARCHAR(20)   NOT NULL UNIQUE,
  serie               VARCHAR(5)    NOT NULL DEFAULT 'A',
  fecha_emision       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  razon_social        VARCHAR(120)  NOT NULL,
  rif_cedula          VARCHAR(15)   NOT NULL,
  direccion_fiscal    VARCHAR(200)  NOT NULL,
  codigo_actividad    VARCHAR(10)   NOT NULL DEFAULT '9609',
  igtf_porcentaje     DECIMAL(5,2)  NOT NULL DEFAULT 0.00,
  igtf_monto_usd      DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  observacion_fiscal  VARCHAR(255)  NOT NULL DEFAULT
    'Documento generado conforme a normativa SENIAT vigente. En una implementación productiva real, este comprobante sería emitido a través de un proveedor de facturación electrónica homologado.',
  CONSTRAINT chk_igtf_valido CHECK (igtf_porcentaje >= 0 AND igtf_porcentaje <= 100),
  CONSTRAINT fk_factura_traslado FOREIGN KEY (id_traslado) REFERENCES traslado(id)
);

-- ----------------------------------------------------------------
-- Tabla notificacion: registro de eventos para mostrar al usuario
-- dentro de la web (campanita de notificaciones), ya que una
-- aplicación web no puede enviar notificaciones push nativas como
-- una app de teléfono. Cada fila es un aviso que el usuario ve al
-- entrar o refrescar su panel. El campo id_usuario referencia
-- directamente a usuario (no a cliente o chofer por separado),
-- porque ambos roles heredan de usuario y así una sola tabla cubre
-- notificaciones para cualquier tipo de cuenta.
-- ----------------------------------------------------------------
CREATE TABLE notificacion (
  id            INT           AUTO_INCREMENT PRIMARY KEY,
  id_usuario    INT           NOT NULL,
  id_traslado   INT           NULL,
  tipo          ENUM('viaje_solicitado','chofer_asignado','chofer_en_camino',
                      'viaje_iniciado','viaje_completado','factura_emitida',
                      'pago_recibido','recarga_acreditada','viaje_cancelado')
                              NOT NULL,
  mensaje       VARCHAR(200)  NOT NULL,
  leida         TINYINT(1)    NOT NULL DEFAULT 0,
  fecha_hora    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_notif_usuario  FOREIGN KEY (id_usuario)  REFERENCES usuario(id) ON DELETE CASCADE,
  CONSTRAINT fk_notif_traslado FOREIGN KEY (id_traslado) REFERENCES traslado(id)
);

-- ================================================================
-- BLOQUE 6: FUNCIÓN HAVERSINE
-- ================================================================

DELIMITER $$

CREATE FUNCTION fn_distancia_km(
  lat1 DECIMAL(10,7), lon1 DECIMAL(10,7),
  lat2 DECIMAL(10,7), lon2 DECIMAL(10,7)
) RETURNS DECIMAL(8,2)
DETERMINISTIC
BEGIN
  DECLARE R   DECIMAL(10,4) DEFAULT 6371.0;
  DECLARE dLat DECIMAL(15,10);
  DECLARE dLon DECIMAL(15,10);
  DECLARE a    DECIMAL(15,10);
  DECLARE c    DECIMAL(15,10);
  SET dLat = RADIANS(lat2 - lat1);
  SET dLon = RADIANS(lon2 - lon1);
  SET a = SIN(dLat/2)*SIN(dLat/2)
        + COS(RADIANS(lat1))*COS(RADIANS(lat2))
        * SIN(dLon/2)*SIN(dLon/2);
  SET c = 2 * ATAN2(SQRT(a), SQRT(1-a));
  RETURN ROUND(R * c, 2);
END$$

-- ================================================================
-- BLOQUE 7: PROCEDIMIENTO CENTRAL DEL TRASLADO
-- ================================================================

CREATE PROCEDURE sp_solicitar_traslado(
  IN  p_id_cliente       INT,
  IN  p_id_zona_origen   INT,
  IN  p_id_zona_destino  INT,
  IN  p_nro_pasajeros    INT,
  IN  p_id_cupon_cliente INT,
  OUT p_id_traslado      INT,
  OUT p_mensaje          VARCHAR(300)
)
sp_solicitar_traslado: BEGIN
  DECLARE TARIFA_BASE      DECIMAL(8,2)  DEFAULT 1.00;
  DECLARE COSTO_KM         DECIMAL(8,4)  DEFAULT 0.45;
  DECLARE RECARGO_ESP      DECIMAL(8,2)  DEFAULT 1.50;
  DECLARE RADIO_1          DECIMAL(5,1)  DEFAULT 5.0;
  DECLARE RADIO_2          DECIMAL(5,1)  DEFAULT 10.0;
  DECLARE RADIO_3          DECIMAL(5,1)  DEFAULT 15.0;

  DECLARE v_lat1 DECIMAL(10,7); DECLARE v_lon1 DECIMAL(10,7);
  DECLARE v_lat2 DECIMAL(10,7); DECLARE v_lon2 DECIMAL(10,7);
  DECLARE v_dist_km        DECIMAL(8,2);
  DECLARE v_hora           INT DEFAULT HOUR(NOW());
  DECLARE v_dia            INT DEFAULT DAYOFWEEK(NOW());
  DECLARE v_recargo        DECIMAL(8,2)  DEFAULT 0.00;
  DECLARE v_factor         DECIMAL(4,2)  DEFAULT 1.00;
  DECLARE v_es_est         TINYINT(1);
  DECLARE v_primer         TINYINT(1);
  DECLARE v_descuento      DECIMAL(8,2)  DEFAULT 0.00;
  DECLARE v_dist_max       INT;
  DECLARE v_tarifa         DECIMAL(10,2);
  DECLARE v_costo_cli      DECIMAL(10,2);
  DECLARE v_monto_ch       DECIMAL(10,2);
  DECLARE v_monto_emp      DECIMAL(10,2);
  DECLARE v_costo_ves      DECIMAL(18,2);
  DECLARE v_saldo          DECIMAL(12,2);
  DECLARE v_id_tasa        INT;
  DECLARE v_tasa_ves       DECIMAL(14,4);
  DECLARE v_id_chofer      INT;
  DECLARE v_id_vehiculo    INT;
  DECLARE v_id_zona_chofer INT;
  DECLARE v_radio          DECIMAL(5,1);
  DECLARE v_id_zona_dest    INT;
  DECLARE v_desc_estudiante DECIMAL(8,2)  DEFAULT 0.00;
  DECLARE v_tarifa_original DECIMAL(10,2) DEFAULT 0.00;

  -- Validar pasajeros
  IF p_nro_pasajeros < 1 OR p_nro_pasajeros > 3 THEN
    SET p_mensaje = 'ERROR: El número de pasajeros debe ser entre 1 y 3.';
    SET p_id_traslado = NULL;
    LEAVE sp_solicitar_traslado;
  END IF;

  -- Validar que el cliente no tenga un viaje activo
  IF EXISTS (
    SELECT 1 FROM traslado
     WHERE id_cliente = p_id_cliente
       AND estado IN ('solicitado','aceptado','en_camino','chofer_llego','en_progreso')
  ) THEN
    SET p_mensaje = 'ERROR: Ya tienes un viaje activo en curso.';
    SET p_id_traslado = NULL;
    LEAVE sp_solicitar_traslado;
  END IF;

  -- Coordenadas de las zonas
  SELECT latitud, longitud INTO v_lat1, v_lon1
    FROM zona WHERE id = p_id_zona_origen;
  SELECT latitud, longitud INTO v_lat2, v_lon2
    FROM zona WHERE id = p_id_zona_destino;

  IF v_lat1 IS NULL OR v_lat2 IS NULL THEN
    SET p_mensaje = 'ERROR: Zona no encontrada.';
    SET p_id_traslado = NULL;
    LEAVE sp_solicitar_traslado;
  END IF;

  -- Distancia Haversine
  SET v_dist_km = fn_distancia_km(v_lat1, v_lon1, v_lat2, v_lon2);

  -- Tarifa base + distancia
  SET v_tarifa = TARIFA_BASE + (v_dist_km * COSTO_KM);

  -- Recargo nocturno o fin de semana
  IF (v_hora >= 19 OR v_hora < 5) OR (v_dia IN (1,7)) THEN
    SET v_recargo = RECARGO_ESP;
    SET v_tarifa  = v_tarifa + v_recargo;
  END IF;

  -- Factor hora pico
  IF    v_hora >= 7  AND v_hora < 9  THEN SET v_factor = 1.20;
  ELSEIF v_hora >= 11 AND v_hora < 13 THEN SET v_factor = 1.15;
  ELSEIF v_hora >= 17 AND v_hora < 19 THEN SET v_factor = 1.25;
  END IF;
  SET v_tarifa = v_tarifa * v_factor;
  SET v_tarifa_original = v_tarifa;

  -- Tipo de cliente
  SELECT es_estudiante, primer_viaje_usado
    INTO v_es_est, v_primer
    FROM cliente WHERE id = p_id_cliente;

  -- Descuento estudiantil (zona origen O destino = sede universitaria)
  IF v_es_est = 1 THEN
    SELECT id INTO v_id_zona_dest FROM zona
     WHERE id IN (p_id_zona_origen, p_id_zona_destino)
       AND nombre IN ('UNEG Sede Atlántico','UNEG Sede Villa Asia','UNEXPO')
     LIMIT 1;
    IF v_id_zona_dest IS NOT NULL THEN
      SET v_desc_estudiante = ROUND(v_tarifa * 0.30, 2);
      SET v_tarifa          = ROUND(v_tarifa * 0.70, 2);
    END IF;
  END IF;

  -- Primer viaje gratis
  IF v_primer = 0 THEN
    SET v_descuento   = v_tarifa;
    SET v_costo_cli   = 0.00;
  ELSE
    -- Cupón de descuento
    IF p_id_cupon_cliente IS NOT NULL THEN
      SELECT c.descuento_usd, c.distancia_max_km
        INTO v_descuento, v_dist_max
        FROM cupon_cliente cc
        JOIN cupon c ON cc.id_cupon = c.id
       WHERE cc.id = p_id_cupon_cliente
         AND cc.id_cliente = p_id_cliente
         AND cc.usado = 0
         AND c.activo = 1;
      IF v_dist_max IS NOT NULL AND v_dist_km > v_dist_max THEN
        SET v_descuento = 0.00;
        SET p_id_cupon_cliente = NULL;
        SET p_mensaje = 'AVISO: Cupón no aplicado (distancia excedida). ';
      END IF;
    END IF;
    SET v_costo_cli = GREATEST(v_tarifa - IFNULL(v_descuento,0), 0.00);
  END IF;

  -- Verificar saldo
  SELECT saldo_usd INTO v_saldo FROM cliente WHERE id = p_id_cliente;
  IF v_saldo < v_costo_cli THEN
    SET p_mensaje = CONCAT(IFNULL(p_mensaje,''),
      'ERROR: Saldo insuficiente. Disponible: $',ROUND(v_saldo,2),
      ' | Necesario: $',ROUND(v_costo_cli,2));
    SET p_id_traslado = NULL;
    LEAVE sp_solicitar_traslado;
  END IF;

  -- Tasa BCV vigente (proximidad histórica)
  SELECT id, tasa_ves INTO v_id_tasa, v_tasa_ves
    FROM tasa_bcv
   WHERE fecha_vigencia <= CURDATE()
   ORDER BY fecha_vigencia DESC
   LIMIT 1;

  IF v_id_tasa IS NULL THEN
    SET p_mensaje = 'ERROR: No hay tasa BCV registrada.';
    SET p_id_traslado = NULL;
    LEAVE sp_solicitar_traslado;
  END IF;

  -- Distribución 70/30 sobre tarifa original (antes del descuento estudiantil)
  -- El chofer siempre recibe 70% de la tarifa sin descuento; la empresa absorbe el descuento
  SET v_monto_ch  = ROUND(v_tarifa_original * 0.70, 2);
  SET v_monto_emp = ROUND((v_tarifa_original * 0.30) - v_desc_estudiante - IFNULL(v_descuento,0), 2);
  SET v_costo_ves = ROUND(v_costo_cli * v_tasa_ves, 2);

  -- Asignación por proximidad (radio 5 → 10 → 15 km)
  SET v_id_chofer = NULL;
  SET v_radio = RADIO_1;
  WHILE v_id_chofer IS NULL AND v_radio <= RADIO_3 DO
    SELECT c.id, v.id, c.id_zona_actual
      INTO v_id_chofer, v_id_vehiculo, v_id_zona_chofer
      FROM chofer c
      JOIN zona  zo ON zo.id = c.id_zona_actual
      JOIN vehiculo v ON v.id_chofer = c.id AND v.activo = 1
      JOIN (SELECT id_chofer FROM evaluacion_psicologica
             WHERE aprobado = 1
               AND fecha_eval >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
             GROUP BY id_chofer) ep ON ep.id_chofer = c.id
      JOIN (SELECT id_vehiculo FROM revision_vehiculo
             WHERE apto = 1
               AND fecha_revision >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
             GROUP BY id_vehiculo) rv ON rv.id_vehiculo = v.id
     WHERE c.habilitado = 1
       AND c.disponible = 1
       AND c.id_zona_actual IS NOT NULL
       AND fn_distancia_km(zo.latitud, zo.longitud, v_lat1, v_lon1) <= v_radio
     ORDER BY RAND()
     LIMIT 1;
    IF v_id_chofer IS NULL THEN
      SET v_radio = v_radio + 5.0;
    END IF;
  END WHILE;

  IF v_id_chofer IS NULL THEN
    SET p_mensaje = CONCAT(IFNULL(p_mensaje,''),
      'ERROR: No hay choferes disponibles en este momento.');
    SET p_id_traslado = NULL;
    LEAVE sp_solicitar_traslado;
  END IF;

  -- Registrar traslado
  INSERT INTO traslado (
    id_cliente, id_chofer, id_vehiculo,
    id_zona_origen, id_zona_destino, id_tasa, id_cupon_cliente,
    nro_pasajeros, distancia_km, tarifa_base_usd,
    recargo_horario_usd, factor_hora_pico, descuento_usd,
    costo_cliente_usd, monto_chofer_usd, monto_empresa_usd,
    costo_cliente_ves, estado,
    eta_minutos, fecha_solicitud
  ) VALUES (
    p_id_cliente, v_id_chofer, v_id_vehiculo,
    p_id_zona_origen, p_id_zona_destino, v_id_tasa, p_id_cupon_cliente,
    p_nro_pasajeros, v_dist_km, v_tarifa,
    v_recargo, v_factor, v_desc_estudiante + IFNULL(v_descuento,0),
    v_costo_cli, v_monto_ch, v_monto_emp,
    v_costo_ves, 'solicitado',
    CEILING(fn_distancia_km(
      (SELECT latitud FROM zona WHERE id = v_id_zona_chofer LIMIT 1),
      (SELECT longitud FROM zona WHERE id = v_id_zona_chofer LIMIT 1),
      v_lat1, v_lon1
    ) / 30 * 60),
    NOW()
  );
  SET p_id_traslado = LAST_INSERT_ID();

  -- Actualizar saldos y disponibilidad
  UPDATE cliente SET saldo_usd = saldo_usd - v_costo_cli WHERE id = p_id_cliente;
  UPDATE chofer  SET saldo_acumulado_usd = saldo_acumulado_usd + v_monto_ch,
                     disponible = 0 WHERE id = v_id_chofer;

  -- Marcar cupón y primer viaje
  IF p_id_cupon_cliente IS NOT NULL THEN
    UPDATE cupon_cliente SET usado = 1, fecha_uso = NOW()
     WHERE id = p_id_cupon_cliente;
  END IF;
  IF v_primer = 0 THEN
    UPDATE cliente SET primer_viaje_usado = 1 WHERE id = p_id_cliente;
  END IF;

  SET p_mensaje = CONCAT(IFNULL(p_mensaje,''),
    'OK: Traslado #', p_id_traslado,
    ' | Dist: ', v_dist_km, ' km',
    ' | Pasajeros: ', p_nro_pasajeros,
    ' | Costo: $', v_costo_cli, ' USD',
    ' | Bs. ', v_costo_ves);
END sp_solicitar_traslado$$

DELIMITER ;

-- ================================================================
-- BLOQUE 8: VISTAS PARA REPORTES
-- ================================================================

CREATE OR REPLACE VIEW v_tasa_vigente AS
  SELECT id, tasa_ves, fecha_vigencia
    FROM tasa_bcv
   WHERE fecha_vigencia <= CURDATE()
   ORDER BY fecha_vigencia DESC
   LIMIT 1;

CREATE OR REPLACE VIEW v_historial_traslados AS
  SELECT t.id, t.id_cliente,
    CONCAT(u_cl.nombre,' ',u_cl.apellido) AS cliente,
    CONCAT(u_ch.nombre,' ',u_ch.apellido) AS chofer,
    veh.placa, veh.marca, veh.modelo, veh.color,
    zo.nombre  AS zona_origen,
    zd.nombre  AS zona_destino,
    t.nro_pasajeros,
    t.distancia_km,
    t.costo_cliente_usd, t.costo_cliente_ves,
    t.estado, t.cancelado_por,
    t.calificacion_estrellas,
    t.eta_minutos, t.duracion_minutos,
    t.fecha_solicitud, t.fecha_fin
  FROM traslado t
  JOIN cliente  cl  ON t.id_cliente  = cl.id
  JOIN usuario  u_cl ON cl.id_usuario = u_cl.id
  JOIN chofer   ch  ON t.id_chofer   = ch.id
  JOIN usuario  u_ch ON ch.id_usuario = u_ch.id
  JOIN vehiculo veh ON t.id_vehiculo  = veh.id
  JOIN zona     zo  ON t.id_zona_origen  = zo.id
  JOIN zona     zd  ON t.id_zona_destino = zd.id;

CREATE OR REPLACE VIEW v_ganancias_empresa AS
  SELECT
    DATE(t.fecha_solicitud)      AS fecha,
    COUNT(*)                     AS cantidad_viajes,
    SUM(t.monto_empresa_usd)     AS total_empresa_usd,
    SUM(t.monto_empresa_usd * tb.tasa_ves) AS total_empresa_ves
  FROM traslado t
  JOIN tasa_bcv tb ON t.id_tasa = tb.id
  WHERE t.estado = 'completado'
  GROUP BY DATE(t.fecha_solicitud)
  ORDER BY fecha DESC;

CREATE OR REPLACE VIEW v_pagos_por_chofer AS
  SELECT pc.id,
    CONCAT(u.nombre,' ',u.apellido) AS chofer,
    b.nombre AS banco,
    pc.monto_usd, pc.monto_ves,
    pc.referencia, pc.fecha_hora
  FROM pago_chofer pc
  JOIN chofer  c ON pc.id_chofer = c.id
  JOIN usuario u ON c.id_usuario = u.id
  JOIN banco   b ON pc.id_banco  = b.id;

CREATE OR REPLACE VIEW v_pendientes_pago_chofer AS
  SELECT
    c.id AS id_chofer,
    CONCAT(u.nombre,' ',u.apellido) AS chofer,
    c.saldo_acumulado_usd,
    COUNT(t.id)             AS viajes_pendientes,
    SUM(t.monto_chofer_usd) AS total_pendiente_usd
  FROM chofer c
  JOIN usuario u ON c.id_usuario = u.id
  JOIN traslado t ON t.id_chofer = c.id
    AND t.estado = 'completado'
  WHERE c.saldo_acumulado_usd > 0
  GROUP BY c.id, u.nombre, u.apellido, c.saldo_acumulado_usd;

CREATE OR REPLACE VIEW v_traslados_cancelados AS
  SELECT t.id,
    CONCAT(u_cl.nombre,' ',u_cl.apellido) AS cliente,
    CONCAT(u_ch.nombre,' ',u_ch.apellido) AS chofer,
    zo.nombre AS zona_origen,
    zd.nombre AS zona_destino,
    t.cancelado_por,
    t.motivo_cancelacion,
    t.fecha_solicitud
  FROM traslado t
  JOIN cliente  cl  ON t.id_cliente  = cl.id
  JOIN usuario  u_cl ON cl.id_usuario = u_cl.id
  JOIN chofer   ch  ON t.id_chofer   = ch.id
  JOIN usuario  u_ch ON ch.id_usuario = u_ch.id
  JOIN zona     zo  ON t.id_zona_origen  = zo.id
  JOIN zona     zd  ON t.id_zona_destino = zd.id
  WHERE t.estado = 'cancelado';

CREATE OR REPLACE VIEW v_facturas_emitidas AS
  SELECT
    f.id, f.nro_documento, f.nro_control, f.serie, f.fecha_emision,
    f.razon_social, f.rif_cedula,
    t.costo_cliente_usd  AS monto_usd,
    t.costo_cliente_ves  AS monto_ves,
    f.igtf_monto_usd,
    zo.nombre AS zona_origen,
    zd.nombre AS zona_destino
  FROM factura f
  JOIN traslado t ON f.id_traslado = t.id
  JOIN zona zo ON t.id_zona_origen  = zo.id
  JOIN zona zd ON t.id_zona_destino = zd.id
  ORDER BY f.fecha_emision DESC;

CREATE OR REPLACE VIEW v_notificaciones_pendientes AS
  SELECT
    n.id, n.id_usuario, n.tipo, n.mensaje, n.fecha_hora,
    CONCAT(u.nombre, ' ', u.apellido) AS usuario,
    u.rol AS rol_usuario
  FROM notificacion n
  JOIN usuario u ON n.id_usuario = u.id
  WHERE n.leida = 0
  ORDER BY n.fecha_hora DESC;

-- ================================================================
-- BLOQUE 8B: TRIGGER DE FACTURACIÓN Y NOTIFICACIONES AUTOMÁTICAS
-- ================================================================
-- Reacciona a los cambios de estado del traslado para generar,
-- en el mismo trigger, tanto la factura fiscal (al completarse)
-- como las notificaciones que el cliente y el chofer verán en su
-- campanita de avisos dentro de la web. Se centraliza en un solo
-- trigger porque ambos efectos dependen del mismo evento: un
-- cambio de estado en traslado.
-- ================================================================

DELIMITER $$

CREATE TRIGGER trg_traslado_eventos
AFTER UPDATE ON traslado
FOR EACH ROW
BEGIN
  DECLARE v_id_usuario_cliente INT;
  DECLARE v_id_usuario_chofer  INT;

  -- Se obtienen los usuarios dueños del traslado para notificarles
  SELECT u.id INTO v_id_usuario_cliente
    FROM cliente cl JOIN usuario u ON cl.id_usuario = u.id
    WHERE cl.id = NEW.id_cliente;

  SELECT u.id INTO v_id_usuario_chofer
    FROM chofer ch JOIN usuario u ON ch.id_usuario = u.id
    WHERE ch.id = NEW.id_chofer;

  -- Notificación: chofer asignado (cambia de solicitado a aceptado)
  IF NEW.estado = 'aceptado' AND OLD.estado <> 'aceptado' THEN
    INSERT INTO notificacion (id_usuario, id_traslado, tipo, mensaje)
    VALUES (v_id_usuario_cliente, NEW.id, 'chofer_asignado',
      'Tu chofer fue asignado y va en camino hacia tu ubicación.');
  END IF;

  -- Notificación: chofer en camino
  IF NEW.estado = 'en_camino' AND OLD.estado <> 'en_camino' THEN
    INSERT INTO notificacion (id_usuario, id_traslado, tipo, mensaje)
    VALUES (v_id_usuario_cliente, NEW.id, 'chofer_en_camino',
      'Tu chofer está en camino al punto de recogida.');
  END IF;

  -- Notificación: viaje iniciado (cliente abordó)
  IF NEW.estado = 'en_progreso' AND OLD.estado <> 'en_progreso' THEN
    INSERT INTO notificacion (id_usuario, id_traslado, tipo, mensaje)
    VALUES (v_id_usuario_cliente, NEW.id, 'viaje_iniciado',
      'Tu viaje ha comenzado. ¡Buen viaje!');
  END IF;

  -- Al completarse: factura + notificación a cliente y a chofer
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

  -- Notificación: viaje cancelado, a ambas partes
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
-- BLOQUE 9: DATOS INICIALES
-- ================================================================

INSERT INTO banco (nombre, codigo_bcv) VALUES
  ('Banco de Venezuela',   'BDV'),
  ('Banesco',              'BNC'),
  ('Mercantil',            'MER'),
  ('BBVA Provincial',      'BBV'),
  ('Bicentenario',         'BIC'),
  ('Banco del Tesoro',     'BTU'),
  ('Banco Exterior',       'BEX');

INSERT INTO zona (nombre, parroquia, latitud, longitud) VALUES
  ('Castillito',           'Cachamay',      8.3153000, -62.7066000),
  ('Centro Cívico',        'Cachamay',      8.3245000, -62.7052000),
  ('Villa Brasil',         'Cachamay',      8.3102000, -62.7276000),
  ('Parque Cachamay',      'Cachamay',      8.3061012, -62.7018302),
  ('Jardines del Orinoco', 'Cachamay',      8.3020049, -62.7696214),
  ('Chirica',              'Chirica',       8.3385000, -62.6311000),
  ('Primero de Mayo',      'Chirica',       8.3592000, -62.6389000),
  ('Angosturita',          'Dalla Costa',   8.3478000, -62.6942000),
  ('La Sabanita',          'Dalla Costa',   8.3412000, -62.6680000),
  ('Las Malvinas',         'Dalla Costa',   8.3332000, -62.6608000),
  ('Parque La Llovizna',   'Dalla Costa',   8.3122729, -62.6785056),
  ('Doña Bárbara',         'Dalla Costa',   8.3394801, -62.6743453),
  ('El Roble por Dentro',  'Dalla Costa',   8.3535246, -62.6821624),
  ('El Roble por Fuera',   'Dalla Costa',   8.3555350, -62.6899840),
  ('Manoa',                'Dalla Costa',   8.3482799, -62.6668012),
  ('El Funcionario',       'Once de Abril', 8.3550000, -62.6550000),
  ('El Gallo',             'Once de Abril', 8.3643000, -62.6467000),
  ('Los Alacranes',        'Once de Abril', 8.3470868, -62.6515735),
  ('Redoma El Dorado',     'Once de Abril', 8.3384898, -62.6558393),
  ('Palúa',                'Simón Bolívar', 8.3503000, -62.6744000),
  ('Pinto Salinas',        'Simón Bolívar', 8.3576000, -62.6528000),
  ('San Félix Centro',     'Simón Bolívar', 8.3676000, -62.6633000),
  ('Core 8',               'Unare',         8.2286000, -62.8254000),
  ('Gran Sabana',          'Unare',         8.2297000, -62.8275000),
  ('Los Pinos',            'Unare',         8.2730000, -62.7928000),
  ('Matanzas',             'Unare',         8.2607000, -62.8392000),
  ('Paisana',              'Unare',         8.3025000, -62.7252000),
  ('Sierra Parima',        'Unare',         8.2503000, -62.8027000),
  ('Unare I',              'Unare',         8.2791000, -62.7515000),
  ('Unare II',             'Unare',         8.2759000, -62.7607000),
  ('Unare III',            'Unare',         8.2737000, -62.7686000),
  ('Villa América',        'Unare',         8.2771000, -62.7436000),
  ('Guayana Mall',         'Unare',         8.2774292, -62.7762992),
  ('CC Atlántico',         'Unare',         8.2788292, -62.7502880),
  ('El Caimito I',         'Unare',         8.2639630, -62.7933884),
  ('El Caimito II',        'Unare',         8.2698370, -62.7889782),
  ('Alta Vista Norte',     'Universidad',   8.3148000, -62.6892000),
  ('Alta Vista Sur',       'Universidad',   8.3052000, -62.6921000),
  ('Alta Vista I',         'Universidad',   8.2943733, -62.7336629),
  ('Alta Vista II',        'Universidad',   8.2932620, -62.7365350),
  ('Arivana',              'Universidad',   8.2981000, -62.7186000),
  ('Los Helechos',         'Universidad',   8.2942000, -62.7197000),
  ('Los Olivos',           'Universidad',   8.3061012, -62.7044051),
  ('Mini Finca',           'Universidad',   8.3015000, -62.7265000),
  ('Toro Muerto',          'Universidad',   8.3350000, -62.7089000),
  ('UNEG Sede Villa Asia', 'Universidad',   8.2822200, -62.7233869),
  ('UNEXPO',               'Universidad',   8.2797000, -62.7303000),
  ('Villa África',         'Universidad',   8.2790000, -62.7211000),
  ('Villa Asia',           'Universidad',   8.2827000, -62.7263000),
  ('Orinokia Mall',        'Universidad',   8.2926674, -62.7415848),
  ('Villa Universitaria',  'Universidad',   8.2719219, -62.7396964),
  ('UNEG Chilemex',        'Universidad',   8.3046222, -62.7249309),
  ('UNEG Sede Atlántico',  'Unare',         8.2721185, -62.7357291),
  ('Vista al Sol',         'Vista al Sol',  8.3519000, -62.6242000);

-- Usuario administrador base (password: Admin2026!)
INSERT INTO usuario (cedula,nombre,apellido,username,password_hash,email,telefono,rol)
VALUES ('V00000001','Admin','XpressRides','admin',
  '$2b$10$T8KVxa9l60H0x3lPf6APTuyFUVWtAPnzNNEYKfBfzNUpPGb4wA1EW','admin@xpressrides.ve','0412-0000000','administrador');

INSERT INTO cupon (codigo, tipo, descuento_usd, distancia_max_km) VALUES
  ('BIENVENIDO', 'bienvenida',  0.00, 15),
  ('ESTUDIANTE', 'estudiante',  0.50, NULL),
  ('PROMO10',    'promocional', 1.00, 20);

-- ================================================================
-- PRUEBAS RÁPIDAS (descomentar para verificar)
-- ================================================================
-- SELECT fn_distancia_km(8.3148,-62.6892,8.2722,-62.7353) AS km_altavista_uneg;
-- SELECT * FROM v_tasa_vigente;
-- CALL sp_solicitar_traslado(1,26,21,2,NULL,@id,@msg);
-- SELECT @id AS traslado, @msg AS resultado;
-- ================================================================
