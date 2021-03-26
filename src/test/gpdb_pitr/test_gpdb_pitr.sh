#!/usr/bin/env bash

## ==================================================================
## Required: A fresh gpdemo cluster with mirrors sourced.
##
## This script tests and showcases a very simple Point-In-Time
## Recovery scenario by utilizing WAL Archiving and restore
## points. This test also demonstrates the commit blocking during
## distributed restore point creation during concurrent transactions
## to guarantee cluster consistency.
##
## Note: After successfully running this test, the PITR cluster will
## still be up and running from the temp_test directory. Run the
## `clean` Makefile target to go back to the gpdemo cluster.
## ==================================================================

# Store gpdemo master and primary segment data directories.
# This assumes default settings for the ports and data directories.
DATADIR="${COORDINATOR_DATA_DIRECTORY%*/*/*}"
MASTER=${DATADIR}/qddir/demoDataDir-1
PRIMARY1=${DATADIR}/dbfast1/demoDataDir0
PRIMARY2=${DATADIR}/dbfast2/demoDataDir1
PRIMARY3=${DATADIR}/dbfast3/demoDataDir2
MIRROR1=${DATADIR}/dbfast_mirror1/demoDataDir0
MIRROR2=${DATADIR}/dbfast_mirror2/demoDataDir1
MIRROR3=${DATADIR}/dbfast_mirror3/demoDataDir2
MASTER_PORT=7000
PRIMARY1_PORT=7002
PRIMARY2_PORT=7003
PRIMARY3_PORT=7004
# Mirrors copy primaries' data
MIRROR1_PORT=7002
MIRROR2_PORT=7003
MIRROR3_PORT=7004

# Set up temporary directories to store the basebackups and the WAL
# archives that will be used for Point-In-Time Recovery later.
TEMP_DIR=$PWD/temp_test
REPLICA_MASTER=$TEMP_DIR/replica_c
REPLICA_PRIMARY1=$TEMP_DIR/replica_p1
REPLICA_PRIMARY2=$TEMP_DIR/replica_p2
REPLICA_PRIMARY3=$TEMP_DIR/replica_p3
REPLICA_STANDBY=$TEMP_DIR/replica_s
REPLICA_MIRROR1=$TEMP_DIR/replica_m1
REPLICA_MIRROR2=$TEMP_DIR/replica_m2
REPLICA_MIRROR3=$TEMP_DIR/replica_m3

REPLICA_MIRROR1_PORT=7005
REPLICA_MIRROR2_PORT=7006
REPLICA_MIRROR3_PORT=7007

ARCHIVE_PREFIX=$TEMP_DIR/archive_seg

REPLICA_MASTER_DBID=10
REPLICA_PRIMARY1_DBID=11
REPLICA_PRIMARY2_DBID=12
REPLICA_PRIMARY3_DBID=13
REPLICA_STANDBY_DBID=100
REPLICA_MIRROR1_DBID=101
REPLICA_MIRROR2_DBID=102
REPLICA_MIRROR3_DBID=103

# The options for pg_regress and pg_isolation2_regress.
REGRESS_OPTS="--dbname=gpdb_pitr_database --use-existing --init-file=../regress/init_file --load-extension=gp_inject_fault"
ISOLATION2_REGRESS_OPTS="${REGRESS_OPTS} --init-file=../isolation2/init_file_isolation2"

# Run test via pg_regress with given test name.
run_test()
{
    ../regress/pg_regress $REGRESS_OPTS $1
    if [ $? != 0 ]; then
        exit 1
    fi
}

# Run test via pg_isolation2_regress with given test name. The
# isolation2 framework is mainly used to demonstrate the commit
# blocking scenario.
run_test_isolation2()
{
    ../isolation2/pg_isolation2_regress $ISOLATION2_REGRESS_OPTS $1
    if [ $? != 0 ]; then
        exit 1
    fi
}

# Remove temporary test directory if it already exists.
[ -d $TEMP_DIR ] && rm -rf $TEMP_DIR

# Set up WAL Archiving by updating the postgresql.conf files of the
# master and primary segments. Afterwards, restart the cluster to load
# the new settings.
echo "Setting up WAL Archiving configurations..."
for segment_role in MASTER PRIMARY1 PRIMARY2 PRIMARY3; do
  DATADIR_VAR=$segment_role
  echo "wal_level = replica
archive_mode = on
archive_command = 'cp %p ${ARCHIVE_PREFIX}%c/%f'" >> ${!DATADIR_VAR}/postgresql.conf
done
mkdir -p ${ARCHIVE_PREFIX}{-1,0,1,2}
gpstop -ar -q

# Create the basebackups which will be our replicas for Point-In-Time
# Recovery later.
echo "Creating basebackups..."
for segment_role in MASTER PRIMARY1 PRIMARY2 PRIMARY3 MIRROR1 MIRROR2 MIRROR3; do
  PORT_VAR=${segment_role}_PORT
  REPLICA_VAR=REPLICA_$segment_role
  REPLICA_DBID_VAR=REPLICA_${segment_role}_DBID
  pg_basebackup -h localhost -p ${!PORT_VAR} -X stream -D ${!REPLICA_VAR} --target-gp-dbid ${!REPLICA_DBID_VAR}
done

# Create our test database.
createdb gpdb_pitr_database

# Run setup test. This will create the tables, create the restore
# points, and demonstrate the commit blocking.
run_test_isolation2 gpdb_pitr_setup

run_test gpdb_pitr_step2a
psql gpdb_pitr_database -f sql/gpdb_pitr_step2b.sql | tail -n 4 > step2b.out
psql gpdb_pitr_database -f sql/gpdb_pitr_step2c.sql

run_test gpdb_pitr_step3a
psql gpdb_pitr_database -f sql/gpdb_pitr_step3b.sql | tail -n 4 > step3b.out
psql gpdb_pitr_database -f sql/gpdb_pitr_step3c.sql

# Stop the gpdemo cluster. We'll be focusing on the PITR cluster from
# now onwards.
echo "Stopping gpdemo cluster to now focus on PITR cluster..."
gpstop -a -q

# Copy configuration files for mirror from original mirror data directories
for segment_role in MIRROR1 MIRROR2 MIRROR3; do
  REPLICA_VAR=REPLICA_$segment_role
  cp -f ${!segment_role}/postgresql.conf ${!REPLICA_VAR}/postgresql.conf
  cp -f ${!segment_role}/postgresql.auto.conf ${!REPLICA_VAR}/postgresql.auto.conf
done

# Appending recovery settings to postgresql.conf in all the replicas to setup
# for Point-In-Time Recovery. Specifically, we need to have the restore_command
# and recovery_target_name set up properly. We'll also need to empty out the
# postgresql.auto.conf file to disable synchronous replication on the PITR
# cluster since it won't have mirrors to replicate to.
# Also touch a recovery_finished file in the datadirs to demonstrate that the
# recovery_end_command GUC is functional.
echo "Appending recovery settings to postgresql.conf files in the replicas and starting them up..."
for segment_role in MASTER PRIMARY1 PRIMARY2 PRIMARY3; do
  REPLICA_VAR=REPLICA_$segment_role
  cp ${!REPLICA_VAR}/postgresql.conf ${!REPLICA_VAR}/postgresql.cluster.conf
  echo "restore_command = 'cp ${ARCHIVE_PREFIX}%c/%f %p'
gp_pause_replay_on_recovery_start = on
hot_standby = on
recovery_target_name = 'unreachable_restore_point'
recovery_target_action = 'pause'
recovery_end_command = 'touch ${!REPLICA_VAR}/recovery_finished'" >> ${!REPLICA_VAR}/postgresql.conf
  mv ${!REPLICA_VAR}/postgresql.auto.conf ${!REPLICA_VAR}/postgresql.cluster.auto.conf
  touch ${!REPLICA_VAR}/recovery.signal
  pg_ctl start -D ${!REPLICA_VAR}
done

for sn in 1 2 3; do
  MIRROR_VAR=REPLICA_MIRROR$sn
  cp ${!MIRROR_VAR}/postgresql.conf ${!MIRROR_VAR}/postgresql.cluster.conf
  REPLICA_PORT=PRIMARY${sn}_PORT
  REPLICA_MIRROR_PORT=REPLICA_MIRROR${sn}_PORT
  echo "
hot_standby = on
port = ${!REPLICA_MIRROR_PORT}  # There is port set above, but this setting rewrites it
" >> ${!MIRROR_VAR}/postgresql.conf
  mv ${!MIRROR_VAR}/postgresql.auto.conf ${!MIRROR_VAR}/postgresql.cluster.auto.conf
  touch ${!MIRROR_VAR}/standby.signal
  pg_ctl start -D ${!MIRROR_VAR}
done

# Wait up to 30 seconds for new master to accept connections.
RETRY=60
while true; do
  pg_isready > /dev/null
  if [ $? == 0 ]; then
    break
  fi

  sleep 0.5s
  RETRY=$[$RETRY - 1]
  if [ $RETRY -le 0 ]; then
    echo "FAIL: Timed out waiting for new master to accept connections."
    exit 1
  fi
done

# Replay WALs step-by-step
for segment_n in -1; do
  PORT=$((7000))
  NEXT_LSN=$(cat step2b.out | grep "^$segment_n" | cut --delimiter=' ' -f 2)
  psql postgres -c "SELECT gp_recovery_pause_on_restore_point_lsn('$NEXT_LSN'); SELECT pg_wal_replay_resume();" -p $PORT
  sleep 1
  psql postgres -c "SELECT pg_last_wal_replay_lsn();" -ea -p $PORT
done
for segment_n in 0 1 2; do
  PORT=$((7002 + $segment_n))
  NEXT_LSN=$(cat step2b.out | grep "^$segment_n" | cut --delimiter=' ' -f 2)
  psql postgres -c "SELECT gp_recovery_pause_on_restore_point_lsn('$NEXT_LSN'); SELECT pg_wal_replay_resume();" -p $PORT
  sleep 1
  psql postgres -c "SELECT pg_last_wal_replay_lsn();" -ea -p $PORT
done

for segment_n in -1; do
  PORT=$((7000))
  NEXT_LSN=$(cat step3b.out | grep "^$segment_n" | cut --delimiter=' ' -f 2)
  psql postgres -c "SELECT gp_recovery_pause_on_restore_point_lsn('$NEXT_LSN'); SELECT pg_wal_replay_resume();" -p $PORT
  sleep 1
  psql postgres -c "SELECT pg_last_wal_replay_lsn();" -ea -p $PORT
done
for segment_n in 0 1 2; do
  PORT=$((7002 + $segment_n))
  NEXT_LSN=$(cat step3b.out | grep "^$segment_n" | cut --delimiter=' ' -f 2)
  psql postgres -c "SELECT gp_recovery_pause_on_restore_point_lsn('$NEXT_LSN'); SELECT pg_wal_replay_resume();" -p $PORT
  sleep 1
  psql postgres -c "SELECT pg_last_wal_replay_lsn();" -ea -p $PORT
done

# Promote cluster
for segment_n in -1; do
  PORT=$((7000))
  psql postgres -c "SELECT pg_promote(false); SELECT pg_wal_replay_resume();" -ea -p $PORT
done
for segment_n in 0 1 2; do
  PORT=$((7002 + $segment_n))
  psql postgres -c "SELECT pg_promote(false); SELECT pg_wal_replay_resume();" -ea -p $PORT
done

echo "Sleeping for 3 seconds until promotion is complete..."
sleep 3

echo "Restoring cluster configuration to normal GPDB cluster configuration..."
export COORDINATOR_DATA_DIRECTORY=$REPLICA_MASTER
export MASTER_DATA_DIRECTORY=$REPLICA_MASTER
for segment_role in MASTER PRIMARY1 PRIMARY2 PRIMARY3 MIRROR1 MIRROR2 MIRROR3; do
  REPLICA_VAR=REPLICA_$segment_role
  mv ${!REPLICA_VAR}/postgresql.cluster.conf ${!REPLICA_VAR}/postgresql.conf
  mv ${!REPLICA_VAR}/postgresql.cluster.auto.conf ${!REPLICA_VAR}/postgresql.auto.conf
done

# Reconfigure the segment configuration on the replica master so that
# the other replicas are recognized as primary segments.
echo "Configuring replica master's gp_segment_configuration..."
PGOPTIONS="-c gp_role=utility" psql postgres -c "
SET allow_system_table_mods=true;
UPDATE gp_segment_configuration SET dbid=${REPLICA_MASTER_DBID}, datadir='${REPLICA_MASTER}', mode='n' WHERE content = -1 AND preferred_role='p';
UPDATE gp_segment_configuration SET dbid=${REPLICA_PRIMARY1_DBID}, datadir='${REPLICA_PRIMARY1}', mode='n' WHERE content = 0 AND preferred_role='p';
UPDATE gp_segment_configuration SET dbid=${REPLICA_PRIMARY2_DBID}, datadir='${REPLICA_PRIMARY2}', mode='n' WHERE content = 1 AND preferred_role='p';
UPDATE gp_segment_configuration SET dbid=${REPLICA_PRIMARY3_DBID}, datadir='${REPLICA_PRIMARY3}', mode='n' WHERE content = 2 AND preferred_role='p';
DELETE FROM gp_segment_configuration WHERE content = -1 AND preferred_role='m';
-- UPDATE gp_segment_configuration SET dbid=${REPLICA_STANDBY_DBID}, datadir='${REPLICA_STANDBY}', status='d', mode='n' WHERE content = -1 AND preferred_role='m';
UPDATE gp_segment_configuration SET dbid=${REPLICA_MIRROR1_DBID}, datadir='${REPLICA_MIRROR1}', status='d', mode='n' WHERE content = 0 AND preferred_role='m';
UPDATE gp_segment_configuration SET dbid=${REPLICA_MIRROR2_DBID}, datadir='${REPLICA_MIRROR2}', status='d', mode='n' WHERE content = 1 AND preferred_role='m';
UPDATE gp_segment_configuration SET dbid=${REPLICA_MIRROR3_DBID}, datadir='${REPLICA_MIRROR3}', status='d', mode='n' WHERE content = 2 AND preferred_role='m';
"

gpstop -ar

echo "Recovering mirrors..."
gprecoverseg -v -a

psql postgres -c "
SELECT * FROM gp_segment_configuration;
SET allow_system_table_mods=true;
UPDATE gp_segment_configuration SET status='u';
"

echo "Restarting cluster after all operations..."
gpstop -ar

# Run validation test to confirm we have gone back in time.
run_test gpdb_pitr_validate_new

# Print unnecessary success output.
echo "============================================="
echo "SUCCESS! GPDB Point-In-Time Recovery worked."
echo "============================================="
