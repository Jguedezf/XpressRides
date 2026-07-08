-- Migración manual para bases de datos ya creadas (no recrear desde cero).
-- Agrega el sistema de referidos: código propio por cliente, cupón de $5 al
-- referente cuando el referido completa su primer viaje pagado, y la opción
-- de agregar el código tardíamente desde el perfil.
-- Ejecutar una sola vez contra la base de datos existente, en orden.

-- 1. Columnas nuevas en cliente. codigo_referido se agrega primero como NULL
--    porque la tabla ya tiene filas (laurap, josecl, marycl, etc.) y MySQL no
--    permite agregar una columna NOT NULL sin DEFAULT sobre una tabla con datos.
ALTER TABLE cliente
  ADD COLUMN codigo_referido VARCHAR(10) NULL,
  ADD COLUMN referido_por INT NULL,
  ADD COLUMN recompensa_referido_otorgada TINYINT(1) NOT NULL DEFAULT 0;

-- 2. Backfill: cada cliente existente recibe un código aleatorio de 8 caracteres.
--    Colisión entre estos pocos clientes de prueba es astronómicamente
--    improbable (espacio de hex de 8 caracteres); si el ALTER del paso 3
--    fallara por una colisión real, basta con volver a correr este UPDATE.
UPDATE cliente
  SET codigo_referido = UPPER(SUBSTRING(MD5(RAND()), 1, 8))
  WHERE codigo_referido IS NULL;

-- 3. Ahora sí, columna obligatoria y única + el FK. IMPORTANTE: el CHECK de
--    "no autoreferencia" NO puede ir en esta misma sentencia (ni en ninguna
--    otra) — MySQL lo rechaza con el error 3823 ("Column 'referido_por'
--    cannot be used in a check constraint ...: needed in a foreign key
--    constraint ... referential action") porque la columna es el lado hijo
--    de un FK con ON DELETE SET NULL. La protección se aplica en el paso 3b
--    con dos triggers en su lugar.
ALTER TABLE cliente
  MODIFY COLUMN codigo_referido VARCHAR(10) NOT NULL UNIQUE,
  ADD CONSTRAINT fk_cliente_referido_por FOREIGN KEY (referido_por) REFERENCES cliente(id) ON DELETE SET NULL;

-- 3b. Protección "no autoreferencia" vía triggers (reemplaza al CHECK del
--     paso 3, que MySQL no permite aquí). BEFORE INSERT es más bien
--     defensivo: con id AUTO_INCREMENT, normalmente no se conoce el propio
--     id todavía en el INSERT, así que la autoreferencia real solo es
--     alcanzable en la práctica vía UPDATE — se cubren ambos casos por
--     completitud.
DROP TRIGGER IF EXISTS trg_cliente_no_autoreferido_insert;
DROP TRIGGER IF EXISTS trg_cliente_no_autoreferido_update;

DELIMITER $$

CREATE TRIGGER trg_cliente_no_autoreferido_insert
BEFORE INSERT ON cliente
FOR EACH ROW
BEGIN
  IF NEW.referido_por IS NOT NULL AND NEW.referido_por = NEW.id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un cliente no puede tener su propio código como referido_por';
  END IF;
END$$

CREATE TRIGGER trg_cliente_no_autoreferido_update
BEFORE UPDATE ON cliente
FOR EACH ROW
BEGIN
  IF NEW.referido_por IS NOT NULL AND NEW.referido_por = NEW.id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un cliente no puede tener su propio código como referido_por';
  END IF;
END$$

DELIMITER ;

-- 4. Nuevo tipo de cupón para la recompensa de referidos.
ALTER TABLE cupon MODIFY tipo ENUM('bienvenida','estudiante','promocional','referido') NOT NULL;

-- 5. Trazabilidad: qué viaje del referido generó cada cupón de recompensa.
ALTER TABLE cupon_cliente
  ADD COLUMN id_traslado_origen INT NULL,
  ADD CONSTRAINT fk_cupon_cliente_traslado FOREIGN KEY (id_traslado_origen) REFERENCES traslado(id);

-- 6. Nuevo tipo de notificación para avisar al referente que ganó su cupón.
ALTER TABLE notificacion MODIFY tipo ENUM(
  'viaje_solicitado','chofer_asignado','chofer_en_camino',
  'chofer_llego','viaje_iniciado','viaje_completado','factura_emitida',
  'pago_recibido','recarga_acreditada','viaje_cancelado','sin_chofer','emergencia',
  'recompensa_referido'
) NOT NULL;

-- 7. Vista de ranking de referentes.
CREATE OR REPLACE VIEW v_top_referentes AS
  SELECT
    r.id                            AS id_referente,
    CONCAT(u.nombre,' ',u.apellido) AS referente,
    COUNT(c.id)                     AS total_referidos
  FROM cliente r
  JOIN usuario u ON r.id_usuario = u.id
  JOIN cliente c ON c.referido_por = r.id
  GROUP BY r.id, u.nombre, u.apellido
  ORDER BY total_referidos DESC;

-- 8. Trigger de recompensa (DROP IF EXISTS por si se re-ejecuta este script).
DROP TRIGGER IF EXISTS trg_recompensa_referido;

DELIMITER $$

CREATE TRIGGER trg_recompensa_referido
AFTER UPDATE ON traslado
FOR EACH ROW
BEGIN
  DECLARE v_id_referente         INT;
  DECLARE v_id_usuario_referente INT;
  DECLARE v_codigo_cupon         VARCHAR(30);
  DECLARE v_id_cupon             INT;
  DECLARE v_filas_marcadas       INT;

  IF NEW.estado = 'completado' AND OLD.estado <> 'completado' AND NEW.costo_cliente_usd > 0 THEN

    SELECT referido_por INTO v_id_referente
      FROM cliente
      WHERE id = NEW.id_cliente;

    IF v_id_referente IS NOT NULL THEN

      UPDATE cliente
        SET recompensa_referido_otorgada = 1
        WHERE id = NEW.id_cliente
          AND recompensa_referido_otorgada = 0;

      SET v_filas_marcadas = ROW_COUNT();

      IF v_filas_marcadas = 1 THEN

        SET v_codigo_cupon = CONCAT('REF-', LPAD(NEW.id, 8, '0'));

        INSERT INTO cupon (codigo, tipo, descuento_usd, distancia_max_km, activo)
        VALUES (v_codigo_cupon, 'referido', 5.00, NULL, 1);

        SET v_id_cupon = LAST_INSERT_ID();

        INSERT INTO cupon_cliente (id_cupon, id_cliente, usado, id_traslado_origen)
        VALUES (v_id_cupon, v_id_referente, 0, NEW.id);

        SELECT u.id INTO v_id_usuario_referente
          FROM cliente cl JOIN usuario u ON cl.id_usuario = u.id
          WHERE cl.id = v_id_referente;

        INSERT INTO notificacion (id_usuario, id_traslado, tipo, mensaje)
        VALUES (v_id_usuario_referente, NEW.id, 'recompensa_referido',
          CONCAT('¡Ganaste un cupón de $5 porque tu referido completó su primer viaje pagado! Código: ', v_codigo_cupon));

      END IF;

    END IF;

  END IF;

END$$

DELIMITER ;
