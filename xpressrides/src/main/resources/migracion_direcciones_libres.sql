ALTER TABLE traslado
  ADD COLUMN origen_direccion VARCHAR(255) NULL,
  ADD COLUMN origen_lat DECIMAL(10,7) NULL,
  ADD COLUMN origen_lng DECIMAL(10,7) NULL,
  ADD COLUMN destino_direccion VARCHAR(255) NULL,
  ADD COLUMN destino_lat DECIMAL(10,7) NULL,
  ADD COLUMN destino_lng DECIMAL(10,7) NULL,
  MODIFY COLUMN id_zona_origen INT NULL,
  MODIFY COLUMN id_zona_destino INT NULL;
