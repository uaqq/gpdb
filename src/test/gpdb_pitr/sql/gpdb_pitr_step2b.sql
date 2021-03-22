-- Step 2: Create another restore point

\pset fieldsep ' '
\pset format unaligned
\pset tuples_only true

SELECT * FROM gp_create_restore_point('step2') AS r(segment_id smallint, restore_lsn pg_lsn);
