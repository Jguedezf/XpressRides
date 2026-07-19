-- ================================================================
--  Migración: entidad Incidente para el flujo de emergencia
--  El botón de emergencia (cliente/chofer) ya enviaba una Notification
--  por cada admin/personal_admin, pero no existía ningún caso con estado
--  que el admin pudiera tomar y cerrar. Esta tabla agrega ese seguimiento
--  mínimo: un Incidente por evento de emergencia reportado (no uno por
--  cada Notification generada, ya que sendEmergencyAlert crea una por
--  cada admin activo).
-- ================================================================

DROP TABLE IF EXISTS `incidente`;

CREATE TABLE `incidente` (
  `id` int NOT NULL AUTO_INCREMENT,
  `id_usuario_reporta` int NOT NULL,
  `id_traslado` int DEFAULT NULL,
  `mensaje` varchar(200) NOT NULL,
  `estado` enum('abierto','en_proceso','cerrado') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'abierto',
  `notas_resolucion` varchar(300) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `id_admin_cierra` int DEFAULT NULL,
  `fecha_creacion` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `fecha_cierre` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_incidente_usuario` (`id_usuario_reporta`),
  KEY `fk_incidente_traslado` (`id_traslado`),
  KEY `fk_incidente_admin_cierra` (`id_admin_cierra`),
  CONSTRAINT `fk_incidente_usuario` FOREIGN KEY (`id_usuario_reporta`) REFERENCES `usuario` (`id`),
  CONSTRAINT `fk_incidente_traslado` FOREIGN KEY (`id_traslado`) REFERENCES `traslado` (`id`),
  CONSTRAINT `fk_incidente_admin_cierra` FOREIGN KEY (`id_admin_cierra`) REFERENCES `usuario` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
