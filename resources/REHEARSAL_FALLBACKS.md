# Lakelink Fiber Margin Truth - Rehearsal fallbacks (scenes 1-7)

Single shared fallback file (agent_notes 1854). Each owner appends its own section. Do not create per-scene files. No screenshots: agents cannot capture them (DEC-025). Freeze from Nov 16 00:00 UTC (DEC-036).

Sections: S1/S4 (PM-FB-S1S4), S2/S3 (PM-FB-S2S3-LINEAGE-RULE, below), S6 (PM-FB-S6), S7 (PM-FB-S7). Verifier: QA-VERIFY-REHEARSAL-FALLBACKS.

---

## S2 - Where the answer comes from (owner @data-engineer, verified read-only 2026-11-14 ~19:30 UTC)

Hero circuit: **45040**, month **2026-10**. Every value below was read by SQL in this run.

| Hop | Table (catalog cdm_tmforum) | Key | Value for 45040 / 2026-10 |
| --- | --- | --- | --- |
| Contract | revenue_assurance.margin_contracts | contract_id a0L06CXppXYs4w9AAA | customer_id 19436, product_id 01t08Dv4RH4mwSgAAA, contract_rate_usd 1,204.20, term_end 2023-06-13, agreement CN-24864603 |
| Circuit | revenue_assurance.margin_circuits | circuit_id 45040 | is_on_net FALSE, vendor_id 00100000000265pAAA (Partner Carrier 55), is_parallel_to_onnet_fiber TRUE, onnet_distance_m 51.00, route "Off-net ELINE-1G via Partner Carrier 55; runs next to Lakelink Fiber fiber in West" |
| Order | tmf_customer.product_order_item (read-only source) | service_id 45040 | product_order_item_id 71767, order_id 45040, state in_progress |
| Bill | revenue_assurance.margin_billing | billing_line_id MGN-BIL-45040-202610 | billed_amount_usd 1,204.20 = expected_amount_usd 1,204.20 (source oracle_erp_source.ra_billed_circuit_rates: SOURCE_LINE_ITEM_ID a0L06CXppXYs4w9AAA, BILLED_TOTAL_AMOUNT 1204.2) |
| Carrier invoice | revenue_assurance.margin_carrier_invoices | carrier_invoice_line_id MGN-CIL-45040-202610 | invoice LLF-CI-65pAAA-202610, invoiced_rate_usd 2,880.05 vs vendor_contract_rate_usd 2,666.71 (rate variance +213.34), paid_amount_usd 2,880.05 |
| Source PDF | volume revenue_assurance.margin_documents | path | `/Volumes/cdm_tmforum/revenue_assurance/margin_documents/carrier_invoices/LLF-CI-65pAAA-202610_CKT-45040.pdf` (2,090 bytes; present in volume and in margin_bronze_invoice_docs) |
| Parsed PDF | revenue_assurance.margin_silver_invoice_parsed | path | ai_extract: circuit_id 45040, invoice_month 2026-10, invoice_number LLF-CI-65pAAA-202610, invoiced_rate_usd 2880.05, vendor_contract_rate_usd 2666.71, vendor_name Partner Carrier 55 |
| Ledger (pipeline) | revenue_assurance.margin_ledger_v2 | circuit_id + ledger_month | revenue 1,204.20, network_expense 2,880.05, cost_to_serve 359.90, source_pdf_path = the PDF above |
| Ledger (MV source) | revenue_assurance.margin_ledger_allocated | circuit_id + ledger_month | revenue 1,204.20 - network 2,880.05 - CTS 359.90 = CM -2,035.75 for 2026-10; 12 months total CM -24,089.72 |
| Cash | oracle_erp_source.ar_cash_receipts_all via hz_cust_accounts (TMF_CUSTOMER_ID 19436 -> CUST_ACCOUNT_ID 919436, account LLF-00019436) | BILL_TO_CUSTOMER_ID 919436 | **Customer level only:** the only receipt for this account is CASH_RECEIPT_ID 916266, 2019-05-03, 4,286.87, STATUS APP. No circuit- or 2026-month-level cash link (gap, escalated to @pm). |

**Lineage edges (system.access.table_lineage, last 7 days, entity_type PIPELINE, entity_id 20960984-a9d3-46f4-826a-6301155bc79a):**

* (volume, Auto Loader, source NULL) -> margin_bronze_invoice_docs: 7 edges
* margin_bronze_invoice_docs -> margin_silver_invoice_parsed: 6 edges
* margin_silver_invoice_parsed -> margin_ledger_v2: 2 edges
* margin_carrier_invoices, margin_billing, margin_circuits, margin_contracts, margin_customers, margin_products, margin_gl_actuals, margin_allocation_rules -> margin_ledger_v2: 4 edges each
* margin_ledger_v2 -> margin_ledger_allocated -> _metrics.margin_ledger_mv: view-read edges (entity_type NULL), not pipeline writes.
* Stale pipeline ccea7e91 is excluded from scene 2 (DEC-029a). Always cite pipeline ids, never names.

**Click path fallback (if the lineage graph or Catalog Explorer does not load):** read the table above aloud. Open the PDF path in the volume browser. Say: "The carrier billed 2,880.05 against a contract rate of 2,666.71. The same 2,880.05 is the network expense on this circuit in the ledger."

**Talk-track caveat:** the cash hop is customer level only. Do not claim that cash is traced to this circuit or to this month.

**Scene-2 lineage click path (DE-S2-LINEAGE-CLICKPATH, read-only via system.access.table_lineage 2026-11-15 ~06:15 UTC; Catalog Explorer UI not readable in a scheduled run):**

* Do NOT start the lineage click from `margin_ledger`. It is a MANAGED table written only by notebooks (no pipeline node), and the live view stopped reading it after 2026-11-13.
* Start at `_metrics.margin_ledger_mv` (or the Genie answer). Its YAML source is `revenue_assurance.margin_ledger_allocated` (VIEW). Open that view's Lineage tab and click the upstream hop **margin_ledger_allocated -> margin_ledger_v2**. `margin_ledger_v2` is a MATERIALIZED_VIEW, and its upstream graph shows the pipeline node **20960984** ("Lakelink Fiber Margin Truth Pipeline").
* From `margin_ledger_v2`, go upstream: margin_silver_invoice_parsed -> margin_bronze_invoice_docs (STREAMING_TABLE, pipeline 20960984). Bronze has no table-level edge from the volume, so open the bronze `path` column (20/20 rows are in `/Volumes/cdm_tmforum/revenue_assurance/margin_documents/`) and open the PDF in the volume browser.
* Stale pipeline ccea7e91 has 0 lineage edges to or from any margin_ table in the last 30 days. Only 20960984 appears.

---

## S3 - Why the number is trusted (owner @data-engineer; live UPDATE is human-only, NOT run by agents)

* **Metric view:** `cdm_tmforum._metrics.margin_ledger_mv` (v1.1 frozen, DEC-028), source `cdm_tmforum.revenue_assurance.margin_ledger_allocated` (DEC-020). Contribution margin is defined only in the MV (DEC-002).
* **Live baseline (verified 2026-11-14 ~19:30 UTC):** MEASURE(contribution_margin) = **2,375,095,705.09**. Raw SUM(revenue_usd - network_expense_usd - cost_to_serve_usd) over margin_ledger_allocated = 2,375,095,705.09 (517,032 rows). Cost to serve = 360,273,982.31. Rules checksum = `6ce4db5c669a8ca287b4df7dffa5a32f`. 8 active rules.
* **The rule row the CEO edits:** `rule_id = 'MGN-ALR-customer_care-ticket_count-v1'` (cost_pool customer_care, driver ticket_count, weight 0.700000, owner Finance). Its partner row `MGN-ALR-customer_care-circuit_count-v1` stays at 0.300000.
* **Change / revert statements:** see `resources/scene3_live_allocation_runbook.md` section (b2), lines 60 and 66 (0.700000 -> 0.900000 -> 0.700000).

| State | ticket_count weight | CM (MEASURE) | Cost to serve | Source |
| --- | --- | --- | --- | --- |
| Before (default) | 0.700000 | 2,375,095,705.09 | 360,273,982.31 | live query this run |
| After change | 0.900000 | 2,360,713,702.39 (delta -14,382,002.70) | 374,655,985.01 | SELECT-only simulator src/data/margin_scene3_simulator.sql, re-run 2026-11-15 ~00:15 UTC (stmt 01f1e089-65dc-1e91-9d03-912932800f51) |
| After revert | 0.700000 | 2,375,095,705.09, checksum 6ce4db5c... again | 360,273,982.31 | runbook b2 line 68 |

**Fallback if the live change cannot run:** describe the change and show the before/after table above. Say "Finance raises the care-cost weight" (not pool-conserving: the care weights sum to 1.20, runbook line 76). Quote the exact CM only from Margin Genie or the dashboard (DEC-030/DEC-040). Never open the MV Sample Data preview (runbook line 78).

---

## S6 - Prove it to audit (owner @ml-engineer, re-verified read-only 2026-11-14 20:22:30-20:23:21 UTC, statement ids below)

The span tables, gateway usage rows, audit rows and SP check below were read in this run with MLflow `get_trace`, `system.ai_gateway.usage`, `system.access.audit` and the SDK service principal list. Two items come from earlier evidence and were not re-read: the guardrail configuration (P4-GATEWAY-SP-TRACING notes, 2026-11-12) and the ticket-to-trace mapping (DEC-037/DEC-044). No writes, no Genie/MV/dashboard edits.

**Agent:** `lakelink_offnet_grooming_agent` (code `agents/margin_grooming_agent.py`). **MLflow experiment:** `/Users/stephen.hage@databricks.com/telco-margin-analysis/agents/margin_grooming_agent_traces` (id 1235449331932066). **Model:** Unity Gateway service `cdm_tmforum.revenue_assurance.margin_grooming_agent_llm` (id 13f5e588-2419-4871-991d-ff7b9fc765a2) -> `system.ai.databricks-claude-sonnet-4-5`, with guardrails block-sensitive-data, block-jailbreak and block-unsafe-content (judge `system.ai.claude-haiku-5-5`).

### Verification log (COO-Q-20261114-84; real run times, not section-header times)

| Check | Statement / call | Ran (UTC) | Result |
| --- | --- | --- | --- |
| `system.access.audit` (query below) | warehouse stmt `01f1e069-1e56-14d2-8886-6155d1245715` | 20:22:30-20:22:39 | SUCCEEDED, 8 rows, all stephen.hage@databricks.com |
| `system.ai_gateway.usage` (requester stephen.hage, endpoints margin_grooming_agent_llm + system.ai.claude-haiku-5-5; trace A window 00:24:00-00:25:05 OR the 3 trace B ids) | warehouse stmt `01f1e069-2f4b-184b-9dc0-027fe99ca26d` | 20:22:59-20:23:03 | SUCCEEDED, 24 rows = 6 requests x (1 model + 3 guardrail judge), all USER, all 200 |
| MLflow `mlflow.get_trace` trace A + trace B | MLflow client (no statement id) | 20:23:06 | A: OK, 9 spans, 51.65 s; B: OK, 12 spans, 59.90 s; both tags run_as=stephen.hage, identity_mode=user_fallback |
| SDK `w.service_principals.list(displayName eq "lakelink-margin-grooming-agent")` | Databricks SDK | 20:23:21 | 0 rows (SP not created) |

Warehouse: `bf0baa637e887c80` (telco_cdm_model). The earlier header time (~20:00 UTC) was written before the check ran. It is replaced by the times above.

### Trace A - approve-click trace (DEC-037: scene 6 opens this one)

`tr-2b088edfed85d22b2db662a6c0a7c68e`: state OK, 51.65 s, start 2026-11-14 00:24:06 UTC, dry_run=false (ticket GROOM-1e655052ef, circuit 10211), run_as stephen.hage@databricks.com, identity_mode user_fallback.

| # | Span | Start (s) | Duration (s) |
| --- | --- | --- | --- |
| 1 | lakelink_offnet_grooming_agent (root) | 0.00 | 51.65 |
| 2 | margin_metric_view_reference | 0.16 | 2.90 |
| 3 | gateway_chat | 3.07 | 11.04 |
| 4 | ask_margin_genie | 14.11 | 13.26 |
| 5 | score_onnet_move | 27.37 | 1.30 |
| 6 | gateway_chat | 28.67 | 11.36 |
| 7 | draft_savings_ticket | 40.03 | 1.30 |
| 8 | score_onnet_move | 40.14 | 0.71 |
| 9 | gateway_chat | 41.33 | 10.32 |

All 9 spans are OK.

Trace A gateway requests (stmt `01f1e069-2f4b-184b-9dc0-027fe99ca26d`): `75661131-6b98-4422-b42f-79d1ff7f70d0` (00:24:09), `aad915a3-3ac1-4ed0-9597-e3c5d3a5ec2c` (00:24:34), `a7599e37-d265-4c44-b414-215131265c2d` (00:24:47). Each one has 1 model row on margin_grooming_agent_llm and 3 guardrail judge rows, all requester stephen.hage@databricks.com, USER, 200.

### Trace B - same-number trace (agent leg of the CM claim, note 1674)

`tr-5ca85c90095b8b0ac5e14191016fc805`: state OK, 59.90 s, start 2026-11-14 13:23:18 UTC, dry_run=true (no queue writes), run_as stephen.hage@databricks.com, identity_mode user_fallback, genie_space_id 01f1df115a08164aab3ae5f6faac807c. The root output ends with portfolio CM **USD 2,375,095,705.09** (statement 01f1e02e-8e41-120c-95a3-5bdd9fd0e8b6).

| # | Span | Start (s) | Duration (s) |
| --- | --- | --- | --- |
| 1 | lakelink_offnet_grooming_agent (root) | 0.00 | 59.90 |
| 2 | margin_metric_view_reference | 0.21 | 3.32 |
| 3 | gateway_chat | 3.53 | 9.17 |
| 4 | ask_margin_genie | 12.70 | 16.15 |
| 5 | score_onnet_move | 28.84 | 1.12 |
| 6 | score_onnet_move | 29.96 | 0.95 |
| 7 | gateway_chat | 30.92 | 14.19 |
| 8 | draft_savings_ticket | 45.11 | 0.98 |
| 9 | score_onnet_move | 45.24 | 0.61 |
| 10 | draft_savings_ticket | 46.09 | 0.90 |
| 11 | score_onnet_move | 46.20 | 0.56 |
| 12 | gateway_chat | 46.99 | 12.91 |

All 12 spans are OK.

### Gateway request ids (trace B gateway_chat spans -> system.ai_gateway.usage)

The spans do not carry the request_id, so they are matched by time to the second (note 1775).

| Span start (UTC) | request_id | Model row (endpoint margin_grooming_agent_llm) | Guardrail judge rows (system.ai.claude-haiku-5-5) |
| --- | --- | --- | --- |
| 13:23:21.8 | 0abb7ce8-2974-4a8f-84b3-9c91b1571417 | 13:23:21, claude-sonnet-4-5, 200 | 3 rows, 200 |
| 13:23:49.2 | bcf946e8-4b7b-4f39-aa8a-cb3b5e10bf1b | 13:23:49, claude-sonnet-4-5, 200 | 3 rows, 200 |
| 13:24:05.2 | 08a8f1c3-3852-495d-9c3a-52c78a6bb26e | 13:24:05, claude-sonnet-4-5, 200 | 3 rows, 200 |

All 12 usage rows: requester stephen.hage@databricks.com, requester_type USER.

### Audit query (system.access.audit)

```sql
SELECT request_id, event_time, service_name, action_name, user_identity.email AS email,
       response.status_code AS status_code,
       CASE WHEN action_name = 'authzEval'
            THEN map_keys(from_json(request_params.actions, 'map<string,string>'))[0] END AS securable,
       LEFT(request_params.commandText, 160) AS command_text
FROM system.access.audit
WHERE event_date = DATE'2026-11-14'
  AND request_id IN ('0abb7ce8-2974-4a8f-84b3-9c91b1571417',
                     'bcf946e8-4b7b-4f39-aa8a-cb3b5e10bf1b',
                     '08a8f1c3-3852-495d-9c3a-52c78a6bb26e',
                     'accf8e8c-6aeb-4f1a-9055-11dfb40d20b0')
ORDER BY event_time;
```

Result (8 rows, all user stephen.hage@databricks.com):

| event_time (UTC) | request_id | service.action | Detail |
| --- | --- | --- | --- |
| 00:24:33.438 | accf8e8c-6aeb-4f1a-9055-11dfb40d20b0 | accounts.tokenLogin | 200 |
| 00:24:33.513 | accf8e8c-6aeb-4f1a-9055-11dfb40d20b0 | databrickssql.commandSubmit | `SELECT * FROM cdm_tmforum.revenue_assurance.margin_score_onnet_move(:cid)` (trace A span 5, +27.37 s = 00:24:33.43) |
| 13:23:21.770 | 0abb7ce8-... | accounts.tokenLogin | 200 |
| 13:23:22.055 | 0abb7ce8-... | unityCatalog.authzEval | system.ai.databricks-claude-sonnet-4-5, 200 |
| 13:23:49.158 | bcf946e8-... | accounts.tokenLogin | 200 |
| 13:23:49.304 | bcf946e8-... | unityCatalog.authzEval | system.ai.databricks-claude-sonnet-4-5, 200 |
| 13:24:05.236 | 08a8f1c3-... | accounts.tokenLogin | 200 |
| 13:24:05.375 | 08a8f1c3-... | unityCatalog.authzEval | system.ai.databricks-claude-sonnet-4-5, 200 |

Optional guardrail proof (agent_notes 1519/1743): request 9b07ddc1-7b6f-4fe9-8682-8ab6f016d4a5 (09:22:32 UTC) was blocked pre_call by block-sensitive-data. Not re-queried this run.

**Presenter points at this audit row (scene 6, 'every action has an identity'):** event_time `2026-11-14T00:24:33.513Z`, user_identity `stephen.hage@databricks.com`, action_name `databrickssql.commandSubmit`, request_id `accf8e8c-6aeb-4f1a-9055-11dfb40d20b0`, command `SELECT * FROM cdm_tmforum.revenue_assurance.margin_score_onnet_move(:cid)`. This is trace A span 5 (score_onnet_move at +27.37 s from 00:24:06.061 = 00:24:33.43).

### Identity wording (DEC-018 user-identity default)

The SDK list `w.service_principals.list(filter='displayName eq "lakelink-margin-grooming-agent"')` returned **0 rows** at 2026-11-14 20:23:21 UTC (also 0 rows at ~19:24 UTC), so the dedicated agent service principal does not exist yet. Unless the SP gate clears by its cutoff, say:

> "In this workspace the agent runs under the presenter's identity, with the tag identity_mode = user_fallback. The trace, the Unity Gateway usage rows and the audit log all record that same identity for every step. In production, each agent gets its own service principal with least-privilege grants, and the same three records then show that principal."

Do not claim on stage that a dedicated agent service principal made these calls. CEO_ACTION_SHEET.md lines that use this identity wording: l.88 (S6 GO-FALLBACK: say 'user identity', not 'service principal'), l.110 (S6 l.88 talk-track default), l.9 and l.57 (gate 3 / I6 Agent SP, Command B l.25-33).

**Click path fallback (if the MLflow UI does not load):** read trace A's span table, then the audit table. Say: "Every step has a record: Genie, the scoring function, the model call through the gateway, with guardrails checked each time."

---

## S7 - Hands-on: $1B Wall challenge cards (owner @designer, verified read-only 2026-11-14 ~19:34 UTC)

**Where it renders:** dashboard `01f1df1950c51bd68e87ace31632c2bf` "Lakelink Fiber Margin Truth", page `challenge_cards` ("Challenge cards", 9 widgets), published revision 2026-11-14T16:18:15.042Z. Copy and widget ids below were read from the Lakeview API (serialized_dashboard) in this run. Numbers are NOT re-queried (Auto Mode blocks designer MV reads, agent_notes 1808); they cite the @data-analyst answer-key evidence on P6-CHALLENGE-CARDS (warehouse stmt 01f1df7e-4367-19db-a07e-2dd14f4c6b1f, Margin Genie 6/6 PASS) and DEC-019/DEC-026.

**Page layout (6-col grid):** `p3_header` (x0 y0 w6 h1) -> cards 1-3 (y1, w2 h3 each) -> cards 4-6 (y4, w2 h3 each) -> `w3_answer_key` table (x0 y7 w6 h6) -> `w3_genie` Genie CTA (x0 y13 w6 h8). Embedded Genie is enabled on the dashboard (space `01f1df115a08164aab3ae5f6faac807c`, Lakelink Fiber Margin Genie).

**Header copy (`p3_header`):** "Challenge cards" / "Find your biggest lever. Pick a card, ask Margin Genie, check the answer."

| # | Widget | Card title | Persona | Margin Genie question (exact copy) | Check line on card | Expected answer (board evidence) |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `w3_card_1` | Legacy losses | Finance | "Which product families lost money after cost to serve last quarter?" | Answer key row 1, and Page 1 'Which product families lose money after cost to serve?' (Quarter = Q3 2026) | Q3 2026: IP-VPN -6,715,475.88; Legacy Voice -249,532.74 |
| 2 | `w3_card_2` | Off-net grooming | Ops | "Which off-net circuits run next to our own fiber, and what do we pay for them?" | Answer key row 2, and Page 2 lever 'Off-net grooming' (est. annual savings, not spend) | 47 grooming candidates; annual off-net cost (what we pay) 1,152,342.12; est. annual savings if moved on-net 412,539.96 (DEC-026) |
| 3 | `w3_card_3` | Renewals below the margin floor | Sales | "Which renewals in the next 90 days are below the margin floor?" | Answer key row 3, and Page 2 lever 'Renewal margin floor' | 586 of 1,377 renewals below floor (as-of DATE'2026-11-19', DEC-019); revenue at stake 18,890,869.75 |
| 4 | `w3_card_4` | Room to grow | Marketing | "Which segments have the highest margin and the most room to grow?" | Answer key row 4, and Page 1 Contribution Margin % with the Customer Segment filter | Commercial: CM 54.4% vs portfolio 54.1%, revenue share below customer share (DEC-013) |
| 5 | `w3_card_5` | Revenue Leakage | Finance | "How much Revenue Leakage is there to recover?" | Answer key row 5, and Page 2 lever 'Revenue leakage recovery' | Revenue Leakage 26,698,861.46 |
| 6 | `w3_card_6` | Carrier Rate Variance | Ops | "How much Carrier Rate Variance did carriers bill us above the contract rate?" | Answer key row 6, and Page 2 lever 'Carrier rate variance recovery' | Carrier Rate Variance 1,694,614.90 |

**Answer key widget `w3_answer_key`:** title "Challenge card answer key"; dataset `ds_card_answers` (MEASURE() only over margin_ledger_mv, margin_offnet_spend_mv, margin_renewal_floor_mv, margin_segment_growth_mv; CM never redefined, DEC-002). Columns: Card, Challenge, Persona, Ask Margin Genie, Expected answer (USD, 2 dp), Source metric view. The Page 2 lever names cited on cards 2, 3, 5, 6 match the `lever` values documented on `cdm_tmforum._metrics.margin_onebillion_wall_mv` (UC column comment: Off-net grooming, Revenue leakage recovery, Carrier rate variance recovery, Legacy repricing, Renewal margin floor).

**Lakelink Fiber brand and a11y check (DESIGN_TOKENS.md, this run):** dashboard theme canvas #F9F7F4, widgets #FFFFFF, border #D9D4CC, font #1B3139, viz palette #1B3139/#FF3621/#00A972/#5F7A8A/#D9603B. Card text #1B3139 on #FFFFFF = 13.59:1 and on #F9F7F4 = 12.71:1 (WCAG 2.1 AA text PASS). Cards carry no color-only meaning. Real-company-name scan of page 3 widgets + `ds_card_answers` SQL (7,245 chars, 17 names incl. the plan's reference company): **0 hits**; whole serialized dashboard: 0 hits. Brand: PASS.

**Fallback if the dashboard does not load:** read the table above aloud card by card. For each card, say the question, then the expected answer. Hand-out wording: "Find your biggest lever. Pick a card, ask Margin Genie, check the answer." If Genie is also down, read the expected answer column and say: "These are the same metric-view numbers Genie and the dashboard return." Do not quote the exact portfolio CM from this section; quote it only from Margin Genie or the dashboard (DEC-030/DEC-040).

---

## S1/S4 - Margin Genie starter questions (owner @data-analyst, verified read-only 2026-11-14 ~21:00 UTC)

Appended at the end on purpose so the S2/S3/S6/S7 line refs in CEO_ACTION_SHEET stay valid (agent_notes 1890). No Genie space, MV or dashboard edit (DEC-046a, DEC-036).

**Source of truth:** Margin Genie space `01f1df115a08164aab3ae5f6faac807c`, benchmark eval run `01f1e02dcc391aee8e2d31609bc08970` (status DONE, 13/13 correct, 0 needs review; read via GET /api/2.0/genie/spaces/<id>/eval-runs/<run>/results in this run). For every row below, the Genie actual SQL was re-run in this run against the metric views, and an independent raw SQL over `cdm_tmforum.revenue_assurance.margin_ledger_allocated` (plus margin_contracts / margin_products / margin_circuits where named) returned the same numbers to the cent.

**Portfolio anchor:** MEASURE(contribution_margin) on margin_ledger_mv = 2,375,095,705.09; raw SUM(revenue_usd - network_expense_usd - cost_to_serve_usd) over margin_ledger_allocated = 2,375,095,705.09 (517,032 rows). Quote it on stage only from Margin Genie or the dashboard (DEC-040).

| Scene | Persona | Exact question | Benchmark id | Eval result id | Actual stmt | Expected stmt | Assessment | Rows |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| S1 | Finance (CFO) | "Which product families lost money after cost to serve last quarter?" | 6237339ad4ec418ba4f77582d3b0cad2 | 01f1e02dcc3c1b92a087c225dcdda7fd | 01f1e02d-ebc6-142b-9dc5-dd0d9f4d08da | 01f1e02d-e7b0-1343-9742-928237110ce7 | GOOD | 2 |
| S4 | Ops | "Which off-net circuits run next to our own fiber, and what do we pay for them?" | f37805ebc22e44fb809345943d919ed6 | 01f1e02dcc3e17e1b30e14aeb191c880 | 01f1e02d-d0bd-1eae-a6c4-48ebb93ada19 | 01f1e02d-cd76-11a0-85c7-3f2598516367 | GOOD | 47 |
| S4 | Sales | "Which renewals in the next 90 days are below the margin floor?" | 948cff73be1a44f3ad03120aefdefc81 | 01f1e02dcc3d1810ab2f55de959f343e | 01f1e02d-d8bd-19c3-aebb-6bbfd1e524d0 | 01f1e02d-d4c0-194c-a8e5-51089f2a3ceb | GOOD | 586 |
| S4 | Marketing | "Which segments have the highest margin and the most room to grow?" | 2a4d6e65d6c24d65a28d856b3855e887 | 01f1e02dcc3b1d65a12b6446c2911418 | 01f1e02d-feca-1131-ac8c-eee6abb0ee0e | 01f1e02d-fa93-158a-aa07-655072edcb22 | GOOD | 4 |

### S1 Finance - expected answer (Q3 2026 = last quarter as of DATE'2026-11-19')

| Product family | Legacy or strategic | Revenue (USD) | Contribution margin (USD) | CM % |
| --- | --- | --- | --- | --- |
| IP-VPN | Legacy | 21,113,431.95 | -6,715,475.88 | -31.8 |
| Legacy Voice | Legacy | 695,307.30 | -249,532.74 | -35.9 |

Total loss across the 2 families: -6,965,008.62. Raw tie-out: margin_ledger_allocated with ledger_month in [2026-07-01, 2026-10-01), grouped by product_family, family_class, HAVING SUM(revenue_usd - network_expense_usd - cost_to_serve_usd) < 0 -> the same 2 rows to the cent (15,996 and 540 ledger rows).

### S4 Ops - expected answer (margin_offnet_spend_mv, is_grooming_candidate)

47 grooming candidates. Annual off-net cost (what we pay) = 1,152,342.12 (monthly 96,028.51). Estimated annual savings if moved on-net = 412,539.96 (monthly 34,378.33). Never label 412,539.96 as spend (DEC-026).

| Circuit | Vendor | Monthly off-net cost | Annual off-net cost | Est. monthly savings | Est. annual savings | Score |
| --- | --- | --- | --- | --- | --- | --- |
| 35360 | Partner Carrier 19 | 2,513.61 | 30,163.32 | 2,307.07 | 27,684.84 | 95 |
| 51882 | Partner Carrier 32 | 2,360.90 | 28,330.80 | 2,153.54 | 25,842.48 | 95 |
| 47257 | Partner Carrier 43 | 2,265.22 | 27,182.64 | 2,061.33 | 24,735.96 | 95 |

Raw tie-out: margin_circuits (NOT is_on_net AND is_parallel_to_onnet_fiber) joined to margin_score_onnet_move(NULL) with est_monthly_savings_usd > 0 -> 47 / 1,152,342.12 / 412,539.96. Caveat: savings and score come from the UC function (the same one the grooming agent calls), so the Ops tie-out is independent of the MV but not of the function. 172 off-net circuits run next to own fiber; 47 of them have positive savings.

### S4 Sales - expected answer (as-of DATE'2026-11-19', inclusive 90-day window, DEC-019)

586 renewals below the margin floor (of 1,490 renewals in the window; 1,377 have ledger rows). CM of the 586 = -1,059,587.28; revenue at stake = 18,890,869.75.

| Contract | Customer | Segment | Product family | Term end | CM % | Floor % | CM (USD) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| a0L00h7hIEMofJiAAA | Bailey Inc | Small Business | IP-VPN | 2026-11-19 | -156.5 | 20.0 | -8,249.76 |
| a0L0aVEGn6ZbQAwAAA | Gould-Petty | Commercial | IP-VPN | 2026-11-19 | -36.5 | 20.0 | -7,842.69 |
| MGN-CTR-000001 | Allen LLC | Strategic Enterprise | Legacy Voice | 2026-11-20 | -58.7 | 20.0 | -7,112.29 |

Raw tie-out: margin_contracts term_end BETWEEN DATE'2026-11-19' AND +90, joined to margin_products and to per-contract SUMs over margin_ledger_allocated, with CM/revenue < margin_floor_pct -> 1,490 / 1,377 / 586 / -1,059,587.28 / 18,890,869.75.

Window boundary (QA-F-RENEWAL-WINDOW-INCLUSIVE, @data-analyst 2026-11-15): the 90-day window is INCLUSIVE at both ends, term_end BETWEEN DATE'2026-11-19' AND DATE'2027-02-17' (DATE'2026-11-19' + 90 = 2027-02-17, so 91 calendar days). This is the margin_renewal_floor_mv is_renewal_next_90d logic and the Margin Genie Sales benchmark. A half-open recompute (term_end < DATE'2027-02-17') gives 584 / CM -1,051,544.08, because 2 below-floor lines end on day 90. Re-verified 2026-11-15 by raw SQL over margin_ledger_allocated: inclusive 586, half-open 584, MV 586. Talk track: "renewals ending in the next 90 days, counting day 90". The MV column comment and the Genie Sales instruction get this wording after Nov 19 (MV freeze DEC-028/DEC-035, Genie freeze DEC-036).

### S4 Marketing - expected answer (DEC-013)

| Segment | Room to grow | CM (USD) | CM % | Portfolio CM % | Revenue share % | Customer share % | Customers |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Commercial | Yes | 821,108,369.20 | 54.4 | 54.1 | 34.4 | 34.5 | 3,424 |
| Enterprise | No | 284,091,394.68 | 54.1 | 54.1 | 12.0 | 12.4 | 1,234 |
| Small Business | No | 1,210,427,531.44 | 54.1 | 54.1 | 51.0 | 50.4 | 5,006 |
| Strategic Enterprise | No | 59,468,409.77 | 52.0 | 54.1 | 2.6 | 2.7 | 272 |

Raw tie-out: margin_ledger_allocated grouped by segment (SUM CM, COUNT DISTINCT customer_id) against portfolio totals -> the same 4 rows and flags. The 4 segment CMs sum to the portfolio anchor.

**Fallback if Genie does not answer:** read the question, then the expected answer table above. Say: "These are the benchmark answers Margin Genie returned in the rehearsal eval, 13 of 13 correct, and they tie to the ledger to the cent." If the dashboard is up, show page 1 with Quarter = Q3 2026 for S1.

---

## S5 - From insight to action (owner @app-developer, verified read-only 2026-11-14 ~20:28 UTC)

Appended at the end so earlier line refs stay valid. No deploy, no approve/reject, no ticket DML, no new asset, no ledger row (PM-FB-S5-QUEUE-STILL).

**Live app:** `lakelink-margin-truth`, w.apps.get at 2026-11-14 20:28 UTC = RUNNING / compute ACTIVE, active deployment `01f1df6665471f5ebf858b80eb08a2bd` (created 2026-11-13T13:30:30Z), pending deployment none. URL `https://lakelink-margin-truth-7474656585748611.aws.databricksapps.com`.

**Queue source:** app Lakebase project `telco-margin-analysis-app`, endpoint `projects/telco-margin-analysis-app/branches/production/endpoints/primary` (host resolved via get_endpoint = `ep-calm-king-d2mq878u...`, ACTIVE), table `public.approval_tickets`. Read in this run: 4 rows, all `pending`; `public.approval_audit` has 4 rows (max audit_id 6), untouched.

**On-screen Ops queue = exactly 3 pending tickets** (TEST-GROOM-4d4c099b0e is pending but hidden by `SHOW_TEST_TICKETS=false`, server/index.ts l.22-24 + app.yaml l.23, DEC-038):

| Ticket | Circuit | Vendor | Monthly off-net cost | Est. monthly savings | Score | Trace |
| --- | --- | --- | --- | --- | --- | --- |
| GROOM-1e655052ef (**live approve target**, DEC-037) | 10211 | Partner Carrier 28 (00100000000264YAAA) | $1,364.58 | $1,357.85 | 99 | tr-2b088edfed85d22b2db662a6c0a7c68e |
| GROOM-44c3612b69 | 45040 | Partner Carrier 55 (00100000000265pAAA) | $2,880.05 | $879.34 | 65 | tr-d9fef3bfbebebdad7bedf0bb88cd0f83 |
| GROOM-6d8f8ce31e | 98532 | Partner Carrier 47 (00100000000265hAAA) | $2,469.86 | $469.00 | 59 | tr-d9fef3bfbebebdad7bedf0bb88cd0f83 |

Tie-out: the same three circuits in `cdm_tmforum.revenue_assurance.margin_score_onnet_move(NULL)` return monthly off-net cost and est. monthly savings equal to the cent (1,364.58/1,357.85; 2,880.05/879.34; 2,469.86/469.00). Vendor names from `margin_vendors`. Approver roles: Ops, AP, FP&A (server/index.ts l.26); approve only flips a `pending` row for the matching role, else HTTP 409 (l.204-209).

**Live click path (if the app loads):** Approval queue -> role Ops -> open GROOM-1e655052ef (10211) -> Approve with comment -> the evidence panel shows trace tr-2b088edf..., agent `lakelink-margin-grooming-agent`, identity_mode user_fallback (no agent SP, see S6 identity wording), and the new approval_audit row. Say: "Two tickets remain" (45040, 98532 stay pending). Then go to S6 with trace A.

**Fallback if the app does not load or misbehaves:**

1. DEC-025: the CEO records the live rehearsal deploy if gate 1 cleared; otherwise use the agent-built stills pack in `apps/margin-truth/stills/` (SCENE5_STILLS.md, frames/frame1_queue.html, frame2_ticket_detail.html, frame3_after_approval_evidence.html, approval_tickets.json, approval_audit.json). The stills pack is the source; agents cannot screen-record.
2. Read the 3-row table above aloud. Say: "The agent found these circuits, Margin Genie confirmed them, and Ops approves before anything changes. Nothing moves without a human decision."
3. Rollback pointer: see `apps/margin-truth/REDEPLOY.md` l.16-20 (owner, cutoff Nov 16 12:00 CT, default = explorer OUT of scenes 1-7, dashboard explorer page used) and l.34 (Verify after deploy). A rollback section in REDEPLOY.md is still pending (DSN-F-S5-ROLLBACK-VERIFY-R1). The call is POST `/api/2.0/apps/lakelink-margin-truth/rollback` to deployment `01f1df6665471f5ebf858b80eb08a2bd`; it returns a NEW deployment id with `rollback_of_deployment_id`, so verify on that field, not on the id (agent_notes 1778, 1837).

**Do not** quote the exact portfolio CM from the app explorer (build 01f1df66 shows 0 dp; DEC-040). Quote it from Margin Genie or the dashboard. MV check this run: MEASURE(contribution_margin) = 2,375,095,705.09 = raw margin_ledger_allocated 2,375,095,705.09 (517,032 rows).

## S6b - Sales sees only its own accounts (row filter; owner @data-engineer, verified read-only 2026-11-14 ~22:20 UTC, COO-Q-20261114-94)

Warehouse bf0baa637e887c80. Statement ids are real execution ids, not header times.

* Attached: `margin_sales_row_filter ON (customer_id)` on margin_ledger_v2 (the MV base via margin_ledger_allocated), margin_ledger, margin_customers, margin_contracts. DESCRIBE stmt 01f1e078-9f81-1af0-ba34-a2883e214e65; information_schema.row_filters stmt 01f1e078-a0fe-151d-86cb-f927e32eb8ac.
* Presenter / Finance path (not in group lakelink_margin_sales): MEASURE(contribution_margin) = 2,375,095,705.09, margin_ledger_v2 = 517,032 rows. Stmt 01f1e078-a1c3-19ae-9336-21c5b0137f5d. The filter does not change the headline.
* Sales path (filter function evaluated as West rep sales.west@lakelinkfiber.example, is_sales = true): MV CM = 476,638,079.13, 1,992 ledger customers (stmt 01f1e078-a4e1-1b88-958f-a79a77298156); 103,176 rows, 0 out-of-region rows, raw CM 476,638,079.13 (stmt 01f1e078-a673-1c4a-bbc1-32004e290e45). An unassigned Sales principal sees 0 customers (stmt 01f1e078-a8ed-1994-a2ac-b7102e90d992).
* Tie-out: the 5 regions sum to 2,375,095,705.09 and 517,032 rows (stmt 01f1e078-a7c8-1472-873b-928118610bd5).

**Fallback (no live Sales identity on stage):** Show the DESCRIBE row filter line, then read: "A West Sales rep sees 103,176 ledger rows and 476.6M of contribution margin, which is only their accounts. Finance sees the full 2.375B. It is the same metric view with one governed filter." Do not log in as a synthetic rep, because the lakelinkfiber.example principals are not workspace users.

## S5-CUE - Live grooming run: pre-start cue and 65s cutoff (owner @app-developer, from COO-Q-20261115-22 / -24, written 2026-11-15 ~06:40 UTC, updated 2026-11-15 ~08:30 UTC for DEC-057 + DSN-REVIEW-S5-CUE-R56)

Appended at the end so earlier line refs stay valid. This section is the presenter copy of the cue. `apps/margin-truth/SCENE5_CLICK_SCRIPT.md` is NOT edited (notes 1805/2182, DEC-055(2)); its md5 stays 2d21dedc3522. The click script describes the pre-run path (3 pending tickets). This section adds the optional live run in front of it.

1. **Pre-start (when the scene-4 Marketing question is asked, about 60s before scene 5 opens):** the operator (the CEO/presenter, DEC-025; one person owns the single start) starts ONE live grooming run: `agents/margin_grooming_agent.py`, DRY_RUN=False, circuit allowlist {35360}, cap 1. Start it exactly once. Never click run again: there is no concurrent-run duplicate guard on approval_tickets (agent_notes 2257, COO-Q-20261115-24(3)).
2. **Cutoff 65s after start:** open Approval queue -> role Ops -> Pending. If a new pending ticket for circuit 35360 is at the top (newest first), say "The agent drafted this one while we were talking," and show it. Expect 4 tickets; skip the click-script step-2 line "3 tickets". Continue at click-script step 3 on GROOM-1e655052ef (10211). The approve click target stays GROOM-1e655052ef (10211), because scene 6 Trace A is tr-2b088edf (DEC-037, DEC-044, confirmed DEC-057(4)). The 35360 ticket is shown pending, never approved. Replace click-script step 8 with: "Three more candidates, 35360, 45040 and 98532, are waiting for Ops." If its ask_margin_genie span shows genie_basis=sql_standin, call it a SQL stand-in draft; do not say Margin Genie confirmed it.
3. **No 35360 ticket at 65s:** say "Here is one the agent drafted earlier," and go straight to the pre-run ticket GROOM-1e655052ef (10211). Then follow SCENE5_CLICK_SCRIPT.md steps 2-5 as written (3 pending tickets on screen). Keep the step-8 line "Two more..." only on this path.
4. **No late ticket (DEC-057 60s deadline):** the agent checks a 60s deadline from run start immediately before the approval_tickets INSERT. If the deadline has passed it returns would_insert and writes nothing, so no 35360 ticket can land after the cutoff and there is nothing late to show in scene 6. Do not wait and do not re-click; go to 10211.
5. **Why 65s:** 9 traces in 48h (agent_notes 2214): wall p50 55.6s / p95 70.8s; ticket insert p50 43.7s / p95 58.4s / max 60.6s; 0/9 sql_fallback. Per DEC-057 option B (agent commit e2355de09dbf on main, verified by @qa in QA-VERIFY-GENIE-DEADLINE) the Genie timeout is 25s (was 120s). A failed, timed-out or empty Genie leg falls back to `sql_standin` instead of aborting, still inside the 60s INSERT deadline. A `sql_standin` ticket or trace is always described as a SQL stand-in, never as a Genie answer. The cutoff stays 65s (60s INSERT deadline plus render margin).
6. **After a rehearsal take with the live run:** the 35360 ticket stays pending. Reject or approve it in the app before the next take, or ask @ml-engineer to re-draft, so the on-screen queue matches the click script again.

Queue state checked read-only before writing this section (app Lakebase ep-calm-king-d2mq878u, 2026-11-15 ~06:35 UTC, re-checked ~08:28 UTC with the same result): pending GROOM-1e655052ef 10211 1,364.58/1,357.85; GROOM-6d8f8ce31e 98532 2,469.86/469.00; GROOM-44c3612b69 45040 2,880.05/879.34; plus TEST-GROOM-4d4c099b0e (hidden, DEC-038). No 35360 ticket. approval_audit 4 rows, max audit_id 6.

---

## S5-WARMUP - Cold-start warm-up and cost/vendor guard (owner @ml-engineer, COO-Q-20261115-52, written 2026-11-15 ~12:35 UTC)

Appended at the end so earlier line refs stay valid.

1. **Why:** the first grooming run in a fresh serverless session took 86.9 s (tr-6cb4eb307cdb39a941a7aeadab729313; draft at 73.5 s -> deadline_exceeded, nothing written). Warm runs on the same prompt: 51.9-57.3 s (tr-be50ef48, tr-dfb0ed97, tr-abdbe756). The 60 s INSERT deadline (DEC-057) is above the warm insert p95 of 58.4 s (S5-CUE line 318) but below this cold run.
2. **Warm-up step (operator, once, before scene 1):** in the SAME session used for the live run, import `agents/margin_grooming_agent.py`, set `DRY_RUN=True`, and run the stage prompt once on circuit 35360. It writes nothing. Start it at least 5 minutes before scene 5 so it finishes about 60-90 s later (cold). Then set `DRY_RUN=False` for the single live start in S5-CUE line 314. Do not restart the session between the warm-up and the live run. This timing comes from the cold vs warm traces above; it was not re-measured in a rehearsal.
3. **If no warm-up was run:** the live run may hit the deadline and write nothing. Follow S5-CUE line 316 (go to pre-run ticket GROOM-1e655052ef, circuit 10211).
4. **Cost/vendor guard (ML-GUARD-COST-VENDOR-RECHECK):** `draft_savings_ticket` now refuses a ticket unless monthly_cost and est_monthly_savings match `margin_score_onnet_move` within 0.01 USD AND vendor_id matches exactly (`guard_mismatch()`). DRY_RUN evidence on 35360 (fn: vendor 00100000000264PAAA, 2513.61 / 2307.07, score 95): correct values -> would_insert tr-0737c00aebadddbcaa6feb3d958ae1c6; monthly_cost +100 -> refused 'monthly_cost mismatch' tr-de84f5d6f32bf88363a27505d225afb5; wrong vendor -> refused 'vendor_id mismatch' tr-f8381c2b386df41f0cdbcad54d779fb3. Commit: DEVOPS-COMMIT-ML-GUARD; md5 check: QA-VERIFY-ML-GUARD-MD5 (deadline 22:00 UTC Nov 15, DEC-060).
