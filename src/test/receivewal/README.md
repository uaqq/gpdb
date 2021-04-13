# `pg_receivewal` test cases: replication proof of concept

This directory contains a set of scripts whose purpose is to demonstrate that replica recovery is possible with `pg_receivewal` utility.

The scripts are as follows:
* `receivewal.sh`: Demonstrates a scenario when GPDB cluster's primary fails, some operations on mirror are performed, the primary is then restored; after all this, the main cluster is stopped and replica "recovery" is performed.
* `receivewal_parallel_consumption.sh`: Demonstrates the same scenario, but WALs are translated from primary and mirror separately, although in result they are placed in the same directory.
* `receivewal_primary_failure.sh`: Demonstrates the ability to "recover" replica when the main's cluster primary fails and does not recover.
