-- =============================================================================
-- STORED PROCEDURE REWRITE: COORDINATE-BASED ROUTING & DRIVER FALLBACK
-- Milestone 1: DB & Backend Migration
-- Target Procedure: sp_solicitar_traslado
-- =============================================================================

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

  -- Distribución 70/30 sobre tarifa original. La empresa absorbe el descuento del
  -- cliente hasta un piso de $0 en su propio 30% (nunca queda en negativo) — mismo
  -- patrón GREATEST que ya usa este SP para v_costo_cli (línea 191) y el cupón
  -- (línea 188). Decisión confirmada por Freddy el 15/07/2026 — ver
  -- Propuesta_Reconciliacion_Algoritmo_Tarifas.md en la raíz del repo.
  SET v_monto_ch  = ROUND(v_tarifa_original * 0.70, 2);
  SET v_monto_emp = GREATEST(ROUND((v_tarifa_original * 0.30) - v_desc_estudiante - IFNULL(v_descuento,0), 2), 0.00);
  SET v_costo_ves = ROUND(v_costo_cli * v_tasa_ves, 2);

  -- Asignación por proximidad (radio 5 → 10 → 15 km)
  SET v_id_chofer = NULL;
  SET v_radio = RADIO_1;
  WHILE v_id_chofer IS NULL AND v_radio <= RADIO_3 DO
    -- Select closest qualified active driver using coordinate logic with zone fallback
    SELECT c.id, v.id, c.id_zona_actual,
           -- Driver Latitud Fallback: GPS if valid (updated in last 2 mins), else Zone latitud
           IF(c.lat_actual IS NOT NULL AND c.lng_actual IS NOT NULL AND c.ubicacion_actualizada_en >= NOW() - INTERVAL 2 MINUTE, c.lat_actual, zo.latitud),
           -- Driver Longitud Fallback: GPS if valid (updated in last 2 mins), else Zone longitud
           IF(c.lat_actual IS NOT NULL AND c.lng_actual IS NOT NULL AND c.ubicacion_actualizada_en >= NOW() - INTERVAL 2 MINUTE, c.lng_actual, zo.longitud)
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
       -- Driver must have either a fresh GPS position or an assigned zone
       AND (
         (c.lat_actual IS NOT NULL AND c.lng_actual IS NOT NULL AND c.ubicacion_actualizada_en >= NOW() - INTERVAL 2 MINUTE)
         OR (c.id_zona_actual IS NOT NULL AND zo.id IS NOT NULL)
       )
       -- Distance is calculated against driver's resolved coordinates (GPS or zone fallback)
       AND fn_distancia_km(
         IF(c.lat_actual IS NOT NULL AND c.lng_actual IS NOT NULL AND c.ubicacion_actualizada_en >= NOW() - INTERVAL 2 MINUTE, c.lat_actual, zo.latitud),
         IF(c.lat_actual IS NOT NULL AND c.lng_actual IS NOT NULL AND c.ubicacion_actualizada_en >= NOW() - INTERVAL 2 MINUTE, c.lng_actual, zo.longitud),
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
    SET p_mensaje = CONCAT(IFNULL(p_mensaje,''),
      'ERROR: No hay choferes disponibles en este momento.');
    SET p_id_traslado = NULL;
    LEAVE sp_solicitar_traslado;
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
    v_costo_ves, 'solicitado',
    CEILING(fn_distancia_km(v_chofer_lat, v_chofer_lng, v_lat1, v_lon1) / 30 * 60),
    NOW()
  );
  SET p_id_traslado = LAST_INSERT_ID();

  -- Actualizar saldos y disponibilidad del chofer
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
    ' | Tasa: ', v_tasa_ves, ' Bs',
    ' | Equivalente: ', v_costo_ves, ' Bs');

END$$

DELIMITER ;
