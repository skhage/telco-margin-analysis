# Scene 5 + 6 click script and storyboard (live or recorded fallback)

Scenes: 5 "From insight to action" (agents act, people approve) and 6 "Prove it to audit" (every action has an identity and a record).
App: `lakelink-margin-truth`, which is the ONE app. Use this script live if gates 1+2 clear, or to record the DEC-018 fallback (cutoff Nov 15 12:00 CT).

## Fixed demo data (verified 2026-11-13 in app Lakebase `public.approval_tickets`)
Exact cents are in this table. The currently deployed build (01f1df66) shows whole US dollars (`fmtUsd` with 0 decimals), so the storyboard quotes the values you will see on screen today.

| Ticket | Type | Approver | Circuit | Vendor (name / ID) | Monthly cost | Est. monthly savings | On screen |
| --- | --- | --- | --- | --- | --- | --- | --- |
| GROOM-44c3612b69 | offnet_grooming | Ops | 45040 | Partner Carrier 55 / 00100000000265pAAA | 2,880.05 | 879.34 | $2,880 / $879 |
| GROOM-6d8f8ce31e | offnet_grooming | Ops | 98532 | Partner Carrier 47 / 00100000000265hAAA | 2,469.86 | 469.00 | $2,470 / $469 |
| GROOM-1e655052ef (LIVE APPROVE TARGET, DEC-037a) | offnet_grooming | Ops | 10211 | Partner Carrier 28 / 00100000000264YAAA | 1,364.58 | 1,357.85 | $1,365 / $1,358 |

Scene-5 pre-roll Ops queue = exactly 3 pending non-TEST tickets (DEC-037a, verified 2026-11-14 ~01:30 UTC in app Lakebase; values tie to MEASURE() on `cdm_tmforum._metrics.margin_offnet_spend_mv`, diff 0.00). The presenter approves GROOM-1e655052ef (circuit 10211) live; 45040 and 98532 stay pending. Scene 6 opens 10211's own trace tr-2b088edfed85d22b2db662a6c0a7c68e (real Margin Genie call + score_onnet_move + ticket INSERT).

Note: the source formatter now shows 2 dp (QA-F-APP-CM-0DP, DEC-030). After the next redeploy the on-screen values become $2,880.05 / $879.34 and $2,469.86 / $469.00.

Trace rule (APP-EVIDENCE-TRACE-FROM-TICKET): this script does NOT name a trace id. The evidence panel builds its "Open trace" link from the approved ticket's own `approval_tickets.trace_id` (server/index.ts: `ticket.trace_id`, else the `trace_id` in the agent's `created` audit row). Before recording, read the id with `SELECT ticket_id, trace_id FROM public.approval_tickets WHERE status='pending'` and open only that trace in scene 6.

SCOPE NOTE (DEC-037a, 2026-11-14): the override below applies ONLY to GROOM-44c3612b69 / GROOM-6d8f8ce31e. The live approve target GROOM-1e655052ef has its own trace_id tr-2b088edfed85d22b2db662a6c0a7c68e with a real Margin Genie call, so for it the evidence-panel "Open trace" link IS the scene-6 trace.
GATED-STATE OVERRIDE (COO-Q-20261113-77, @ml-engineer 2026-11-13): while ML-HERO-REDRAFT-LIVE-GENIE is gated, both hero tickets carry trace_id tr-d9fef3bfbebebdad7bedf0bb88cd0f83, whose `ask_margin_genie` span is the SQL fallback (genie_basis=sql_fallback). NEVER click the evidence-panel "Open trace" link and never open tr-d9fef3bf. Steps 6-7 instead: open the MLflow experiment `margin_grooming_agent_traces` (ID 1235449331932066) > Traces tab in a pre-opened second browser tab, search request ID `tr-7e87cf4df0dfdbf4a2ae39e1f1ab0478`, and open that trace. It has 11 spans; `ask_margin_genie` has genie_basis=margin_genie on `_metrics.margin_offnet_spend_mv` (47 rows); both `draft_savings_ticket` spans return existing_ticket GROOM-44c3612b69 and GROOM-6d8f8ce31e, which is the on-screen link from these two tickets to this trace. Say: "This is the agent run that confirmed these two tickets through Margin Genie." Remove this override once the re-draft lands and the ticket's own trace_id has genie_basis=margin_genie.

Agent: `approval_tickets.agent_name` = `lakelink-margin-grooming-agent` on both hero tickets (checked 2026-11-13, DSN-SCENE5-R1). The app's Agent column and the evidence panel show this value. `lakelink_offnet_grooming_agent` is only the root span name inside the MLflow trace (step 6). Vendor names come from `cdm_tmforum.revenue_assurance.margin_vendors`. If the app cannot read that table, the Vendor column shows only the ID.

Both hero tickets come from ONE grooming-agent run, so they share one trace. TEST-GROOM-4d4c099b0e is hidden by `SHOW_TEST_TICKETS=false`. Its row is kept by decision DEC-038 (no DELETE, no UPDATE; approval_audit row 3 references it through FK approval_audit_ticket_id_fkey and is never touched). "No TEST rows" means no TEST rows on screen. Verified 2026-11-14 ~03:1x UTC: pending = GROOM-44c3612b69, GROOM-6d8f8ce31e, GROOM-1e655052ef + hidden TEST-GROOM-4d4c099b0e.
As of 2026-11-13 the shared trace on both hero tickets (experiment 1235449331932066) has state OK, 11 spans, and ran about 36 s. A re-draft (ML-HERO-REDRAFT-LIVE-GENIE) gives a new trace id. The panel picks it up automatically, so this script needs no edit. Span order: `lakelink_offnet_grooming_agent`, `gateway_chat`, `ask_margin_genie`, `score_onnet_move`, `score_onnet_move`, `gateway_chat`, `draft_savings_ticket`, `score_onnet_move`, `draft_savings_ticket`, `score_onnet_move`, `gateway_chat` (4 scoring calls, 2 ticket drafts).
Identity caveat: `agent_sp_name` / `agent_sp_app_id` are NULL on both tickets. The trace was run under the user identity (user_fallback). Until an agent SP exists (cutoff Nov 15 12:00 CT, fallback ML-GROOMING-FALLBACK-PATH), use the COO-Q-20261113-46 (c) line: "Today the agent runs under my own identity, so every model call, Genie query and ticket is logged against a named person. In production it runs as its own service principal, lakelink-margin-grooming-agent, with least-privilege grants on the margin tables only." Do not claim an SP on screen. If tickets are re-drafted with AGENT_SP_APP_ID set, the panel shows the SP and the line changes to the SP.

## Pre-roll (before recording)
1. Confirm REDEPLOY.md verify steps 1-4 pass.
2. Leave all 3 hero tickets (45040, 98532, 10211) `pending`. If either was approved in a rehearsal, ask @ml-engineer to re-draft. The dedup guard returns `existing_ticket` for pending tickets only.
3. Browser at 1440x900 and 100% zoom, signed in as the presenter (the approver email is taken from x-forwarded-email).
4. Do not open the Margin explorer tab in scenes 5-6 while the live deployment is 01f1df66 (check `active_deployment` in REDEPLOY.md step 1). That build shows contribution margin in whole dollars (for example Wavelength $1,815,451,951), not to the cent (DEC-030). Stay on the Approval queue tab and its evidence panel: they show only ticket monthly cost and savings, with no CM value. For CM, quote Margin Genie (USD 2,375,095,705.09) or the dashboard. If a later redeploy shows $2,375,095,705.09 in the explorer, you can remove this step. (DSN-REVIEW-COO-Q-20261114-1-FALLBACK)

## Storyboard
| # | Screen | Click | Say | Expected on screen |
| --- | --- | --- | --- | --- |
| 1 | Header "Lakelink Fiber \| Margin Truth" | None | "The grooming agent asked Margin Genie, scored the circuits, and drafted savings tickets." | Tabs: Approval queue, Margin explorer, Margin Genie (one panel visible at a time) |
| 2 | Approval queue | Approver role = Ops, Status = Pending | "Ops owns off-net grooming approvals." | 3 tickets, circuits 10211, 98532 and 45040 (newest first), no TEST rows |
| 3 | Row GROOM-1e655052ef | Read the rationale under the ticket title | "Circuit 10211 runs 476 meters from our own fiber. We lease it from Partner Carrier 28 for $1,365 a month and can save $1,358." | Monthly cost $1,365, Est. monthly savings $1,358, Vendor "Partner Carrier 28" with ID 00100000000264YAAA below it, rationale "Margin Genie confirms circuit 10211 runs parallel to Lakelink Fiber's own fiber at only 476 meters distance..." |
| 4 | Same row | Type "Move on-net Q1" in Comment (optional), then Approve | "Agents act, people approve." | Row leaves the pending list. Screen reader announcement: "<ticket title> approved by Ops. Decision recorded in the audit log." Focus moves to "Evidence for GROOM-1e655052ef" |
| 5 | Evidence for GROOM-1e655052ef | Opens after the decision | "Every action has an identity and a record." | Agent: lakelink-margin-grooming-agent. Audit row: action Approved, actor = presenter email, role Ops, timestamp, details "Comment: Move on-net Q1" |
| 6 | Evidence panel | Click "Open trace <id>" (the id is this ticket's own approval_tickets.trace_id) | "Here is every step the agent took." | MLflow trace tr-2b088edfed85d22b2db662a6c0a7c68e: ask_margin_genie (real Margin Genie call), score_onnet_move, draft_savings_ticket (INSERT) |
| 7 | Trace span `ask_margin_genie` | Expand | "Same Margin Genie and same contribution margin as the dashboard." | Genie question and answer |
| 8 | Back to app | None (do NOT approve the other tickets) | "Two more candidates, 45040 and 98532, are waiting for Ops." | 2 tickets remain pending for Ops: GROOM-6d8f8ce31e (98532) and GROOM-44c3612b69 (45040) |

Approved on stage: $1,358 a month on screen (exact 1,357.85). Still pending after scene 5: 879.34 + 469.00 = 1,348.34 a month.

## Reset after a rehearsal
Approved tickets cannot be re-approved (409, not pending).
1. Reject or approve the hero tickets in the app. This frees the dedup guard, which only matches pending non-TEST tickets.
2. Ask @ml-engineer to re-draft: run the grooming agent with DRY_RUN=False against the live Margin Genie space. Expect exactly 2 new pending tickets (45040, 98532) sharing one NEW trace_id.
3. Re-read `approval_tickets.trace_id` (see the Trace rule above). Do not copy an old id into this script.
Never DELETE or UPDATE approval_audit rows or decided tickets.

## Stills pack captions (DEC-025 / DEC-037a / DEC-038, 3-ticket queue)
Workspace copy of record. The volume copy in /Volumes/cdm_tmforum/revenue_assurance/margin_documents/recordings/scene5/ is deferred (scheduled runs cannot write the volume); regenerate post-freeze or by the CEO.

| Frame | Caption |
| --- | --- |
| frame1_queue | Ops Approval queue, Pending: 3 tickets, newest first: GROOM-1e655052ef (10211), GROOM-6d8f8ce31e (98532), GROOM-44c3612b69 (45040). No TEST rows on screen. |
| frame2_detail | GROOM-1e655052ef, circuit 10211, vendor Partner Carrier 28 (00100000000264YAAA): monthly cost 1,364.58, est. monthly savings 1,357.85. Comment "Move on-net Q1", then Approve. |
| frame3_evidence (PROJECTED) | "Approved by Ops. Decision recorded in the audit log." 2 tickets remain pending (98532, 45040). Evidence panel: agent lakelink-margin-grooming-agent, audit row Approved, trace tr-2b088edfed85d22b2db662a6c0a7c68e. |
| tie-out row | Ticket values = MEASURE(monthly_offnet_cost) / MEASURE(est_monthly_savings) on cdm_tmforum._metrics.margin_offnet_spend_mv: 10211 1,364.58 / 1,357.85; 45040 2,880.05 / 879.34; 98532 2,469.86 / 469.00 (diff 0.00, 2026-11-14). |

## Recording tips (fallback)
Record scenes 5-6 as one take of about 90 s. Also take a still screenshot of steps 5 and 6 as a second-level fallback (plan: "recorded walkthrough of scenes 1 to 6").
