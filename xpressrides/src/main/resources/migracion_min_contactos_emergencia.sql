-- ================================================================
--  Migración: exactamente 2 contactos de emergencia para habilitar chofer
--  Ver propuesta_minimo_2_contactos_emergencia.md, sección 2 (Opción A) y 5.2.a.
--  Bloquea el paso chofer.habilitado 0 -> 1 si el chofer no tiene
--  exactamente 2 filas en contacto_emergencia. No afecta el alta
--  incremental de contactos (INSERT/UPDATE/DELETE libres mientras
--  habilitado siga en 0).
-- ================================================================

DROP TRIGGER IF EXISTS trg_chofer_min_contactos;

DELIMITER $$
CREATE TRIGGER trg_chofer_min_contactos
BEFORE UPDATE ON chofer
FOR EACH ROW
BEGIN
  IF NEW.habilitado = 1 AND OLD.habilitado = 0 THEN
    IF (SELECT COUNT(*) FROM contacto_emergencia WHERE id_chofer = NEW.id) <> 2 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No se puede habilitar al chofer: requiere exactamente 2 contactos de emergencia.';
    END IF;
  END IF;
END$$
DELIMITER ;

-- ================================================================
--  Opción B (ver propuesta_minimo_2_contactos_emergencia.md, sección 2):
--  protege el otro lado del ciclo de vida — un chofer YA habilitado no
--  puede quedar por debajo de 2 contactos al borrar uno. Se dispara
--  AFTER DELETE porque en ese momento el conteo ya refleja el estado
--  final de la fila borrada (a diferencia de un AFTER INSERT, que
--  rompería el alta incremental — ver Opción A descartada en la propuesta).
-- ================================================================

DROP TRIGGER IF EXISTS trg_contacto_no_bajar_de_2;

DELIMITER $$
CREATE TRIGGER trg_contacto_no_bajar_de_2
AFTER DELETE ON contacto_emergencia
FOR EACH ROW
BEGIN
  IF (SELECT habilitado FROM chofer WHERE id = OLD.id_chofer) = 1
     AND (SELECT COUNT(*) FROM contacto_emergencia WHERE id_chofer = OLD.id_chofer) < 2 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'No se puede eliminar: el chofer habilitado debe mantener mínimo 2 contactos de emergencia.';
  END IF;
END$$
DELIMITER ;
