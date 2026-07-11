ALTER TABLE chofer
  ADD COLUMN lat_actual DECIMAL(10,7) NULL,
  ADD COLUMN lng_actual DECIMAL(10,7) NULL,
  ADD COLUMN ubicacion_actualizada_en DATETIME NULL;
