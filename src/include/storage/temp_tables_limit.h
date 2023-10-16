#include "access/aocssegfiles.h"
#include "cdb/cdbbufferedappend.h"
#include "c.h"

#ifndef TEMP_TABLES_LIMIT_H
#define TEMP_TABLES_LIMIT_H

/* init */

Size TempTablesLimitSize(void);

void TempTablesLimitShmemInit(void);

/* ao */

void BufferedAppendWritePreHook(BufferedAppend *bufferedAppend);

void BufferedAppendWritePostHook(BufferedAppend *bufferedAppend);

void TruncateAOSegmentFilePreHook(Relation rel, File fd);

void TruncateAOSegmentFilePostHook(Relation rel, int64 offset);

/* heap */

void mdextend_pre_hook(SMgrRelation reln, ForkNumber forknum, int64 size);

void mdextend_post_hook(SMgrRelation reln, int64 size);

void mdunlinkfork_pre_hook(RelFileNodeBackend rnode, ForkNumber forkNum);

void mdunlinkfork_post_hook(RelFileNodeBackend rnode);

void mdunlinkforksegment_pre_hook(RelFileNodeBackend rnode, char *segpath);

void mdunlinkforksegment_post_hook(RelFileNodeBackend rnode);

void mdunlink_ao_perFile_pre_hook(char *segPath);

void mdunlink_ao_perFile_post_hook(void);

void mdtruncate_pre_hook(SMgrRelation reln, File vfd, BlockNumber blockNum);

void mdtruncate_post_hook(SMgrRelation reln, BlockNumber blockNum);

#endif
