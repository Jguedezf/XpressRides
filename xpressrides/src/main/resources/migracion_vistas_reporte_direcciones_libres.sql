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
