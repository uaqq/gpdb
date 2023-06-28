-- start_matchsubs
-- m/ Gather Motion [12]:1  \(slice1; segments: [12]\)/
-- s/ Gather Motion [12]:1  \(slice1; segments: [12]\)/ Gather Motion XXX/
-- m/Memory Usage: \d+\w?B/
-- s/Memory Usage: \d+\w?B/Memory Usage: ###B/
-- m/Buckets: \d+/
-- s/Buckets: \d+/Buckets: ###/
-- m/Batches: \d+/
-- s/Batches: \d+/Batches: ###/
-- m/Execution time: \d+\.\d+ ms/
-- s/Execution time: \d+\.\d+ ms/Execution time: ##.### ms/
-- m/Planning time: \d+\.\d+ ms/
-- s/Planning time: \d+\.\d+ ms/Planning time: ##.### ms/
-- m/\(slice\d+\)    Executor memory: (\d+)\w bytes\./
-- s/Executor memory: (\d+)\w bytes\./Executor memory: (#####)K bytes./
-- m/\(slice\d+\)    Executor memory: (\d+)\w bytes avg x \d+ workers, \d+\w bytes max \(seg\d+\)\./
-- s/Executor memory: (\d+)\w bytes avg x \d+ workers, \d+\w bytes max \(seg\d+\)\./Executor memory: ####K bytes avg x #### workers, ####K bytes max (seg#)./
-- m/Memory used:  \d+\w?B/
-- s/Memory used:  \d+\w?B/Memory used: ###B/
-- end_matchsubs

CREATE TEMP TABLE empty_table(a int, b int);
-- We used to incorrectly report "never executed" for a node that returns 0 rows
-- from every segment. This was misleading because "never executed" should
-- indicate that the node was never executed by its parent.
-- explain_processing_off

EXPLAIN (ANALYZE, TIMING OFF, COSTS OFF) SELECT a FROM empty_table;
-- explain_processing_on

-- For a node that is truly never executed, we still expect "never executed" to
-- be reported
-- explain_processing_off
EXPLAIN (ANALYZE, TIMING OFF, COSTS OFF) SELECT t1.a FROM empty_table t1 join empty_table t2 on t1.a = t2.a;

-- Test with predicate
INSERT INTO empty_table select generate_series(1, 1000)::int as a;
EXPLAIN (ANALYZE, TIMING OFF, COSTS OFF) SELECT a FROM empty_table WHERE b = 2;

ANALYZE empty_table;
EXPLAIN (ANALYZE, TIMING OFF, COSTS OFF) SELECT a FROM empty_table WHERE b = 2;
-- explain_processing_on

--
-- Test EXPLAIN ANALYZE with DECLARE CURSOR.
-- DECLARE CURSOR should not be created if we have ANALYZE in Query.
--

-- start_ignore
DROP TABLE IF EXISTS d,r;
-- end_ignore

CREATE TABLE d (a int, b int, c int) DISTRIBUTED BY (a);
CREATE TABLE r (a int, b int, c char(2)) DISTRIBUTED REPLICATED;

EXPLAIN (ANALYZE on, COSTS off, VERBOSE off)
DECLARE c CURSOR FOR
WITH e AS (
    SELECT b FROM d LIMIT 2
)
SELECT * FROM r
    JOIN (
        SELECT count(*) b FROM e
        ) i USING (b)
    JOIN e USING (b);

DROP TABLE d, r;
