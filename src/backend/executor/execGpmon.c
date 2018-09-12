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


/**
 * Add GPMON_MAGIC, GPMON_PACKET_VERSION and gpmon packet type to the given gpmon packet
 */
inline void gp_to_gpmmon_set_header(gpmon_packet_t* pkt, enum gpmon_pkttype_t pkttype)
{
	pkt->pkttype = pkttype;
	pkt->magic = GPMON_MAGIC;
	pkt->version = GPMON_PACKET_VERSION;
}

/**
 * Report current values of PlanState to gpperfmon using 'planmetric' packet.
 *
 * This procedure should be called after every PlanState change
 */
void ReportPlanMetricGpmonPkt(NodeTag plan_node_type, int plan_node_id) {
	gpmon_packet_t planmetric_packet;
	GpMonotonicTime gptime;

	if (!gp_enable_gpperfmon) {
		return;
	}

	memset(&planmetric_packet, 0, sizeof(gpmon_packet_t));
	gp_to_gpmmon_set_header(&planmetric_packet, GPMON_PKTTYPE_PLANMETRIC);
	gp_get_monotonic_time(&gptime);

	gpmon_gettmid(&planmetric_packet.u.planmetric.key.tmid);
	planmetric_packet.u.planmetric.key.ssid = (int32)gp_session_id;
	planmetric_packet.u.planmetric.key.ccnt = (int16)gp_command_count;
	planmetric_packet.u.planmetric.key.twms = (int64)gptime.endTime.tv_sec * (int64)USECS_PER_SECOND + (int64)gptime.endTime.tv_usec;
	planmetric_packet.u.planmetric.key.segid = (int16)GpIdentity.segindex;
	planmetric_packet.u.planmetric.key.pid = (int32)MyProcPid;
	planmetric_packet.u.planmetric.key.nid = (int16)plan_node_id;

	planmetric_packet.u.planmetric.node_tag = (int32)plan_node_type;
	planmetric_packet.u.planmetric.t_start = (int32)time(NULL);
	planmetric_packet.u.planmetric.t_finish = (int32)-1;  // TODO

	gpmon_send(&planmetric_packet);
}

/*
 * Report query start to gpperfmon and form a gpmon packet of
 */
void InitPlanNodeGpmonPkt(Plan *plan, gpmon_packet_t *gpmon_pkt, EState *estate)
{
	if (!plan) {
		return;
	}

	ReportPlanMetricGpmonPkt(plan->type, plan->plan_node_id);

	memset(gpmon_pkt, 0, sizeof(gpmon_packet_t));
	gp_to_gpmmon_set_header(gpmon_pkt, GPMON_PKTTYPE_QEXEC);

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

/**
 * Check whether the updates PlanState were reported to gpperfmon,
 * and if they were not, report (send the gpmon packet of this PlanState)
 */
void CheckSendPlanStateGpmonPkt(PlanState *ps)
{
	if (!gp_enable_gpperfmon || !ps) {
		return;
	}

	ReportPlanMetricGpmonPkt(ps->type, ps->plan->plan_node_id); // TODO: Try other options

	if (!ps->fHadSentGpmon || ps->gpmon_plan_tick != gpmon_tick)
	{
		if (ps->state && LocallyExecutingSliceIndex(ps->state) == currentSliceId)
		{
			gpmon_send(&ps->gpmon_pkt);
		}
		ps->fHadSentGpmon = true;
	}
	ps->gpmon_plan_tick = gpmon_tick;
}

/**
 * Report query finish to gpperfmon
 */
void EndPlanStateGpmonPkt(PlanState *ps)
{
	if (!ps) {
		return;
	}

	ReportPlanMetricGpmonPkt(ps->type, ps->plan->plan_node_id);

	ps->gpmon_pkt.u.qexec.status = (uint8)PMNS_Finished;

	if (gp_enable_gpperfmon && ps->state &&
		LocallyExecutingSliceIndex(ps->state) == currentSliceId)
	{
		gpmon_send(&ps->gpmon_pkt);
	}
}

