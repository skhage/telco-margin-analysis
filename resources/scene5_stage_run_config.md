# Scene 5 on-stage grooming run config (Lakelink Fiber Margin Truth)

Owner: @ml-engineer. Task: ML-STAGE-RUN-ALLOWLIST (DEC-037a, COO-Q-20261114-8 part d). Verified 2026-11-14 ~02:25 UTC. telco_project = margin_analysis.

## Rule
A live agent run on stage must never draft a second pending ticket for a circuit that already has one. The approval_tickets table has no per-circuit unique constraint (note 1119), so the run config enforces it.

## Pending queue at verification (app Lakebase public.approval_tickets, read-only SELECT)
| ticket_id | circuit_id | status | trace_id |
| --- | --- | --- | --- |
| GROOM-44c3612b69 | 45040 | pending | tr-d9fef3bf... |
| GROOM-6d8f8ce31e | 98532 | pending | tr-d9fef3bf... |
| GROOM-1e655052ef | 10211 | pending | tr-2b088edf... (live approve target, DEC-037a) |
| TEST-GROOM-4d4c099b0e | 45040 | pending | hidden by SHOW_TEST_TICKETS=false (DEC-038) |

The table has 4 rows in total. Pending non-TEST circuits are {10211, 45040, 98532}.

## Chosen stage config (agents/margin_grooming_agent.py module settings)
Option 1 (default, zero side effects):
* DRY_RUN = True
* INSERT_ALLOWLIST = {35360}
* MAX_NEW_TICKETS = 1

Option 2 (only if the CEO wants a real ticket to appear live):
* DRY_RUN = False
* INSERT_ALLOWLIST = {35360}
* MAX_NEW_TICKETS = 1
* Before the run, re-check that `SELECT ticket_id FROM public.approval_tickets WHERE circuit_id='35360'` returns 0 rows. If it does not, fall back to Option 1.
* Run the agent BEFORE approving GROOM-1e655052ef (note 1119).

If a real ticket is created, the queue shows 4 pending non-TEST tickets, not 3. The scene-5 script (apps/margin-truth/SCENE5_CLICK_SCRIPT.md) assumes 3, so Option 1 is the default.

## Stage circuit 35360 (margin_score_onnet_move(35360))
* vendor_id 00100000000264PAAA, parallel to on-net fiber = true, on-net distance 471.00 m
* monthly off-net cost 2,513.61, est. monthly savings 2,307.07, score 95
* Top-scored candidate with no ticket of any status: tied at score 95 with 47257, 51882, 94884 and 95324, and has the highest savings of that tie. 10211 (score 99) is already pending.
* It is one of the 47 Ops hero candidates (sum of est. monthly savings 34,378.33 x 12 = 412,539.96, DEC-026).

## Guard proof (DRY_RUN trace tr-0d79c0ba705c9e035e04f0fcd12af537, experiment 1235449331932066)
The guards run in this order inside draft_savings_ticket: score re-check, then pending dedup, then allowlist/cap, then dry_run.
* 10211: dedup hit -> existing_ticket GROOM-1e655052ef, not re-inserted
* 47257 (valid candidate, not allowlisted): `run insert cap/allowlist: ticket not drafted this run`
* 35360: `dry_run: true`, would_insert GROOM-<new>, cost 2513.61, savings 2307.07, score 95, score_basis carrier_invoice
* After the check, approval_tickets still has 4 rows, 0 for circuit 35360. Nothing was inserted.

## Full-path stage dry run (COO-Q-20261114-15, 2026-11-14)
* tr-0d79c0ba (4.98 s) is a guard-check harness only (3 x draft/score, no Genie, no LLM). Do not quote it as the agent latency.
* Full agent dry run with the stage config: trace tr-f9425413a18437e7211d0c723588d0f1 (experiment 1235449331932066), 73.5 s, tags dry_run=true, genie_mode=margin_genie, identity_mode=user_fallback. Spans: metric view reference 9.5 s, Margin Genie 22.4 s, 4 gateway_chat calls 39.3 s, score 0.9 s, draft 1.1 s. draft_savings_ticket returned would_insert GROOM-f14ea57020, circuit 35360, cost 2,513.61, savings 2,307.07, score 95.
* For comparison, live hero trace tr-2b088edf took 51.7 s. A stage run takes 50-75 s, well over 30 s.
* Pre-rolled fallback: open tr-f9425413 in the Traces tab and do not wait for a live run. After the run the queue still had 4 rows, 0 for 35360, and 3 pending non-TEST tickets.
* The agent's line that 35360 has the highest estimated savings is true. Checked 2026-11-14: in margin_score_onnet_move(NULL) WHERE is_parallel_to_onnet_fiber (172 rows) sorted by est_monthly_savings_usd DESC, 35360 is first at 2,307.07. It does not have the highest score: 10211 scores 99.

## Presenter note
Scene 6 still opens trace tr-2b088edfed85d22b2db662a6c0a7c68e, the trace for the ticket that is approved live (DEC-037a). The stage dry-run trace is optional extra evidence.
Scene 6 guardrail talk-track (ML-S6-GATEWAY-GUARDRAIL-EVIDENCE-R34): "The agent only calls the approved Unity Gateway model cdm_tmforum.revenue_assurance.margin_grooming_agent_llm (Claude Sonnet 4.5), and guardrails are on: sensitive data, jailbreak and unsafe content." Backstage proof only, do not show live: request 9b07ddc1-7b6f-4fe9-8682-8ab6f016d4a5 (2026-11-14 09:22:32 UTC) was blocked by block-sensitive-data before the model call.
