# Lakelink Fiber Margin Truth: CEO Action Sheet (pinned)

Owner: @pm. Created 2026-11-13 06:10 UTC (COO-Q-20261113-25). This file is the CEO delivery channel because the Slack MCP connector has no send/DM tool in scheduled runs (agent_notes 310). @pm updates it in place every run. Each gate is one copy-paste action, about 15 minutes in total. When you finish a gate, mark the task completed on the Lakebase board, or reply in chat "gate N done".

| # | Gate (task) | Scene blocked | CEO action (exact) | Est. | Cutoff -> automatic fallback (DEC-018) |
| --- | --- | --- | --- | --- | --- |
| 1 | App SP GRANTs (P3-APP-SCAFFOLD) | S5 approval app | Run SQL A below on app Lakebase project telco-margin-analysis-app (endpoint ep-calm-king-d2mq878u), database databricks_postgres | 3 min | Nov 15 12:00 CT -> recorded scene 5 |
| 2 | App redeploy (after gate 1) | S5 | Reply "approve redeploy" in an @app-developer run, or in the Apps UI click Deploy on lakelink-margin-truth (source apps/margin-truth) | 2 min | Nov 16 12:00 CT -> dashboard explorer page |
| 3 | Agent SP (P4-GATEWAY-SP-TRACING) | S6 identity | Command B below (create SP lakelink-margin-grooming-agent + grants) | 4 min | Nov 15 12:00 CT -> user-identity trace (ML-GROOMING-FALLBACK-PATH) |
| 4 | ~~Discover domain quota (DP-ESC-DOMAIN-QUOTA)~~ DONE 2026-11-13: domain 2abc9194-aed9-4088-bfa6-4b4d33870ebd verified by GET (@pm run #9). No CEO action. | - | - | - | - |
| 5 | Genie One capture (PM-GENIE-ONE-CEO-CAPTURE) | S1/S4 Genie One claim | Steps C below (2 questions, 2 screenshots) | 3 min | Nov 14 18:00 UTC -> Margin Genie only on stage, no Genie One claim |
| 6 | Delete TEST ticket (TEST-GROOM-4d4c099b0e) | S5 queue cleanliness | SQL D below on app Lakebase (optional: the UI filter APP-HIDE-TEST-TICKETS already hides it) | 1 min | Nov 16 12:00 CT -> UI filter (already built) |
| 7 | @devops approval gate (DEVOPS-JOBS-ONLY-FALLBACK) | Leave-behind DAB | Reply "approve DEVOPS-JOBS-ONLY-FALLBACK" when a @devops run asks, or set the task in_progress on the board | 1 min | Nov 16 12:00 CT -> DAB shown as source in git only |
| 8 | Delete stale pipeline (DE-DELETE-STALE-PIPELINE) | ONE-pipeline rule, S2 lineage clarity | In the Pipelines UI, delete pipeline ccea7e91-e657-4168-82fe-588f4e6437d5 (IDLE, owns 0 UC datasets; live pipeline is 20960984). Agent deletes are blocked by the safety guardrail. | 1 min | Nov 14 18:00 UTC -> ccea7e91 stays IDLE, excluded from demo, retire after demo (PM-STALE-PIPELINE-FALLBACK) |

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

## Steps C: Genie One capture (gate 5)
1. Open Genie One (workspace chat, not the Margin Genie space).
2. Ask: "Which product families lost money after cost to serve last quarter?" Expected: IP-VPN -6,715,475.88 and Legacy Voice -249,532.74.
3. Ask: "What is total contribution margin by product family?" Expected total 2,375,095,705.09.
4. Screenshot both answers plus the SQL panel, showing MEASURE(contribution_margin) from cdm_tmforum._metrics.margin_ledger_mv. Save them to /Volumes/cdm_tmforum/revenue_assurance/margin_documents/rehearsal/genie_one/.

## SQL D: TEST ticket delete (gate 6, optional)
```sql
DELETE FROM public.approval_tickets WHERE ticket_id = 'TEST-GROOM-4d4c099b0e';
```

## CEO interactive session (COO-Q-20261113-47, @pm 2026-11-13 run #12)

The Genie Code Auto Mode guardrail blocks these in scheduled runs, so the CEO has to run them in ONE interactive Genie Code session or the matching UI. This section is in this sheet (not in a new file) because of the consolidation rule. About 25 minutes total. Slot: Nov 14 (before 18:00 UTC) is preferred. Nov 17 rehearsal is the last slot.

| # | Item (task) | Exact action | Expected before -> after | Rollback | Min | Board confirmer |
| --- | --- | --- | --- | --- | --- | --- |
| I1 | Scene 3 live rule change (COO-Q-20261113-23, -41) | `UPDATE cdm_tmforum.revenue_assurance.margin_allocation_rules SET weight=0.900000 WHERE rule_id='MGN-ALR-customer_care-ticket_count-v1' AND weight=0.700000;` then check the MV, Margin Genie, dashboard and app explorer | `MEASURE(contribution_margin)` 2,375,095,705.09 -> 2,360,713,702.39 | `UPDATE ... SET weight=0.700000 WHERE rule_id='MGN-ALR-customer_care-ticket_count-v1';` gives MV 2,375,095,705.09 again, rules checksum c4ae4e2bf5df1fca7109e22bc80314d5f5a98ae31e008106df2bd822abb94ff3 | 10 | @qa (COO-Q-20261113-41) |
| I2 | MV v1.2 ALTER (DA-MV-V12-DEPLOY) | NOT REQUIRED. DEC-028 freezes v1.1 for the demo. Nothing to run. | v1.1 stays at 2,375,095,705.09 | n/a (rollback file margin_ledger_mv_v1_1_rollback.yaml kept) | 0 | @data-analyst |
| I3 | Stale pipeline (DE-DELETE-STALE-PIPELINE, gate 8) | In the Pipelines UI, delete ccea7e91-e657-4168-82fe-588f4e6437d5 (NOT 20960984) | pipelines LIKE %margin% 2 -> 1 | none (IDLE, owns 0 UC datasets) | 1 | @data-engineer, then @repo-pruner removes notebook 1551722662311991 |
| I4 | TEST ticket (gate 6) | SQL D below on the app Lakebase | 1 TEST row -> 0 | optional, the UI filter already hides it | 1 | @ml-engineer |
| I5 | App SP grants + redeploy (gates 1-2) | SQL A below, then Deploy lakelink-margin-truth | SP privileges false -> true; new active_deployment id | REVOKE the same grants | 5 | @app-developer |
| I6 | Agent SP (gate 3) | Command B below | trace identity user -> SP | remove SP | 4 | @ml-engineer |
| I7 | Leave-behind jobs (P6-DAB-DEPLOY) | Web terminal, from bundle/: `databricks bundle deploy -t jobs_only` | 0 -> 4 lakelink-margin-* jobs | `databricks bundle destroy -t jobs_only` | 3 | @devops |
| I8 | Genie One capture (gate 5) | Steps C below | 2 screenshots | n/a | 3 | @qa |

If I1 has not run by Nov 15 12:00 CT, scene 3 is DESCOPED to definition plus simulation (DEC-027(3)). Other cutoffs follow DEC-018.

## Scene readiness matrix (refreshed 2026-11-13 06:10 UTC, replaces COO-Q-20261113-21)

Update 2026-11-13 @pm run #9: gate 4 closed; P2-GLOSSARY-PAGES and P2-DISCOVER-DOMAINS unblocked. COO review #15 reports Margin Genie with 9 sources (5 MVs + 4 dims) and 13/13 benchmarks passing, so S4 no longer waits on the MVs being added as Genie sources.

| Scene | Status | Artifact / last verified | Open gate | Fallback trigger |
| --- | --- | --- | --- | --- |
| S1 Question (Genie, CFO) | GO (Margin Genie); Genie One AT RISK | Genie 01f1df115a08164aab3ae5f6faac807c, Finance starter exact to the cent (@qa 05:42 UTC) | Gate 5 | Nov 14 18:00 UTC |
| S2 Answer -> ledger -> lineage -> PDF | GO | margin_ledger_allocated repointed to margin_ledger_v2, MV = 2,375,095,705.09 | none (lineage audit P5-LINEAGE-AUDIT open @qa) | fast path stays canonical if v2 drifts |
| S3 Metric view + live rule change | GO (simulated), live UPDATE at rehearsal | read-only sim: 0.70->0.90 gives 2,360,713,702.39 (@ml-engineer) | rehearsal UPDATE | Nov 17 -> pre-recorded clip |
| S4 One Genie Ops/Sales/Marketing | GO on accuracy, display FIX open (run #12) | 9 Genie sources, 13/13 benchmark SQLs correct; pct/USD/boolean display fails (DSN-GENIE-FORMAT-R2); Ops label DEC-026 (DA-OPS-SAVINGS-LABEL-FIX) | none (agent work) | Nov 15 12:00 CT -> answer from margin_ledger_mv + dims |
| S5 Grooming agent -> approval app | NO-GO live | agent GO (47 candidates, heroes 45040/98532); app SP has zero table privileges | Gates 1, 2, 6 | Nov 15 12:00 CT -> recorded scene 5 |
| S6 Trace / SP / audit | CONDITIONAL | trace tr-7e87cf4df0dfdbf4a2ae39e1f1ab0478 (user identity; open from experiment 1235449331932066, per SCENE5_CLICK_SCRIPT.md:18). Say 'user identity', not 'service principal'; say 'guardrails are on', not 'we saw it block' | Gate 3 | Nov 15 12:00 CT -> user-identity trace |
| S7 $1B Wall cards | AT RISK | dashboard 01f1df1950c51bd68e87ace31632c2bf p2 live on wall MV | none | P6-CHALLENGE-CARDS due Nov 16 12:00 CT |
