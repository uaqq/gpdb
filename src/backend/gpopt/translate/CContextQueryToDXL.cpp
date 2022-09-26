//---------------------------------------------------------------------------
//  Greenplum Database
//	Copyright (C) 2018-Present Pivotal Software, Inc.
//
//	@filename:
//		CContextQueryToDXL.cpp
//
//	@doc:
//		Implementation of the methods used to hold information about
//		the whole query, when translate a query into DXL tree. All
//		translator methods allocate memory in the provided memory pool,
//		and the caller is responsible for freeing it
//
//---------------------------------------------------------------------------
#include "gpopt/translate/CContextQueryToDXL.h"

#include "gpopt/translate/CTranslatorUtils.h"
#include "naucrates/dxl/CIdGenerator.h"

using namespace gpdxl;

CContextQueryToDXL::CContextQueryToDXL(CMemoryPool *mp)
	: m_mp(mp),
	  m_has_distributed_tables(false),
	  m_distribution_hashops(DistrHashOpsNotDeterminedYet),
	  m_has_replicated_tables(false),
	  m_has_volatile_functions(false)
{
	// map that stores gpdb att to optimizer col mapping
	m_colid_counter = GPOS_NEW(mp) CIdGenerator(GPDXL_COL_ID_START);
	m_processed_rte_map = GPOS_NEW(mp) RTEPointerMap(mp);
	m_table_descr_id_counter =  GPOS_NEW(mp) CIdGenerator(GPDXL_TABLE_DESCR_ID_START);
	m_cte_id_counter = GPOS_NEW(mp) CIdGenerator(GPDXL_CTE_ID_START);
}

CContextQueryToDXL::~CContextQueryToDXL()
{
	m_processed_rte_map->Release();
	GPOS_DELETE(m_table_descr_id_counter);
	GPOS_DELETE(m_colid_counter);
	GPOS_DELETE(m_cte_id_counter);
}

ULONG CContextQueryToDXL::GetTableDescrId(ULONG_PTR rte_ptr)
{
	ULONG *id = NULL;
	ULONG_PTR *key = GPOS_NEW(m_mp) ULONG_PTR(rte_ptr);
	if ((id = m_processed_rte_map->Find(key))) {
		return *id;
	}

	ULONG *new_id = GPOS_NEW(m_mp) ULONG(m_table_descr_id_counter->next_id());
	m_processed_rte_map->Insert(key, new_id);
	return *new_id;
}