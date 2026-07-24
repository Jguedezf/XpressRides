-- ================================================================
--  Migración: tabla token_revocado
--  Persiste la lista negra de JWT revocados que antes vivía solo
--  en memoria (ConcurrentHashMap). Tras esta migración, los tokens
--  revocados sobreviven reinicios del servidor.
-- ================================================================

USE decarrerita;

CREATE TABLE IF NOT EXISTS token_revocado (
  token       VARCHAR(512) NOT NULL PRIMARY KEY,
  revocado_en DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
