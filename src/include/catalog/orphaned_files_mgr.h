#ifndef ORPHANED_FILES_MGR_H
#define ORPHANED_FILES_MGR_H

#include "postgres.h"
#include "storage/relfilenode.h"
#include "access/transam.h"

extern Size OrphanedFilesShmemSize(void);
extern void OrphanedFilesShmemInit(void);

extern void OrphanedFilesShmemAdd(RelFileNodePendingDelete *relnode, TransactionId xid);
extern void OrphanedFilesShmemRemove(void);

#endif							/* ORPHANED_FILES_MGR_H */