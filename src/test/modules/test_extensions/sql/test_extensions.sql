-- CVE-2022-2625
-- https://github.com/postgres/postgres/commit/5919bb5a5989cda232ac3d1f8b9d90f337be2077
--
-- It's generally bad style to use CREATE OR REPLACE unnecessarily.
-- Test what happens if an extension does it anyway.
-- Replacing a shell type or operator is sort of like CREATE OR REPLACE;
-- check that too.

CREATE FUNCTION ext_cor_func() RETURNS text
  AS $$ SELECT 'ext_cor_func: original'::text $$ LANGUAGE sql;

CREATE EXTENSION test_ext_cor;  -- fail

SELECT ext_cor_func();

DROP FUNCTION ext_cor_func();

CREATE VIEW ext_cor_view AS
  SELECT 'ext_cor_view: original'::text AS col;

CREATE EXTENSION test_ext_cor;  -- fail

SELECT ext_cor_func();

SELECT * FROM ext_cor_view;

DROP VIEW ext_cor_view;

CREATE TYPE test_ext_type;

CREATE EXTENSION test_ext_cor;  -- fail

DROP TYPE test_ext_type;

-- this makes a shell "point <<@@ polygon" operator too
CREATE OPERATOR @@>> ( PROCEDURE = poly_contain_pt,
  LEFTARG = polygon, RIGHTARG = point,
  COMMUTATOR = <<@@ );

CREATE EXTENSION test_ext_cor;  -- fail

DROP OPERATOR <<@@ (point, polygon);

CREATE EXTENSION test_ext_cor;  -- now it should work

SELECT ext_cor_func();

SELECT * FROM ext_cor_view;

SELECT 'x'::test_ext_type;

SELECT point(0,0) <<@@ polygon(circle(point(0,0),1));

\dx+ test_ext_cor

--
-- CREATE IF NOT EXISTS is an entirely unsound thing for an extension
-- to be doing, but let's at least plug the major security hole in it.
--

CREATE SCHEMA ext_cine_schema;
CREATE EXTENSION test_ext_cine;  -- fail
DROP SCHEMA ext_cine_schema;

CREATE TABLE ext_cine_tab1 (x int);
CREATE EXTENSION test_ext_cine;  -- fail
DROP TABLE ext_cine_tab1;

CREATE EXTENSION test_ext_cine;
\dx+ test_ext_cine
ALTER EXTENSION test_ext_cine UPDATE TO '1.1';
\dx+ test_ext_cine

--
-- test case for `create extension ... with schema version from unpackaged`
-- (related to problem: https://github.com/greenplum-db/gpdb/issues/6716)
--

-- create schema for extension (and it's functions) and reset search_path to new schema 
show search_path;
create schema foo;
set search_path=foo;

-- Create extension functions. Code copied from from test_ext_unpackaged--1.0.sql
-- to run 
create function test_func1(a int, b int) returns int
as $$
begin
	return a + b;
end;
$$
LANGUAGE plpgsql;

create function test_func2(a int, b int) returns int
as $$
begin
	return a - b;
end;
$$
LANGUAGE plpgsql;

-- restore search path
reset search_path;

begin;
-- change search_path
set search_path=pg_catalog;
show search_path;

-- create extension in schema foo
create extension test_ext_unpackaged with schema foo version '1.1' from unpackaged;

-- check that search path doesn't changed after create extension
show search_path;

-- show functions at schema foo (check that create extension works correctly)
set search_path=foo;
\df

SELECT e.extname, ne.nspname AS extschema, p.proname, np.nspname AS proschema
FROM pg_catalog.pg_extension AS e
    INNER JOIN pg_catalog.pg_depend AS d ON (d.refobjid = e.oid)
    INNER JOIN pg_catalog.pg_proc AS p ON (p.oid = d.objid)
    INNER JOIN pg_catalog.pg_namespace AS ne ON (ne.oid = e.extnamespace)
    INNER JOIN pg_catalog.pg_namespace AS np ON (np.oid = p.pronamespace)
WHERE d.deptype = 'e' and e.extname = 'test_ext_unpackaged'
ORDER BY 1, 3;

rollback;

drop schema foo cascade;
