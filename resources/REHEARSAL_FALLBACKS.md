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

---

## S3 - Why the number is trusted (owner @data-engineer; live UPDATE is human-only, NOT run by agents)

* **Metric view:** `cdm_tmforum._metrics.margin_ledger_mv` (v1.1 frozen, DEC-028), source `cdm_tmforum.revenue_assurance.margin_ledger_allocated` (DEC-020). Contribution margin is defined only in the MV (DEC-002).
* **Live baseline (verified 2026-11-14 ~19:30 UTC):** MEASURE(contribution_margin) = **2,375,095,705.09**. Raw SUM(revenue_usd - network_expense_usd - cost_to_serve_usd) over margin_ledger_allocated = 2,375,095,705.09 (517,032 rows). Cost to serve = 360,273,982.31. Rules checksum = `6ce4db5c669a8ca287b4df7dffa5a32f`. 8 active rules.
* **The rule row the CEO edits:** `rule_id = 'MGN-ALR-customer_care-ticket_count-v1'` (cost_pool customer_care, driver ticket_count, weight 0.700000, owner Finance). Its partner row `MGN-ALR-customer_care-circuit_count-v1` stays at 0.300000.
* **Change / revert statements:** see `resources/scene3_live_allocation_runbook.md` section (b2), lines 60 and 66 (0.700000 -> 0.900000 -> 0.700000).

| State | ticket_count weight | CM (MEASURE) | Cost to serve | Source |
| --- | --- | --- | --- | --- |
| Before (default) | 0.700000 | 2,375,095,705.09 | 360,273,982.31 | live query this run |
| After change | 0.900000 | 2,360,713,702.39 (delta -14,382,002.70) | 374,655,985.01 | runbook b2 line 62 (SELECT-only simulation, existing evidence, not re-run) |
| After revert | 0.700000 | 2,375,095,705.09, checksum 6ce4db5c... again | 360,273,982.31 | runbook b2 line 68 |

**Fallback if the live change cannot run:** describe the change and show the before/after table above. Say "Finance raises the care-cost weight" (not pool-conserving: the care weights sum to 1.20, runbook line 76). Quote the exact CM only from Margin Genie or the dashboard (DEC-030/DEC-040). Never open the MV Sample Data preview (runbook line 78).

---

## S6 - Prove it to audit (owner @ml-engineer, verified read-only 2026-11-14 ~20:00 UTC)

The span tables, gateway usage rows, audit rows and SP check below were read in this run with MLflow `get_trace`, `system.ai_gateway.usage`, `system.access.audit` and the SDK service principal list. Two items come from earlier evidence and were not re-read: the guardrail configuration (P4-GATEWAY-SP-TRACING notes, 2026-11-12) and the ticket-to-trace mapping (DEC-037/DEC-044). No writes, no Genie/MV/dashboard edits.

**Agent:** `lakelink_offnet_grooming_agent` (code `agents/margin_grooming_agent.py`). **MLflow experiment:** `/Users/stephen.hage@databricks.com/telco-margin-analysis/agents/margin_grooming_agent_traces` (id 1235449331932066). **Model:** Unity Gateway service `cdm_tmforum.revenue_assurance.margin_grooming_agent_llm` (id 13f5e588-2419-4871-991d-ff7b9fc765a2) -> `system.ai.databricks-claude-sonnet-4-5`, with guardrails block-sensitive-data, block-jailbreak and block-unsafe-content (judge `system.ai.claude-haiku-5-5`).

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

### Identity wording (DEC-018 user-identity default)

The SDK list `w.service_principals.list(filter='displayName eq "lakelink-margin-grooming-agent"')` returned **0 rows** on 2026-11-14 ~20:00 UTC, so the dedicated agent service principal does not exist yet. Unless the SP gate clears by its cutoff, say:

> "In this workspace the agent runs under the presenter's identity, with the tag identity_mode = user_fallback. The trace, the Unity Gateway usage rows and the audit log all record that same identity for every step. In production, each agent gets its own service principal with least-privilege grants, and the same three records then show that principal."

Do not claim on stage that a dedicated agent service principal made these calls.

**Click path fallback (if the MLflow UI does not load):** read trace A's span table, then the audit table. Say: "Every step has a record: Genie, the scoring function, the model call through the gateway, with guardrails checked each time."

---

## S7 - Hands-on: $1B Wall challenge cards (owner @designer, verified read-only 2026-11-14 ~20:30 UTC)

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
