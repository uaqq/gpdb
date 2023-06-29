/*------------------------------------------------------------------------------
 *
 * aocs_compaction.h
 *
 * Copyright (c) 2013-Present Pivotal Software, Inc.
 *
 *
 * IDENTIFICATION
 *	    src/include/access/aocs_compaction.h
 *
 *------------------------------------------------------------------------------
 */
#ifndef AOCS_COMPACTION_H
#define AOCS_COMPACTION_H

#include "nodes/pg_list.h"
#include "utils/rel.h"
#include "nodes/parsenodes.h"

extern void AOCSDrop(Relation aorel,
			List *compaction_segno);
extern Bitmapset *AOCSCollectDeadSegments(Relation aorel,
			List *compaction_segno);
extern void AOCSCompact(Relation aorel,
			VacuumStmt *vacstmt,
			int insert_segno);
extern void AOCSTruncateToEOF(Relation aorel);
extern void AOCSCompaction_DropSegmentFile(Relation aorel, int segno);
#endif
