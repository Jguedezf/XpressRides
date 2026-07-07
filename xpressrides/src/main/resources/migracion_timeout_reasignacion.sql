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
