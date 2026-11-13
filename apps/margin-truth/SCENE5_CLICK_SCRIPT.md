# Scene 5 + 6 click script and storyboard (live or recorded fallback)

Scenes: 5 "From insight to action" (agents act, people approve) and 6 "Prove it to audit" (every action has an identity and a record).
App: `lakelink-margin-truth`, which is the ONE app. Use this script live if gates 1+2 clear, or to record the DEC-018 fallback (cutoff Nov 15 12:00 CT).

## Fixed demo data (verified 2026-11-13 in app Lakebase `public.approval_tickets`)
Exact cents are kept only in this table. The app shows whole US dollars (design rule, `fmtUsd` with 0 decimals), so the storyboard quotes the values you will see on screen.

| Ticket | Type | Approver | Circuit | Vendor (name / ID) | Monthly cost | Est. monthly savings | On screen | Trace |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| GROOM-44c3612b69 | offnet_grooming | Ops | 45040 | Partner Carrier 55 / 00100000000265pAAA | 2,880.05 | 879.34 | $2,880 / $879 | tr-d9fef3bfbebebdad7bedf0bb88cd0f83 |
| GROOM-6d8f8ce31e | offnet_grooming | Ops | 98532 | Partner Carrier 47 / 00100000000265hAAA | 2,469.86 | 469.00 | $2,470 / $469 | tr-d9fef3bfbebebdad7bedf0bb88cd0f83 |

Agent: `approval_tickets.agent_name` = `lakelink-margin-grooming-agent` on both hero tickets (checked 2026-11-13, DSN-SCENE5-R1). The app's Agent column and the evidence panel show this value. `lakelink_offnet_grooming_agent` is only the root span name inside the MLflow trace (step 6). Vendor names come from `cdm_tmforum.revenue_assurance.margin_vendors`. If the app cannot read that table, the Vendor column shows only the ID.

Both hero tickets come from ONE grooming-agent run, so they share one trace. TEST-GROOM-4d4c099b0e is hidden by `SHOW_TEST_TICKETS=false`. Its row is kept.
Trace tr-d9fef3bfbebebdad7bedf0bb88cd0f83 (experiment 1235449331932066) has state OK, 11 spans, and ran about 36 s. Span order: `lakelink_offnet_grooming_agent`, `gateway_chat`, `ask_margin_genie`, `score_onnet_move`, `score_onnet_move`, `gateway_chat`, `draft_savings_ticket`, `score_onnet_move`, `draft_savings_ticket`, `score_onnet_move`, `gateway_chat` (4 scoring calls, 2 ticket drafts).
Identity caveat: `agent_sp_name` / `agent_sp_app_id` are NULL on both tickets. The trace was run under the user identity. Until an agent SP exists (cutoff Nov 15 12:00 CT, fallback ML-GROOMING-FALLBACK-PATH), say: "Today this ran under a named user. In production each agent has its own service principal." Do not claim an SP on screen.

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
| 6 | Evidence panel | Open trace tr-d9fef3... | "Here is every step the agent took." | MLflow trace, 11 spans: Genie call, 4 score_onnet_move calls, 2 draft_savings_ticket spans |
| 7 | Trace span `ask_margin_genie` | Expand | "Same Margin Genie and same contribution margin as the dashboard." | Genie question and answer |
| 8 | Back to app | Approve GROOM-6d8f8ce31e (optional, shows the second ticket) | "Second circuit, 98532, from Partner Carrier 47, saves $469 a month." | Queue empty for Ops |

Total hero savings: $1,348 a month on screen (exact 879.34 + 469.00 = 1,348.34 in the data table).

## Reset after a rehearsal
Approved tickets cannot be re-approved (409, not pending). Ask @ml-engineer to re-run the agent with DRY_RUN=False to draft fresh pending tickets. Never DELETE or UPDATE audit rows.

## Recording tips (fallback)
Record scenes 5-6 as one take of about 90 s. Also take a still screenshot of steps 5 and 6 as a second-level fallback (plan: "recorded walkthrough of scenes 1 to 6").
