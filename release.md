**Arenadata DB 5.3.0 includes these new features.**
==================================================

**Greenplum Parameter optimizer_join_order**
**citext Data Type**

Greenplum Parameter optimizer_join_order
*When GPORCA is enabled, this parameter sets the optimization level for join ordering during query optimization by specifying which types of join ordering alternatives to evaluate.*

query - Uses the join order specified in the query.
greedy - Evaluates the join order specified in the query and alternatives based on minimum cardinalities of the relations in the joins.
exhaustive - Applies transformation rules to find and evaluate all join ordering alternatives.
The default value is exhaustive. Setting this parameter to query or greedy can generate a suboptimal query plan. However, if the administrator is confident that a satisfactory plan is generated with the query or greedy setting, query optimization time can be improved by setting the parameter to the lower optimization level.

Setting this parameter to query or greedy overrides the optimizer_join_order_threshold and optimizer_join_arity_for_associativity_commutativity parameters.

This parameter can be set for an individual database, a session, or a query.

**citext Data Type**
Arenadata DB 5.3.0 includes the PostgreSQL citext module. The module provides the case-insensitive character string type citext that makes performing case-insensitive comparison easier. Essentially, the function lower() is called internally when comparing citext values. Otherwise, it behaves almost exactly like the text data type.

For information about the citext data type, see the Greenplum Database Utility Guide.


Experimental Features
=====================
**Key experimental features in Arenadata DB 5.3.0 include:**
gpbackup and gprestore are experimental utilities that are designed to improve the performance, functionality, and reliability of backups as compared to gpcrondump and gpdbrestore. gpbackup utilizes ACCESS SHARE locks at the individual table level, instead of EXCLUSIVE locks on the pg_class catalog table. This enables you to execute DDL statements during the backup, such as CREATE, ALTER, DROP, and TRUNCATE operations, as long as those operations do not target the current backup set.
In Greenplum Database 5.3.0, gpbackup and gprestore include these new features.
gpbackup lets you specify the gzip compression level for data files with the --compression-level option. A valid level is an integer between 1 and 9. gpbackup uses the default compression level of 1.
gpbackup can optionally create a single backup file per segment instance when you specify the -single-data-file option. By default, gpbackup creates one .csv file per table, per segment, during a backup operation.
gprestore now supports restoring specific schemas and tables in a backup set using the -include-schema and -include-table-file options.
Backup files created with gpbackup are designed to provide future capabilities for restoring individual database objects along with their dependencies, such as functions and required user-defined datatypes. See Parallel Backup with gpbackup and gprestore for more information.
Greenplum PL/Container Extension. Greenplum PL/Container Extension
Recursive WITH Queries (Common Table Expressions). See WITH Queries (Common Table Expressions).
Writing text and SequenceFile binary format data to HDFS using the Greenplum Platform Extension Framework (PXF). See Writing Data to HDFS with PXF (Experimental).

Resolved Issues
===============
**The listed issues that are resolved in Arenadata DB 5.3.0**

 - 29148 - PL/pgSQL, 3674 - Query Execution
In some cases, INSERT commands acquired a table lock in Greenplum Database 5.x. This was a change from Greenplum Database 4.3.x releases.
This issue has been resolved. INSERT commands no longer acquire a table lock.

 - 29143 - S3
In some cases when inserting a large amount of data to an external table defined with s3 protocol, the operation failed when AWS returned a RequestTimeout error. The s3 protocol did not retry writing to the S3 data source.
This issue has been resolved. The s3 protocol has been enhanced to retry writing to the AWS S3 data store when a RequestTimeout error occurs.

 - 29132 - S3
When inserting data into a Greenplum Database writable external table that is defined with the s3 protocol and is configured to use compression, the data was not stored in compressed format in the S3 data store.
This issue has been resolved. Now the data is stored in compressed format in the S3 data store.

 - 29129 - Query Execution
In some cases, when Greenplum Database memory consumption was extremely high, the runaway query termination mechanism that is used to free memory caused a Greenplum Database PANIC. The query termination mechanism did not terminate some query sessions correctly.
This issue has been resolved. The selection and termination methods for the termination mechanism have been improved.

 - 29008 - Query Optimizer
For some queries that could use a Bitmap index, GPORCA did not choose a bitmap index scan because an incorrect cost model was used to cost bitmap scans. This caused GPORCA to choose a less efficient query plan.
This issue has been resolved. GPORCA now uses a cost model that chooses a plan with a bitmap index scan whenever applicable.

 - 3490 - Backup and Restore
The Greenplum Database backup and restore utilities gpcrondump, gpdbrestore, pg_dump, and pg_restore had limited support for backing up and restoring partitioned tables that have been altered by exchanging a leaf child partition with a readable external table.
You could not back up and restore multi-level partitioned tables when a leaf child partition is a readable external table. You can back up and restore single-level partitioned tables when a leaf child partition is a readable external table if the partitions are named partitions (partitionname in the pg_partitions system view is not NULL for the partition).
This issue has been resolved. The utilities support backing up and restoring the specified type of table.

 - 152456087 - Query Optimizer
For queries against only partitioned tables where the number of table joins is greater than 2, and the exhaustive join ordering algorithm was disabled, GPORCA generated a plan that did not use Hash Join based implementation of joins.
This issue has been resolved. GPORCA now generates plans that use a more efficient Hash Joint in the specified situation.

 - 152455099 - Query Optimizer
For some queries, GPORCA generated join ordering alternatives that were swaps of join predicates rather than a change of the order of the join participants. These join ordering alternatives degraded GPORCA performance by causing unnecessary plan alternatives to be generated.
This issue has been resolved. Now GPORCA does not generate join ordering alternatives that are swaps of join predicates.

 - 151530276 - Query Optimizer
When generating a query plan, GPORCA did not recognize requests to interrupt and abort query optimization when processing queries that have long optimization time resulting in the VMEM limit being reached or the system becoming unstable.
This issue has been resolved. Now GPORCA aborts query optimization when it receives an interrupt request in the specified situations.

Known Issues and Limitations
============================
 - 151135629	COPY command	When the ON SEGMENT clause is specified, the COPY command does not support specifying a SELECT statement in the COPY TO clause. For example, this command is not supported.
COPY (SELECT * FROM testtbl) TO '/tmp/mytst<SEGID>' ON SEGMENT

 - 29064	Storage: DDL	The money data type accepts out-of-range values as negative values, and no error message is displayed.
Workaround: Use only in-range values for the money data type (32-bit for Greenplum Database 4.x, or 64-bit for Greenplum Database 5.x). Or, use an alternative data type such as numeric or decimal.

 - 3290	JSON	The to_json() function is not implemented as a callable function. Attempting to call the function results in an error. For example:
tutorial=# select to_json('Fred said "Hi."'::text); 
ERROR: function to_json(text) does not exist
LINE 1: select to_json('Fred said "Hi."'::text);
^
HINT: No function matches the given name and argument types. 
You might need to add explicit type casts.
Workaround: Greenplum Database invokes to_json() internally when casting to the json data type, so perform a cast instead. For example: SELECT '{"foo":"bar"}'::json; Greenplum Database also provides the array_to_json() and row_to_json() functions.

 - 148119917	Resource Groups	Testing of the resource groups feature has found that a kernel panic can occur when using the default kernel in RHEL/CentOS system. The problem occurs due to a problem in the kernel cgroups implementation, and results in a kernel panic backtrace similar to:
[81375.325947] BUG: unable to handle kernel NULL pointer dereference at 0000000000000010
      [81375.325986] IP: [<ffffffff812f94b1>] rb_next+0x1/0x50 [81375.326014] PGD 0 [81375.326025]
      Oops: 0000 [#1] SMP [81375.326041] Modules linked in: veth ipt_MASQUERADE
      nf_nat_masquerade_ipv4 iptable_nat nf_conntrack_ipv4 nf_defrag_ipv4 nf_nat_ipv4 xt_addrtype
      iptable_filter xt_conntrack nf_nat nf_conntrack bridge stp llc intel_powerclamp coretemp
      intel_rapl dm_thin_pool dm_persistent_data dm_bio_prison dm_bufio kvm_intel kvm crc32_pclmul
      ghash_clmulni_intel aesni_intel lrw gf128mul glue_helper ablk_helper cryptd iTCO_wdt
      iTCO_vendor_support ses enclosure ipmi_ssif pcspkr lpc_ich sg sb_edac mfd_core edac_core
      mei_me ipmi_si mei wmi ipmi_msghandler shpchp acpi_power_meter acpi_pad ip_tables xfs
      libcrc32c sd_mod crc_t10dif crct10dif_generic mgag200 syscopyarea sysfillrect crct10dif_pclmul
      sysimgblt crct10dif_common crc32c_intel drm_kms_helper ixgbe ttm mdio ahci igb libahci drm ptp
      pps_core libata dca i2c_algo_bit [81375.326369]  i2c_core megaraid_sas dm_mirror
      dm_region_hash dm_log dm_mod [81375.326396] CPU: 17 PID: 0 Comm: swapper/17 Not tainted
      3.10.0-327.el7.x86_64 #1 [81375.326422] Hardware name: Cisco Systems Inc
      UCSC-C240-M4L/UCSC-C240-M4L, BIOS C240M4.2.0.8b.0.080620151546 08/06/2015 [81375.326459] task:
      ffff88140ecec500 ti: ffff88140ed10000 task.ti: ffff88140ed10000 [81375.326485] RIP:
      0010:[<ffffffff812f94b1>]  [<ffffffff812f94b1>] rb_next+0x1/0x50 [81375.326514] RSP:
      0018:ffff88140ed13e10  EFLAGS: 00010046 [81375.326534] RAX: 0000000000000000 RBX:
      0000000000000000 RCX: 0000000000000000 [81375.326559] RDX: ffff88282f1d4800 RSI:
      ffff88280bc0f140 RDI: 0000000000000010 [81375.326584] RBP: ffff88140ed13e58 R08:
      0000000000000000 R09: 0000000000000001 [81375.326609] R10: 0000000000000000 R11:
      0000000000000001 R12: ffff88280b0e7000 [81375.326634] R13: 0000000000000000 R14:
      0000000000000000 R15: 0000000000b6f979 [81375.326659] FS:  0000000000000000(0000)
      GS:ffff88282f1c0000(0000) knlGS:0000000000000000 [81375.326688] CS:  0010 DS: 0000 ES: 0000
      CR0: 0000000080050033 [81375.326708] CR2: 0000000000000010 CR3: 000000000194a000 CR4:
      00000000001407e0 [81375.326733] DR0: 0000000000000000 DR1: 0000000000000000 DR2:
      0000000000000000 [81375.326758] DR3: 0000000000000000 DR6: 00000000ffff0ff0 DR7:
      0000000000000400 [81375.326783] Stack: [81375.326792]  ffff88140ed13e58 ffffffff810bf539
      ffff88282f1d4780 ffff88282f1d4780 [81375.326826]  ffff88140ececae8 ffff88282f1d4780
      0000000000000011 ffff88140ed10000 [81375.326861]  0000000000000000 ffff88140ed13eb8
      ffffffff8163a10a ffff88140ecec500 [81375.326895] Call Trace: [81375.326912]
      [<ffffffff810bf539>] ? pick_next_task_fair+0x129/0x1d0 [81375.326940]  [<ffffffff8163a10a>]
      __schedule+0x12a/0x900 [81375.326961]  [<ffffffff8163b9e9>] schedule_preempt_disabled+0x29/0x70
      [81375.326987]  [<ffffffff810d6244>] cpu_startup_entry+0x184/0x290 [81375.327011]
      [<ffffffff810475fa>] start_secondary+0x1ba/0x230 [81375.327032] Code: e5 48 85 c0 75 07 eb 19 66
      90 48 89 d0 48 8b 50 10 48 85 d2 75 f4 48 8b 50 08 48 85 d2 75 eb 5d c3 31 c0 5d c3 0f 1f 44
      00 00 55 <48> 8b 17 48 89 e5 48 39 d7 74 3b 48 8b 47 08 48 85 c0 75 0e eb [81375.327157] RIP
      [<ffffffff812f94b1>] rb_next+0x1/0x50 [81375.327179]  RSP <ffff88140ed13e10> [81375.327192] CR2:
      0000000000000010
Workaround: Upgrade to the latest-available kernel for your Red Hat or CentOS release to avoid the above system panic.

 - 149789783	Resource Groups	Significant Greenplum performance degradation has been observed when enabling resource group-based workload management on Red Hat 6.x, CentOS 6.x, and SuSE 11 systems. This issue is caused by a Linux cgroup kernel bug. This kernel bug has been fixed in CentOS 7.x and Red Hat 7.x systems.
When resource groups are enabled on systems with an affected kernel, there can be a delay of 1 second or longer when starting a transaction or a query. The delay is caused by a Linux cgroup kernel bug where a synchronization mechanism called synchronize_sched is abused when a process is attached to a cgroup. See http://www.spinics.net/lists/cgroups/msg05708.html and https://lkml.org/lkml/2013/1/14/97 for more information.

The issue causes single attachment operations to take longer and also causes all concurrent attachments to be executed in sequence. For example, one process attachment could take about 0.01 second. When concurrently attaching 100 processes, the fastest process attachment takes 0.01 second and the slowest takes about 1 second. So the performance degradation is dependent on concurrent started transactions or queries, and not related to concurrent running queries.

Workaround: This bug does not affect CentOS 7.x and Red Hat 7.x systems.

If you use Red Hat 6 and the performance with resource groups is acceptable for your use case, upgrade your kernel to version 2.6.32-696 or higher to benefit from other fixes to the cgroups implementation.


 - 150906510	Backup and Restore	Greenplum Database 4.3.15.0 and later backups contain the following line in the backup files:
SET gp_strict_xml_parse = false;
However, Greenplum Database 5.0.0 does not have a parameter named gp_strict_xml_parse. When you restore the 4.3 backup set to the 5.0.0 cluster, you may see the warning:

[WARNING]:-gpdbrestore finished but ERRORS were found, please check the restore report file for details
Also, the report file may contain the error:

ERROR:  unrecognized configuration parameter "gp_strict_xml_parse"
These warnings and errors do not affect the restoration procedure, and can be ignored.





























