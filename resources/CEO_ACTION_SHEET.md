# Lakelink Fiber Margin Truth: CEO Action Sheet (pinned)

Owner: @pm. Created 2026-11-13 06:10 UTC (COO-Q-20261113-25). This file is the CEO delivery channel because the Slack MCP connector has no send/DM tool in scheduled runs (agent_notes 310). @pm updates it in place every run. Each gate is one copy-paste action, about 15 minutes in total. When you finish a gate, mark the task completed on the Lakebase board, or reply in chat "gate N done".

| # | Gate (task) | Scene blocked | CEO action (exact) | Est. | Cutoff -> automatic fallback (DEC-018) |
| --- | --- | --- | --- | --- | --- |
| 1 | App SP GRANTs (P3-APP-SCAFFOLD) | S5 approval app | Run SQL A below on app Lakebase project telco-margin-analysis-app (endpoint ep-calm-king-d2mq878u), database databricks_postgres | 3 min | Nov 15 12:00 CT -> recorded scene 5 |
| 2 | App redeploy (after gate 1) | S5 | Reply "approve redeploy" in an @app-developer run, or in the Apps UI click Deploy on lakelink-margin-truth (source apps/margin-truth) | 2 min | Nov 16 12:00 CT -> dashboard explorer page |
| 3 | Agent SP (P4-GATEWAY-SP-TRACING) | S6 identity | Command B below (create SP lakelink-margin-grooming-agent + grants) | 4 min | Nov 15 12:00 CT -> user-identity trace (ML-GROOMING-FALLBACK-PATH) |
| 4 | ~~Discover domain quota (DP-ESC-DOMAIN-QUOTA)~~ DONE 2026-11-13: domain 2abc9194-aed9-4088-bfa6-4b4d33870ebd verified by GET (@pm run #9). No CEO action. | - | - | - | - |
| 5 | ~~Genie One capture (PM-GENIE-ONE-CEO-CAPTURE)~~ EXPIRED - default applied (DEC-029b) at Nov 14 18:05 UTC (@pm run #42): no capture in margin_documents/rehearsal/genie_one/. Margin Genie only on stage, no Genie One claim. | S1/S4 | none | - | applied |
| 6 | ~~Delete TEST ticket~~ CLOSED 2026-11-14 by DEC-038: no CEO action. The row stays, because approval_audit FK audit_id=3 references it. The live SHOW_TEST_TICKETS=false filter hides it, so the Ops queue shows exactly 3 tickets. Do NOT run SQL D. | - | - | - | - |
| 7 | @devops approval gate (DEVOPS-JOBS-ONLY-FALLBACK) | Leave-behind DAB | Reply "approve DEVOPS-JOBS-ONLY-FALLBACK" when a @devops run asks, or set the task in_progress on the board | 1 min | Nov 16 12:00 CT -> DAB shown as source in git only |
| 9 | Certify glossary pages (DP-ESC-GLOSSARY-CERTIFY) | S3 trust claim | Discover > Margin domain > Glossary: certify the 15 PUBLISHED Margin pages (ids in agent_notes 1041). Certification is UI-only; the API has no field for it (note 1185) | 5 min | Nov 15 12:00 CT -> say 'published and owned by Finance', not 'certified' |
| 8 | Delete stale pipeline (DE-DELETE-STALE-PIPELINE) - EXPIRED, default applied (DEC-029a) at Nov 14 18:05 UTC (@pm run #42) | S2 | Optional after Nov 19: in the Pipelines UI, delete ccea7e91-e657-4168-82fe-588f4e6437d5 (IDLE, verified 18:04 UTC). Demo shows only 20960984. | 1 min | applied: IDLE, excluded from demo, retire after demo |

## SQL A: app SP grants (gate 1)
```sql
GRANT USAGE ON SCHEMA public TO "606dcc12-ad8e-423a-b7a5-407b87d84121";
GRANT SELECT, UPDATE ON public.approval_tickets TO "606dcc12-ad8e-423a-b7a5-407b87d84121";
GRANT SELECT, INSERT ON public.approval_audit TO "606dcc12-ad8e-423a-b7a5-407b87d84121";
GRANT USAGE ON SEQUENCE public.approval_audit_audit_id_seq TO "606dcc12-ad8e-423a-b7a5-407b87d84121";
```

## Command B: agent SP (gate 3)
1. Workspace Settings > Identity and access > Service principals > Add > name `lakelink-margin-grooming-agent`.
2. In SQL:
```sql
GRANT USE CATALOG ON CATALOG cdm_tmforum TO `lakelink-margin-grooming-agent`;
GRANT USE SCHEMA, SELECT, EXECUTE ON SCHEMA cdm_tmforum.revenue_assurance TO `lakelink-margin-grooming-agent`;
GRANT USE SCHEMA, SELECT ON SCHEMA cdm_tmforum._metrics TO `lakelink-margin-grooming-agent`;
```
(Use the SP application id instead of the display name if the name is rejected.)

## Steps C: Genie One capture (gate 5) - EXPIRED, default applied (DEC-029b); optional only, no stage claim
1. Open Genie One (workspace chat, not the Margin Genie space).
2. Ask: "Which product families lost money after cost to serve last quarter?" Expected: IP-VPN -6,715,475.88 and Legacy Voice -249,532.74.
3. Ask: "What is total contribution margin by product family?" Expected total 2,375,095,705.09.
4. Screenshot both answers plus the SQL panel, showing MEASURE(contribution_margin) from cdm_tmforum._metrics.margin_ledger_mv. Save them to /Volumes/cdm_tmforum/revenue_assurance/margin_documents/rehearsal/genie_one/.

## SQL D: TEST ticket delete (gate 6, RETIRED by DEC-038, do not run)
```sql
DELETE FROM public.approval_tickets WHERE ticket_id = 'TEST-GROOM-4d4c099b0e';
```

## CEO interactive session (COO-Q-20261113-47, @pm 2026-11-13 run #12)

The Genie Code Auto Mode guardrail blocks these in scheduled runs, so the CEO has to run them in ONE interactive Genie Code session or the matching UI. This section is in this sheet (not in a new file) because of the consolidation rule. About 25 minutes total. Slot: Nov 14 (before 18:00 UTC) is preferred. Nov 17 rehearsal is the last slot.

| # | Item (task) | Exact action | Expected before -> after | Rollback | Min | Board confirmer |
| --- | --- | --- | --- | --- | --- | --- |
| I1 | Scene 3 live rule change (COO-Q-20261113-23, -41) | `UPDATE cdm_tmforum.revenue_assurance.margin_allocation_rules SET weight=0.900000 WHERE rule_id='MGN-ALR-customer_care-ticket_count-v1' AND weight=0.700000;` then check the MV, Margin Genie, dashboard and app explorer | `MEASURE(contribution_margin)` 2,375,095,705.09 -> 2,360,713,702.39 | `UPDATE ... SET weight=0.700000 WHERE rule_id='MGN-ALR-customer_care-ticket_count-v1';` gives MV 2,375,095,705.09 again, rules checksum c4ae4e2bf5df1fca7109e22bc80314d5f5a98ae31e008106df2bd822abb94ff3 | 10 | @qa (COO-Q-20261113-41) |
| I2 | MV v1.2 ALTER (DA-MV-V12-DEPLOY) | NOT REQUIRED. DEC-028 freezes v1.1 for the demo. Nothing to run. | v1.1 stays at 2,375,095,705.09 | n/a (rollback source = src/metric_views/margin_ledger_mv.yaml at git commit 85afbd1 on main, per DEC-036d; no separate rollback file exists) | 0 | @data-analyst |
| I3 | Stale pipeline (DE-DELETE-STALE-PIPELINE, gate 8) | In the Pipelines UI, delete ccea7e91-e657-4168-82fe-588f4e6437d5 (NOT 20960984) | pipelines LIKE %margin% 2 -> 1 | none (IDLE, owns 0 UC datasets) | 1 | @data-engineer, then @repo-pruner removes notebook 1551722662311991 |
| I4 | TEST ticket (gate 6) | SQL D below on the app Lakebase | 1 TEST row -> 0 | optional, the UI filter already hides it | 1 | @ml-engineer |
| I5 | App SP grants + redeploy (gates 1-2) | SQL A below, then Deploy lakelink-margin-truth | SP privileges false -> true; new active_deployment id | REVOKE the same grants | 5 | @app-developer |
| I6 | Agent SP (gate 3) | Command B below | trace identity user -> SP | remove SP | 4 | @ml-engineer |
| I7 | Leave-behind jobs (P6-DAB-DEPLOY) | Web terminal, from bundle/: `databricks bundle deploy -t jobs_only` | 0 -> 4 lakelink-margin-* jobs | `databricks bundle destroy -t jobs_only` | 3 | @devops |
| I8 | Genie One capture (gate 5) - EXPIRED, default applied (DEC-029b) | none | - | n/a | 0 | @qa |

If I1 has not run by Nov 15 12:00 CT, scene 3 is DESCOPED to definition plus simulation (DEC-027(3)). Other cutoffs follow DEC-018.

## Scene readiness matrix (refreshed 2026-11-13 06:10 UTC, replaces COO-Q-20261113-21)

Update 2026-11-13 @pm run #9: gate 4 closed; P2-GLOSSARY-PAGES and P2-DISCOVER-DOMAINS unblocked. COO review #15 reports Margin Genie with 9 sources (5 MVs + 4 dims) and 13/13 benchmarks passing, so S4 no longer waits on the MVs being added as Genie sources.

| Scene | Status | Artifact / last verified | Open gate | Fallback trigger |
| --- | --- | --- | --- | --- |
| S1 Question (Genie, CFO) | GO (Margin Genie only; Genie One not claimed, DEC-029b) | Genie 01f1df115a08164aab3ae5f6faac807c, Finance starter exact to the cent (@qa 05:42 UTC) | none (gate 5 expired) | applied Nov 14 18:05 UTC |
| S2 Answer -> ledger -> lineage -> PDF | GO | margin_ledger_allocated repointed to margin_ledger_v2, MV = 2,375,095,705.09 | none (lineage audit P5-LINEAGE-AUDIT open @qa) | fast path stays canonical if v2 drifts |
| S3 Metric view + allocation rule simulation | GO-FALLBACK (read-only sim, DEC-027(3)); live UPDATE only if I1 runs by Nov 15 12:00 CT | read-only sim: care ticket weight 0.70->0.90 gives 2,360,713,702.39 (@data-analyst COO-Q-20261114-14, stmt 01f1dfda-1045-19e0-b62c-de220bc21390) | I1 (CEO, optional) | Nov 15 12:00 CT -> definition + read-only simulation (no recorded clip) |
| S4 One Genie Ops/Sales/Marketing | GO on accuracy, display FIX open (run #12) | 9 Genie sources, 13/13 benchmark SQLs correct; pct/USD/boolean display fails (DSN-GENIE-FORMAT-R2); Ops label DEC-026 (DA-OPS-SAVINGS-LABEL-FIX) | none (agent work) | Nov 15 12:00 CT -> answer from margin_ledger_mv + dims |
| S5 Grooming agent -> approval app | NO-GO live | agent GO (47 candidates). Pre-roll queue = 3 pending (45040, 98532, 10211), with TEST hidden (DEC-037a, DEC-038). Live approve target GROOM-1e655052ef (10211). App SP has zero table privileges | Gates 1, 2 | Nov 15 12:00 CT -> recorded scene 5 |
| S6 Trace / SP / audit | CONDITIONAL | hero trace tr-2b088edfed85d22b2db662a6c0a7c68e (DEC-037a; earlier trace tr-7e87cf4df0dfdbf4a2ae39e1f1ab0478 is superseded) (user identity; open from experiment 1235449331932066, per SCENE5_CLICK_SCRIPT.md:18). Say 'user identity', not 'service principal'; say 'guardrails are on', not 'we saw it block'. Sales row filter: GO if account group lakelink_margin_sales exists by Nov 15 12:00 CT (log in as a member, expect 103,176 of 517,032 rows); else GO-FALLBACK, say: "Sales reps are filtered by margin_sales_row_filter; West rep simulation shows 103,176 of 517,032 rows" | Gate 3 + PM-SALES-TEST-PRINCIPAL | Nov 15 12:00 CT -> user-identity trace + Sales SQL simulation |
| S7 $1B Wall cards | GO | dashboard 01f1df1950c51bd68e87ace31632c2bf p2 live on wall MV; P6-CHALLENGE-CARDS completed | none | - |

## All-defaults run sheet (plan of record if no CEO session; @pm run #27, 2026-11-14 02:10 UTC, answers COO-Q-20261114-13 / COO-Q-20261113-73)

Owner: @pm. This sheet becomes the plan of record gate by gate at each cutoff below, with no further escalation. Final become-plan time: Nov 15 18:00 UTC (12:00 CT). Readiness verifier on Nov 18: @qa (5-surface same-number matrix + 13/13 eval), with @coo grading.

| Scene | All-defaults status | Default applied (DEC) | Line said on stage |
| --- | --- | --- | --- |
| S1 | GO-FALLBACK | Gate 5 expires Nov 14 18:00 UTC -> Margin Genie only (DEC-029b) | "Margin Genie answers in seconds: contribution margin USD 2,375,095,705.09, from one metric view." (No Genie One claim.) |
| S2 | GO | Gate 8 expires Nov 14 18:00 UTC -> ccea7e91 stays IDLE and excluded, retired after the demo (DEC-029a) | "One pipeline, Bronze to Gold, and lineage back to the carrier invoice PDF." (Show pipeline 20960984 only.) |
| S3 | GO-FALLBACK | I1 not run by Nov 15 12:00 CT -> definition + read-only simulation (DEC-027(3)) | "Finance owns the definition once. Finance raises the care-cost weight from 0.70 to 0.90 — contribution margin moves to USD 2,360,713,702.39, as this simulation shows." (No 'change the rule live'.) Show `margin_ledger_mv` on its Overview/definition, never the Sample Data preview (0 dp, DEC-030); quote exact CM only from Margin Genie or the dashboard (DEC-040). |
| S4 | GO | none (agent work done, eval 13/13) | Ops: "off-net circuits that run next to our own fiber" -> 47 candidates, 1,152,342.12 a year paid, 412,539.96 a year savings (DEC-026). Sales 586. Marketing Commercial. |
| S5 | GO-FALLBACK | Gate 1 expires Nov 15 12:00 CT -> recorded scene 5 (DEC-025). The app stays on build 01f1df66, which shows CM at 0 dp (DEC-030/033 talk track) | "The agent drafted three savings tickets. Ops approves circuit 10211." Approval click = recorded clip. Optional live agent run on stage uses resources/scene5_stage_run_config.md (DRY_RUN=True, allowlist {35360}, max 1): audience sees the trace with 35360 'would_insert' and 0 new tickets; the queue stays at 3 (@pm run #28, reconciles COO-Q-20261114-8/-15). |
| S6 | GO-FALLBACK | Gate 3 expires Nov 15 12:00 CT -> user-identity trace tr-2b088edf (ML-GROOMING-FALLBACK-PATH) | "Every step is traced under a governed identity, and guardrails are on." Say 'user identity', not 'service principal'. Sales: "margin_sales_row_filter: West rep simulation shows 103,176 of 517,032 rows." |
| S7 | GO | none | "Find your biggest lever on the $1B Wall." |

Same-number stage rule (DEC-040, @pm run #30, 2026-11-14 ~05:10 UTC): the exact CM 2,375,095,705.09 is claimed on stage only on Margin Genie and on the dashboard at its default filters (Quarter=All is the dashboard default since 2026-11-14 05:19 UTC, DEC-041c; glancing at the Quarter filter before the CM tile is an optional check, not a stage step. The scene-1 card-1 talk track still sets Quarter=Q3 2026 on purpose). The app explorer CM column is not used for the same-number claim while build 01f1df66 (0 dp) is live, and there is no Genie One claim unless gate 5 clears by Nov 14 18:00 UTC. Lifted per surface only if @qa verifies the fix before the Nov 16 00:00 UTC freeze.

Nov 17 rehearsal check (human, @data-planner COO-Q-20261114-17):
- [ ] Discover > Lakelink Fiber Margin (domain 2abc9194) > Finance shows exactly 12 assets: 9 UC objects (margin_allocation_rules, margin_dq_gl_tieout, margin_gl_actuals, margin_ledger, margin_ledger_allocated, margin_ledger_v2, margin_products, _metrics.margin_ledger_mv, _metrics.margin_onebillion_wall_mv) + dashboard Lakelink Fiber Margin Truth (01f1df1950c51bd68e87ace31632c2bf) + Margin Genie (01f1df115a08164aab3ae5f6faac807c) + app lakelink-margin-truth. Pipeline ccea7e91 must NOT appear. If the count differs, note it here and tell @data-planner.

## Stage-mode matrix, scenes 1-7 (COO-Q-20261114-72, @pm run #42, 2026-11-14 ~18:05 UTC)

Mode is what happens if no human acts before each cutoff. Live = driven on stage from the workspace. Recorded = a clip the CEO records at the Nov 17 rehearsal (DEC-025; agents cannot screen-record). Still = a static image or SQL result. No fallback screenshot or recording exists in resources/ or the margin_documents volume as of this run.

| Scene | Surface + asset id | Mode (no human action) | Gate / DEC | Fallback artifact | Owner | Last verified (UTC) |
| --- | --- | --- | --- | --- | --- | --- |
| S1 | Margin Genie 01f1df115a08164aab3ae5f6faac807c | Live | G5 expired -> DEC-029b (no Genie One claim) | Eval 01f1e02d 13/13, Finance stmt 01f1e02d-ebc6-142b-9dc5-dd0d9f4d08da (no screenshot; PM-GENIE-BENCH-SCREENSHOTS open) | @data-analyst | Nov 14 17:44 (@qa status 594) |
| S2 | margin_ledger_allocated -> lineage -> PDF; pipeline 20960984 only | Live | G8 expired -> DEC-029a (ccea7e91 IDLE, excluded) | none needed (read-only UC pages) | @data-engineer | Nov 14 18:04 (@pm pipelines.get) |
| S3 | _metrics.margin_ledger_mv + read-only simulation | Live (definition + simulation) | I1 cutoff Nov 15 18:00 UTC -> DEC-027(3) | stmt 01f1dfda-1045-19e0-b62c-de220bc21390 (2,360,713,702.39) | @data-analyst | Nov 14 17:48 (COO MV = raw) |
| S4 | Margin Genie 01f1df115a08164aab3ae5f6faac807c | Live | none | eval 01f1e02d 13/13 | @data-analyst | Nov 14 17:44 |
| S5 | App lakelink-margin-truth, deployment 01f1df66 | Recorded (approval click) | G1 cutoff Nov 15 18:00 UTC -> DEC-025 | Clip does not exist yet: CEO records at Nov 17 rehearsal. If nobody records, scene 5 becomes a still of the 3-ticket queue taken at rehearsal | @app-developer | Nov 14 17:28 (app RUNNING, pending None) |
| S6 | MLflow trace tr-2b088edf (experiment 1235449331932066) + audit rows | Live (user identity) | G3 cutoff Nov 15 18:00 UTC -> ML-GROOMING-FALLBACK-PATH | gateway request_ids in agent_notes 1774 | @ml-engineer | Nov 14 17:23 (ML R42) |
| S7 | Dashboard 01f1df1950c51bd68e87ace31632c2bf page 2 ($1B Wall) | Live | none | none | @data-analyst | republished Nov 14 16:18:15 |

Talk-track lines that change under defaults: S1 l.83 (no Genie One), S3 l.85 (simulation, not live change), S5 l.87 (recorded approval), S6 l.88 ('user identity', Sales SQL simulation). S2 l.84 and S7 l.89 unchanged.

Delivery: no path has reached the CEO yet. margin_ceo_slack is not created (checked 02:05 UTC 11-14), and the Slack MCP connector has read/search tools only. This sheet and status_updates (ceo_escalation) are the only channels.
