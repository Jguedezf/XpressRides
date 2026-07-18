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
