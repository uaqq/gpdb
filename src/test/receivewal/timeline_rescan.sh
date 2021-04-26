#!/usr/bin/env bash


RUN_STAMP=$(date +%M)


# Initial state: gpdemo with ONE primary-mirror pair

DIR_TEMP=$PWD/temp

[ -d ${DIR_TEMP} ] && rm -rf ${DIR_TEMP}
mkdir ${DIR_TEMP}


# Original cluster

DIR_DATA="${COORDINATOR_DATA_DIRECTORY%*/*/*}"

COORDINATOR_DIR=${DIR_DATA}/qddir/demoDataDir-1
COORDINATOR_PORT=7000

PRIMARY1_DIR=${DIR_DATA}/dbfast1/demoDataDir0
PRIMARY1_PORT=7002

MIRROR1_DIR=${DIR_DATA}/dbfast_mirror1/demoDataDir0
MIRROR1_PORT=7003


# Replica (a single PostgreSQL instance, for segment '1' of the original cluster)

REPLICA_DBID=2
REPLICA_DIR=${DIR_TEMP}/replica

WAL_ARCHIVE_DIR=${DIR_TEMP}/wal_archive
mkdir ${WAL_ARCHIVE_DIR}


# Script run variables

RECEIVEWAL_PRIMARY_PID=-1
RECEIVEWAL_MIRROR_PID=-1


# ASSUME the GPDB cluster is running normally at this point


echo ">>> Creating basebackup of primary1"
pg_basebackup -h localhost -p ${PRIMARY1_PORT} -X stream -D ${REPLICA_DIR} --target-gp-dbid ${REPLICA_DBID}
echo "<<<"

echo ">>> Modifying primary1's configuration to enable WAL archiving"
echo "
wait_for_replication_threshold = 0
archive_mode = 'always'
archive_command = '$PWD/archive_command.sh %p ${WAL_ARCHIVE_DIR}/%f'
" >> ${PRIMARY1_DIR}/postgresql.conf
echo "
wait_for_replication_threshold = 0
archive_mode = 'always'
archive_command = '$PWD/archive_command.sh %p ${WAL_ARCHIVE_DIR}/%f'
" >> ${MIRROR1_DIR}/postgresql.conf
echo "<<<"

echo ">>> Restarting cluster to start archiving"
gpstop -M smart -a -r
echo "<<<"

echo ">>> Generating changes, creating a restore point 1, switching WAL"
psql postgres -ea -c "CHECKPOINT;"
psql postgres -ea -c "DROP SCHEMA IF EXISTS faulty CASCADE; CREATE SCHEMA faulty;"
psql postgres -ea -c "CREATE TABLE faulty.t(i INT);"
psql postgres -ea -c "INSERT INTO faulty.t(i) VALUES (1), (2), (3);"
psql postgres -ea -c "SELECT gp_create_restore_point('rp1');"
psql postgres -ea -c "INSERT INTO faulty.t(i) VALUES (4);"
sleep 1
echo "<<<"

echo ">>> Running recovery on replica"
cat ${REPLICA_DIR}/postgresql.conf | sed -e "s/^port.*/port = 7070/" > ${REPLICA_DIR}/postgresql.backup.conf
cp -f ${REPLICA_DIR}/postgresql.backup.conf ${REPLICA_DIR}/postgresql.conf
echo "
restore_command = 'cp \"${WAL_ARCHIVE_DIR}/%f\" \"%p\"'
recovery_target_name = 'rp2'
recovery_target_action = 'promote'
hot_standby = on
gp_pause_on_restore_point_replay = on
" >> ${REPLICA_DIR}/postgresql.conf
touch ${REPLICA_DIR}/recovery.signal
touch ${REPLICA_DIR}/standby.signal
pg_ctl start -D ${REPLICA_DIR}
sleep 1
echo "<<<"

echo ">>> Generating data after restore point 1, switching WAL, generating extra data"
psql postgres -ea -c "INSERT INTO faulty.t(i) VALUES (5), (6), (7);"
psql postgres -ea -c "SELECT pg_switch_wal() FROM gp_dist_random('gp_id');"
psql postgres -ea -c "INSERT INTO faulty.t(i) VALUES (8), (9), (10);"
echo "<<<"

echo ">>> Stopping primary1. Conducting a CHECKPOINT on the cluster so that it acknowledges that the primary is down"
pg_ctl stop -D ${PRIMARY1_DIR}
psql postgres -ea -c "CHECKPOINT;"
sleep 1
echo "<<<"

echo ">>> Generating extra data, creating a restore point 2"
psql postgres -ea -c "INSERT INTO faulty.t(i) VALUES (11), (12), (13);"
psql postgres -ea -c "SELECT gp_create_restore_point('rp2');"
psql postgres -ea -c "INSERT INTO faulty.t(i) VALUES (14), (15), (16);"
psql postgres -ea -c "SELECT pg_switch_wal() FROM gp_dist_random('gp_id');"
sleep 1
echo "<<<"

echo ">>> Continuing WAL replay (twice)"
psql postgres -p 7070 -ea -c "SELECT pg_wal_replay_resume();"
sleep 3
psql postgres -p 7070 -ea -c "SELECT pg_wal_replay_resume();"
sleep 3
echo "<<<"

echo ">>> Stopping cluster"
gpstop -M smart -a
echo "<<<"

echo ">>> Observe expected state of the replica after that"
psql postgres -p 7070 -ea -c "SELECT * FROM faulty.t ORDER BY i;"
echo "<<<"
