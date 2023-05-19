/* gpcontrib/arenadata_toolkit/arenadata_toolkit--1.0.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION arenadata_toolkit" to load this file. \quit

CREATE SCHEMA arenadata_toolkit;
GRANT USAGE ON SCHEMA arenadata_toolkit TO public;

-- table for collection statistics
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
) DISTRIBUTED RANDOMLY;
GRANT SELECT ON TABLE arenadata_toolkit.db_files_current TO public;

-- daily_operation log
CREATE TABLE arenadata_toolkit.daily_operation
(
	schema_name TEXT,
	table_name TEXT,
	action TEXT,
	status TEXT,
	time BIGINT,
	processed_dttm TIMESTAMP
)
WITH (appendonly=true, compresstype=zlib, compresslevel=1)
DISTRIBUTED RANDOMLY;
GRANT SELECT ON TABLE arenadata_toolkit.daily_operation TO public;

-- Exception table
CREATE TABLE arenadata_toolkit.operation_exclude
(
	schema_name TEXT
)
WITH (appendonly=true, compresstype=zlib, compresslevel=1)
DISTRIBUTED RANDOMLY;
GRANT SELECT ON TABLE arenadata_toolkit.operation_exclude TO public;

-- Exception list
INSERT INTO arenadata_toolkit.operation_exclude (schema_name)
	VALUES	('gp_toolkit'),
			('information_schema'),
			('pg_aoseg'),
			('pg_bitmapindex'),
			('pg_catalog'),
			('pg_toast');
