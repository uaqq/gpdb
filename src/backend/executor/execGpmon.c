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

	if(gp_enable_gpperfmon)
	{
		// FIXME: This is a temporary solution (experiment)
		gpmon_packet_t *planmetric_packet = palloc0(sizeof(gpmon_packet_t));

		planmetric_packet->magic = GPMON_MAGIC;
		planmetric_packet->version = GPMON_PACKET_VERSION;
		planmetric_packet->pkttype = GPMON_PKTTYPE_PLANMETRIC;

		gpmon_gettmid(&planmetric_packet->u.planmetric.key.tmid);
		planmetric_packet->u.planmetric.key.ssid = gp_session_id;
		planmetric_packet->u.planmetric.key.ccnt = gp_command_count;
		planmetric_packet->u.planmetric.key.nid = ps->plan->plan_node_id;

		planmetric_packet->u.planmetric.node = ps->type;
		planmetric_packet->u.planmetric.t_start = time(NULL);

		gpmon_send(planmetric_packet);
		pfree(planmetric_packet);
		// END

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
