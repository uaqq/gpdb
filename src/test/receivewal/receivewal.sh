#!/usr/bin/env bash

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
REPLICA_PRIMARY1_ARCHIVE=${DIR_TEMP}/replica_p1_archive

REPLICA_MIRROR1_DIR=${DIR_TEMP}/replica_m1
REPLICA_MIRROR1_PORT=7005


RECEIVEWAL_PID=-1


# Assume the GPDB cluster is running normally at this point

[ -d ${DIR_TEMP} ] && rm -rf ${DIR_TEMP}
mkdir ${DIR_TEMP}

echo "(1) Create basebackup of primary1"
for r in PRIMARY1; do
    PORT_VAR=${r}_PORT
    REPLICA_DIR_VAR=REPLICA_${r}_DIR
    REPLICA_DBID_VAR=REPLICA_${r}_DBID
    pg_basebackup -h localhost -p ${!PORT_VAR} -X stream -D ${!REPLICA_DIR_VAR} --target-gp-dbid ${!REPLICA_DBID_VAR}
done
echo "(1) FINISHED"

echo "(2) Launching pg_receivewal for WALs from primary1"
for r in PRIMARY1; do
    PORT_VAR=${r}_PORT
    REPLICA_ARCHIVE_VAR=REPLICA_${r}_ARCHIVE
    mkdir ${!REPLICA_ARCHIVE_VAR}
    pg_receivewal -h localhost -p ${!PORT_VAR} -D ${!REPLICA_ARCHIVE_VAR} >${DIR_TEMP}/receivewal.log 2>&1 &
    RECEIVEWAL_PID=$!
done
echo "(2) FINISHED"

echo "(3) Generating some changes"
psql postgres -ea -c 'DROP SCHEMA IF EXISTS receivewal CASCADE; CREATE SCHEMA receivewal; CREATE TABLE receivewal.t(i INT); INSERT INTO receivewal.t VALUES (1), (2), (3);'
echo "(3) FINISHED"

echo "(4) Killing primary1"
PRIMARY1_PID=$(ps ax | grep postgres | grep "${PRIMARY1_DIR}" | awk '{print $1}')
kill -9 ${PRIMARY1_PID}
gpstate
echo "(4) FINISHED"

echo "(5) Restarting pg_receivewal: consume WAL from mirror1"
for rn in 1; do
    kill -s SIGINT ${RECEIVEWAL_PID}
    PORT_MIRROR_VAR=MIRROR${rn}_PORT
    pg_receivewal -h localhost -p ${!PORT_MIRROR_VAR} -D ${!REPLICA_ARCHIVE_VAR} >${DIR_TEMP}/receivewal.log 2>&1 &
    RECEIVEWAL_PID=$!
    ls -ltrh ${!REPLICA_ARCHIVE_VAR}
done
echo "(5) FINISHED"

echo "(6) Generating some changes"
psql postgres -ea -c 'INSERT INTO receivewal.t VALUES (4), (5), (6); CHECKPOINT;'
echo "(6) FINISHED"

echo "(7) Recovering GPDB cluster"
gprecoverseg -a
gprecoverseg -a -r
echo "(7) FINISHED"

echo "(8) Restarting pg_receivewal: consume WAL from primary1"
for rn in 1; do
    kill -s SIGINT ${RECEIVEWAL_PID}
    PORT_PRIMARY_VAR=PRIMARY${rn}_PORT
    pg_receivewal -h localhost -p ${!PORT_PRIMARY_VAR} -D ${!REPLICA_ARCHIVE_VAR} >${DIR_TEMP}/receivewal.log 2>&1 &
    RECEIVEWAL_PID=$!
    ls -ltrh ${!REPLICA_ARCHIVE_VAR}
done
echo "(8) FINISHED"

echo "(9) Creating a restore point"
psql postgres -ea -c "SELECT gp_create_restore_point('rp');"
echo "(9) FINISHED"

echo "(10) Stopping the original cluster and pg_receivewal"
gpstop -M fast -a
for rn in 1; do
    kill -s SIGINT ${RECEIVEWAL_PID}
done
echo "(10) FINISHED"

echo "(11) Recovering segment"
for r in PRIMARY1; do
    REPLICA_DIR_VAR=REPLICA_${r}_DIR
    REPLICA_ARCHIVE_VAR=REPLICA_${r}_ARCHIVE
    cp ${!REPLICA_DIR_VAR}/postgresql.conf ${!REPLICA_DIR_VAR}/postgresql.conf.backup
    echo "
restore_command = 'cp ${!REPLICA_ARCHIVE_VAR}/%f %p'
recovery_target_name = 'rp'
recovery_target_action = 'promote'
" >> ${!REPLICA_DIR_VAR}/postgresql.conf
    touch ${!REPLICA_DIR_VAR}/recovery.signal
    pg_ctl start -D ${!REPLICA_DIR_VAR}
done
echo "(11) FINISHED"
