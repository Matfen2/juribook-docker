-- Init authdb (auth-service)
-- Flyway gère les migrations de schéma.
-- Ce script crée uniquement les extensions nécessaires.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
