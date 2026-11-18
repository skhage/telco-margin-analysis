# Scene 5 on-stage grooming run config (Lakelink Fiber Margin Truth)
**DEC-118 BANNER (2026-11-17):** Lines 58-113 (pinned rc4 cells l.63-103 + stop rule l.105-109) are the LIVE ANNEX of CEO_ACTION_SHEET.md l.87 and are NOT superseded; the DEC-115 SUPERSEDED label applies only to the rest of this file.  
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
* Code default aligned 2026-11-14 23:22 UTC (ML-S5-ALLOWLIST-DEFAULT / COO-Q-20261114-96): agents/margin_grooming_agent.py now ships INSERT_ALLOWLIST = {35360} (md5 7c7a2ed87ff2653cdc4d5b1cd7691800). No presenter step needed to set it. Fresh DRY_RUN trace tr-7423ff956174e02766a1427b6fde2dcd: would_insert 35360, CM 2,375,095,705.09; queue unchanged (4 rows, 3 pending non-TEST, 0 for 35360).

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

## Presenter session procedure, rc4 build of record (COO-Q-20261117-52, @ml-engineer 2026-11-17 ~15:30 UTC)
Build of record: git d624244 (origin/main). agents/margin_grooming_agent.py blob md5 824f52d39ee968b66d46c344a55580f0 (448 lines; l.54 DRY_RUN = True, l.108 INSERT_ALLOWLIST = {35360}, l.109 MAX_NEW_TICKETS = 1, l.57 GENIE_TIMEOUT_S = 25, l.58 RUN_DEADLINE_S = 60, l.98 MLFLOW_EXPERIMENT_ID 1235449331932066, l.446-448 task text). agents/margin_grooming_agent_tools.py blob md5 15eaf3e04cf531f46f0466e75f2dc6f4 (105 lines). Never run the working-copy files (md5 207b207b / ec2e1421, drifted).

Run in a fresh serverless notebook session. Run cells 1-3 once before the show as the warm-up, then run cell 3 again for the stage run.

Cell 1 (materialize, ~1-6 s):
```python
import subprocess, hashlib, os
P = "/Workspace/Users/stephen.hage@databricks.com/telco-margin-analysis"
os.makedirs("/tmp/rc4", exist_ok=True)
for f, want in [("margin_grooming_agent.py", "824f52d39ee968b66d46c344a55580f0"),
                ("margin_grooming_agent_tools.py", "15eaf3e04cf531f46f0466e75f2dc6f4")]:
    b = subprocess.run(["git", "-C", P, "show", f"d624244:agents/{f}"], capture_output=True, check=True).stdout
    open(f"/tmp/rc4/{f}", "wb").write(b)
    assert hashlib.md5(b).hexdigest() == want, f
```

Cell 2 (import, ~0.4-3.3 s):
```python
import sys, time, mlflow
sys.path.insert(0, "/tmp/rc4")
import margin_grooming_agent as ga
assert ga.DRY_RUN is True and ga.INSERT_ALLOWLIST == {35360} and ga.MAX_NEW_TICKETS == 1
TASK = ("Find Lakelink Fiber off-net circuits that run next to our own fiber and draft savings tickets "
        "for good candidates. Start by asking Margin Genie which off-net circuits run next to our own "
        "fiber and what we pay for them, then score circuits 45040 and 98532 individually.")
tags = dict(source_path="git:d624244:agents/margin_grooming_agent.py", source_md5="824f52d39ee968b66d46c344a55580f0",
            tools_md5="15eaf3e04cf531f46f0466e75f2dc6f4", git_ref="d624244", dry_run="True", series="S5-stage")
```

Cell 3 (agent run, 45-73 s observed):
```python
err = out = None
with mlflow.start_run(experiment_id="1235449331932066") as run:
    mlflow.log_params(tags)
    t = time.time()
    try:
        out = ga.run_agent(TASK)
    except Exception as e:
        err = repr(e)[:300]
    wall = round(time.time() - t, 1)
tr = mlflow.get_last_active_trace_id()
for k, v in tags.items():
    mlflow.MlflowClient().set_trace_tag(tr, k, v)
print("wall", wall, "trace", tr, "err", err)
```

### Stop rule (wall clock, presenter)
* Order (DEC-113(2)): approve the pre-run ticket GROOM-1e655052ef (circuit 10211) first. The live run is optional and comes after.
* Start a stopwatch when cell 3 starts. If cell 3 has not printed by 75 s, or it prints err that is not None (for example TypeError ... missing 'rationale', the empty-args crash QA-F-ML-EMPTY-ARGS-CRASH-1117), STOP. Do not re-run on stage. Switch to the pre-run fallback: open trace tr-2b088edfed85d22b2db662a6c0a7c68e (the one S5/S6 fallback per DEC-142; ticket GROOM-1e655052ef, circuit 10211) in the Traces tab of experiment 1235449331932066.
* 75 s = slowest successful observed run (73.5 s) plus a small margin. RUN_DEADLINE_S = 60 (l.58) already blocks any late ticket write; with DRY_RUN = True nothing is written anyway.
* Observed rc4 empty-args event since 11-16: 8 of 33 runs (about 24%). Unguarded stage code: 4 of 18 runs ended ERROR (22.2%). Guarded copy: 0 of 15 ERROR, but slower (61-68 s). Expect about 1 in 4 to 1 in 5 unguarded live runs to hit the stop rule (ML-RC4-GUARD-SCRATCH-1117).

### Evidence for this procedure
* Session 1117-142052-qunmczr9-v2n (14:2x UTC): git 0.79 s, import 3.28 s, DRY_RUN #1 65.3 s OK tr-5afbb3f8272b71d29ebbc812494cd165, DRY_RUN #2 48.7 s ERROR tr-66d91b99726fff903dbc9cf0e8b86e29.
* Session 1117-152050-6cl2lkzf-v2n (15:2x UTC, these exact cells): md5 both MATCH, import 0.43 s, run #1 45.7 s ERROR (empty-args TypeError) tr-12f835d44dacfafa4ed9a7a8204b570b, run #2 57.5 s OK tr-0476def75bebea06b6a3119bb8f23878 (6 tool calls, CM 2,375,095,705.09, 47 candidates / 1,152,342.12 / 412,539.96).
