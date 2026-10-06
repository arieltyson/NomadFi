CREATE ROLE nomadfi_runtime NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
CREATE ROLE nomadfi_fibot NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
GRANT USAGE ON SCHEMA nomadfi TO nomadfi_runtime, nomadfi_fibot;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA nomadfi TO nomadfi_runtime;
ALTER DEFAULT PRIVILEGES IN SCHEMA nomadfi
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO nomadfi_runtime;
GRANT SELECT ON nomadfi.fibot_connections, nomadfi.fibot_profiles TO nomadfi_fibot;
-- PostgreSQL row locks require UPDATE on at least one column; this grants no plan or consent writes.
GRANT UPDATE (worker_lock) ON nomadfi.fibot_profiles TO nomadfi_fibot;
GRANT SELECT, INSERT, UPDATE, DELETE ON nomadfi.fibot_jobs, nomadfi.fibot_alerts TO nomadfi_fibot;
