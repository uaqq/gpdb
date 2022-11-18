/* contrib/intagg/intagg--1.0.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "ALTER EXTENSION intagg " to load this file. \quit

ALTER EXTENSION intagg DROP function int_agg_state(internal,integer);
-- ALTER EXTENSION intagg ADD function int_agg_final_array(internal);
-- ALTER EXTENSION intagg ADD function int_array_aggregate(integer);
-- ALTER EXTENSION intagg ADD function int_array_enum(integer[]);
