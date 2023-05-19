/* gpcontrib/arenadata_toolkit/arenadata_toolkit--unpackaged--1.0.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION arenadata_toolkit FROM unpackaged" to load this file. \quit

ALTER EXTENSION arenadata_toolkit ADD SCHEMA arenadata_toolkit;
GRANT USAGE ON SCHEMA arenadata_toolkit TO public;

ALTER EXTENSION arenadata_toolkit ADD TABLE arenadata_toolkit.daily_operation;
GRANT SELECT ON TABLE arenadata_toolkit.daily_operation TO public;

DO $$
BEGIN
	IF EXISTS (SELECT 1 FROM pg_tables
					WHERE schemaname = 'arenadata_toolkit' AND tablename  = 'db_files_current')
	THEN
		ALTER EXTENSION arenadata_toolkit ADD TABLE arenadata_toolkit.db_files_current;
	ELSE
		CREATE TABLE arenadata_toolkit.db_files_current
		(
			oid BIGINT,
			table_name TEXT,
			table_schema TEXT,
			type CHAR(1),
			storage CHAR(1),
			table_parent_table TEXT,
			table_parent_schema TEXT,
			table_database TEXT,
			table_tablespace TEXT,
			"content" INTEGER,
			segment_preferred_role CHAR(1),
			hostname TEXT,
			address TEXT,
			file TEXT,
			modifiedtime TIMESTAMP WITHOUT TIME ZONE,
			file_size BIGINT
		)
		DISTRIBUTED RANDOMLY;
	END IF;

	GRANT SELECT ON TABLE arenadata_toolkit.db_files_current TO public;

	IF EXISTS (SELECT 1 FROM pg_tables
					WHERE schemaname = 'arenadata_toolkit' AND tablename  = 'db_files')
	THEN
		DROP EXTERNAL TABLE arenadata_toolkit.db_files;
	END IF;
END$$;


ALTER EXTENSION arenadata_toolkit ADD TABLE arenadata_toolkit.db_files_history;
GRANT SELECT ON TABLE arenadata_toolkit.db_files_history TO public;
ALTER EXTENSION arenadata_toolkit ADD TABLE arenadata_toolkit.operation_exclude;
GRANT SELECT ON TABLE arenadata_toolkit.operation_exclude TO public;
