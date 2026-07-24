-- ================================================================
-- Script de Migración
-- Ejecutar en la base de datos `decarrerita` para aplicar
-- los últimos cambios sin tener que borrar los datos actuales.
-- ================================================================

-- 1. Crear tabla incidente (Faltaba en la BD para el botón SOS)
CREATE TABLE IF NOT EXISTS incidente (
  id                  INT           AUTO_INCREMENT PRIMARY KEY,
  id_usuario_reporta  INT           NOT NULL,
  id_traslado         INT           NULL,
  mensaje             VARCHAR(255)  NOT NULL,
  estado              ENUM('abierto', 'en_proceso', 'cerrado') NOT NULL DEFAULT 'abierto',
  notas_resolucion    TEXT          NULL,
  id_admin_cierra     INT           NULL,
  fecha_creacion      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_cierre        DATETIME      NULL,
  CONSTRAINT fk_inc_usuario_rep FOREIGN KEY (id_usuario_reporta) REFERENCES usuario(id) ON DELETE CASCADE,
  CONSTRAINT fk_inc_traslado    FOREIGN KEY (id_traslado)        REFERENCES traslado(id) ON DELETE CASCADE,
  CONSTRAINT fk_inc_admin       FOREIGN KEY (id_admin_cierra)    REFERENCES usuario(id) ON DELETE SET NULL
);

-- 2. Crear tabla catalogo_banco (Para lista dinámica del Frontend)
CREATE TABLE IF NOT EXISTS catalogo_banco (
  codigo_bcv  VARCHAR(4)    PRIMARY KEY,
  nombre      VARCHAR(100)  NOT NULL
);

-- 3. Insertar datos en catalogo_banco (Ignora si ya existen)
INSERT IGNORE INTO catalogo_banco (nombre, codigo_bcv) VALUES
  ('Banesco', '0134'),
  ('Banco Mercantil', '0105'),
  ('BBVA Provincial', '0108'),
  ('BNC', '0191'),
  ('Bancamiga', '0172'),
  ('Bancaribe', '0114'),
  ('Banco Exterior', '0115'),
  ('Banplus', '0174'),
  ('BFC', '0151'),
  ('Banco Plaza', '0138'),
  ('Banco Caroní', '0128'),
  ('DELSUR', '0157'),
  ('Banco Activo', '0171'),
  ('Sofitasa', '0137'),
  ('100% Banco', '0156'),
  ('BVC', '0104'),
  ('Bancrecer', '0168'),
  ('BDV', '0102'),
  ('BDT', '0175'),
  ('Banco del Tesoro', '0163'),
  ('BAV', '0166'),
  ('BANFANB', '0177');

-- 4. Actualizar códigos antiguos en tabla banco por los verdaderos códigos BCV
UPDATE banco SET codigo_bcv = '0102' WHERE codigo_bcv = 'BDV';
UPDATE banco SET codigo_bcv = '0134' WHERE codigo_bcv = 'BAN';
UPDATE banco SET codigo_bcv = '0105' WHERE codigo_bcv = 'MER';
UPDATE banco SET codigo_bcv = '0108' WHERE codigo_bcv = 'BBV';
UPDATE banco SET codigo_bcv = '0175' WHERE codigo_bcv = 'BIC';
UPDATE banco SET codigo_bcv = '0163' WHERE codigo_bcv = 'BTU';
UPDATE banco SET codigo_bcv = '0115' WHERE codigo_bcv = 'BEX';
UPDATE banco SET codigo_bcv = '0114' WHERE codigo_bcv = 'BCB';
UPDATE banco SET codigo_bcv = '0191' WHERE codigo_bcv = 'BNC';
UPDATE banco SET codigo_bcv = '0138' WHERE codigo_bcv = 'BPZ';
UPDATE banco SET codigo_bcv = '0151' WHERE codigo_bcv = 'BFC';
