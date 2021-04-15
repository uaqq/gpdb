#!/usr/bin/env bash

# Archive command for `faulty_timeline.sh`

SOURCE_FILE=$1
DESTINATION_FILE=$2


if test -f "${DESTINATION_FILE}"; then
    DIFF=$(diff -q ${SOURCE_FILE} ${DESTINATION_FILE} | wc -l)
    if [ "${DIFF}" -gt 0 ]; then
        exit 1
    fi
    exit 0
fi

cp ${SOURCE_FILE} ${DESTINATION_FILE}
