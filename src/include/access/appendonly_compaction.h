/*------------------------------------------------------------------------------
 *
 * appendonly_compaction
 *
 * Copyright (c) 2013-Present Pivotal Software, Inc.
 *
 *
 * IDENTIFICATION
 *	    src/include/access/appendonly_compaction.h
 *
 *------------------------------------------------------------------------------
*/
#ifndef APPENDONLY_COMPACTION_H
#define APPENDONLY_COMPACTION_H

#include "nodes/pg_list.h"
#include "access/appendonly_visimap.h"
#include "utils/rel.h"
#include "access/memtup.h"
#include "executor/tuptable.h"
#include "nodes/parsenodes.h"

#define APPENDONLY_COMPACTION_SEGNO_INVALID (-1)

extern void AppendOptimizedDropDeadSegments(Relation aorel, Bitmapset *segnos);
extern Bitmapset *AppendOnlyCollectDeadSegments(Relation aorel,
				  List *compaction_segno);
extern void AppendOnlyCompact(Relation aorel,
				  VacuumStmt *vacstmt,
				  int insert_segno);
extern bool AppendOnlyCompaction_ShouldCompact(
								   Relation aoRelation,
								   int segno,
								   int64 segmentTotalTupcount,
								   bool isFull,
								   Snapshot appendOnlyMetaDataSnapshot);
extern void AppendOnlyThrowAwayTuple(Relation rel,
						 TupleTableSlot *slot, MemTupleBinding *mt_bind);
extern void AppendOnlyTruncateToEOF(Relation aorel);
extern bool HasLockForSegmentFileDrop(Relation aorel);
extern bool AppendOnlyCompaction_IsRelationEmpty(Relation aorel);

#endif
