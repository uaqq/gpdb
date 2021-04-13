#!/usr/bin/env bash


RUN_STAMP=$(date +%M)


# Initial state: gpdemo with ONE primary-mirror pair

DIR_DATA="${COORDINATOR_DATA_DIRECTORY%*/*/*}"

COORDINATOR_DIR=${DIR_DATA}/qddir/demoDataDir-1
COORDINATOR_PORT=7000

PRIMARY1_DIR=${DIR_DATA}/dbfast1/demoDataDir0
PRIMARY1_PORT=7002

MIRROR1_DIR=${DIR_DATA}/dbfast_mirror1/demoDataDir0
MIRROR1_PORT=7003


# Replica server

DIR_TEMP=$PWD/temp

REPLICA_COORDINATOR_DIR=${DIR_TEMP}/replica_c
REPLICA_COORDINATOR_DBID=10

REPLICA_PRIMARY1_DBID=2
REPLICA_PRIMARY1_DIR=${DIR_TEMP}/replica_p1
REPLICA_PRIMARY1_ARCHIVE=${REPLICA_PRIMARY1_DIR}/pg_wal


RECEIVEWAL_PRIMARY_PID=-1
RECEIVEWAL_MIRROR_PID=-1


# Assume the GPDB cluster is running normally at this point

[ -d ${DIR_TEMP} ] && rm -rf ${DIR_TEMP}
mkdir ${DIR_TEMP}

echo "(1) Create basebackup of primary1"
pg_basebackup -h localhost -p ${PRIMARY1_PORT} -X stream -D ${REPLICA_PRIMARY1_DIR} --target-gp-dbid ${REPLICA_PRIMARY1_DBID}
echo "(1) FINISHED"

echo "(2) Launching pg_receivewal for WALs from primary1 and from mirror1"
pg_receivewal -h localhost -p ${PRIMARY1_PORT} -D ${REPLICA_PRIMARY1_ARCHIVE} >>${DIR_TEMP}/receivewal.log 2>&1 &
RECEIVEWAL_PRIMARY_PID=$!
pg_receivewal -h localhost -p ${MIRROR1_PORT} -D ${REPLICA_PRIMARY1_ARCHIVE} >>${DIR_TEMP}/receivewal.log 2>&1 &
RECEIVEWAL_MIRROR_PID=$!
echo "(2) FINISHED"

echo "(3) Generating some changes"
psql postgres -ea -c "DROP SCHEMA IF EXISTS receivewal CASCADE; CREATE SCHEMA receivewal; CREATE TABLE receivewal.t(i INT); INSERT INTO receivewal.t VALUES (61), (62), (${RUN_STAMP});"
echo "(3) FINISHED"

echo "(4) Killing primary1"
PRIMARY1_PID=$(ps ax | grep postgres | grep "${PRIMARY1_DIR}" | awk '{print $1}')
kill -9 ${PRIMARY1_PID}
psql postgres -ea -c 'CHECKPOINT;'
gpstate
echo "(4) FINISHED"

echo "(5) [mirror acting as primary] Generating some changes"
psql postgres -ea -c "INSERT INTO receivewal.t VALUES (63), (64), (${RUN_STAMP});"
echo "(5) FINISHED"

echo "(6) [mirror acting as primary] Creating a CHECKPOINT and a restore point"
psql postgres -ea -c "CHECKPOINT; SELECT gp_create_restore_point('m');"
echo "(6) FINISHED"

echo "(7) [mirror acting as primary] Recovering GPDB cluster"
gprecoverseg -a
gprecoverseg -a -r
echo "(7) FINISHED"

echo "(8) Generating some changes"
psql postgres -ea -c "INSERT INTO receivewal.t VALUES (65), (66), (${RUN_STAMP});"
echo "(8) FINISHED"

echo "(9) Creating a CHECKPOINT and a restore point"
psql postgres -ea -c "CHECKPOINT; SELECT gp_create_restore_point('p');"
echo "(9) FINISHED"

echo "(10) Stopping the original cluster and pg_receivewal"
gpstop -M fast -a
kill -s SIGINT ${RECEIVEWAL_PRIMARY_PID}
kill -s SIGINT ${RECEIVEWAL_MIRROR_PID}
echo "(10) FINISHED"

echo "(11) Hacky modifications (renaming) of WAL files obtained by pg_receivewal"
ls -ltrh ${REPLICA_PRIMARY1_ARCHIVE}
FILE_TO_RENAME=$(ls -1 ${REPLICA_PRIMARY1_ARCHIVE} | tail -n 3 | head -n 1)
FILE_TO_RENAME_WITH_PATH="${REPLICA_PRIMARY1_ARCHIVE}/${FILE_TO_RENAME}"
RESULTING_FILE="${FILE_TO_RENAME%.*}"
RESULTING_FILE_WITH_PATH="${REPLICA_PRIMARY1_ARCHIVE}/${RESULTING_FILE}"
mv ${FILE_TO_RENAME_WITH_PATH} ${RESULTING_FILE_WITH_PATH}
ls -ltrh ${REPLICA_PRIMARY1_ARCHIVE}
echo "(11) FINISHED"

echo "(12) Recovering segment"
cp ${REPLICA_PRIMARY1_DIR}/postgresql.conf ${REPLICA_PRIMARY1_DIR}/postgresql.backup.conf
echo "
restore_command = 'ls ${REPLICA_PRIMARY1_ARCHIVE}/%f > /dev/null 2>&1'
recovery_target_name = 'p'
recovery_target_action = 'pause'
hot_standby = on
" >> ${REPLICA_PRIMARY1_DIR}/postgresql.conf
touch ${REPLICA_PRIMARY1_DIR}/recovery.signal
pg_ctl start -D ${REPLICA_PRIMARY1_DIR}
echo "(12) FINISHED"
