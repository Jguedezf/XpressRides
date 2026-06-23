-- ================================================================
--  XpressRides (Decarrerita) — Sistemas de Base de Datos I
--  UNEG · Prof. María Raquel Herrera E. · Junio 2026
--  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
--          Manuel Jaimes · Ángel Martínez
-- ================================================================
--  Archivo:     datos_prueba.sql
--  Módulo:      Datos semilla (seed data) para pruebas
--  Descripción: Inserta un escenario completo y funcional para
--               probar el flujo de solicitud de traslado:
--               1 chofer totalmente habilitado (con evaluación
--               psicológica aprobada, revisión vehicular aprobada,
--               vehículo activo y 2 contactos de emergencia) y
--               1 cliente estudiante con saldo disponible.
--
--               Es idempotente: puede ejecutarse múltiples veces
--               sin generar duplicados (limpia datos previos de
--               prueba antes de insertar). Usa transacción para
--               garantizar consistencia y resuelve los IDs por
--               nombre para no depender de valores fijos.
--
--  Uso:         Ejecutar completo en MySQL Workbench sobre la BD
--               'decarrerita' DESPUÉS de cargar decarrerita.sql.
--               Seleccionar (Ctrl+A) y ejecutar (rayo).
--
--  Versión:     1.2.0
--  Fecha:       23/06/2026
-- ================================================================

USE decarrerita;

-- FIX Error 1175: Desactiva safe update mode de MySQL Workbench
SET SQL_SAFE_UPDATES = 0;

START TRANSACTION;

-- ----------------------------------------------------------------
-- LIMPIEZA PREVIA — dentro de la transacción para permitir ROLLBACK.
-- Solo elimina los usuarios de prueba (carlosr, laurap), nunca el
-- usuario administrador base del sistema.
-- ----------------------------------------------------------------
SET FOREIGN_KEY_CHECKS = 0;

DELETE FROM contacto_emergencia
  WHERE id_chofer IN (
    SELECT id FROM (
      SELECT c.id FROM chofer c
      JOIN usuario u ON c.id_usuario = u.id
      WHERE u.username = 'carlosr'
    ) AS tmp
  );

DELETE FROM evaluacion_psicologica
  WHERE id_chofer IN (
    SELECT id FROM (
      SELECT c.id FROM chofer c
      JOIN usuario u ON c.id_usuario = u.id
      WHERE u.username = 'carlosr'
    ) AS tmp
  );

DELETE FROM revision_vehiculo
  WHERE id_vehiculo IN (
    SELECT id FROM (
      SELECT v.id FROM vehiculo v
      JOIN chofer c ON v.id_chofer = c.id
      JOIN usuario u ON c.id_usuario = u.id
      WHERE u.username = 'carlosr'
    ) AS tmp
  );

DELETE FROM vehiculo
  WHERE id_chofer IN (
    SELECT id FROM (
      SELECT c.id FROM chofer c
      JOIN usuario u ON c.id_usuario = u.id
      WHERE u.username = 'carlosr'
    ) AS tmp
  );

DELETE FROM chofer
  WHERE id_usuario IN (
    SELECT id FROM (SELECT id FROM usuario WHERE username = 'carlosr') AS tmp
  );

DELETE FROM cliente
  WHERE id_usuario IN (
    SELECT id FROM (SELECT id FROM usuario WHERE username = 'laurap') AS tmp
  );

DELETE FROM usuario WHERE username IN ('carlosr', 'laurap');

SET FOREIGN_KEY_CHECKS = 1;

-- ----------------------------------------------------------------
-- RESOLUCIÓN DE IDs POR NOMBRE — evita depender de valores fijos.
-- El campo id_admin referencia a personal_admin(id), por eso primero
-- se asegura que el administrador base exista en esa tabla.
-- ----------------------------------------------------------------
SET @id_usuario_admin = (
  SELECT id FROM usuario
  WHERE rol IN ('admin', 'administrador', 'Administrador')
  LIMIT 1
);

INSERT INTO personal_admin (id_usuario, cargo)
VALUES (@id_usuario_admin, 'Administrador General')
ON DUPLICATE KEY UPDATE cargo = VALUES(cargo);

SET @id_admin = (
  SELECT id FROM personal_admin WHERE id_usuario = @id_usuario_admin
);

SET @id_banco = (SELECT id FROM banco WHERE nombre LIKE '%Venezuela%' LIMIT 1);
SET @id_zona  = (SELECT id FROM zona  WHERE nombre LIKE '%Alta Vista Norte%' LIMIT 1);

-- ----------------------------------------------------------------
-- DIAGNÓSTICO — confirma que ninguna variable quedó en NULL.
-- Si alguna sale NULL, hacer ROLLBACK y revisar el dato faltante.
-- ----------------------------------------------------------------
SELECT
  @id_usuario_admin AS id_usuario_admin,
  @id_admin         AS id_admin,
  @id_banco         AS id_banco,
  @id_zona          AS id_zona;

-- ----------------------------------------------------------------
-- USUARIO CHOFER + módulo operativo completo
-- ----------------------------------------------------------------
INSERT INTO usuario (cedula, nombre, apellido, username, password_hash,
                     email, telefono, rol)
VALUES ('V15234567', 'Carlos', 'Rodríguez', 'carlosr',
        '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lHuu',
        'carlos.rodriguez@test.ve', '0414-5234567', 'chofer');
SET @id_usuario_chofer = LAST_INSERT_ID();

INSERT INTO chofer (id_usuario, id_banco, id_zona_actual, numero_cuenta,
                    saldo_acumulado_usd, habilitado, disponible)
VALUES (@id_usuario_chofer, @id_banco, @id_zona,
        '01020123456789012345', 0.00, 1, 1);
SET @id_chofer = LAST_INSERT_ID();

INSERT INTO vehiculo (id_chofer, placa, marca, modelo,
                      anio_fabricacion, color, activo)
VALUES (@id_chofer, 'AB123CD', 'Toyota', 'Corolla', 2020, 'Blanco', 1);
SET @id_vehiculo = LAST_INSERT_ID();

-- Fechas dinámicas: siempre dentro del último año (3 meses atrás)
INSERT INTO evaluacion_psicologica (id_chofer, id_admin, calificacion,
                                     fecha_eval, observacion)
VALUES (@id_chofer, @id_admin, 85.00,
        DATE_SUB(CURDATE(), INTERVAL 3 MONTH),
        'Evaluación aprobada sin observaciones.');

INSERT INTO revision_vehiculo (id_vehiculo, id_admin, calificacion,
                                fecha_revision, observacion)
VALUES (@id_vehiculo, @id_admin, 90.00,
        DATE_SUB(CURDATE(), INTERVAL 3 MONTH),
        'Vehículo en óptimas condiciones.');

INSERT INTO contacto_emergencia (id_chofer, nombre, telefono, parentesco)
VALUES
    (@id_chofer, 'Ana Rodríguez',   '0414-5234568', 'Esposa'),
    (@id_chofer, 'Pedro Rodríguez', '0414-5234569', 'Padre');

-- ----------------------------------------------------------------
-- USUARIO CLIENTE ESTUDIANTE con saldo
-- primer_viaje_usado = 0 para que aplique el beneficio de primer viaje
-- ----------------------------------------------------------------
INSERT INTO usuario (cedula, nombre, apellido, username, password_hash,
                     email, telefono, rol)
VALUES ('V20123456', 'Laura', 'Pérez', 'laurap',
        '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lHuu',
        'laura.perez@test.ve', '0416-1234567', 'cliente');
SET @id_usuario_cliente = LAST_INSERT_ID();

INSERT INTO cliente (id_usuario, saldo_usd, es_estudiante, primer_viaje_usado)
VALUES (@id_usuario_cliente, 20.00, 1, 0);

COMMIT;

-- Restaurar el modo seguro de Workbench
SET SQL_SAFE_UPDATES = 1;

-- ================================================================
-- VERIFICACIÓN ESPECÍFICA — muestra solo los registros de prueba
-- creados por este script, con sus campos relevantes.
-- ================================================================
SELECT 'CHOFER' AS entidad, u.username, u.nombre, u.apellido,
       c.habilitado, c.disponible, c.saldo_acumulado_usd
FROM usuario u
JOIN chofer c ON c.id_usuario = u.id
WHERE u.username = 'carlosr';

SELECT 'VEHICULO' AS entidad, v.placa, v.marca, v.modelo, v.anio_fabricacion
FROM vehiculo v
JOIN chofer c ON v.id_chofer = c.id
JOIN usuario u ON c.id_usuario = u.id
WHERE u.username = 'carlosr';

SELECT 'EVALUACION' AS entidad, ep.calificacion, ep.fecha_eval, ep.aprobado
FROM evaluacion_psicologica ep
JOIN chofer c ON ep.id_chofer = c.id
JOIN usuario u ON c.id_usuario = u.id
WHERE u.username = 'carlosr';

SELECT 'REVISION' AS entidad, rv.calificacion, rv.fecha_revision, rv.apto
FROM revision_vehiculo rv
JOIN vehiculo v ON rv.id_vehiculo = v.id
JOIN chofer c ON v.id_chofer = c.id
JOIN usuario u ON c.id_usuario = u.id
WHERE u.username = 'carlosr';

SELECT 'CONTACTOS' AS entidad, ce.nombre, ce.telefono, ce.parentesco
FROM contacto_emergencia ce
JOIN chofer c ON ce.id_chofer = c.id
JOIN usuario u ON c.id_usuario = u.id
WHERE u.username = 'carlosr';

SELECT 'CLIENTE' AS entidad, u.username, cl.saldo_usd, cl.es_estudiante, cl.primer_viaje_usado
FROM usuario u
JOIN cliente cl ON cl.id_usuario = u.id
WHERE u.username = 'laurap';