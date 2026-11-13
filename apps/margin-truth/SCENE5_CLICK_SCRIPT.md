# Scene 5 + 6 click script and storyboard (live or recorded fallback)

Scenes: 5 "From insight to action" (agents act, people approve) and 6 "Prove it to audit" (every action has an identity and a record).
App: `lakelink-margin-truth`, which is the ONE app. Use this script live if gates 1+2 clear, or to record the DEC-018 fallback (cutoff Nov 15 12:00 CT).

## Fixed demo data (verified 2026-11-13 in app Lakebase `public.approval_tickets`)
Exact cents are in this table. The currently deployed build (01f1df66) shows whole US dollars (`fmtUsd` with 0 decimals), so the storyboard quotes the values you will see on screen today.

| Ticket | Type | Approver | Circuit | Vendor (name / ID) | Monthly cost | Est. monthly savings | On screen |
| --- | --- | --- | --- | --- | --- | --- | --- |
| GROOM-44c3612b69 | offnet_grooming | Ops | 45040 | Partner Carrier 55 / 00100000000265pAAA | 2,880.05 | 879.34 | $2,880 / $879 |
| GROOM-6d8f8ce31e | offnet_grooming | Ops | 98532 | Partner Carrier 47 / 00100000000265hAAA | 2,469.86 | 469.00 | $2,470 / $469 |

Note: the source formatter now shows 2 dp (QA-F-APP-CM-0DP, DEC-030). After the next redeploy the on-screen values become $2,880.05 / $879.34 and $2,469.86 / $469.00.

Trace rule (APP-EVIDENCE-TRACE-FROM-TICKET): this script does NOT name a trace id. The evidence panel builds its "Open trace" link from the approved ticket's own `approval_tickets.trace_id` (server/index.ts: `ticket.trace_id`, else the `trace_id` in the agent's `created` audit row). Before recording, read the id with `SELECT ticket_id, trace_id FROM public.approval_tickets WHERE status='pending'` and open only that trace in scene 6.

Agent: `approval_tickets.agent_name` = `lakelink-margin-grooming-agent` on both hero tickets (checked 2026-11-13, DSN-SCENE5-R1). The app's Agent column and the evidence panel show this value. `lakelink_offnet_grooming_agent` is only the root span name inside the MLflow trace (step 6). Vendor names come from `cdm_tmforum.revenue_assurance.margin_vendors`. If the app cannot read that table, the Vendor column shows only the ID.

Both hero tickets come from ONE grooming-agent run, so they share one trace. TEST-GROOM-4d4c099b0e is hidden by `SHOW_TEST_TICKETS=false`. Its row is kept.
As of 2026-11-13 the shared trace on both hero tickets (experiment 1235449331932066) has state OK, 11 spans, and ran about 36 s. A re-draft (ML-HERO-REDRAFT-LIVE-GENIE) gives a new trace id. The panel picks it up automatically, so this script needs no edit. Span order: `lakelink_offnet_grooming_agent`, `gateway_chat`, `ask_margin_genie`, `score_onnet_move`, `score_onnet_move`, `gateway_chat`, `draft_savings_ticket`, `score_onnet_move`, `draft_savings_ticket`, `score_onnet_move`, `gateway_chat` (4 scoring calls, 2 ticket drafts).
Identity caveat: `agent_sp_name` / `agent_sp_app_id` are NULL on both tickets. The trace was run under the user identity (user_fallback). Until an agent SP exists (cutoff Nov 15 12:00 CT, fallback ML-GROOMING-FALLBACK-PATH), use the COO-Q-20261113-46 (c) line: "Today the agent runs under my own identity, so every model call, Genie query and ticket is logged against a named person. In production it runs as its own service principal, lakelink-margin-grooming-agent, with least-privilege grants on the margin tables only." Do not claim an SP on screen. If tickets are re-drafted with AGENT_SP_APP_ID set, the panel shows the SP and the line changes to the SP.

## Pre-roll (before recording)
1. Confirm REDEPLOY.md verify steps 1-4 pass.
2. Leave both hero tickets `pending`. If either was approved in a rehearsal, ask @ml-engineer to re-draft. The dedup guard returns `existing_ticket` for pending tickets only.
3. Browser at 1440x900 and 100% zoom, signed in as the presenter (the approver email is taken from x-forwarded-email).

## Storyboard
| # | Screen | Click | Say | Expected on screen |
| --- | --- | --- | --- | --- |
| 1 | Header "Lakelink Fiber \| Margin Truth" | None | "The grooming agent asked Margin Genie, scored the circuits, and drafted savings tickets." | Tabs: Approval queue, Margin explorer, Margin Genie (one panel visible at a time) |
| 2 | Approval queue | Approver role = Ops, Status = Pending | "Ops owns off-net grooming approvals." | 2 tickets, circuits 45040 and 98532, no TEST rows |
| 3 | Row GROOM-44c3612b69 | Read the rationale under the ticket title | "Circuit 45040 runs next to our own fiber. We lease it from Partner Carrier 55 for $2,880 a month and can save $879." | Monthly cost $2,880, Est. monthly savings $879, Vendor "Partner Carrier 55" with ID 00100000000265pAAA below it, rationale "Circuit runs parallel to Lakelink Fiber's own fiber at 51m distance..." |
| 4 | Same row | Type "Move on-net Q1" in Comment (optional), then Approve | "Agents act, people approve." | Row leaves the pending list. Screen reader announcement: "<ticket title> approved by Ops. Decision recorded in the audit log." Focus moves to "Evidence for GROOM-44c3612b69" |
| 5 | Evidence for GROOM-44c3612b69 | Opens after the decision | "Every action has an identity and a record." | Agent: lakelink-margin-grooming-agent. Audit row: action Approved, actor = presenter email, role Ops, timestamp, details "Comment: Move on-net Q1" |
| 6 | Evidence panel | Click "Open trace <id>" (the id is this ticket's own approval_tickets.trace_id) | "Here is every step the agent took." | MLflow trace, 11 spans: Genie call, 4 score_onnet_move calls, 2 draft_savings_ticket spans |
| 7 | Trace span `ask_margin_genie` | Expand | "Same Margin Genie and same contribution margin as the dashboard." | Genie question and answer |
| 8 | Back to app | Approve GROOM-6d8f8ce31e (optional, shows the second ticket) | "Second circuit, 98532, from Partner Carrier 47, saves $469 a month." | Queue empty for Ops |

Total hero savings: $1,348 a month on screen (exact 879.34 + 469.00 = 1,348.34 in the data table).

## Reset after a rehearsal
Approved tickets cannot be re-approved (409, not pending).
1. Reject or approve the hero tickets in the app. This frees the dedup guard, which only matches pending non-TEST tickets.
2. Ask @ml-engineer to re-draft: run the grooming agent with DRY_RUN=False against the live Margin Genie space. Expect exactly 2 new pending tickets (45040, 98532) sharing one NEW trace_id.
3. Re-read `approval_tickets.trace_id` (see the Trace rule above). Do not copy an old id into this script.
Never DELETE or UPDATE approval_audit rows or decided tickets.

## Recording tips (fallback)
Record scenes 5-6 as one take of about 90 s. Also take a still screenshot of steps 5 and 6 as a second-level fallback (plan: "recorded walkthrough of scenes 1 to 6").
