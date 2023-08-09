#include "catalog/orphaned_files_mgr.h"

#include "pg_config.h"
#include "miscadmin.h"
#include "utils/dsa.h"
#include "storage/lwlock.h"
#include "storage/shmem.h"

#include "nodes/pg_list.h"

typedef struct OrphanedNode
{
	RelFileNodePendingDelete pnode;
	TransactionId xid;
} OrphanedNode;

typedef struct OrphanedListNode
{
	OrphanedNode o_node;
	dsa_pointer next;
	dsa_pointer prev;
} OrphanedListNode;

typedef struct OrphanedFilesShmemStruct
{
	dsa_pointer ol_head;
	char dsa_mem[FLEXIBLE_ARRAY_MEMBER];
} OrphanedFilesShmemStruct;

static OrphanedFilesShmemStruct *OrphanedFilesShmem = NULL;
static List *OrphanedFilesLocal = NIL;

Size
OrphanedFilesShmemSize(void)
{
	Size		size;

	size = offsetof(OrphanedFilesShmemStruct, dsa_mem);
	size = add_size(size, dsa_minimum_size());

	return size;
}

void
OrphanedFilesShmemInit(void)
{
	Size		size = OrphanedFilesShmemSize();
	bool		found;

	OrphanedFilesShmem = (OrphanedFilesShmemStruct *)
		ShmemInitStruct("Orphaned Files",
						size,
						&found);

	if (!found)
	{
		dsa_area *dsa = dsa_create_in_place(
			OrphanedFilesShmem->dsa_mem,
			dsa_minimum_size(),
			LWTRANCHE_ORPHANED_FILES_DSA,
			NULL
		);
		dsa_pin(dsa);
		OrphanedFilesShmem->ol_head = InvalidDsaPointer;
		elog(LOG, "dsa main: %p", dsa);

		//on_shmem_exit(apw_detach_shmem, 0);
	}
}

static void print_shmem(dsa_area *dsa)
{
	dsa_pointer ol_node_dsa = OrphanedFilesShmem->ol_head;

	while (ol_node_dsa != InvalidDsaPointer)
	{
		OrphanedListNode *ol_node = dsa_get_address(dsa, ol_node_dsa);

		elog(NOTICE, "Shmem contains: (%d, %d)", ol_node->o_node.pnode.node.relNode, ol_node->o_node.xid);
		ol_node_dsa = ol_node->next;
	}
}

static void add_shmem_node(dsa_pointer cur, dsa_area *dsa)
{
	dsa_pointer head = OrphanedFilesShmem->ol_head;
	OrphanedListNode *cur_node = dsa_get_address(dsa, cur);
	
	cur_node->next = head;
	cur_node->prev = InvalidDsaPointer;
	if (head != InvalidDsaPointer)
	{
		OrphanedListNode *head_node = dsa_get_address(dsa, head);

		head_node->prev = cur;
	}
	OrphanedFilesShmem->ol_head = cur;

	elog(NOTICE, "%d added to shmem.", cur_node->o_node.pnode.node.relNode);
}

static void del_shmem_node(dsa_pointer cur, dsa_area *dsa)
{
	dsa_pointer head = OrphanedFilesShmem->ol_head;
	OrphanedListNode *cur_node = dsa_get_address(dsa, cur);

	if (cur_node->next != InvalidDsaPointer)
	{
		OrphanedListNode *next_node = dsa_get_address(dsa, cur_node->next);

		next_node->prev = cur_node->prev;
	}

	if (cur_node->prev != InvalidDsaPointer)
	{
		OrphanedListNode *prev_node = dsa_get_address(dsa, cur_node->prev);

		prev_node->next = cur_node->next;
	}

	if (cur == head)
		OrphanedFilesShmem->ol_head = cur_node->next;

	elog(NOTICE, "%d removed from shmem.", cur_node->o_node.pnode.node.relNode);
	
	dsa_free(dsa, cur);
}

void OrphanedFilesShmemAdd(RelFileNodePendingDelete *relnode, TransactionId xid)
{
	dsa_pointer ol_node_dsa;
	dsa_pointer *ol_node_dsa_local;
	OrphanedListNode *ol_node;
	dsa_area *dsa;
	MemoryContext oldcontext;

	elog(NOTICE, "Trying to add (%d, %d) to shmem.", relnode->node.relNode, xid);

	if (xid == InvalidTransactionId || !IsUnderPostmaster)
		return;

	dsa = dsa_attach_in_place(OrphanedFilesShmem->dsa_mem, NULL);

	ol_node_dsa = dsa_allocate(dsa, sizeof(OrphanedListNode));
	ol_node = dsa_get_address(dsa, ol_node_dsa);

	memcpy(&ol_node->o_node.pnode, relnode, sizeof(*relnode));
	ol_node->o_node.xid = xid;

	add_shmem_node(ol_node_dsa, dsa);

	oldcontext = MemoryContextSwitchTo(TopMemoryContext);
	ol_node_dsa_local = palloc(sizeof(dsa_pointer));
	*ol_node_dsa_local = ol_node_dsa;
	OrphanedFilesLocal = lappend(OrphanedFilesLocal, ol_node_dsa_local);
	MemoryContextSwitchTo(oldcontext);

	print_shmem(dsa);

	dsa_detach(dsa);
}

void OrphanedFilesShmemRemove(void)
{
	ListCell *cell;
	dsa_area *dsa;

	elog(NOTICE, "Trying to remove all from shmem.");

	if (list_length(OrphanedFilesLocal) == 0)
		return;

	dsa = dsa_attach_in_place(OrphanedFilesShmem->dsa_mem, NULL);
	
	foreach(cell, OrphanedFilesLocal)
	{
		dsa_pointer *ol_node_dsa_local = lfirst(cell);
		del_shmem_node(*ol_node_dsa_local, dsa);
	}

	list_free_deep(OrphanedFilesLocal);
	OrphanedFilesLocal = NIL;

	print_shmem(dsa);

	dsa_detach(dsa);
}