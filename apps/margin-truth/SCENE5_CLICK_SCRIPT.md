# Scene 5 + 6 click script and storyboard (live or recorded fallback)

Scenes: 5 "From insight to action" (agents act, people approve) and 6 "Prove it to audit" (every action has an identity and a record).
App: `lakelink-margin-truth`, which is the ONE app. Use this script live if gates 1+2 clear, or to record the DEC-018 fallback (cutoff Nov 15 12:00 CT).

## Fixed demo data (verified 2026-11-13 in app Lakebase `public.approval_tickets`)
Exact cents are in this table. Open the app by name (lakelink-margin-truth; active deployment of record 01f1e21c, DEC-108). The storyboard quotes exact cents (DEC-030); check on screen that the values match before you quote them. Values re-verified 2026-11-16 ~21:30 UTC in app Lakebase and against MEASURE() on `cdm_tmforum._metrics.margin_offnet_spend_mv` (diff 0.00).

| Ticket | Type | Approver | Circuit | Vendor (name / ID) | Monthly cost | Est. monthly savings | On screen |
| --- | --- | --- | --- | --- | --- | --- | --- |
| GROOM-44c3612b69 | offnet_grooming | Ops | 45040 | Partner Carrier 55 / 00100000000265pAAA | 2,880.05 | 879.34 | $2,880.05 / $879.34 |
| GROOM-6d8f8ce31e (REJECTED 2026-11-17 15:28:00Z, audit_id 12; not in the Pending list) | offnet_grooming | Ops | 98532 | Partner Carrier 47 / 00100000000265hAAA | 2,469.86 | 469.00 | Not shown under Pending |
| GROOM-1e655052ef (LIVE APPROVE TARGET, DEC-037a) | offnet_grooming | Ops | 10211 | Partner Carrier 28 / 00100000000264YAAA | 1,364.58 | 1,357.85 | $1,364.58 / $1,357.85 |

Scene-5 pre-roll Ops queue (DEC-117 / DEC-121, re-verified read-only 2026-11-17 ~17:2x UTC in app Lakebase `public.approval_tickets`; hero values tie to MEASURE() on `cdm_tmforum._metrics.margin_offnet_spend_mv`, diff 0.00). GROOM-6d8f8ce31e (98532) is rejected, so it is not in the Pending list. Pick the branch that matches the queue at show time. Check it with `SELECT ticket_id, circuit_id, status FROM public.approval_tickets WHERE status='pending' AND ticket_id NOT LIKE 'TEST-%' ORDER BY created_at DESC`.
* **Branch A: DEC-117(5) cleanup ran by 2026-11-18 18:00Z.** The 5 untraced 15:26:01Z tickets are status `rejected`, with an approval_audit row each. 2 pending, newest first: row 1 GROOM-1e655052ef (10211), row 2 GROOM-44c3612b69 (45040). After the approve, 45040 is still pending ($879.34 a month).
* **Branch B: no cleanup.** 7 pending, newest first. Rows 1-5 are the untraced 15:26:01Z tickets GROOM-695bb7c525, -36f2c510c9, -0a57924117, -d3dd7dd2c8 and -00bf23be93. They share one created_at, so their order among rows 1-5 can change between loads. Row 6 is GROOM-1e655052ef (10211) and row 7 is GROOM-44c3612b69 (45040). Do not click, name or describe rows 1-5 (DEC-121(a)). After the approve, 6 stay pending, including 45040.
* In both branches, the presenter selects GROOM-1e655052ef **by ticket_id**, never by "top of queue" or row position (DEC-117(3)). GROOM-44c3612b69 is the backup. Presenter line (DEC-121(a), replaces the DEC-117(4) line): "This is the ticket the agent drafted from the trace we just ran."

The presenter approves GROOM-1e655052ef (circuit 10211) live. Scene 6 opens 10211's own trace tr-2b088edfed85d22b2db662a6c0a7c68e (real Margin Genie call + score_onnet_move + ticket INSERT).

Trace rule (APP-EVIDENCE-TRACE-FROM-TICKET): this script does NOT name a trace id. The evidence panel builds its "Open trace" link from the approved ticket's own `approval_tickets.trace_id` (server/index.ts: `ticket.trace_id`, else the `trace_id` in the agent's `created` audit row). Before recording, read the id with `SELECT ticket_id, trace_id FROM public.approval_tickets WHERE status='pending'` and open only that trace in scene 6.

SCOPE NOTE (DEC-037a, 2026-11-14): the override below applies ONLY to GROOM-44c3612b69 / GROOM-6d8f8ce31e. The live approve target GROOM-1e655052ef has its own trace_id tr-2b088edfed85d22b2db662a6c0a7c68e with a real Margin Genie call, so for it the evidence-panel "Open trace" link IS the scene-6 trace.
Not used in the storyboard. Applies only if the presenter opens 45040 or 98532.
GATED-STATE OVERRIDE (COO-Q-20261113-77, @ml-engineer 2026-11-13): while ML-HERO-REDRAFT-LIVE-GENIE is gated, tickets 45040 and 98532 carry trace_id tr-d9fef3bfbebebdad7bedf0bb88cd0f83, whose `ask_margin_genie` span is the SQL fallback (genie_basis=sql_fallback). NEVER click the evidence-panel "Open trace" link and never open tr-d9fef3bf. Steps 6-7 instead: open the MLflow experiment `margin_grooming_agent_traces` (ID 1235449331932066) > Traces tab in a pre-opened second browser tab, search request ID `tr-7e87cf4df0dfdbf4a2ae39e1f1ab0478`, and open that trace. It has 11 spans; `ask_margin_genie` has genie_basis=margin_genie on `_metrics.margin_offnet_spend_mv` (47 rows); the two `draft_savings_ticket` spans return existing_ticket GROOM-44c3612b69 and GROOM-6d8f8ce31e, which is the on-screen link from these two tickets to this trace. Say: "This is the agent run that confirmed these two tickets through Margin Genie." Remove this override once the re-draft lands and the ticket's own trace_id has genie_basis=margin_genie.

Agent: `approval_tickets.agent_name` = `lakelink-margin-grooming-agent` on all 3 hero tickets (checked 2026-11-14, DSN-SCENE5-R1 / APP-SCENE5-SCRIPT-3TICKET-R2). The app's Agent column and the evidence panel show this value. `lakelink_offnet_grooming_agent` is only the root span name inside the MLflow trace (step 6). Vendor names come from `cdm_tmforum.revenue_assurance.margin_vendors`. If the app cannot read that table, the Vendor column shows only the ID.

45040 and 98532 come from one agent run and share tr-d9fef3bf; 10211 has its own trace tr-2b088edf. TEST-GROOM-4d4c099b0e is hidden by `SHOW_TEST_TICKETS=false`. Its row is kept by decision DEC-038 (no DELETE, no UPDATE; approval_audit row 3 references it through FK approval_audit_ticket_id_fkey and is never touched). "No TEST rows" means no TEST rows on screen. Verified 2026-11-14 ~03:1x UTC: pending = GROOM-44c3612b69, GROOM-6d8f8ce31e, GROOM-1e655052ef + hidden TEST-GROOM-4d4c099b0e.
As of 2026-11-13 the shared trace on 45040 and 98532 (experiment 1235449331932066) has state OK, 11 spans, and ran about 36 s. A re-draft (ML-HERO-REDRAFT-LIVE-GENIE) gives a new trace id. The panel picks it up automatically, so this script needs no edit. Span order: `lakelink_offnet_grooming_agent`, `gateway_chat`, `ask_margin_genie`, `score_onnet_move`, `score_onnet_move`, `gateway_chat`, `draft_savings_ticket`, `score_onnet_move`, `draft_savings_ticket`, `score_onnet_move`, `gateway_chat` (4 scoring calls, 2 ticket drafts).
Identity caveat: `agent_sp_name` / `agent_sp_app_id` are NULL on all 3 hero tickets. The trace was run under the user identity (user_fallback). Until an agent SP exists (cutoff Nov 15 12:00 CT, fallback ML-GROOMING-FALLBACK-PATH), use this line (DEC-041(b), matches CEO_ACTION_SHEET.md:74/88): "Today the agent runs under the presenter user identity; the target design gives each agent its own service principal." Say 'user identity', not 'service principal', for what runs today. Do not claim an SP on screen. If tickets are re-drafted with AGENT_SP_APP_ID set, the panel shows the SP and the line changes to the SP.

## Pre-roll (before recording)
1. Confirm REDEPLOY.md verify steps 1-4 pass, or, after a rollback, the REDEPLOY.md rollback verify.
2. Leave the 2 remaining hero tickets (10211, 45040) `pending`. 98532 was rejected on 2026-11-17 and stays rejected. If any was approved in a rehearsal, ask @ml-engineer to re-draft. The dedup guard returns `existing_ticket` for pending tickets only.
3. Browser at 1440x900 and 100% zoom, signed in as the presenter (the approver email is taken from x-forwarded-email).
4. Do not open the Margin explorer tab during scenes 1-7. P3-APP-EXPLORER is descoped until after the demo, and the dashboard explorer page covers margin browsing (REDEPLOY.md l.20, CEO_ACTION_SHEET.md l.8). On any build (active deployment of record 01f1e21c, DEC-108), the explorer is not a stage surface for exact CM (DEC-040). Stay on the Approval queue tab and its evidence panel: they show only ticket monthly cost and savings, with no CM value. For CM, quote Margin Genie (USD 2,375,095,705.09) or the dashboard (DEC-040). (DSN-REVIEW-COO-Q-20261114-1-FALLBACK)

## Storyboard
| # | Screen | Click | Say | Expected on screen |
| --- | --- | --- | --- | --- |
| 1 | Header "Lakelink Fiber \| Margin Truth" | None | "The grooming agent asked Margin Genie, scored the circuits, and drafted savings tickets." | Tabs: Approval queue, Margin explorer, Margin Genie (one panel visible at a time) |
| 2 | Approval queue | Approver role = Ops, Status = Pending. Find GROOM-1e655052ef by ticket_id | "Ops owns off-net grooming approvals. This is the ticket the agent drafted from the trace we just ran." | Branch A: 2 tickets, 10211 (row 1) and 45040 (row 2). Branch B: 7 tickets, GROOM-1e655052ef at row 6 under 5 untraced rows (do not mention them). No TEST rows in either branch |
| 3 | Row GROOM-1e655052ef | Read the rationale under the ticket title | "Circuit 10211 runs 476 meters from our own fiber. We lease it from Partner Carrier 28 for $1,364.58 a month and can save $1,357.85." | Monthly cost $1,364.58, Est. monthly savings $1,357.85, Vendor "Partner Carrier 28" with ID 00100000000264YAAA below it, rationale "Margin Genie confirms circuit 10211 runs parallel to Lakelink Fiber's own fiber at only 476 meters distance..." |
| 4 | Same row | Type "Move on-net Q1" in Comment (optional), then Approve | "Agents act, people approve." | Row leaves the pending list. Screen reader announcement: "<ticket title> approved by Ops. Decision recorded in the audit log." Focus moves to "Evidence for GROOM-1e655052ef" |
| 5 | Evidence for GROOM-1e655052ef | Opens after the decision | "Every action has an identity and a record." | Agent: lakelink-margin-grooming-agent. Audit row: action Approved, actor = presenter email, role Ops, timestamp, details "Comment: Move on-net Q1" |
| 6 | Evidence panel | Click "Open trace <id>" (the id is this ticket's own approval_tickets.trace_id) | "Here is every step the agent took." | MLflow trace tr-2b088edfed85d22b2db662a6c0a7c68e: ask_margin_genie (real Margin Genie call), score_onnet_move, draft_savings_ticket (INSERT) |
| 6a | Trace span `margin_metric_view_reference` | Expand (only on 10211's own trace tr-2b088edfed85d22b2db662a6c0a7c68e; skip on the tr-7e87cf4d override path) | "The agent reads the same contribution margin, 2,375,095,705.09, from margin_ledger_mv - you can see it in the trace." | portfolio_contribution_margin_usd 2375095705.09; metric_view_cm cdm_tmforum._metrics.margin_ledger_mv (the ticket itself has no CM; never say the ticket shows CM) |
| 7 | Trace span `ask_margin_genie` | Expand | "The agent asked the same Margin Genie the CFO used." | Genie question and answer (no contribution margin claim here; exact CM is claimed only on Margin Genie and the dashboard, DEC-040) |
| 8 | Back to app | None (do NOT approve or reject any other ticket) | "Another candidate, circuit 45040, is still waiting for Ops." | Branch A: 1 ticket pending, GROOM-44c3612b69 (45040). Branch B: 6 pending, including GROOM-44c3612b69 (45040). 98532 is not pending (rejected) |

Approved on stage: $1,357.85 a month on screen. Quote this for the hero path after scene 5: 45040 is still pending at $879.34 a month. 98532 ($469.00) is rejected and is no longer counted as pending. In Branch B, never quote a total pending amount, because the 5 untraced tickets are not tied to the metric view.

## Reset after a rehearsal
Approved tickets cannot be re-approved (409, not pending).
1. Reject or approve the hero tickets in the app. This frees the dedup guard, which only matches pending non-TEST tickets. The approved 10211 (GROOM-1e655052ef) must be re-drafted before the next take.
2. Ask @ml-engineer to re-draft: run the grooming agent with DRY_RUN=False against the live Margin Genie space. Expect 10211 and 45040 pending, plus any other pending rows from Branch A or Branch B above (98532 stays rejected unless it is re-drafted); 10211 is re-drafted after the rehearsal approve and gets a NEW trace_id. Re-read it per the Trace rule.
3. Re-read `approval_tickets.trace_id` (see the Trace rule above). Do not copy an old id into this script.
Never DELETE or UPDATE approval_audit rows or decided tickets.

## Stills pack captions (DEC-025 / DEC-037a / DEC-038, 3-ticket queue)
Workspace copy of record. The volume copy in /Volumes/cdm_tmforum/revenue_assurance/margin_documents/recordings/scene5/ is deferred (scheduled runs cannot write the volume); regenerate post-freeze or by the CEO.

| Frame | Caption |
| --- | --- |
| frame1_queue | Ops Approval queue, Pending, newest first. Branch A: 2 tickets, GROOM-1e655052ef (10211) and GROOM-44c3612b69 (45040). Branch B: 7 tickets, GROOM-1e655052ef at row 6 (selected by ticket_id). No TEST rows on screen. (The existing frame1 still shows the old 3-ticket state; see DSN-F-STILLS-ORDER-POSTFREEZE.) |
| frame2_detail | GROOM-1e655052ef, circuit 10211, vendor Partner Carrier 28 (00100000000264YAAA): monthly cost $1,364.58, est. monthly savings $1,357.85. Comment "Move on-net Q1", then Approve. |
| frame3_evidence (PROJECTED) | "Approved by Ops. Decision recorded in the audit log." 45040 still pending (Branch A: the only pending ticket; Branch B: one of 6). Evidence panel: agent lakelink-margin-grooming-agent, audit row Approved, trace tr-2b088edfed85d22b2db662a6c0a7c68e. |
| tie-out row | Ticket values = MEASURE(monthly_offnet_cost) / MEASURE(est_monthly_savings) on cdm_tmforum._metrics.margin_offnet_spend_mv: 10211 $1,364.58 / $1,357.85; 45040 $2,880.05 / $879.34; 98532 $2,469.86 / $469.00 (rejected) (diff 0.00, re-verified 2026-11-17). |

## Recording tips (fallback)
Record scenes 5-6 as one take of about 90 s. Also take a still screenshot of steps 5 and 6 as a second-level fallback (plan: "recorded walkthrough of scenes 1 to 6").
