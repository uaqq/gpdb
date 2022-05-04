set optimizer to off;
drop table  if exists pg_stat_test;
create table pg_stat_test(a int);

select
    gp_segment_id,
    schemaname, relname, seq_scan, seq_tup_read, idx_scan, idx_tup_fetch, n_tup_ins, n_tup_upd,
    n_tup_del, n_tup_hot_upd, n_live_tup, n_dead_tup
from gp_dist_random('pg_stat_all_tables_internal') where relname = 'pg_stat_test'
order by gp_segment_id;
select
    schemaname, relname, seq_scan, seq_tup_read, idx_scan, idx_tup_fetch, n_tup_ins, n_tup_upd,
    n_tup_del, n_tup_hot_upd, n_live_tup, n_dead_tup
from pg_stat_all_tables where relname = 'pg_stat_test';
select
    schemaname, relname, seq_scan, seq_tup_read, idx_scan, idx_tup_fetch, n_tup_ins, n_tup_upd,
    n_tup_del, n_tup_hot_upd, n_live_tup, n_dead_tup
from pg_stat_user_tables where relname = 'pg_stat_test';
select
    schemaname, relname, indexrelname, idx_scan, idx_tup_read, idx_tup_fetch
from pg_stat_all_indexes where relname = 'pg_stat_test';
select
    schemaname, relname, indexrelname, idx_scan, idx_tup_read, idx_tup_fetch
from pg_stat_user_indexes where relname = 'pg_stat_test';

begin; -- make analyze same transcation with insert to avoid double the pgstat causes by unorder message read.
insert into pg_stat_test select * from generate_series(1, 100);
analyze pg_stat_test;
commit;

create index pg_stat_user_table_index on pg_stat_test(a);

select count(*) from pg_stat_test;

delete from pg_stat_test where a < 10;

-- FIXME: update operation doesn't increment scan-related counters
-- they are repaired after next selection query with index scan
update pg_stat_test set a = 1000 where a > 90;

set enable_seqscan to off;
select pg_sleep(10);
select * from pg_stat_test where a = 1;
reset enable_seqscan;

-- wait until statistics on all segments will be updated
select pg_sleep(1) from gp_dist_random('gp_id');

select
    gp_segment_id,
    schemaname, relname, seq_scan, seq_tup_read, idx_scan, idx_tup_fetch, n_tup_ins, n_tup_upd,
    n_tup_del, n_tup_hot_upd, n_live_tup, n_dead_tup
from gp_dist_random('pg_stat_all_tables_internal') where relname = 'pg_stat_test'
order by gp_segment_id;
select
    schemaname, relname, seq_scan, seq_tup_read, idx_scan, idx_tup_fetch, n_tup_ins, n_tup_upd,
    n_tup_del, n_tup_hot_upd, n_live_tup, n_dead_tup, n_mod_since_analyze
from pg_stat_all_tables where relname = 'pg_stat_test';
select
    schemaname, relname, seq_scan, seq_tup_read, idx_scan, idx_tup_fetch, n_tup_ins, n_tup_upd,
    n_tup_del, n_tup_hot_upd, n_live_tup, n_dead_tup, n_mod_since_analyze
from pg_stat_user_tables where relname = 'pg_stat_test';
select
    gp_segment_id,
    schemaname, relname, indexrelname, idx_scan, idx_tup_read, idx_tup_fetch
from gp_dist_random('pg_stat_all_indexes_internal') where relname = 'pg_stat_test'
order by gp_segment_id;
select
    schemaname, relname, indexrelname, idx_scan, idx_tup_read, idx_tup_fetch
from pg_stat_all_indexes where relname = 'pg_stat_test';
select
    schemaname, relname, indexrelname, idx_scan, idx_tup_read, idx_tup_fetch
from pg_stat_user_indexes where relname = 'pg_stat_test';

-- Verify transactional counters
begin;
insert into pg_stat_test select * from generate_series(1, 9);
select count(*) from pg_stat_test;
delete from pg_stat_test where a < 10;
update pg_stat_test set a = 100 where a >= 1000;
set enable_seqscan to off;
select * from pg_stat_test where a = 1;
reset enable_seqscan;

-- FIXME: the last update operation haven't incremented scan-related counters
select
    gp_segment_id,
    schemaname, relname, seq_scan, seq_tup_read, idx_scan, idx_tup_fetch, n_tup_ins, n_tup_upd,
    n_tup_del, n_tup_hot_upd
from gp_dist_random('pg_stat_xact_all_tables_internal') where relname = 'pg_stat_test'
order by gp_segment_id;
-- FIXME: distributed view pg_stat_xact_all_tables returns zero counters
--  select
    --  schemaname, relname, seq_scan, seq_tup_read, idx_scan, idx_tup_fetch, n_tup_ins, n_tup_upd,
    --  n_tup_del, n_tup_hot_upd
--  from pg_stat_xact_all_tables where relname = 'pg_stat_test';
rollback;

reset optimizer;
