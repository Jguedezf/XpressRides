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
