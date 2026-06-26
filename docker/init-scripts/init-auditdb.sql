-- Init auditdb (audit-service)
-- Table append-only : aucune UPDATE ni DELETE autorisée.
-- La contrainte est portée par l'application, pas par PostgreSQL,
-- mais on pose l'extension pour les timestamps précis.
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
