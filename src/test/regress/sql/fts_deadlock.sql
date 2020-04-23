--
-- Test queries that can lead to deadlock on the gp_segment_configuration table
-- between the QD backend and FTS. The queries could be gp_add_segment_mirror()
-- and gp_remove_segment_mirror(), both are called during gprecoverseg.
--

-- start_ignore
create language plpythonu;
create language plpgsql;
CREATE EXTENSION IF NOT EXISTS gp_inject_fault;
-- end_ignore

create or replace function stop_segment(datadir text)
returns text as $$
    import subprocess
    cmd = 'pg_ctl -l postmaster.log -D %s -w -m immediate stop' % datadir
    return subprocess.check_output(cmd, stderr=subprocess.STDOUT, shell=True).replace('.', '')
$$ language plpythonu;

-- Wait for content 0 to assume specified mode
create or replace function wait_for_content0(target_mode char) /*in func*/
returns void as $$ /*in func*/
declare /*in func*/
    iterations int := 0; /*in func*/
begin /*in func*/
    while iterations < 120 loop /*in func*/
        perform pg_sleep(1); /*in func*/
        if exists (select * from gp_segment_configuration where content = 0 and mode = target_mode) then /*in func*/
                return; /*in func*/
        end if; /*in func*/
        iterations := iterations + 1; /*in func*/
    end loop; /*in func*/
end $$ /*in func*/
language plpgsql;

-- Stop content 0 primary and let the mirror take over
select stop_segment(fselocation) from pg_filespace_entry fe, gp_segment_configuration c, pg_filespace f
where fe.fsedbid = c.dbid and c.content=0 and c.role='m' and f.oid = fe.fsefsoid and f.fsname = 'pg_system';

select wait_for_content0('c');

SELECT gp_inject_fault('add_segment_persistent_entries', 'sleep', '', '', '', 1, 70, 2::smallint);

-- start_ignore
\! gprecoverseg -a -F;
-- end_ignore

select wait_for_content0('s');

select gp_inject_fault('add_segment_persistent_entries', 'reset', 2);
