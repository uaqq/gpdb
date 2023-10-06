#ifndef STORAGE_PENDING_H
#define STORAGE_PENDING_H

#include "access/xlog.h"

/* Pending delete node linked to xact it created */
typedef struct PendingRelXactDelete
{
	RelFileNodePendingDelete relnode;
	TransactionId xid;
}			PendingRelXactDelete;

typedef struct PendingRelXactDeleteArray
{
	size_t		count;
	PendingRelXactDelete array[FLEXIBLE_ARRAY_MEMBER];
}			PendingRelXactDeleteArray;

extern Size PdlShmemSize(void);
extern void PdlShmemInit(void);

/*
 * dsa_pointer type is declared and defined in dsa.h, which use atomics.h.
 * atomics.h can't be included if FRONTEND defined.
 * As we don't need to use functions below in frontend, it's safe to use
 * a simple workaround.
 */
#ifndef FRONTEND
#include "utils/dsa.h"
extern dsa_pointer PdlShmemAdd(RelFileNodePendingDelete * relnode, TransactionId xid);
extern void PdlShmemRemove(dsa_pointer node_ptr);
#endif

extern XLogRecPtr PdlXLogInsert(void);

extern void PdlRedoAdd(PendingRelXactDelete * pd);
extern void PdlRedoXLogRecord(XLogReaderState *record);
extern void PdlRedoRemove(TransactionId xid);
extern void PdlRedoDropFiles(void);

#endif							/* STORAGE_PENDING_H */
