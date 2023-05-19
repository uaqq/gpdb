----------------------------------------------------------------------------------------------------------
-- test helpers
----------------------------------------------------------------------------------------------------------

-- function that mocks manual installation of arenadata_toolkit from bundle
CREATE FUNCTION mock_manual_installation() RETURNS VOID AS $$
BEGIN
	CREATE SCHEMA arenadata_toolkit;
	EXECUTE 'GRANT ALL ON SCHEMA arenadata_toolkit to ' || (SELECT current_user);
	CREATE TABLE arenadata_toolkit.db_files_history (field INT) WITH (appendonly=true) DISTRIBUTED RANDOMLY
		PARTITION BY RANGE(field) (START (1) END(3) EVERY(2), DEFAULT PARTITION extra);
	CREATE TABLE arenadata_toolkit.daily_operation(field INT) WITH (appendonly=true) DISTRIBUTED RANDOMLY;
	CREATE TABLE arenadata_toolkit.operation_exclude(schema_name TEXT) WITH (appendonly=true) DISTRIBUTED RANDOMLY;
END;
$$ LANGUAGE plpgsql;

-- function that returns information about tables that belongs to the arenadata_toolkit schema (and schema itself)
CREATE FUNCTION get_toolkit_objects_info() RETURNS TABLE (objid OID, objtype TEXT, objname NAME, objstorage "char", objacl TEXT) AS $$
BEGIN
	RETURN QUERY SELECT * FROM
		(SELECT oid, 'schema', nspname, '-'::"char",
			replace(nspacl::text, (select current_user), 'owner') AS acl -- replace current_user to static string, to prevent test flakiness
			FROM pg_namespace WHERE nspname = 'arenadata_toolkit') a UNION
		(SELECT oid, 'table', relname, relstorage,
			replace(relacl::text, (select current_user), 'owner') AS acl -- replace current_user to static string, to prevent test flakiness
			FROM pg_class WHERE relname IN (SELECT table_name FROM information_schema.tables WHERE table_schema = 'arenadata_toolkit')
		);
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
-- test case 1 (create extension from unpackaged): arenadata_toolkit installed manually, tables
-- db_files, db_files_current and db_files_history_backup_N weren't created by toolkit
----------------------------------------------------------------------------------------------------------

-- setup
SELECT mock_manual_installation();

-- check that created toolkit objects don't depend on extension
SELECT * FROM pg_depend d JOIN (SELECT * FROM get_toolkit_objects_info()) objs ON d.objid = objs.objid AND d.deptype='e';

-- show toolkit objects (and their grants) that belongs to arenadata_toolkit schema
SELECT objname, objtype, objstorage, objacl FROM (SELECT * FROM get_toolkit_objects_info()) t ORDER BY objname;

-- run the unpackaged script
CREATE extension arenadata_toolkit FROM unpackaged;

-- show toolkit objects (and their grants) that belongs to arenadata_toolkit schema after creating extension
SELECT objname, objtype, objstorage, objacl FROM (SELECT * FROM get_toolkit_objects_info()) t ORDER BY objname;

-- check that toolkit objects now depends on extension
SELECT objname, objtype, extname, deptype FROM pg_depend d JOIN
	(SELECT * FROM get_toolkit_objects_info()) objs ON d.objid = objs.objid JOIN
	pg_extension e ON d.refobjid = e.oid
WHERE d.deptype = 'e' AND e.extname = 'arenadata_toolkit' ORDER BY objname;

-- check all objects were deleted
DROP extension arenadata_toolkit;
SELECT * FROM (SELECT * FROM get_toolkit_objects_info()) t;

----------------------------------------------------------------------------------------------------------
-- test case 2 (create extension from unpackaged): arenadata_toolkit installed manually, tables
-- db_files, db_files_current and db_files_history_backup_N were created by toolkit
----------------------------------------------------------------------------------------------------------

-- setup
SELECT mock_manual_installation();
CREATE TABLE arenadata_toolkit.db_files_current (field TEXT) DISTRIBUTED RANDOMLY;
CREATE TABLE arenadata_toolkit.db_files_history_backup_N (field INT) WITH (appendonly=true) DISTRIBUTED RANDOMLY
	PARTITION BY RANGE(field) (START (1) END(3) EVERY(2), DEFAULT PARTITION extra);
CREATE EXTERNAL WEB TABLE arenadata_toolkit.db_files (field TEXT) EXECUTE 'echo 1' FORMAT 'TEXT';

-- check that created objects don't depend on extension
SELECT * FROM pg_depend d JOIN (SELECT * FROM get_toolkit_objects_info()) objs ON d.objid = objs.objid AND d.deptype='e';

-- show toolkit objects (and their grants) that belongs to arenadata_toolkit schema
SELECT objname, objtype, objstorage, objacl FROM (SELECT * FROM get_toolkit_objects_info()) t ORDER BY objname;

-- run the unpackaged script
CREATE extension arenadata_toolkit FROM unpackaged;

-- show toolkit objects (and their grants) that belongs to arenadata_toolkit schema after creating extension
SELECT objname, objtype, objstorage, objacl FROM (SELECT * FROM get_toolkit_objects_info()) t ORDER BY objname;

-- check that toolkit objects now depends on extension
SELECT objname, objtype, extname, deptype FROM pg_depend d JOIN
	(SELECT * FROM get_toolkit_objects_info()) objs ON d.objid = objs.objid JOIN
	pg_extension e ON d.refobjid = e.oid
WHERE d.deptype = 'e' AND e.extname = 'arenadata_toolkit' ORDER BY objname;

-- must fail, because db_files_history_backup_N should be dropped manually
DROP extension arenadata_toolkit;

DROP TABLE arenadata_toolkit.db_files_history_backup_N;

-- check all objects were deleted
DROP extension arenadata_toolkit;
SELECT * FROM (SELECT * FROM get_toolkit_objects_info()) t;

----------------------------------------------------------------------------------------------------------
-- test case 3 (create extension): there is no arenadata_toolkit - new installation
----------------------------------------------------------------------------------------------------------

create extension arenadata_toolkit;

-- show toolkit objects (and their grants) that belongs to arenadata_toolkit schema after creating extension
SELECT objname, objtype, objstorage, objacl FROM (SELECT * FROM get_toolkit_objects_info()) t ORDER BY objname;

-- check that toolkit objects were created by extension and check their grants
SELECT objname, objtype, extname, deptype FROM pg_depend d JOIN
	(SELECT * FROM get_toolkit_objects_info()) objs ON d.objid = objs.objid JOIN
	pg_extension e ON d.refobjid = e.oid
WHERE d.deptype = 'e' AND e.extname = 'arenadata_toolkit' ORDER BY objname;

-- check all objects were deleted
DROP extension arenadata_toolkit;
SELECT * FROM (SELECT * FROM get_toolkit_objects_info()) t;
