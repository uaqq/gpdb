#include <libgen.h>
#include <sys/stat.h>

#include "postgres.h"

#include "c.h"
#include "cdb/cdbbufferedappend.h"
#include "cdb/cdbvars.h"
#include "pg_config_manual.h"
#include "port/atomics.h"
#include "storage/fd.h"
#include "storage/relfilenode.h"
#include "storage/shmem.h"
#include "storage/smgr.h"
#include "storage/temp_tables_limit.h"
#include "utils/elog.h"
#include "utils/guc.h"

#define TempTablesLimitChecks() do {\
									if (!IsUnderPostmaster || Gp_role != GP_ROLE_EXECUTE)\
										return;\
									\
									Assert(temp_tables_limit_value != NULL);\
								} while (0)

static volatile pg_atomic_uint64 *temp_tables_limit_value = NULL;
static int64 prevFileLen = -1;
static int64 prevSegFileLen = -1;
static bool fileSkip = false;
static bool segFileSkip = false;

static int64
TempTablesLimitToBytes(void)
{
	return temp_tables_limit * 1024 * 1024;
}

/* init */

Size
TempTablesLimitSize(void)
{
	return sizeof(pg_atomic_uint64);
}

void
TempTablesLimitShmemInit(void)
{
	temp_tables_limit_value = (volatile pg_atomic_uint64 *) ShmemAlloc(sizeof(pg_atomic_uint64));
	pg_atomic_init_u64((pg_atomic_uint64 *) temp_tables_limit_value, 0);
}

/* ao */

void
BufferedAppendWritePreHook(BufferedAppend *bufferedAppend)
{
	TempTablesLimitChecks();

	if (RelFileNodeBackendIsTemp(bufferedAppend->relFileNode))
	{
		prevFileLen = bufferedAppend->largeWritePosition;

		if (bufferedAppend->largeWriteLen > 0 &&
			temp_tables_limit_value->value + bufferedAppend->largeWriteLen > TempTablesLimitToBytes())
			elog(ERROR, "Temp tables quota exceeded");
	}
}

void
BufferedAppendWritePostHook(BufferedAppend *bufferedAppend)
{
	TempTablesLimitChecks();

	if (RelFileNodeBackendIsTemp(bufferedAppend->relFileNode))
	{
		Assert(prevFileLen >= 0);
		pg_atomic_add_fetch_u64(temp_tables_limit_value, bufferedAppend->largeWriteLen);
	}

	prevFileLen = -1;
}

void
TruncateAOSegmentFilePreHook(Relation rel, File fd)
{
	TempTablesLimitChecks();

	if (rel->rd_islocaltemp)
	{
		prevFileLen = FileDiskSize(fd);
	}
}

void
TruncateAOSegmentFilePostHook(Relation rel, int64 offset)
{
	int64 bytesToTruncate;

	TempTablesLimitChecks();

	if (rel->rd_islocaltemp)
	{
		Assert(prevFileLen >= 0);

		bytesToTruncate = prevFileLen - offset;
		pg_atomic_sub_fetch_u64(temp_tables_limit_value, bytesToTruncate);
	}

	prevFileLen = -1;
}

/* heap */

void
mdextend_pre_hook(SMgrRelation reln, ForkNumber forknum, int64 size)
{
	TempTablesLimitChecks();

	if (SmgrIsTemp(reln))
		if (temp_tables_limit_value->value + size > TempTablesLimitToBytes()
			&& forknum == MAIN_FORKNUM) /* visibility map can be extended during vacuum */
			elog(ERROR, "Temp tables quota exceeded");
}

void
mdextend_post_hook(SMgrRelation reln, int64 size)
{
	TempTablesLimitChecks();

	if (SmgrIsTemp(reln))
		pg_atomic_add_fetch_u64(temp_tables_limit_value, size);
}

void
mdunlinkfork_pre_hook(RelFileNodeBackend rnode, ForkNumber forkNum)
{
	struct stat buf;
	char *path;
	int fd;

	TempTablesLimitChecks();

	if (RelFileNodeBackendIsTemp(rnode))
	{
		path = relpath(rnode, forkNum);
		fd = OpenTransientFile((char *) path, O_RDWR | PG_BINARY, 0);
		if (fstat(fd, &buf) == 0)
		{
			prevFileLen = buf.st_size;
			CloseTransientFile(fd);
		}
		else
			fileSkip = true; // file didn't exist, skip it
	}
}

void
mdunlinkfork_post_hook(RelFileNodeBackend rnode)
{
	TempTablesLimitChecks();

	if (RelFileNodeBackendIsTemp(rnode) && !fileSkip)
	{
		Assert(prevFileLen >= 0);

		pg_atomic_sub_fetch_u64(temp_tables_limit_value, prevFileLen);
	}

	prevFileLen = -1;
	fileSkip = false;
}

void
mdunlinkforksegment_pre_hook(RelFileNodeBackend rnode, char *segpath)
{
	struct stat buf;
	char fullPath[MAXPGPATH];
	size_t strLen = strnlen(data_directory, MAXPGPATH) + strnlen(segpath, MAXPGPATH) + 1;

	TempTablesLimitChecks();

	snprintf(fullPath, strLen, "%s/%s", data_directory, segpath);

	if (RelFileNodeBackendIsTemp(rnode))
		if (stat(fullPath, &buf) == 0)
			prevSegFileLen = buf.st_size;
		else
			segFileSkip = true;
}

void
mdunlinkforksegment_post_hook(RelFileNodeBackend rnode)
{
	TempTablesLimitChecks();

	if (RelFileNodeBackendIsTemp(rnode) && !segFileSkip)
	{
		Assert(prevSegFileLen >= 0);

		pg_atomic_sub_fetch_u64(temp_tables_limit_value, prevSegFileLen);
	}

	prevSegFileLen = -1;
	segFileSkip = false;
}

void
mdunlink_ao_perFile_pre_hook(char *segPath)
{
	struct stat buf;
	char segPathCopy[MAXPGPATH];
	char *name;

	segPathCopy[0] = '\0';
	strncpy(segPathCopy, segPath, strnlen(segPathCopy, MAXPGPATH)); // basename may modify incoming string so we better make a copy

	name = basename(segPathCopy);
	if (name[0] == 't')
		if (stat(segPath, &buf) == 0)
			prevSegFileLen = buf.st_size;
		else
			segFileSkip = true;
	else
		segFileSkip = true;
}

void
mdunlink_ao_perFile_post_hook(void)
{
	TempTablesLimitChecks();

	if (!segFileSkip)
	{
		Assert(prevSegFileLen >= 0);

		pg_atomic_sub_fetch_u64(temp_tables_limit_value, prevSegFileLen);
	}

	prevSegFileLen = -1;
	segFileSkip = false;
}

void
mdtruncate_pre_hook(SMgrRelation reln, File vfd, BlockNumber blockNum)
{
	TempTablesLimitChecks();

	if (SmgrIsTemp(reln))
	{
		prevFileLen = FileDiskSize(vfd);
	}
}

void
mdtruncate_post_hook(SMgrRelation reln, BlockNumber blockNum)
{
	TempTablesLimitChecks();

	if (SmgrIsTemp(reln))
	{
		Assert(prevFileLen >= 0);

		pg_atomic_sub_fetch_u64(temp_tables_limit_value, prevFileLen - blockNum * BLCKSZ);
	}

	prevFileLen = -1;
}
