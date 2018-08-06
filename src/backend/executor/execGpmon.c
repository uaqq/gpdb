/*-------------------------------------------------------------------------
 * execGpmon.c
 *	  Gpmon related functions inside executor.
 *
 * Portions Copyright (c) 2012 - present, EMC/Greenplum
 * Portions Copyright (c) 2012-Present Pivotal Software, Inc.
 *
 *
 * IDENTIFICATION
 *	    src/backend/executor/execGpmon.c
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include "cdb/cdbvars.h"
#include "nodes/execnodes.h"

void CheckSendPlanStateGpmonPkt(PlanState *ps)
{
	if(!ps)
		return;

	// FIXME: This is a temporary solution (experiment)
	gpmon_packet_t *qn_packet = palloc0(sizeof(gpmon_packet_t));

	qn_packet->magic = GPMON_MAGIC;
	qn_packet->version = GPMON_PACKET_VERSION;
	qn_packet->pkttype = GPMON_PKTTYPE_QUERY_NODE;
	qn_packet->u.qnode.t_start = time(NULL);
	qn_packet->u.qnode.node = ps->type;
	gpmon_gettmid(&qn_packet->u.qnode.key.tmid);
	qn_packet->u.qnode.key.ssid = gp_session_id;
	qn_packet->u.qnode.key.ccnt = gp_command_count;
	qn_packet->u.qnode.key.nid = ps->plan->plan_node_id;

	gpmon_send(qn_packet);
	pfree(qn_packet);

	if(gp_enable_gpperfmon)
	{
		if(!ps->fHadSentGpmon || ps->gpmon_plan_tick != gpmon_tick)
		{
			if (ps->state && LocallyExecutingSliceIndex(ps->state) == currentSliceId)
			{
				gpmon_send(&ps->gpmon_pkt);
			}
			ps->fHadSentGpmon = true;
		}
		ps->gpmon_plan_tick = gpmon_tick;
	}
}

void EndPlanStateGpmonPkt(PlanState *ps)
{
	if(!ps)
		return;

	ps->gpmon_pkt.u.qexec.status = (uint8)PMNS_Finished;

	if(gp_enable_gpperfmon &&
	   ps->state &&
	   LocallyExecutingSliceIndex(ps->state) == currentSliceId)
	{
		gpmon_send(&ps->gpmon_pkt);
	}
}

/*
 * InitPlanNodeGpmonPkt -- initialize the init gpmon package, and send it off.
 */
void InitPlanNodeGpmonPkt(Plan *plan, gpmon_packet_t *gpmon_pkt, EState *estate)
{
	if (!plan)
		return;

	memset(gpmon_pkt, 0, sizeof(gpmon_packet_t));

	gpmon_pkt->magic = GPMON_MAGIC;
	gpmon_pkt->version = GPMON_PACKET_VERSION;
	gpmon_pkt->pkttype = GPMON_PKTTYPE_QEXEC;

	gpmon_gettmid(&gpmon_pkt->u.qexec.key.tmid);
	gpmon_pkt->u.qexec.key.ssid = gp_session_id;
	gpmon_pkt->u.qexec.key.ccnt = gp_command_count;
	gpmon_pkt->u.qexec.key.hash_key.segid = GpIdentity.segindex;
	gpmon_pkt->u.qexec.key.hash_key.pid = MyProcPid;
	gpmon_pkt->u.qexec.key.hash_key.nid = plan->plan_node_id;

	gpmon_pkt->u.qexec.rowsout = 0;

	gpmon_pkt->u.qexec.status = (uint8)PMNS_Initialize;

	if (gp_enable_gpperfmon && estate)
	{
		gpmon_send(gpmon_pkt);
	}

	gpmon_pkt->u.qexec.status = (uint8)PMNS_Executing;
}
