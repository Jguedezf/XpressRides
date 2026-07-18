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
