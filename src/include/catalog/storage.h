/*-------------------------------------------------------------------------
 *
 * storage.h
 *	  prototypes for functions in backend/catalog/storage.c
 *
 *
 * Portions Copyright (c) 1996-2019, PostgreSQL Global Development Group
 * Portions Copyright (c) 1994, Regents of the University of California
 *
 * src/include/catalog/storage.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef STORAGE_H
#define STORAGE_H

#include "storage/block.h"
#include "storage/relfilenode.h"
#include "storage/smgr.h"
#include "utils/relcache.h"

/* TODO: find a better place for this (or no?) */
typedef struct PENDING_DELETES
{
	/*
	 * TODO: We should add enum with custom record type and use it here and
	 * inside TMGXACT_CHECKPOINT.
	 * This enum should be respected inside UnpackCheckPointRecord().
	 */	
	int ndelrels;
	RelFileNodePendingDelete delrels[1];
} PENDING_DELETES;

#define PENDING_DELETES_BYTES(ndelrels) \
	(offsetof(PENDING_DELETES, delrels) + sizeof(RelFileNodePendingDelete) * (ndelrels))

#define DELFILENODE_DEF_CNT 50

void add_delrelnode_to_shmem(RelFileNodePendingDelete *relnode);
void add_delrelnode_to_global(RelFileNodePendingDelete *relnode);
void remove_delrelnode_from_shmem(RelFileNodePendingDelete *relnode);
void remove_delrelnode_from_global(RelFileNodePendingDelete *relnode);
PENDING_DELETES* get_delrelnode_global_slim_copy();


extern SMgrRelation RelationCreateStorage(RelFileNode rnode,
										  char relpersistence,
										  SMgrImpl smgr_which);
extern void RelationDropStorage(Relation rel);
extern void RelationPreserveStorage(RelFileNode rnode, bool atCommit);
extern void RelationTruncate(Relation rel, BlockNumber nblocks);
extern void RelationCopyStorage(SMgrRelation src, SMgrRelation dst,
								ForkNumber forkNum, char relpersistence);

/*
 * These functions used to be in storage/smgr/smgr.c, which explains the
 * naming
 */
extern void smgrDoPendingDeletes(bool isCommit);
extern int	smgrGetPendingDeletes(bool forCommit, RelFileNodePendingDelete **ptr);
extern void AtSubCommit_smgr(void);
extern void AtSubAbort_smgr(void);
extern void PostPrepare_smgr(void);

#endif							/* STORAGE_H */
