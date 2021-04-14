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


RECEIVEWAL_PID=-1


# Assume the GPDB cluster is running normally at this point

[ -d ${DIR_TEMP} ] && rm -rf ${DIR_TEMP}
mkdir ${DIR_TEMP}

echo "(1) Create basebackup of primary1"
pg_basebackup -h localhost -p ${PRIMARY1_PORT} -X stream -D ${REPLICA_PRIMARY1_DIR} --target-gp-dbid ${REPLICA_PRIMARY1_DBID}
echo "(1) FINISHED"

echo "(2) Launching pg_receivewal for WALs from primary1"
pg_receivewal -h localhost -p ${PRIMARY1_PORT} -D ${REPLICA_PRIMARY1_ARCHIVE} >>${DIR_TEMP}/receivewal.log 2>&1 &
RECEIVEWAL_PID=$!
echo "(2) FINISHED"

echo "(3) Generating some changes"
psql postgres -ea -c "DROP SCHEMA IF EXISTS receivewal CASCADE; CREATE SCHEMA receivewal; CHECKPOINT; CREATE TABLE receivewal.t(i INT); INSERT INTO receivewal.t VALUES (${RUN_STAMP});"
echo "(3) FINISHED"

echo "(4) Creating restore point 1"
psql postgres -ea -c "SELECT gp_create_restore_point('rp1');"
echo "(4) FINISHED"

echo "(5) Generating faulty changes on primary1 and creating a restore point"
echo "(5) In a real installation, these would originate from actions performed cluster-wide"
PGOPTIONS="-c gp_role=utility" psql postgres -ea -c "INSERT INTO receivewal.t VALUES (663), (664), (${RUN_STAMP});" -p 7002
PGOPTIONS="-c gp_role=utility" psql postgres -ea -c "SELECT pg_create_restore_point('rpfaulty');" -p 7002
echo "(5) FINISHED"

echo "(6) Stopping primary1 and making sure GPDB acknowledges that primary1 is now unresponsive. Stopping pg_receivewal"
PRIMARY1_PID=$(ps ax | grep postgres | grep "${PRIMARY1_DIR}" | awk '{print $1}')
kill -s SIGKILL ${PRIMARY1_PID}
rm -f /tmp/.s.PGSQL.7002.lock
kill -s SIGKILL ${RECEIVEWAL_PID}
RECEIVEWAL_PID=-1
psql postgres -ea -c 'CHECKPOINT;'
gpstate
echo "(6) FINISHED"

echo "(7) Hacky renaming of WAL files obtained by pg_receivewal"
ls -ltrh ${REPLICA_PRIMARY1_ARCHIVE}
FILE_TO_RENAME_WITH_PATH=$(ls -1 ${REPLICA_PRIMARY1_ARCHIVE}/*.partial | tail -n 1)
RESULTING_FILE_WITH_PATH="${FILE_TO_RENAME_WITH_PATH%.*}"
cp ${FILE_TO_RENAME_WITH_PATH} ${RESULTING_FILE_WITH_PATH}
ls -ltrh ${REPLICA_PRIMARY1_ARCHIVE}
echo "(7) FINISHED"

echo "(8) Starting recovery on replica"
cat ${REPLICA_PRIMARY1_DIR}/postgresql.conf | sed -e "s/^port.*/port = 7007/" > ${REPLICA_PRIMARY1_DIR}/postgresql.backup.conf
cp -f ${REPLICA_PRIMARY1_DIR}/postgresql.backup.conf ${REPLICA_PRIMARY1_DIR}/postgresql.conf
echo "
restore_command = 'ls ${REPLICA_PRIMARY1_ARCHIVE}/%f > /dev/null 2>&1'
recovery_target_name = 'rp2'
recovery_target_action = 'pause'
hot_standby = on
gp_pause_on_restore_point_replay = on
" >> ${REPLICA_PRIMARY1_DIR}/postgresql.conf
touch ${REPLICA_PRIMARY1_DIR}/recovery.signal
pg_ctl start -D ${REPLICA_PRIMARY1_DIR}
echo "(8) FINISHED"

echo "(8.1) At this point, replica is stopped at 'rp1', and it will continue to replay the CURRENT WAL until it reaches 'rpfaulty'."
echo "(8.1) Let's provide newer files from mirror. GPDB permits clusters that do not have primaries"

echo "(9) Restarting cluster (with mirror1 down) and launching pg_receivewal for WALs from mirror1"
gpstop -M fast -a -r
pg_receivewal -h localhost -p ${MIRROR1_PORT} -D ${REPLICA_PRIMARY1_ARCHIVE} >>${DIR_TEMP}/receivewal.log 2>&1 &
RECEIVEWAL_PID=$!
echo "(9) FINISHED"

echo "(10) Generating some changes"
psql postgres -ea -c "INSERT INTO receivewal.t VALUES (61), (62), (${RUN_STAMP});"
echo "(10) FINISHED"

echo "(10.1) Sleeping for 3 seconds to wait for WAL transmission"
sleep 3
echo "(10.1) FINISHED"

echo "(11) Hacky renaming of WAL files obtained by pg_receivewal"
ls -ltrh ${REPLICA_PRIMARY1_ARCHIVE}
FILE_TO_RENAME_WITH_PATH=$(ls -1 ${REPLICA_PRIMARY1_ARCHIVE}/*.partial | tail -n 1)
RESULTING_FILE_WITH_PATH="${FILE_TO_RENAME_WITH_PATH%.*}"
cp ${FILE_TO_RENAME_WITH_PATH} ${RESULTING_FILE_WITH_PATH}
ls -ltrh ${REPLICA_PRIMARY1_ARCHIVE}
echo "(12) FINISHED"

echo "(13) Continuing recovery on replica"
psql postgres -ea -c "SELECT pg_wal_replay_resume();" -p 7007
echo "(13) FINISHED"

echo "(13.1) Sleeping for 3 seconds to wait for recovery completion"
sleep 3
echo "(13.1) FINISHED"

echo "(14) At this point, replica has reached state in which cluster has never been. Illustrating this"
psql postgres -ea -c "SELECT * FROM receivewal.t;" -p 7007
echo "(14) FINISHED"

echo "(15) The replica has now been promoted because it has read its WAL completely"