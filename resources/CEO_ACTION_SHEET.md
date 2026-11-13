# Lakelink Fiber Margin Truth: CEO Action Sheet (pinned)

Owner: @pm. Created 2026-11-13 06:10 UTC (COO-Q-20261113-25). This file is the CEO delivery channel because the Slack MCP connector has no send/DM tool in scheduled runs (agent_notes 310). @pm updates it in place every run. Each gate is one copy-paste action, about 15 minutes in total. When you finish a gate, mark the task completed on the Lakebase board, or reply in chat "gate N done".

| # | Gate (task) | Scene blocked | CEO action (exact) | Est. | Cutoff -> automatic fallback (DEC-018) |
| --- | --- | --- | --- | --- | --- |
| 1 | App SP GRANTs (P3-APP-SCAFFOLD) | S5 approval app | Run SQL A below on app Lakebase project telco-margin-analysis-app (endpoint ep-calm-king-d2mq878u), database databricks_postgres | 3 min | Nov 15 12:00 CT -> recorded scene 5 |
| 2 | App redeploy (after gate 1) | S5 | Reply "approve redeploy" in an @app-developer run, or in the Apps UI click Deploy on lakelink-margin-truth (source apps/margin-truth) | 2 min | Nov 16 12:00 CT -> dashboard explorer page |
| 3 | Agent SP (P4-GATEWAY-SP-TRACING) | S6 identity | Command B below (create SP lakelink-margin-grooming-agent + grants) | 4 min | Nov 15 12:00 CT -> user-identity trace (ML-GROOMING-FALLBACK-PATH) |
| 4 | Discover domain quota (DP-ESC-DOMAIN-QUOTA) | S1/S4 Genie One discoverability, Glossary Pages | Account admin: delete stale demo domains in Account console > Discover/Domains (quota 1000 reached, HTTP 429), or file a quota increase | 3 min | Nov 15 12:00 CT -> DP-GENIE-ONE-FALLBACK (table/MV comments + certified MV, no Domain/Pages) |
| 5 | Genie One capture (PM-GENIE-ONE-CEO-CAPTURE) | S1/S4 Genie One claim | Steps C below (2 questions, 2 screenshots) | 3 min | Nov 14 18:00 UTC -> Margin Genie only on stage, no Genie One claim |
| 6 | Delete TEST ticket (TEST-GROOM-4d4c099b0e) | S5 queue cleanliness | SQL D below on app Lakebase (optional: the UI filter APP-HIDE-TEST-TICKETS already hides it) | 1 min | Nov 16 12:00 CT -> UI filter (already built) |
| 7 | @devops approval gate (DEVOPS-JOBS-ONLY-FALLBACK) | Leave-behind DAB | Reply "approve DEVOPS-JOBS-ONLY-FALLBACK" when a @devops run asks, or set the task in_progress on the board | 1 min | Nov 16 12:00 CT -> DAB shown as source in git only |

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

## Scene readiness matrix (refreshed 2026-11-13 06:10 UTC, replaces COO-Q-20261113-21)

| Scene | Status | Artifact / last verified | Open gate | Fallback trigger |
| --- | --- | --- | --- | --- |
| S1 Question (Genie, CFO) | GO (Margin Genie); Genie One AT RISK | Genie 01f1df115a08164aab3ae5f6faac807c, Finance starter exact to the cent (@qa 05:42 UTC) | Gate 5 | Nov 14 18:00 UTC |
| S2 Answer -> ledger -> lineage -> PDF | GO | margin_ledger_allocated repointed to margin_ledger_v2, MV = 2,375,095,705.09 | none (lineage audit P5-LINEAGE-AUDIT open @qa) | fast path stays canonical if v2 drifts |
| S3 Metric view + live rule change | GO (simulated), live UPDATE at rehearsal | read-only sim: 0.70->0.90 gives 2,360,713,702.39 (@ml-engineer) | rehearsal UPDATE | Nov 17 -> pre-recorded clip |
| S4 One Genie Ops/Sales/Marketing | AT RISK | 4 suite MVs live (offnet 47, renewal 586, segment DEC-013) but NOT yet in Genie data_sources | none (agent work: COO-Q-20261113-22, P3-GENIE-BENCHMARKS) | Nov 15 12:00 CT -> answer from margin_ledger_mv + dims |
| S5 Grooming agent -> approval app | NO-GO live | agent GO (47 candidates, heroes 45040/98532); app SP has zero table privileges | Gates 1, 2, 6 | Nov 15 12:00 CT -> recorded scene 5 |
| S6 Trace / SP / audit | CONDITIONAL | trace tr-f09d04073ced6c20fad2e0100ad00eb2 (user identity) | Gate 3 | Nov 15 12:00 CT -> user-identity trace |
| S7 $1B Wall cards | AT RISK | dashboard 01f1df1950c51bd68e87ace31632c2bf p2 live on wall MV | none | P6-CHALLENGE-CARDS due Nov 16 12:00 CT |
