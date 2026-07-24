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
