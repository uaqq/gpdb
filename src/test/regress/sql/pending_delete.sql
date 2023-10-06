-- start_ignore
create extension if not exists gp_inject_fault;
create extension if not exists plpython3u;
-- end_ignore

-- Helper.
-- Call pg_waldump over given WAL file and find last PENDING_DELETE record.
-- Return its content.
create or replace procedure find_last_pending_delete_record(wal_name text, data_dir text)
as $$
    import os

    cmd = 'pg_waldump %s -p %s/pg_wal | grep PENDING_DELETE | tail -1' % (wal_name, data_dir)
    res = os.popen(cmd).read()
    if res:
        pos = res.find('PENDING_DELETE')
        plpy.notice(res[pos:])
$$ language plpython3u;

-- Helper.
-- Print content of last PENDING_DELETE record on coordinator and all segments.
create or replace procedure print_pending_delete()
language plpgsql as $$
declare
    d text;
    w text;
begin
    for d, w in
        select t1.datadir, t2.walname
        from(
            select content, datadir 
            from gp_segment_configuration
            where role = 'p'
        ) t1
        join(
            select gp_segment_id, pg_walfile_name(pg_current_wal_lsn()) walname
            from gp_dist_random('gp_id')
            union all
            select -1, pg_walfile_name(pg_current_wal_lsn())
        ) t2 on t1.content = t2.gp_segment_id
        order by t1.content
    loop
        call find_last_pending_delete_record(w, d);
    end loop;
end $$;

-- Prepare for tests. Force checkpoint so the planned one can't interfere tests.
select gp_inject_fault('checkpoint_control_file_updated', 'skip', dbid)
from gp_segment_configuration WHERE role='p';
checkpoint;
select gp_inject_fault('checkpoint_control_file_updated', 'reset', dbid)
from gp_segment_configuration WHERE role='p';

-- Define a point, which is the same for 3 tests
select gp_inject_fault_infinite('checkpoint_control_file_updated', 'skip', dbid)
from gp_segment_configuration WHERE role='p';

-- Test 1
-- Create AO table and check that nodes count in xlog record is correct.
begin;
create table if not exists test_ao(i int) with (appendonly=true);
insert into test_ao select generate_series(1, 10000);
checkpoint;
select gp_wait_until_triggered_fault('checkpoint_control_file_updated', 1, dbid)
from gp_segment_configuration WHERE role='p';
call print_pending_delete();
rollback;

-- Test 2
-- Create heap table and check that nodes count in xlog record is correct.
begin;
create table if not exists test_heap(i int);
insert into test_heap select generate_series(1, 10000);
checkpoint;
select gp_wait_until_triggered_fault('checkpoint_control_file_updated', 2, dbid)
from gp_segment_configuration WHERE role='p';
call print_pending_delete();
rollback;

-- Test 3
-- Create table out of explicit transaction. Shmem list is empty as transaction is completed.
-- print_pending_delete() will show previous records.
create table if not exists test_heap(i int);
insert into test_heap select generate_series(1, 10000);
checkpoint;
select gp_wait_until_triggered_fault('checkpoint_control_file_updated', 3, dbid)
from gp_segment_configuration WHERE role='p';
call print_pending_delete();
drop table if exists test_heap;

-- Reset point
select gp_inject_fault_infinite('checkpoint_control_file_updated', 'reset', dbid)
from gp_segment_configuration WHERE role='p';

-- start_ignore
drop procedure if exists print_pending_delete();
drop procedure if exists find_last_pending_delete_record(text, text);
-- end_ignore
