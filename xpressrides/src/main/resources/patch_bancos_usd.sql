-- Parche para agregar soporte de Bancos en Divisas (USD)
-- Ejecutar este script en la base de datos `decarrerita`

USE decarrerita;

-- 1. Añadir columnas a la tabla banco
ALTER TABLE banco 
ADD COLUMN acepta_usd TINYINT(1) NOT NULL DEFAULT 0 AFTER codigo_bcv,
ADD COLUMN acepta_ves TINYINT(1) NOT NULL DEFAULT 1 AFTER acepta_usd;

-- 2. Corregir el código BCV de Banesco (estaba como BNC)
UPDATE banco SET codigo_bcv = 'BAN' WHERE nombre = 'Banesco';

-- 3. Marcar los bancos existentes que SÍ aceptan divisas
UPDATE banco SET acepta_usd = 1 WHERE nombre IN ('Banco de Venezuela', 'Mercantil', 'BBVA Provincial');

-- 4. Insertar los bancos nuevos que aceptan USD
INSERT INTO banco (nombre, codigo_bcv, acepta_usd, acepta_ves) VALUES
('Bancaribe', 'BCB', 1, 1),
('BNC (Banco Nacional de Credito)', 'BNC', 1, 1),
('Banco Plaza', 'BPZ', 1, 1),
('BFC (Banco Fondo Comun)', 'BFC', 1, 1);
