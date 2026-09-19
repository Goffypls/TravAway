-- Extensiones que usa el esquema de TravAway (ver docs/03-modelo-datos.md)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";  -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "citext";    -- email case-insensitive
