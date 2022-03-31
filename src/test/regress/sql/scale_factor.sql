create table scale_factor_repl(c1 int, c2 int) distributed replicated;
create table scale_factor_distr(c1 int, c2 int) distributed by (c1);
create table scale_factor_rand_distr(c1 int, c2 int);
create table scale_factor_partitioned (a int) partition by range(a) (start(1) end(10) every(1));

set allow_system_table_mods = on;
create table scale_factor_part_distr(c1 int, c2 int) distributed by(c1);
update gp_distribution_policy set numsegments = 2 where localoid = 'scale_factor_part_distr'::regclass;
reset allow_system_table_mods;

insert into scale_factor_repl select i,i from generate_series(1, 10)i;
insert into scale_factor_distr select i,i from generate_series(1, 10)i;
insert into scale_factor_rand_distr select i,i from generate_series(5, 15)i;
insert into scale_factor_part_distr select i,i from generate_series(1, 10)i;
insert into scale_factor_partitioned values (1), (1), (1);

analyze scale_factor_repl;
analyze scale_factor_distr;
analyze scale_factor_rand_distr;
analyze scale_factor_part_distr;
analyze scale_factor_partitioned;

--
-- scaleFactor, motion_snd and motion_recv definition tests
-- Test cases cover conditions refactored or removed
-- from the old ExplainNode implementation.
--

set optimizer = off;

-- CdbPathLocus_IsSingleQE (PO)
explain select * from scale_factor_distr where c2 < (select c1/2 from scale_factor_rand_distr limit 3);

-- CdbPathLocus_IsSegmentGeneral (PO)
explain select * from scale_factor_repl limit 1;

-- Direct dispatch (PO)
explain select * from scale_factor_distr where c1 = 2 or c1 = 5;

reset optimizer;

-- Direct dispatch (ORCA)
explain select count(*) from scale_factor_partitioned where a = 1;

-- Partial table (fallback to PO)
explain select * from scale_factor_part_distr;

-- Explicit Gather Motion
explain update scale_factor_repl a set c1 = b.c2 from scale_factor_part_distr b returning *;

-- Explicit Redistribute Motion
explain update scale_factor_part_distr pd set c2=(select c2 from scale_factor_distr d where pd.c1 = d.c1);

--
-- Previously erroneous cases:
--

-- node(s) above Gather Motion in slice0 (used to show incorrect value for ORCA)
explain select t1.c1, row_number() over (order by t1.c1 desc) from scale_factor_distr t1 join scale_factor_distr t2 using(c2);


drop table scale_factor_repl;
drop table scale_factor_distr;
drop table scale_factor_rand_distr;
drop table scale_factor_part_distr;
drop table scale_factor_partitioned;
