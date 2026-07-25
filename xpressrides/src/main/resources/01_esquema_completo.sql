-- ==================================================================
-- SCRIPT CONSOLIDADO DE ESQUEMA Y MIGRACIONES
-- GENERADO AUTOMATICAMENTE
-- ==================================================================


-- ============================================================
-- INICIO DE ARCHIVO: decarrerita.sql
-- ============================================================

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
-- ----------------------------------------------------------------
-- Catálogo de Bancos Venezolanos (Para selects y formularios)
-- ----------------------------------------------------------------
CREATE TABLE catalogo_banco (
  codigo_bcv VARCHAR(4) PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL
);

-- ----------------------------------------------------------------
-- Tabla Banco (Bancos activos en el sistema para pagos)
-- ----------------------------------------------------------------
CREATE TABLE banco (
  id          INT           AUTO_INCREMENT PRIMARY KEY,
  nombre      VARCHAR(100)  NOT NULL,
  codigo_bcv  VARCHAR(10)   NOT NULL UNIQUE,
  acepta_usd  TINYINT(1)    NOT NULL DEFAULT 0,
  acepta_ves  TINYINT(1)    NOT NULL DEFAULT 1,
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

  -- Programa de referidos: código propio (generado en Java, no derivado del ID),
  -- quién lo refirió (si aplica) y si esa referencia ya generó la recompensa de
  -- $5 para el referente. Ver trg_recompensa_referido más abajo.
  codigo_referido               VARCHAR(10) NOT NULL UNIQUE,
  referido_por                  INT         NULL,
  recompensa_referido_otorgada  TINYINT(1)  NOT NULL DEFAULT 0,

  CONSTRAINT chk_saldo_cliente CHECK (saldo_usd >= 0),
  CONSTRAINT fk_cliente_usuario FOREIGN KEY (id_usuario) REFERENCES usuario(id) ON DELETE CASCADE,
  -- La protección "no puede referirse a sí mismo" NO puede ser un CHECK aquí:
  -- MySQL prohíbe (error 3823) que una columna con CHECK sea a la vez el lado
  -- hijo de un FK con ON DELETE SET NULL en la misma tabla. Se aplica en su
  -- lugar con trg_cliente_no_autoreferido_insert/_update (BLOQUE 8C, más abajo).
  CONSTRAINT fk_cliente_referido_por FOREIGN KEY (referido_por) REFERENCES cliente(id) ON DELETE SET NULL
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
  tipo             ENUM('bienvenida','estudiante','promocional','referido') NOT NULL,
  descuento_usd    DECIMAL(8,2)  NOT NULL DEFAULT 0.00,
  distancia_max_km INT           NULL,
  activo           TINYINT(1)    NOT NULL DEFAULT 1,
  creado_en        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_descuento CHECK (descuento_usd >= 0)
);

CREATE TABLE cupon_cliente (
  id                INT       AUTO_INCREMENT PRIMARY KEY,
  id_cupon          INT       NOT NULL,
  id_cliente        INT       NOT NULL,
  usado             TINYINT(1) NOT NULL DEFAULT 0,
  fecha_uso         DATETIME  NULL,
  -- Traslado del REFERIDO que generó este cupón de recompensa (solo aplica a
  -- cupones tipo 'referido'; NULL para el resto) — trazabilidad para la defensa.
  id_traslado_origen INT      NULL,
  creado_en         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_cupon_cliente  UNIQUE (id_cupon, id_cliente),
  CONSTRAINT fk_cuponcli_cupon    FOREIGN KEY (id_cupon)          REFERENCES cupon(id),
  CONSTRAINT fk_cuponcli_cliente  FOREIGN KEY (id_cliente)        REFERENCES cliente(id)
  -- fk_cupon_cliente_traslado se agrega más abajo vía ALTER TABLE, después de
  -- CREATE TABLE traslado (que todavía no existe en este punto del script)
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
  cancelado_por         ENUM('cliente','chofer','empresa','sistema') NULL,
  motivo_cancelacion    VARCHAR(200)  NULL,

  -- Calificación del cliente
  calificacion_estrellas INT          NULL,
  comentario_cliente    VARCHAR(255)  NULL,

  -- Tiempos del viaje
  intentos_asignacion   INT           NOT NULL DEFAULT 1,
  rechazos              INT           NOT NULL DEFAULT 0,
  eta_minutos           INT           NULL,
  fecha_solicitud       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_asignacion_actual DATETIME    NULL,
  fecha_aceptacion      DATETIME      NULL,
  fecha_inicio          DATETIME      NULL,
  fecha_fin             DATETIME      NULL,
  duracion_minutos      INT           NULL,
  pagado_al_chofer      TINYINT(1)    NOT NULL DEFAULT 0,

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

-- Cubre GET /api/cliente/viaje-activo y el polling de viaje activo del dashboard
-- Evita full table scan en traslado (tabla de mayor crecimiento del sistema)
CREATE INDEX idx_traslado_cliente_estado ON traslado(id_cliente, estado);

-- Cubre el job de timeout (TripTimeoutScheduler) que busca viajes 'solicitado'
-- vencidos por fecha_asignacion_actual, corre cada pocos segundos
CREATE INDEX idx_traslado_estado_asignacion ON traslado(estado, fecha_asignacion_actual);

-- cupon_cliente.id_traslado_origen no pudo llevar su FK inline porque cupon_cliente
-- (BLOQUE 4) se crea antes que traslado (BLOQUE 5) en este script — se agrega aquí.
ALTER TABLE cupon_cliente
  ADD CONSTRAINT fk_cupon_cliente_traslado FOREIGN KEY (id_traslado_origen) REFERENCES traslado(id);

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
                      'chofer_llego','viaje_iniciado','viaje_completado','factura_emitida',
                      'pago_recibido','recarga_acreditada','viaje_cancelado','sin_chofer','emergencia',
                      'recompensa_referido')
                              NOT NULL,
  mensaje       VARCHAR(200)  NOT NULL,
  leida         TINYINT(1)    NOT NULL DEFAULT 0,
  fecha_hora    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_notif_usuario  FOREIGN KEY (id_usuario)  REFERENCES usuario(id) ON DELETE CASCADE,
  CONSTRAINT fk_notif_traslado FOREIGN KEY (id_traslado) REFERENCES traslado(id)
);

-- Cubre countByUser_IdAndReadFalse (badge de campanita) y listado del panel
-- Sin este índice el conteo hace full scan en notificacion para cada polling
CREATE INDEX idx_notif_usuario_leida ON notificacion(id_usuario, leida);

-- ----------------------------------------------------------------
-- TABLA: incidente
-- Guarda los reportes de emergencia generados por el botón SOS.
-- Permite al administrador tomar el caso, resolverlo y dejar notas.
-- ----------------------------------------------------------------
CREATE TABLE incidente (
  id                  INT           AUTO_INCREMENT PRIMARY KEY,
  id_usuario_reporta  INT           NOT NULL,
  id_traslado         INT           NULL,
  mensaje             VARCHAR(255)  NOT NULL,
  estado              ENUM('abierto', 'en_proceso', 'cerrado') NOT NULL DEFAULT 'abierto',
  notas_resolucion    TEXT          NULL,
  id_admin_cierra     INT           NULL,
  fecha_creacion      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_cierre        DATETIME      NULL,
  CONSTRAINT fk_inc_usuario_rep FOREIGN KEY (id_usuario_reporta) REFERENCES usuario(id) ON DELETE CASCADE,
  CONSTRAINT fk_inc_traslado    FOREIGN KEY (id_traslado)        REFERENCES traslado(id) ON DELETE CASCADE,
  CONSTRAINT fk_inc_admin       FOREIGN KEY (id_admin_cierra)    REFERENCES usuario(id) ON DELETE SET NULL
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
  -- Piso de tarifa cuando se aplica un cupón de referido: nunca puede dejar
  -- el viaje en $0 (es una promoción de $5, no un viaje gratis). Otros tipos
  -- de cupón (bienvenida, promocional) conservan el piso de $0.00 de siempre.
  DECLARE TARIFA_MIN_CUPON_REFERIDO DECIMAL(8,2) DEFAULT 1.00;

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
  DECLARE v_tipo_cupon      VARCHAR(20);
  DECLARE v_estado VARCHAR(20) DEFAULT 'solicitado';
  DECLARE v_eta_minutos INT DEFAULT NULL;

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
      SELECT c.descuento_usd, c.distancia_max_km, c.tipo
        INTO v_descuento, v_dist_max, v_tipo_cupon
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
      -- Cupón de referido: descuento = MIN(descuento_usd, tarifa - piso).
      -- Los demás tipos (bienvenida, promocional) no pasan por aquí y
      -- conservan el comportamiento genérico de siempre (puede llegar a $0).
      IF v_tipo_cupon = 'referido' THEN
        SET v_descuento = LEAST(IFNULL(v_descuento,0), GREATEST(v_tarifa - TARIFA_MIN_CUPON_REFERIDO, 0.00));
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
    SET v_estado = 'buscando';
  ELSE
    SET v_eta_minutos = CEILING(fn_distancia_km(
      (SELECT latitud FROM zona WHERE id = v_id_zona_chofer LIMIT 1),
      (SELECT longitud FROM zona WHERE id = v_id_zona_chofer LIMIT 1),
      v_lat1, v_lon1
    ) / 30 * 60);
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
    v_costo_ves, v_estado,
    v_eta_minutos, NOW()
  );
  SET p_id_traslado = LAST_INSERT_ID();

  -- Actualizar saldos y disponibilidad
  UPDATE cliente SET saldo_usd = saldo_usd - v_costo_cli WHERE id = p_id_cliente;
  IF v_id_chofer IS NOT NULL THEN
    UPDATE chofer  SET disponible = 0 WHERE id = v_id_chofer;
  END IF;

  -- Marcar cupón y primer viaje
  IF p_id_cupon_cliente IS NOT NULL THEN
    UPDATE cupon_cliente SET usado = 1, fecha_uso = NOW()
     WHERE id = p_id_cupon_cliente;
  END IF;
  IF v_primer = 0 THEN
    UPDATE cliente SET primer_viaje_usado = 1 WHERE id = p_id_cliente;
  END IF;

  IF v_estado = 'buscando' THEN
    SET p_mensaje = CONCAT(IFNULL(p_mensaje,''),
      'OK: Traslado #', p_id_traslado, ' (Buscando chofer)');
  ELSE
    SET p_mensaje = CONCAT(IFNULL(p_mensaje,''),
      'OK: Traslado #', p_id_traslado,
      ' | Dist: ', v_dist_km, ' km',
      ' | Pasajeros: ', p_nro_pasajeros,
      ' | Costo: $', v_costo_cli, ' USD',
      ' | Bs. ', v_costo_ves);
  END IF;
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
    t.id                         AS id_traslado,
    DATE(t.fecha_solicitud)      AS fecha,
    (t.costo_cliente_usd + t.descuento_usd) AS costo_total_usd,
    t.descuento_usd              AS descuento_usd,
    t.monto_empresa_usd          AS total_empresa_usd,
    (t.monto_empresa_usd * tb.tasa_ves) AS total_empresa_ves,
    IF(t.descuento_usd > 0, 'Viaje con descuento', 'Viaje regular') AS concepto
  FROM traslado t
  JOIN tasa_bcv tb ON t.id_tasa = tb.id
  WHERE t.estado = 'completado'
  ORDER BY t.fecha_solicitud DESC;

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
  LEFT JOIN traslado t ON t.id_chofer = c.id
    AND t.estado = 'completado'
    AND t.pagado_al_chofer = 0
  WHERE c.saldo_acumulado_usd > 0
  GROUP BY c.id, u.nombre, u.apellido, c.saldo_acumulado_usd
  HAVING COUNT(t.id) > 0;

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

  -- Notificación: chofer llegó al punto de origen
  IF NEW.estado = 'chofer_llego' AND OLD.estado <> 'chofer_llego' THEN
    INSERT INTO notificacion (id_usuario, id_traslado, tipo, mensaje)
    VALUES (v_id_usuario_cliente, NEW.id, 'chofer_llego',
      'Tu chofer llegó al punto de recogida. ¡Está esperándote!');
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
-- BLOQUE 8C: PROGRAMA DE REFERIDOS
-- ================================================================
-- Vista de ranking (mismo patrón que las demás vistas del BLOQUE 8) y
-- trigger de recompensa, deliberadamente SEPARADO de trg_traslado_eventos:
-- ese trigger ya reacciona a todos los cambios de estado del traslado con
-- fines de notificación/facturación y es bastante largo. La recompensa de
-- referidos es una regla de negocio distinta — depende también de la tabla
-- cliente, no solo de traslado — y con su propio ciclo de vida. Separarlo
-- evita que una futura modificación a uno de los dos obligue a tocar el
-- otro, y permite explicar cada trigger de forma independiente en la
-- defensa del proyecto.
-- ================================================================

CREATE OR REPLACE VIEW v_top_referentes AS
  SELECT
    r.id                          AS id_referente,
    CONCAT(u.nombre,' ',u.apellido) AS referente,
    COUNT(c.id)                   AS total_referidos
  FROM cliente r
  JOIN usuario u ON r.id_usuario = u.id
  JOIN cliente c ON c.referido_por = r.id
  GROUP BY r.id, u.nombre, u.apellido
  ORDER BY total_referidos DESC;

-- Reemplaza al CHECK que MySQL no permite junto al FK con ON DELETE SET NULL
-- de referido_por (ver comentario en CREATE TABLE cliente). BEFORE INSERT es
-- más bien defensivo: con id AUTO_INCREMENT, NEW.id normalmente no se conoce
-- todavía en el INSERT, así que la auto-referencia real solo es alcanzable en
-- la práctica vía UPDATE — pero se cubren ambos casos por completitud.
DELIMITER $$

CREATE TRIGGER trg_cliente_no_autoreferido_insert
BEFORE INSERT ON cliente
FOR EACH ROW
BEGIN
  IF NEW.referido_por IS NOT NULL AND NEW.referido_por = NEW.id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un cliente no puede tener su propio código como referido_por';
  END IF;
END$$

CREATE TRIGGER trg_cliente_no_autoreferido_update
BEFORE UPDATE ON cliente
FOR EACH ROW
BEGIN
  IF NEW.referido_por IS NOT NULL AND NEW.referido_por = NEW.id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un cliente no puede tener su propio código como referido_por';
  END IF;
END$$

DELIMITER ;

DELIMITER $$

CREATE TRIGGER trg_recompensa_referido
AFTER UPDATE ON traslado
FOR EACH ROW
BEGIN
  DECLARE v_id_referente         INT;
  DECLARE v_id_usuario_referente INT;
  DECLARE v_codigo_cupon         VARCHAR(30);
  DECLARE v_id_cupon             INT;
  DECLARE v_filas_marcadas       INT;

  -- Solo interesa el instante en que el viaje se completa y tuvo costo real:
  -- un viaje 100% cubierto por descuento no genera recompensa, para que nadie
  -- pueda encadenar viajes gratuitos entre cuentas propias y farmear cupones
  -- sin que la empresa reciba ingreso real por ese viaje.
  IF NEW.estado = 'completado' AND OLD.estado <> 'completado' AND NEW.costo_cliente_usd > 0 THEN

    SELECT referido_por INTO v_id_referente
      FROM cliente
      WHERE id = NEW.id_cliente;

    IF v_id_referente IS NOT NULL THEN

      -- Reclamo atómico de la recompensa: UPDATE condicionado por
      -- recompensa_referido_otorgada = 0, verificando ROW_COUNT(), en vez de
      -- un SELECT seguido de un UPDATE por separado (mismo patrón que
      -- TripRejectionService.claimSolicitadoForReassignment usa en el backend
      -- Java para el mismo tipo de problema). Así, si este cliente referido
      -- llegara a disparar el trigger dos veces para "su primer viaje pagado"
      -- por cualquier motivo, la segunda vez encuentra 0 filas afectadas y no
      -- se genera un cupón duplicado.
      UPDATE cliente
        SET recompensa_referido_otorgada = 1
        WHERE id = NEW.id_cliente
          AND recompensa_referido_otorgada = 0;

      SET v_filas_marcadas = ROW_COUNT();

      IF v_filas_marcadas = 1 THEN

        -- Cupón INDIVIDUAL (no uno compartido tipo 'BIENVENIDO'): cada
        -- recompensa es su propia fila en cupon con código único, para poder
        -- trazar en cupon_cliente.id_traslado_origen exactamente qué viaje
        -- del referido generó cada cupón del referente.
        SET v_codigo_cupon = CONCAT('REF-', LPAD(NEW.id, 8, '0'));

        INSERT INTO cupon (codigo, tipo, descuento_usd, distancia_max_km, activo)
        VALUES (v_codigo_cupon, 'referido', 5.00, NULL, 1);

        SET v_id_cupon = LAST_INSERT_ID();

        INSERT INTO cupon_cliente (id_cupon, id_cliente, usado, id_traslado_origen)
        VALUES (v_id_cupon, v_id_referente, 0, NEW.id);

        SELECT u.id INTO v_id_usuario_referente
          FROM cliente cl JOIN usuario u ON cl.id_usuario = u.id
          WHERE cl.id = v_id_referente;

        INSERT INTO notificacion (id_usuario, id_traslado, tipo, mensaje)
        VALUES (v_id_usuario_referente, NEW.id, 'recompensa_referido',
          CONCAT('¡Ganaste un cupón de $5 porque tu referido completó su primer viaje pagado! Código: ', v_codigo_cupon));

      END IF;

    END IF;

  END IF;

END$$

DELIMITER ;

-- ================================================================
-- BLOQUE 9: DATOS INICIALES
-- ================================================================

  ('BFC', '0151'),
  ('Banco Plaza', '0138'),
  ('Banco Caroní', '0128'),
  ('DELSUR', '0157'),
  ('Banco Activo', '0171'),
  ('Sofitasa', '0137'),
  ('100% Banco', '0156'),
  ('BVC', '0104'),
  ('Bancrecer', '0168'),
  ('BDV', '0102'),
  ('BDT', '0175'),
  ('Banco del Tesoro', '0163'),
  ('BAV', '0166'),
  ('BANFANB', '0177');

INSERT INTO banco (nombre, codigo_bcv, acepta_usd, acepta_ves) VALUES
  ('Banco de Venezuela',            '0102', 1, 1),
  ('Banesco',                       '0134', 0, 1),
  ('Mercantil',                     '0105', 1, 1),
  ('BBVA Provincial',               '0108', 1, 1),
  ('Bicentenario',                  '0175', 0, 1),
  ('Banco del Tesoro',              '0163', 0, 1),
  ('Banco Exterior',                '0115', 0, 1),
  ('Bancaribe',                     '0114', 1, 1),
  ('BNC (Banco Nacional de Credito)', '0191', 1, 1),
  ('Banco Plaza',                   '0138', 1, 1),
  ('BFC (Banco Fondo Comun)',       '0151', 1, 1);

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
-- PROCEDIMIENTO BÚSQUEDA DE CHOFER
-- ================================================================
DELIMITER $$
CREATE PROCEDURE sp_buscar_chofer_viaje(
  IN p_id_traslado INT,
  OUT p_id_chofer INT
)
sp_buscar_chofer_viaje: BEGIN
  DECLARE RADIO_1 DECIMAL(5,1) DEFAULT 5.0;
  DECLARE RADIO_2 DECIMAL(5,1) DEFAULT 10.0;
  DECLARE RADIO_3 DECIMAL(5,1) DEFAULT 15.0;
  DECLARE v_radio DECIMAL(5,1) DEFAULT RADIO_1;

  DECLARE v_lat1 DECIMAL(10,7);
  DECLARE v_lon1 DECIMAL(10,7);
  DECLARE v_id_zona_chofer INT;
  DECLARE v_id_vehiculo INT;
  DECLARE v_eta_minutos INT;

  SET p_id_chofer = NULL;

  -- Obtener origen del viaje
  SELECT z.latitud, z.longitud
    INTO v_lat1, v_lon1
    FROM traslado t
    JOIN zona z ON z.id = t.id_zona_origen
   WHERE t.id = p_id_traslado AND t.estado = 'buscando';

  IF v_lat1 IS NULL THEN
    LEAVE sp_buscar_chofer_viaje;
  END IF;

  WHILE p_id_chofer IS NULL AND v_radio <= RADIO_3 DO
    SELECT c.id, v.id, c.id_zona_actual
      INTO p_id_chofer, v_id_vehiculo, v_id_zona_chofer
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

    IF p_id_chofer IS NULL THEN
      SET v_radio = v_radio + 5.0;
    END IF;
  END WHILE;

  IF p_id_chofer IS NOT NULL THEN
    SET v_eta_minutos = CEILING(fn_distancia_km(
      (SELECT latitud FROM zona WHERE id = v_id_zona_chofer LIMIT 1),
      (SELECT longitud FROM zona WHERE id = v_id_zona_chofer LIMIT 1),
      v_lat1, v_lon1
    ) / 30 * 60);

    UPDATE traslado 
       SET id_chofer = p_id_chofer,
           id_vehiculo = v_id_vehiculo,
           estado = 'solicitado',
           eta_minutos = v_eta_minutos,
           fecha_asignacion_actual = NOW()
     WHERE id = p_id_traslado;

    UPDATE chofer SET disponible = 0 WHERE id = p_id_chofer;
  END IF;

END sp_buscar_chofer_viaje$$
DELIMITER ;

-- ================================================================
-- PRUEBAS RÁPIDAS (descomentar para verificar)
-- ================================================================
-- SELECT fn_distancia_km(8.3148,-62.6892,8.2722,-62.7353) AS km_altavista_uneg;
-- SELECT * FROM v_tasa_vigente;
-- CALL sp_solicitar_traslado(1,26,21,2,NULL,@id,@msg);
-- SELECT @id AS traslado, @msg AS resultado;
-- ================================================================



-- ============================================================
-- INICIO DE ARCHIVO: migracion_sistema_referidos.sql
-- ============================================================

-- Migración manual para bases de datos ya creadas (no recrear desde cero).
-- Agrega el sistema de referidos: código propio por cliente, cupón de $5 al
-- referente cuando el referido completa su primer viaje pagado, y la opción
-- de agregar el código tardíamente desde el perfil.
-- Ejecutar una sola vez contra la base de datos existente, en orden.

-- 1. Columnas nuevas en cliente. codigo_referido se agrega primero como NULL
--    porque la tabla ya tiene filas (laurap, josecl, marycl, etc.) y MySQL no
--    permite agregar una columna NOT NULL sin DEFAULT sobre una tabla con datos.
ALTER TABLE cliente
  ADD COLUMN codigo_referido VARCHAR(10) NULL,
  ADD COLUMN referido_por INT NULL,
  ADD COLUMN recompensa_referido_otorgada TINYINT(1) NOT NULL DEFAULT 0;

-- 2. Backfill: cada cliente existente recibe un código aleatorio de 8 caracteres.
--    Colisión entre estos pocos clientes de prueba es astronómicamente
--    improbable (espacio de hex de 8 caracteres); si el ALTER del paso 3
--    fallara por una colisión real, basta con volver a correr este UPDATE.
UPDATE cliente
  SET codigo_referido = UPPER(SUBSTRING(MD5(RAND()), 1, 8))
  WHERE codigo_referido IS NULL;

-- 3. Ahora sí, columna obligatoria y única + el FK. IMPORTANTE: el CHECK de
--    "no autoreferencia" NO puede ir en esta misma sentencia (ni en ninguna
--    otra) — MySQL lo rechaza con el error 3823 ("Column 'referido_por'
--    cannot be used in a check constraint ...: needed in a foreign key
--    constraint ... referential action") porque la columna es el lado hijo
--    de un FK con ON DELETE SET NULL. La protección se aplica en el paso 3b
--    con dos triggers en su lugar.
ALTER TABLE cliente
  MODIFY COLUMN codigo_referido VARCHAR(10) NOT NULL UNIQUE,
  ADD CONSTRAINT fk_cliente_referido_por FOREIGN KEY (referido_por) REFERENCES cliente(id) ON DELETE SET NULL;

-- 3b. Protección "no autoreferencia" vía triggers (reemplaza al CHECK del
--     paso 3, que MySQL no permite aquí). BEFORE INSERT es más bien
--     defensivo: con id AUTO_INCREMENT, normalmente no se conoce el propio
--     id todavía en el INSERT, así que la autoreferencia real solo es
--     alcanzable en la práctica vía UPDATE — se cubren ambos casos por
--     completitud.
DROP TRIGGER IF EXISTS trg_cliente_no_autoreferido_insert;
DROP TRIGGER IF EXISTS trg_cliente_no_autoreferido_update;

DELIMITER $$

CREATE TRIGGER trg_cliente_no_autoreferido_insert
BEFORE INSERT ON cliente
FOR EACH ROW
BEGIN
  IF NEW.referido_por IS NOT NULL AND NEW.referido_por = NEW.id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un cliente no puede tener su propio código como referido_por';
  END IF;
END$$

CREATE TRIGGER trg_cliente_no_autoreferido_update
BEFORE UPDATE ON cliente
FOR EACH ROW
BEGIN
  IF NEW.referido_por IS NOT NULL AND NEW.referido_por = NEW.id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un cliente no puede tener su propio código como referido_por';
  END IF;
END$$

DELIMITER ;

-- 4. Nuevo tipo de cupón para la recompensa de referidos.
ALTER TABLE cupon MODIFY tipo ENUM('bienvenida','estudiante','promocional','referido') NOT NULL;

-- 5. Trazabilidad: qué viaje del referido generó cada cupón de recompensa.
ALTER TABLE cupon_cliente
  ADD COLUMN id_traslado_origen INT NULL,
  ADD CONSTRAINT fk_cupon_cliente_traslado FOREIGN KEY (id_traslado_origen) REFERENCES traslado(id);

-- 6. Nuevo tipo de notificación para avisar al referente que ganó su cupón.
ALTER TABLE notificacion MODIFY tipo ENUM(
  'viaje_solicitado','chofer_asignado','chofer_en_camino',
  'chofer_llego','viaje_iniciado','viaje_completado','factura_emitida',
  'pago_recibido','recarga_acreditada','viaje_cancelado','sin_chofer','emergencia',
  'recompensa_referido'
) NOT NULL;

-- 7. Vista de ranking de referentes.
CREATE OR REPLACE VIEW v_top_referentes AS
  SELECT
    r.id                            AS id_referente,
    CONCAT(u.nombre,' ',u.apellido) AS referente,
    COUNT(c.id)                     AS total_referidos
  FROM cliente r
  JOIN usuario u ON r.id_usuario = u.id
  JOIN cliente c ON c.referido_por = r.id
  GROUP BY r.id, u.nombre, u.apellido
  ORDER BY total_referidos DESC;

-- 8. Trigger de recompensa (DROP IF EXISTS por si se re-ejecuta este script).
DROP TRIGGER IF EXISTS trg_recompensa_referido;

DELIMITER $$

CREATE TRIGGER trg_recompensa_referido
AFTER UPDATE ON traslado
FOR EACH ROW
BEGIN
  DECLARE v_id_referente         INT;
  DECLARE v_id_usuario_referente INT;
  DECLARE v_codigo_cupon         VARCHAR(30);
  DECLARE v_id_cupon             INT;
  DECLARE v_filas_marcadas       INT;

  IF NEW.estado = 'completado' AND OLD.estado <> 'completado' AND NEW.costo_cliente_usd > 0 THEN

    SELECT referido_por INTO v_id_referente
      FROM cliente
      WHERE id = NEW.id_cliente;

    IF v_id_referente IS NOT NULL THEN

      UPDATE cliente
        SET recompensa_referido_otorgada = 1
        WHERE id = NEW.id_cliente
          AND recompensa_referido_otorgada = 0;

      SET v_filas_marcadas = ROW_COUNT();

      IF v_filas_marcadas = 1 THEN

        SET v_codigo_cupon = CONCAT('REF-', LPAD(NEW.id, 8, '0'));

        INSERT INTO cupon (codigo, tipo, descuento_usd, distancia_max_km, activo)
        VALUES (v_codigo_cupon, 'referido', 5.00, NULL, 1);

        SET v_id_cupon = LAST_INSERT_ID();

        INSERT INTO cupon_cliente (id_cupon, id_cliente, usado, id_traslado_origen)
        VALUES (v_id_cupon, v_id_referente, 0, NEW.id);

        SELECT u.id INTO v_id_usuario_referente
          FROM cliente cl JOIN usuario u ON cl.id_usuario = u.id
          WHERE cl.id = v_id_referente;

        INSERT INTO notificacion (id_usuario, id_traslado, tipo, mensaje)
        VALUES (v_id_usuario_referente, NEW.id, 'recompensa_referido',
          CONCAT('¡Ganaste un cupón de $5 porque tu referido completó su primer viaje pagado! Código: ', v_codigo_cupon));

      END IF;

    END IF;

  END IF;

END$$

DELIMITER ;



-- ============================================================
-- INICIO DE ARCHIVO: migracion_timeout_reasignacion.sql
-- ============================================================

-- Migración manual para bases de datos ya creadas (no recrear desde cero).
-- Agrega soporte para reasignación automática por timeout de 30s del chofer.
-- Ejecutar una sola vez contra la base de datos existente.

-- 1. Permitir 'sistema' como valor de cancelado_por (antes solo cliente/chofer/empresa;
--    la cancelación automática por agotar los 3 intentos ya usaba 'sistema' en el código
--    pero el ENUM no lo permitía, lo cual fallaba con error SQL).
ALTER TABLE traslado
  MODIFY COLUMN cancelado_por ENUM('cliente','chofer','empresa','sistema') NULL;

-- 2. Nueva columna: fecha en que se asignó el chofer ACTUAL del viaje (se actualiza
--    en cada asignación y reasignación). El timeout de 30s se mide desde aquí, no
--    desde fecha_solicitud, para que cada chofer reasignado tenga su propia ventana
--    completa de 30 segundos.
ALTER TABLE traslado
  ADD COLUMN fecha_asignacion_actual DATETIME NULL AFTER fecha_solicitud;

-- 3. Backfill: para viajes existentes, usar fecha_solicitud como mejor aproximación
--    de cuándo se asignó el chofer actual.
UPDATE traslado
  SET fecha_asignacion_actual = fecha_solicitud
  WHERE fecha_asignacion_actual IS NULL;

-- 4. Índice para que el job de timeout (corre cada pocos segundos) no haga full scan.
CREATE INDEX idx_traslado_estado_asignacion ON traslado(estado, fecha_asignacion_actual);



-- ============================================================
-- INICIO DE ARCHIVO: migracion_uso_cupon_referido.sql
-- ============================================================

-- Migración manual para bases de datos ya creadas (no recrear desde cero).
-- Agrega el piso de $1.00 exclusivo para cupones tipo 'referido' dentro de
-- sp_solicitar_traslado. MySQL no permite ALTER PROCEDURE sobre el cuerpo,
-- así que se hace DROP + CREATE con el procedimiento completo (mismo patrón
-- que trg_recompensa_referido en migracion_sistema_referidos.sql).
-- Ejecutar una sola vez contra la base de datos existente.

DROP PROCEDURE IF EXISTS sp_solicitar_traslado;

DELIMITER $$

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
  -- Piso de tarifa cuando se aplica un cupón de referido: nunca puede dejar
  -- el viaje en $0 (es una promoción de $5, no un viaje gratis). Otros tipos
  -- de cupón (bienvenida, promocional) conservan el piso de $0.00 de siempre.
  DECLARE TARIFA_MIN_CUPON_REFERIDO DECIMAL(8,2) DEFAULT 1.00;

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
  DECLARE v_tipo_cupon      VARCHAR(20);

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
      SELECT c.descuento_usd, c.distancia_max_km, c.tipo
        INTO v_descuento, v_dist_max, v_tipo_cupon
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
      -- Cupón de referido: descuento = MIN(descuento_usd, tarifa - piso).
      -- Los demás tipos (bienvenida, promocional) no pasan por aquí y
      -- conservan el comportamiento genérico de siempre (puede llegar a $0).
      IF v_tipo_cupon = 'referido' THEN
        SET v_descuento = LEAST(IFNULL(v_descuento,0), GREATEST(v_tarifa - TARIFA_MIN_CUPON_REFERIDO, 0.00));
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
  UPDATE chofer  SET disponible = 0 WHERE id = v_id_chofer;

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



-- ============================================================
-- INICIO DE ARCHIVO: migracion_direcciones_libres.sql
-- ============================================================

ALTER TABLE traslado
  ADD COLUMN origen_direccion VARCHAR(255) NULL,
  ADD COLUMN origen_lat DECIMAL(10,7) NULL,
  ADD COLUMN origen_lng DECIMAL(10,7) NULL,
  ADD COLUMN destino_direccion VARCHAR(255) NULL,
  ADD COLUMN destino_lat DECIMAL(10,7) NULL,
  ADD COLUMN destino_lng DECIMAL(10,7) NULL,
  MODIFY COLUMN id_zona_origen INT NULL,
  MODIFY COLUMN id_zona_destino INT NULL;



-- ============================================================
-- INICIO DE ARCHIVO: migracion_ubicacion_chofer.sql
-- ============================================================

ALTER TABLE chofer
  ADD COLUMN lat_actual DECIMAL(10,7) NULL,
  ADD COLUMN lng_actual DECIMAL(10,7) NULL,
  ADD COLUMN ubicacion_actualizada_en DATETIME NULL;



-- ============================================================
-- INICIO DE ARCHIVO: migracion_charset_v_ganancias_empresa.sql
-- ============================================================

-- ================================================================
--  Fix de charset: v_ganancias_empresa quedó creada con
--  character_set_client = cp850 (codepage de Windows, típico de
--  quien la corrió desde cmd.exe sin especificar charset) — todas
--  las demás vistas y rutinas de esta BD ya son utf8mb4. Se
--  recrea con la misma lógica exacta, solo cambia el charset con
--  el que MySQL registra la definición.
--
--  IMPORTANTE: correr este archivo con el cliente en utf8mb4, ej.:
--    mysql --default-character-set=utf8mb4 -u root -p decarrerita < migracion_charset_v_ganancias_empresa.sql
--  (en Workbench, la conexión ya usa utf8mb4 por defecto — no
--  hace falta nada especial ahí).
--
--  sp_solicitar_traslado ya quedó en utf8mb4 al recrearse hoy para
--  el cambio de "vehículo en uso" — verificado, no necesita otra
--  pasada.
-- ================================================================

CREATE OR REPLACE VIEW v_ganancias_empresa AS
  SELECT
    t.id                         AS id_traslado,
    DATE(t.fecha_solicitud)      AS fecha,
    (t.costo_cliente_usd + t.descuento_usd) AS costo_total_usd,
    t.descuento_usd              AS descuento_usd,
    t.monto_empresa_usd          AS total_empresa_usd,
    (t.monto_empresa_usd * tb.tasa_ves) AS total_empresa_ves,
    IF(t.descuento_usd > 0, 'Viaje con descuento', 'Viaje regular') AS concepto
  FROM traslado t
  JOIN tasa_bcv tb ON t.id_tasa = tb.id
  WHERE t.estado = 'completado'
  ORDER BY t.fecha_solicitud DESC;



-- ============================================================
-- INICIO DE ARCHIVO: migracion_drop_v_top_referentes.sql
-- ============================================================

-- ================================================================
--  v_top_referentes: vista huérfana, sin consumidor en el código
--  (ni Java ni frontend) — confirmado por grep antes de eliminarla.
--  Ver propuesta_v_top_referentes.md.
-- ================================================================

DROP VIEW v_top_referentes;



-- ============================================================
-- INICIO DE ARCHIVO: migracion_min_contactos_emergencia.sql
-- ============================================================

-- ================================================================
--  Migración: exactamente 2 contactos de emergencia para habilitar chofer
--  Ver propuesta_minimo_2_contactos_emergencia.md, sección 2 (Opción A) y 5.2.a.
--  Bloquea el paso chofer.habilitado 0 -> 1 si el chofer no tiene
--  exactamente 2 filas en contacto_emergencia. No afecta el alta
--  incremental de contactos (INSERT/UPDATE/DELETE libres mientras
--  habilitado siga en 0).
-- ================================================================

DROP TRIGGER IF EXISTS trg_chofer_min_contactos;

DELIMITER $$
CREATE TRIGGER trg_chofer_min_contactos
BEFORE UPDATE ON chofer
FOR EACH ROW
BEGIN
  IF NEW.habilitado = 1 AND OLD.habilitado = 0 THEN
    IF (SELECT COUNT(*) FROM contacto_emergencia WHERE id_chofer = NEW.id) <> 2 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No se puede habilitar al chofer: requiere exactamente 2 contactos de emergencia.';
    END IF;
  END IF;
END$$
DELIMITER ;

-- ================================================================
--  Opción B (ver propuesta_minimo_2_contactos_emergencia.md, sección 2):
--  protege el otro lado del ciclo de vida — un chofer YA habilitado no
--  puede quedar por debajo de 2 contactos al borrar uno. Se dispara
--  AFTER DELETE porque en ese momento el conteo ya refleja el estado
--  final de la fila borrada (a diferencia de un AFTER INSERT, que
--  rompería el alta incremental — ver Opción A descartada en la propuesta).
-- ================================================================

DROP TRIGGER IF EXISTS trg_contacto_no_bajar_de_2;

DELIMITER $$
CREATE TRIGGER trg_contacto_no_bajar_de_2
AFTER DELETE ON contacto_emergencia
FOR EACH ROW
BEGIN
  IF (SELECT habilitado FROM chofer WHERE id = OLD.id_chofer) = 1
     AND (SELECT COUNT(*) FROM contacto_emergencia WHERE id_chofer = OLD.id_chofer) < 2 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'No se puede eliminar: el chofer habilitado debe mantener mínimo 2 contactos de emergencia.';
  END IF;
END$$
DELIMITER ;



-- ============================================================
-- INICIO DE ARCHIVO: migracion_vehiculo_en_uso.sql
-- ============================================================

-- ================================================================
--  Migración: soporte real de varios vehículos por chofer
--  Ver recomendacion_diseno_vehiculo_en_uso.md — Opción 2 completa.
--
--  Antes de esta migración, un chofer solo podía tener 1 vehículo
--  (restricción a nivel de aplicación). sp_solicitar_traslado.sql
--  asume esa cardinalidad en su JOIN a `vehiculo` (línea 239 del
--  archivo fuente) — por eso la columna `en_uso` se agrega con
--  garantía de unicidad a nivel de BD, y con backfill inmediato,
--  en ese orden exacto, antes de tocar el procedimiento.
--
--  Nota de implementación: el plan original era una columna
--  generada STORED (en_uso_unico) + UNIQUE KEY sobre ella. Al
--  aplicarlo contra la tabla real, MySQL 8.0.46 devolvió
--  "ERROR 1215: Cannot add foreign key constraint" de forma
--  consistente (reproducido y aislado en tablas de prueba con
--  estructura equivalente sin la combinación exacta de FK saliente
--  + FK entrantes que tiene `vehiculo` en la BD real — no se logró
--  aislar la causa raíz exacta dentro del tiempo disponible). Se
--  optó por un ÍNDICE FUNCIONAL de MySQL 8 (expresión directa en el
--  índice, sin columna física intermedia) — misma garantía exacta
--  (NULL cuando en_uso=0, valor único de id_chofer cuando en_uso=1),
--  probado y funcionando: un INSERT/UPDATE que intente un segundo
--  vehículo en_uso=1 para el mismo chofer es rechazado con
--  "ERROR 1062: Duplicate entry ... for key
--  'vehiculo.uq_vehiculo_en_uso_por_chofer'".
-- ================================================================

ALTER TABLE vehiculo
  ADD COLUMN en_uso TINYINT(1) NOT NULL DEFAULT 0;

ALTER TABLE vehiculo
  ADD UNIQUE KEY uq_vehiculo_en_uso_por_chofer ((CASE WHEN en_uso = 1 THEN id_chofer END));

-- Backfill: hoy cada chofer tiene como máximo 1 vehículo (restricción
-- que se está levantando), así que este UPDATE es 100% determinista —
-- no hay ambigüedad de cuál vehículo marcar como en uso.
UPDATE vehiculo SET en_uso = 1;



-- ============================================================
-- INICIO DE ARCHIVO: migracion_vistas_reporte_direcciones_libres.sql
-- ============================================================

-- ================================================================
--  Migración: vistas de reporte a LEFT JOIN + COALESCE
--  Parte A del plan de direcciones libres (Plan_Migracion_Google_Places_
--  Propuesta.docx, sección 5.1): con id_zona_origen/id_zona_destino ahora
--  nullable (migracion_direcciones_libres.sql), las 3 vistas de reporte que
--  siguen usando INNER JOIN sobre zona pierden silenciosamente cualquier
--  viaje que use dirección libre en vez de zona. Se recrean con LEFT JOIN +
--  COALESCE(zona.nombre, direccion_libre) — mismo patrón ya usado en
--  InvoiceRepository.findInvoiceDataByTripId (columnas zonaOrigen/zonaDestino).
--  No destructivo: CREATE OR REPLACE VIEW, no se borra ninguna vista.
-- ================================================================

CREATE OR REPLACE VIEW v_historial_traslados AS
  SELECT t.id, t.id_cliente,
    CONCAT(u_cl.nombre,' ',u_cl.apellido) AS cliente,
    CONCAT(u_ch.nombre,' ',u_ch.apellido) AS chofer,
    veh.placa, veh.marca, veh.modelo, veh.color,
    COALESCE(zo.nombre, t.origen_direccion)  AS zona_origen,
    COALESCE(zd.nombre, t.destino_direccion) AS zona_destino,
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
  LEFT JOIN zona zo ON t.id_zona_origen  = zo.id
  LEFT JOIN zona zd ON t.id_zona_destino = zd.id;

CREATE OR REPLACE VIEW v_traslados_cancelados AS
  SELECT t.id,
    CONCAT(u_cl.nombre,' ',u_cl.apellido) AS cliente,
    CONCAT(u_ch.nombre,' ',u_ch.apellido) AS chofer,
    COALESCE(zo.nombre, t.origen_direccion)  AS zona_origen,
    COALESCE(zd.nombre, t.destino_direccion) AS zona_destino,
    t.cancelado_por,
    t.motivo_cancelacion,
    t.fecha_solicitud
  FROM traslado t
  JOIN cliente  cl  ON t.id_cliente  = cl.id
  JOIN usuario  u_cl ON cl.id_usuario = u_cl.id
  JOIN chofer   ch  ON t.id_chofer   = ch.id
  JOIN usuario  u_ch ON ch.id_usuario = u_ch.id
  LEFT JOIN zona zo ON t.id_zona_origen  = zo.id
  LEFT JOIN zona zd ON t.id_zona_destino = zd.id
  WHERE t.estado = 'cancelado';

CREATE OR REPLACE VIEW v_facturas_emitidas AS
  SELECT
    f.id, f.nro_documento, f.nro_control, f.serie, f.fecha_emision,
    f.razon_social, f.rif_cedula,
    t.costo_cliente_usd  AS monto_usd,
    t.costo_cliente_ves  AS monto_ves,
    f.igtf_monto_usd,
    COALESCE(zo.nombre, t.origen_direccion)  AS zona_origen,
    COALESCE(zd.nombre, t.destino_direccion) AS zona_destino
  FROM factura f
  JOIN traslado t ON f.id_traslado = t.id
  LEFT JOIN zona zo ON t.id_zona_origen  = zo.id
  LEFT JOIN zona zd ON t.id_zona_destino = zd.id
  ORDER BY f.fecha_emision DESC;



-- ============================================================
-- INICIO DE ARCHIVO: migracion_vehiculo_en_uso_reversion.sql
-- ============================================================

-- ================================================================
--  Reversión de migracion_vehiculo_en_uso.sql
--  Solo usar si hace falta deshacer el cambio de "vehículo en uso".
--  Recordar revertir también la línea del JOIN en
--  sp_solicitar_traslado.sql:239 (quitar "AND v.en_uso = 1") ANTES
--  de correr esto, en el mismo orden inverso en que se aplicó.
-- ================================================================

ALTER TABLE vehiculo
  DROP KEY uq_vehiculo_en_uso_por_chofer,
  DROP COLUMN en_uso;



-- ============================================================
-- INICIO DE ARCHIVO: Tabla_Incidentes.sql
-- ============================================================

CREATE TABLE incidente (
  id                  INT           AUTO_INCREMENT PRIMARY KEY,
  id_usuario_reporta  INT           NOT NULL,
  id_traslado         INT           NULL,
  mensaje             VARCHAR(255)  NOT NULL,
  estado              ENUM('abierto', 'en_proceso', 'cerrado') NOT NULL DEFAULT 'abierto',
  notas_resolucion    TEXT          NULL,
  id_admin_cierra     INT           NULL,
  fecha_creacion      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_cierre        DATETIME      NULL,
  CONSTRAINT fk_inc_usuario_rep FOREIGN KEY (id_usuario_reporta) REFERENCES usuario(id) ON DELETE CASCADE,
  CONSTRAINT fk_inc_traslado    FOREIGN KEY (id_traslado)        REFERENCES traslado(id) ON DELETE CASCADE,
  CONSTRAINT fk_inc_admin       FOREIGN KEY (id_admin_cierra)    REFERENCES usuario(id) ON DELETE SET NULL
);


-- ============================================================
-- INICIO DE ARCHIVO: migracion_incidentes.sql
-- ============================================================

-- ================================================================
--  Migración: entidad Incidente para el flujo de emergencia
--  El botón de emergencia (cliente/chofer) ya enviaba una Notification
--  por cada admin/personal_admin, pero no existía ningún caso con estado
--  que el admin pudiera tomar y cerrar. Esta tabla agrega ese seguimiento
--  mínimo: un Incidente por evento de emergencia reportado (no uno por
--  cada Notification generada, ya que sendEmergencyAlert crea una por
--  cada admin activo).
-- ================================================================

DROP TABLE IF EXISTS `incidente`;

CREATE TABLE `incidente` (
  `id` int NOT NULL AUTO_INCREMENT,
  `id_usuario_reporta` int NOT NULL,
  `id_traslado` int DEFAULT NULL,
  `mensaje` varchar(200) NOT NULL,
  `estado` enum('abierto','en_proceso','cerrado') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'abierto',
  `notas_resolucion` varchar(300) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `id_admin_cierra` int DEFAULT NULL,
  `fecha_creacion` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `fecha_cierre` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_incidente_usuario` (`id_usuario_reporta`),
  KEY `fk_incidente_traslado` (`id_traslado`),
  KEY `fk_incidente_admin_cierra` (`id_admin_cierra`),
  CONSTRAINT `fk_incidente_usuario` FOREIGN KEY (`id_usuario_reporta`) REFERENCES `usuario` (`id`),
  CONSTRAINT `fk_incidente_traslado` FOREIGN KEY (`id_traslado`) REFERENCES `traslado` (`id`),
  CONSTRAINT `fk_incidente_admin_cierra` FOREIGN KEY (`id_admin_cierra`) REFERENCES `usuario` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;



-- ============================================================
-- INICIO DE ARCHIVO: migracion_token_revocado.sql
-- ============================================================

-- ================================================================
--  Migración: tabla token_revocado
--  Persiste la lista negra de JWT revocados que antes vivía solo
--  en memoria (ConcurrentHashMap). Tras esta migración, los tokens
--  revocados sobreviven reinicios del servidor.
-- ================================================================

USE decarrerita;

CREATE TABLE IF NOT EXISTS token_revocado (
  token       VARCHAR(512) NOT NULL PRIMARY KEY,
  revocado_en DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;



-- ============================================================
-- INICIO DE ARCHIVO: actualizacion_bd.sql
-- ============================================================

-- ================================================================
-- Script de Migración
-- Ejecutar en la base de datos `decarrerita` para aplicar
-- los últimos cambios sin tener que borrar los datos actuales.
-- ================================================================

-- 1. Crear tabla incidente (Faltaba en la BD para el botón SOS)
CREATE TABLE IF NOT EXISTS incidente (
  id                  INT           AUTO_INCREMENT PRIMARY KEY,
  id_usuario_reporta  INT           NOT NULL,
  id_traslado         INT           NULL,
  mensaje             VARCHAR(255)  NOT NULL,
  estado              ENUM('abierto', 'en_proceso', 'cerrado') NOT NULL DEFAULT 'abierto',
  notas_resolucion    TEXT          NULL,
  id_admin_cierra     INT           NULL,
  fecha_creacion      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_cierre        DATETIME      NULL,
  CONSTRAINT fk_inc_usuario_rep FOREIGN KEY (id_usuario_reporta) REFERENCES usuario(id) ON DELETE CASCADE,
  CONSTRAINT fk_inc_traslado    FOREIGN KEY (id_traslado)        REFERENCES traslado(id) ON DELETE CASCADE,
  CONSTRAINT fk_inc_admin       FOREIGN KEY (id_admin_cierra)    REFERENCES usuario(id) ON DELETE SET NULL
);

-- 2. Crear tabla catalogo_banco (Para lista dinámica del Frontend)
CREATE TABLE IF NOT EXISTS catalogo_banco (
  codigo_bcv  VARCHAR(4)    PRIMARY KEY,
  nombre      VARCHAR(100)  NOT NULL
);

-- 3. Insertar datos en catalogo_banco (Ignora si ya existen)
INSERT IGNORE INTO catalogo_banco (nombre, codigo_bcv) VALUES
  ('Banesco', '0134'),
  ('Banco Mercantil', '0105'),
  ('BBVA Provincial', '0108'),
  ('BNC', '0191'),
  ('Bancamiga', '0172'),
  ('Bancaribe', '0114'),
  ('Banco Exterior', '0115'),
  ('Banplus', '0174'),
  ('BFC', '0151'),
  ('Banco Plaza', '0138'),
  ('Banco Caroní', '0128'),
  ('DELSUR', '0157'),
  ('Banco Activo', '0171'),
  ('Sofitasa', '0137'),
  ('100% Banco', '0156'),
  ('BVC', '0104'),
  ('Bancrecer', '0168'),
  ('BDV', '0102'),
  ('BDT', '0175'),
  ('Banco del Tesoro', '0163'),
  ('BAV', '0166'),
  ('BANFANB', '0177');

-- 4. Actualizar códigos antiguos en tabla banco por los verdaderos códigos BCV
UPDATE banco SET codigo_bcv = '0102' WHERE codigo_bcv = 'BDV';
UPDATE banco SET codigo_bcv = '0134' WHERE codigo_bcv = 'BAN';
UPDATE banco SET codigo_bcv = '0105' WHERE codigo_bcv = 'MER';
UPDATE banco SET codigo_bcv = '0108' WHERE codigo_bcv = 'BBV';
UPDATE banco SET codigo_bcv = '0175' WHERE codigo_bcv = 'BIC';
UPDATE banco SET codigo_bcv = '0163' WHERE codigo_bcv = 'BTU';
UPDATE banco SET codigo_bcv = '0115' WHERE codigo_bcv = 'BEX';
UPDATE banco SET codigo_bcv = '0114' WHERE codigo_bcv = 'BCB';
UPDATE banco SET codigo_bcv = '0191' WHERE codigo_bcv = 'BNC';
UPDATE banco SET codigo_bcv = '0138' WHERE codigo_bcv = 'BPZ';
UPDATE banco SET codigo_bcv = '0151' WHERE codigo_bcv = 'BFC';



-- ============================================================
-- INICIO DE ARCHIVO: sp_solicitar_traslado.sql
-- ============================================================




-- ============================================================
-- INICIO DE ARCHIVO: migracion_v2.sql
-- ============================================================

-- ==============================================================================
-- SCRIPT DE MIGRACIÓN (V2) - CORREGIDO PARA DIRECCIONES LIBRES
-- ==============================================================================
USE decarrerita;

-- 1. Actualizar estructura de Estado en la tabla traslado para soportar 'buscando'
ALTER TABLE traslado MODIFY COLUMN estado ENUM('buscando', 'solicitado', 'aceptado', 'en_camino', 'chofer_llego', 'en_progreso', 'completado', 'cancelado') NOT NULL DEFAULT 'buscando';

-- 2. Modificar sp_solicitar_traslado (CON SOPORTE PARA DIRECCIONES LIBRES Y ESTADO BUSCANDO)
DROP PROCEDURE IF EXISTS sp_solicitar_traslado;
DELIMITER $$
CREATE PROCEDURE sp_solicitar_traslado(
  IN  p_id_cliente         INT,
  IN  p_id_zona_origen     INT,       -- Nullable, kept for backward compatibility
  IN  p_id_zona_destino    INT,       -- Nullable, kept for backward compatibility
  IN  p_origen_direccion   VARCHAR(255),
  IN  p_origen_lat         DECIMAL(10,7),
  IN  p_origen_lng         DECIMAL(10,7),
  IN  p_destino_direccion  VARCHAR(255),
  IN  p_destino_lat        DECIMAL(10,7),
  IN  p_destino_lng        DECIMAL(10,7),
  IN  p_nro_pasajeros      INT,
  IN  p_id_cupon_cliente   INT,
  OUT p_id_traslado        INT,
  OUT p_mensaje            VARCHAR(300)
)
sp_solicitar_traslado: BEGIN
  DECLARE TARIFA_BASE      DECIMAL(8,2)  DEFAULT 1.00;
  DECLARE COSTO_KM         DECIMAL(8,4)  DEFAULT 0.45;
  DECLARE RECARGO_ESP      DECIMAL(8,2)  DEFAULT 1.50;
  DECLARE RADIO_1          DECIMAL(5,1)  DEFAULT 5.0;
  DECLARE RADIO_2          DECIMAL(5,1)  DEFAULT 10.0;
  DECLARE RADIO_3          DECIMAL(5,1)  DEFAULT 15.0;
  DECLARE TARIFA_MIN_CUPON_REFERIDO DECIMAL(8,2) DEFAULT 1.00;
  DECLARE DISTANCIA_MAX_PRIMER_VIAJE DECIMAL(5,1) DEFAULT 15.0;

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
  
  -- Driver-specific matching variables
  DECLARE v_id_chofer      INT;
  DECLARE v_id_vehiculo    INT;
  DECLARE v_id_zona_chofer INT;
  DECLARE v_chofer_lat     DECIMAL(10,7);
  DECLARE v_chofer_lng     DECIMAL(10,7);
  
  DECLARE v_radio          DECIMAL(5,1);
  DECLARE v_id_zona_dest    INT;
  DECLARE v_desc_estudiante DECIMAL(8,2)  DEFAULT 0.00;
  DECLARE v_tarifa_original DECIMAL(10,2) DEFAULT 0.00;
  DECLARE v_tipo_cupon      VARCHAR(20);
  
  -- VARIABLES PARA EL ESTADO BUSCANDO
  DECLARE v_estado VARCHAR(20) DEFAULT 'solicitado';
  DECLARE v_eta_minutos INT DEFAULT NULL;

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
       AND estado IN ('buscando','solicitado','aceptado','en_camino','chofer_llego','en_progreso')
  ) THEN
    SET p_mensaje = 'ERROR: Ya tienes un viaje activo en curso.';
    SET p_id_traslado = NULL;
    LEAVE sp_solicitar_traslado;
  END IF;

  -- Resolving origin coordinates: GPS inputs first, fallback to Zone Table
  IF p_origen_lat IS NOT NULL AND p_origen_lng IS NOT NULL THEN
    SET v_lat1 = p_origen_lat;
    SET v_lon1 = p_origen_lng;
  ELSEIF p_id_zona_origen IS NOT NULL THEN
    SELECT latitud, longitud INTO v_lat1, v_lon1
      FROM zona WHERE id = p_id_zona_origen;
  END IF;

  -- Resolving destination coordinates: GPS inputs first, fallback to Zone Table
  IF p_destino_lat IS NOT NULL AND p_destino_lng IS NOT NULL THEN
    SET v_lat2 = p_destino_lat;
    SET v_lon2 = p_destino_lng;
  ELSEIF p_id_zona_destino IS NOT NULL THEN
    SELECT latitud, longitud INTO v_lat2, v_lon2
      FROM zona WHERE id = p_id_zona_destino;
  END IF;

  -- Verify coordinates are resolved
  IF v_lat1 IS NULL OR v_lon1 IS NULL OR v_lat2 IS NULL OR v_lon2 IS NULL THEN
    SET p_mensaje = 'ERROR: No se pudieron determinar las coordenadas de origen o destino.';
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
  ELSE
    -- Factor hora pico (solo si no es nocturno o fin de semana)
    IF    v_hora >= 7  AND v_hora < 9  THEN SET v_factor = 1.20;
    ELSEIF v_hora >= 11 AND v_hora < 13 THEN SET v_factor = 1.15;
    ELSEIF v_hora >= 17 AND v_hora < 19 THEN SET v_factor = 1.25;
    END IF;
  END IF;
  SET v_tarifa = v_tarifa * v_factor;
  SET v_tarifa_original = v_tarifa;

  -- Tipo de cliente
  SELECT es_estudiante, primer_viaje_usado
    INTO v_es_est, v_primer
    FROM cliente WHERE id = p_id_cliente;

  -- Descuento estudiantil (zona origen O destino = sede universitaria)
  IF v_es_est = 1 THEN
    SET v_id_zona_dest = NULL;
    
    -- Option A: Check direct zone IDs if they were provided
    IF p_id_zona_origen IS NOT NULL OR p_id_zona_destino IS NOT NULL THEN
      SELECT id INTO v_id_zona_dest FROM zona
       WHERE id IN (p_id_zona_origen, p_id_zona_destino)
         AND nombre IN ('UNEG Sede Atlántico','UNEG Sede Villa Asia','UNEXPO')
       LIMIT 1;
    END IF;

    -- Option B: Fallback check if coordinates are within 0.3 km of a university zone
    IF v_id_zona_dest IS NULL THEN
      SELECT id INTO v_id_zona_dest FROM zona
       WHERE nombre IN ('UNEG Sede Atlántico','UNEG Sede Villa Asia','UNEXPO')
         AND (fn_distancia_km(latitud, longitud, v_lat1, v_lon1) <= 0.3
              OR fn_distancia_km(latitud, longitud, v_lat2, v_lon2) <= 0.3)
       LIMIT 1;
    END IF;

    IF v_id_zona_dest IS NOT NULL THEN
      SET v_desc_estudiante = ROUND(v_tarifa * 0.30, 2);
      SET v_tarifa          = ROUND(v_tarifa * 0.70, 2);
    END IF;
  END IF;

  -- Primer viaje gratis (sujeto al tope de distancia DISTANCIA_MAX_PRIMER_VIAJE)
  IF v_primer = 0 AND v_dist_km <= DISTANCIA_MAX_PRIMER_VIAJE THEN
    SET v_descuento   = v_tarifa;
    SET v_costo_cli   = 0.00;
  ELSE
    -- Cupón de descuento
    IF p_id_cupon_cliente IS NOT NULL THEN
      SELECT c.descuento_usd, c.distancia_max_km, c.tipo
        INTO v_descuento, v_dist_max, v_tipo_cupon
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
      -- Cupón de referido: descuento = MIN(descuento_usd, tarifa - piso).
      IF v_tipo_cupon = 'referido' THEN
        SET v_descuento = LEAST(IFNULL(v_descuento,0), GREATEST(v_tarifa - TARIFA_MIN_CUPON_REFERIDO, 0.00));
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

  -- Tasa BCV vigente
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

  SET v_monto_ch  = ROUND(v_tarifa_original * 0.70, 2);
  SET v_monto_emp = GREATEST(ROUND((v_tarifa_original * 0.30) - v_desc_estudiante - IFNULL(v_descuento,0), 2), 0.00);
  SET v_costo_ves = ROUND(v_costo_cli * v_tasa_ves, 2);

  -- Asignación por proximidad (radio 5 → 10 → 15 km)
  SET v_id_chofer = NULL;
  SET v_radio = RADIO_1;
  WHILE v_id_chofer IS NULL AND v_radio <= RADIO_3 DO
    -- Select closest qualified active driver using coordinate logic with zone fallback
    SELECT c.id, v.id, c.id_zona_actual,
           -- Driver Latitud Fallback
           IF(c.lat_actual IS NOT NULL AND c.lng_actual IS NOT NULL AND c.ubicacion_actualizada_en >= NOW() - INTERVAL 60 MINUTE, c.lat_actual, zo.latitud),
           -- Driver Longitud Fallback
           IF(c.lat_actual IS NOT NULL AND c.lng_actual IS NOT NULL AND c.ubicacion_actualizada_en >= NOW() - INTERVAL 60 MINUTE, c.lng_actual, zo.longitud)
      INTO v_id_chofer, v_id_vehiculo, v_id_zona_chofer, v_chofer_lat, v_chofer_lng
      FROM chofer c
      LEFT JOIN zona zo ON zo.id = c.id_zona_actual
      JOIN vehiculo v ON v.id_chofer = c.id AND v.activo = 1 AND v.en_uso = 1
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
       AND (
         (c.lat_actual IS NOT NULL AND c.lng_actual IS NOT NULL AND c.ubicacion_actualizada_en >= NOW() - INTERVAL 60 MINUTE)
         OR (c.id_zona_actual IS NOT NULL AND zo.id IS NOT NULL)
       )
       AND fn_distancia_km(
         IF(c.lat_actual IS NOT NULL AND c.lng_actual IS NOT NULL AND c.ubicacion_actualizada_en >= NOW() - INTERVAL 60 MINUTE, c.lat_actual, zo.latitud),
         IF(c.lat_actual IS NOT NULL AND c.lng_actual IS NOT NULL AND c.ubicacion_actualizada_en >= NOW() - INTERVAL 60 MINUTE, c.lng_actual, zo.longitud),
         v_lat1,
         v_lon1
       ) <= v_radio
     ORDER BY RAND()
     LIMIT 1;

    IF v_id_chofer IS NULL THEN
      SET v_radio = v_radio + 5.0;
    END IF;
  END WHILE;

  IF v_id_chofer IS NULL THEN
    SET v_estado = 'buscando';
  ELSE
    SET v_eta_minutos = CEILING(fn_distancia_km(v_chofer_lat, v_chofer_lng, v_lat1, v_lon1) / 30 * 60);
  END IF;

  -- Registrar traslado
  INSERT INTO traslado (
    id_cliente, id_chofer, id_vehiculo,
    id_zona_origen, id_zona_destino, id_tasa, id_cupon_cliente,
    origen_direccion, origen_lat, origen_lng,
    destino_direccion, destino_lat, destino_lng,
    nro_pasajeros, distancia_km, tarifa_base_usd,
    recargo_horario_usd, factor_hora_pico, descuento_usd,
    costo_cliente_usd, monto_chofer_usd, monto_empresa_usd,
    costo_cliente_ves, estado,
    eta_minutos, fecha_solicitud
  ) VALUES (
    p_id_cliente, v_id_chofer, v_id_vehiculo,
    p_id_zona_origen, p_id_zona_destino, v_id_tasa, p_id_cupon_cliente,
    p_origen_direccion, v_lat1, v_lon1,
    p_destino_direccion, v_lat2, v_lon2,
    p_nro_pasajeros, v_dist_km, v_tarifa,
    v_recargo, v_factor, v_desc_estudiante + IFNULL(v_descuento,0),
    v_costo_cli, v_monto_ch, v_monto_emp,
    v_costo_ves, v_estado,
    v_eta_minutos, NOW()
  );
  SET p_id_traslado = LAST_INSERT_ID();

  -- Actualizar saldos y disponibilidad del chofer
  UPDATE cliente SET saldo_usd = saldo_usd - v_costo_cli WHERE id = p_id_cliente;
  
  IF v_id_chofer IS NOT NULL THEN
    UPDATE chofer  SET disponible = 0 WHERE id = v_id_chofer;
  END IF;

  -- Marcar cupón y primer viaje
  IF p_id_cupon_cliente IS NOT NULL THEN
    UPDATE cupon_cliente SET usado = 1, fecha_uso = NOW()
     WHERE id = p_id_cupon_cliente;
  END IF;
  IF v_primer = 0 AND v_dist_km <= DISTANCIA_MAX_PRIMER_VIAJE THEN
    UPDATE cliente SET primer_viaje_usado = 1 WHERE id = p_id_cliente;
  END IF;

  IF v_estado = 'buscando' THEN
    SET p_mensaje = CONCAT(IFNULL(p_mensaje,''), 'OK: Traslado #', p_id_traslado, ' (Buscando chofer)');
  ELSE
    SET p_mensaje = CONCAT(IFNULL(p_mensaje,''),
      'OK: Traslado #', p_id_traslado,
      ' | Dist: ', v_dist_km, ' km',
      ' | Pasajeros: ', p_nro_pasajeros,
      ' | Costo: $', v_costo_cli, ' USD',
      ' | Tasa: ', v_tasa_ves, ' Bs',
      ' | Equivalente: ', v_costo_ves, ' Bs');
  END IF;

END$$
DELIMITER ;

-- 3. Crear SP para buscar chofer en segundo plano
DROP PROCEDURE IF EXISTS sp_buscar_chofer_viaje;
DELIMITER $$
CREATE PROCEDURE sp_buscar_chofer_viaje(
  IN p_id_traslado INT,
  OUT p_id_chofer INT
)
sp_buscar_chofer_viaje: BEGIN
  DECLARE RADIO_1 DECIMAL(5,1) DEFAULT 5.0;
  DECLARE RADIO_2 DECIMAL(5,1) DEFAULT 10.0;
  DECLARE RADIO_3 DECIMAL(5,1) DEFAULT 15.0;
  DECLARE v_radio DECIMAL(5,1) DEFAULT RADIO_1;

  DECLARE v_lat1 DECIMAL(10,7);
  DECLARE v_lon1 DECIMAL(10,7);
  DECLARE v_id_zona_chofer INT;
  DECLARE v_id_vehiculo INT;
  DECLARE v_eta_minutos INT;
  
  DECLARE v_chofer_lat DECIMAL(10,7);
  DECLARE v_chofer_lng DECIMAL(10,7);

  SET p_id_chofer = NULL;

  -- Obtener origen del viaje
  SELECT 
    IF(origen_lat IS NOT NULL AND origen_lng IS NOT NULL, origen_lat, (SELECT latitud FROM zona WHERE id = t.id_zona_origen)),
    IF(origen_lat IS NOT NULL AND origen_lng IS NOT NULL, origen_lng, (SELECT longitud FROM zona WHERE id = t.id_zona_origen))
    INTO v_lat1, v_lon1
    FROM traslado t
   WHERE t.id = p_id_traslado AND t.estado = 'buscando';

  IF v_lat1 IS NULL THEN
    LEAVE sp_buscar_chofer_viaje;
  END IF;

  WHILE p_id_chofer IS NULL AND v_radio <= RADIO_3 DO
    SELECT c.id, v.id, c.id_zona_actual,
           IF(c.lat_actual IS NOT NULL AND c.lng_actual IS NOT NULL AND c.ubicacion_actualizada_en >= NOW() - INTERVAL 60 MINUTE, c.lat_actual, zo.latitud),
           IF(c.lat_actual IS NOT NULL AND c.lng_actual IS NOT NULL AND c.ubicacion_actualizada_en >= NOW() - INTERVAL 60 MINUTE, c.lng_actual, zo.longitud)
      INTO p_id_chofer, v_id_vehiculo, v_id_zona_chofer, v_chofer_lat, v_chofer_lng
      FROM chofer c
      LEFT JOIN zona  zo ON zo.id = c.id_zona_actual
      JOIN vehiculo v ON v.id_chofer = c.id AND v.activo = 1 AND v.en_uso = 1
      JOIN (SELECT id_chofer FROM evaluacion_psicologica WHERE aprobado = 1 AND fecha_eval >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR) GROUP BY id_chofer) ep ON ep.id_chofer = c.id
      JOIN (SELECT id_vehiculo FROM revision_vehiculo WHERE apto = 1 AND fecha_revision >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR) GROUP BY id_vehiculo) rv ON rv.id_vehiculo = v.id
     WHERE c.habilitado = 1
       AND c.disponible = 1
       AND (
         (c.lat_actual IS NOT NULL AND c.lng_actual IS NOT NULL AND c.ubicacion_actualizada_en >= NOW() - INTERVAL 60 MINUTE)
         OR (c.id_zona_actual IS NOT NULL AND zo.id IS NOT NULL)
       )
       AND fn_distancia_km(
         IF(c.lat_actual IS NOT NULL AND c.lng_actual IS NOT NULL AND c.ubicacion_actualizada_en >= NOW() - INTERVAL 60 MINUTE, c.lat_actual, zo.latitud),
         IF(c.lat_actual IS NOT NULL AND c.lng_actual IS NOT NULL AND c.ubicacion_actualizada_en >= NOW() - INTERVAL 60 MINUTE, c.lng_actual, zo.longitud),
         v_lat1, v_lon1
       ) <= v_radio
     ORDER BY RAND()
     LIMIT 1;

    IF p_id_chofer IS NULL THEN
      SET v_radio = v_radio + 5.0;
    END IF;
  END WHILE;

  IF p_id_chofer IS NOT NULL THEN
    SET v_eta_minutos = CEILING(fn_distancia_km(v_chofer_lat, v_chofer_lng, v_lat1, v_lon1) / 30 * 60);

    UPDATE traslado 
       SET id_chofer = p_id_chofer,
           id_vehiculo = v_id_vehiculo,
           estado = 'solicitado',
           eta_minutos = v_eta_minutos,
           fecha_asignacion_actual = NOW()
     WHERE id = p_id_traslado;

    UPDATE chofer SET disponible = 0 WHERE id = p_id_chofer;
  END IF;

END$$
DELIMITER ;

-- 4. Actualizar tabla banco para usar Códigos BCV reales
UPDATE banco SET codigo_bcv = '0102' WHERE nombre LIKE '%Venezuela%';
UPDATE banco SET codigo_bcv = '0134' WHERE nombre LIKE '%Banesco%';
UPDATE banco SET codigo_bcv = '0105' WHERE nombre LIKE '%Mercantil%';
UPDATE banco SET codigo_bcv = '0108' WHERE nombre LIKE '%Provincial%';
UPDATE banco SET codigo_bcv = '0175' WHERE nombre LIKE '%Bicentenario%';
UPDATE banco SET codigo_bcv = '0163' WHERE nombre LIKE '%Tesoro%';
UPDATE banco SET codigo_bcv = '0115' WHERE nombre LIKE '%Exterior%';
UPDATE banco SET codigo_bcv = '0114' WHERE nombre LIKE '%Bancaribe%';
UPDATE banco SET codigo_bcv = '0191' WHERE nombre LIKE '%BNC%';
UPDATE banco SET codigo_bcv = '0138' WHERE nombre LIKE '%Plaza%';
UPDATE banco SET codigo_bcv = '0151' WHERE nombre LIKE '%BFC%';

-- 5. Crear tabla catalogo_banco si no existe y poblarla
CREATE TABLE IF NOT EXISTS catalogo_banco (
  codigo_bcv VARCHAR(4) PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL
);
INSERT IGNORE INTO catalogo_banco (codigo_bcv, nombre) VALUES
('0102', 'Banco de Venezuela, S.A. Banco Universal'),
('0104', 'Venezolano de Crédito, S.A. Banco Universal'),
('0105', 'Banco Mercantil C.A., Banco Universal'),
('0108', 'Banco Provincial S.A., Banco Universal'),
('0114', 'Bancaribe C.A., Banco Universal'),
('0115', 'Banco Exterior C.A., Banco Universal'),
('0128', 'Banco Caroní, C.A. Banco Universal'),
('0134', 'Banesco Banco Universal, C.A.'),
('0138', 'Banco Plaza, Banco Universal'),
('0151', 'BFC Banco Fondo Común C.A., Banco Universal'),
('0156', '100% Banco, Banco Universal C.A.'),
('0157', 'Banco del Sur, Banco Universal, C.A.'),
('0163', 'Banco del Tesoro C.A., Banco Universal'),
('0168', 'Bancrecer S.A., Banco Microfinanciero'),
('0169', 'Mi Banco, Banco Microfinanciero, C.A.'),
('0171', 'Banco Activo C.A., Banco Universal'),
('0172', 'Bancamiga Banco Microfinanciero, C.A.'),
('0174', 'Banplus Banco Universal, C.A.'),
('0175', 'Banco Bicentenario del Pueblo, Banco Universal C.A.'),
('0177', 'Banco de la Fuerza Armada Nacional Bolivariana (BANFANB)'),
('0191', 'Banco Nacional de Crédito, C.A. Banco Universal (BNC)');

-- 6. Limpieza: Cancelar viajes 'buscando' huérfanos que hayan quedado estancados
UPDATE traslado 
   SET estado = 'cancelado', 
       cancelado_por = 'sistema',
       motivo_cancelacion = 'Viaje limpiado por migración (estado buscando estancado)',
       id_chofer = NULL
 WHERE estado = 'buscando';

-- 7. Limpieza: Resetear disponibilidad de choferes que no tienen viaje activo
UPDATE chofer c
   SET c.disponible = 1
 WHERE c.disponible = 0
   AND c.id NOT IN (
     SELECT t.id_chofer FROM traslado t
      WHERE t.id_chofer IS NOT NULL
        AND t.estado IN ('solicitado','aceptado','en_camino','chofer_llego','en_progreso')
   );


