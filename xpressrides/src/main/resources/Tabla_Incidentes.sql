CREATE TABLE incidente (
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