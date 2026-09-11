#!/bin/bash
# Creates the application user and the Datadog DBM user with explain support.
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<EOSQL
-- ------------------------------------------------------------- app user
CREATE USER __DEMO_NAME__ WITH PASSWORD '${POSTGRES_APP_PASSWORD}';
GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO __DEMO_NAME__;
GRANT USAGE ON SCHEMA public TO __DEMO_NAME__;
-- CREATE is required for the live index-remediation endpoint; since PG 15
-- the public schema no longer grants it implicitly.
GRANT CREATE ON SCHEMA public TO __DEMO_NAME__;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO __DEMO_NAME__;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO __DEMO_NAME__;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO __DEMO_NAME__;

-- The catalog service creates and drops indexes live during the demo, which
-- requires table ownership -- not just DML grants.
DO \$do\$
DECLARE r record;
BEGIN
  FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
    EXECUTE format('ALTER TABLE public.%I OWNER TO __DEMO_NAME__', r.tablename);
  END LOOP;
  FOR r IN SELECT sequencename FROM pg_sequences WHERE schemaname = 'public' LOOP
    EXECUTE format('ALTER SEQUENCE public.%I OWNER TO __DEMO_NAME__', r.sequencename);
  END LOOP;
END
\$do\$;

-- --------------------------------------------------------- datadog DBM user
CREATE USER datadog WITH PASSWORD '${POSTGRES_DD_PASSWORD}';
GRANT pg_monitor TO datadog;
GRANT SELECT ON pg_stat_database TO datadog;
GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO datadog;
GRANT USAGE ON SCHEMA public TO datadog;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO datadog;

CREATE SCHEMA IF NOT EXISTS datadog;
GRANT USAGE ON SCHEMA datadog TO datadog;
GRANT USAGE ON SCHEMA public  TO datadog;

CREATE OR REPLACE FUNCTION datadog.explain_statement(
   l_query TEXT,
   OUT explain JSON
)
RETURNS SETOF JSON AS
\$\$
DECLARE
curs REFCURSOR;
plan JSON;
BEGIN
   OPEN curs FOR EXECUTE pg_catalog.concat('EXPLAIN (FORMAT JSON) ', l_query);
   FETCH curs INTO plan;
   CLOSE curs;
   RETURN QUERY SELECT plan;
END;
\$\$
LANGUAGE 'plpgsql'
RETURNS NULL ON NULL INPUT
SECURITY DEFINER;

ALTER FUNCTION datadog.explain_statement OWNER TO postgres;
EOSQL

echo "[init] Datadog DBM user configured for PostgreSQL."
