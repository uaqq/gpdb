/* src/test/modules/test_extensions/test_ext_unpackaged--1.0--1.1.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "ALTER EXTENSION test_ext_unpackaged" to load this file. \quit

ALTER EXTENSION test_ext_unpackaged DROP function test_func1(int, int);
