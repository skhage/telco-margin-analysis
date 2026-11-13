# Genie One Instructions Proposal: Lakelink Fiber Margin Truth

Owner: @data-planner · Task: DP-GENIE-ONE-FALLBACK · Status: DRAFT v1.0 (2026-11-13) · Company: Lakelink Fiber (fictional) · telco_project = margin_analysis

This is a PROPOSAL only. The CEO must approve it before anything is copied into `/Workspace/.genie_workspace_instructions.md`. No agent edits that file.

Why this exists: Discover Domains and UC Glossary Pages are blocked by the account domain quota (HTTP 429, 1000 domains, gate DP-ESC-DOMAIN-QUOTA, cutoff Nov 15 12:00 CT per DEC-018). Until that clears, Genie One finds the margin assets through (a) table, column and metric view comments, (b) Margin Genie instructions, and (c) this proposed workspace instruction block.

## 1. Proposed block for /Workspace/.genie_workspace_instructions.md (CEO approval required)

```
## Lakelink Fiber margin and profitability (Margin Truth)
- For questions about margin, contribution margin, profitability, cost to serve, losing products or circuits, off-net or on-net circuits, renewals below the margin floor, revenue leakage, carrier rate variance, grooming, or the $1B Wall, use the Margin Genie agent (Lakelink Fiber Margin Genie) or the metric view cdm_tmforum._metrics.margin_ledger_mv.
- Contribution margin = revenue - network expense - cost to serve. It is defined ONCE as the measure contribution_margin in cdm_tmforum._metrics.margin_ledger_mv. Always query it with MEASURE(contribution_margin). Never recompute it from columns, and never add your own cost to serve.
- Legacy vs strategic follows margin_products.family_class (legacy = IP-VPN and Legacy Voice; all others strategic).
- Off-net means the circuit rides a third-party carrier (is_on_net = FALSE, vendor_id NOT NULL). On-net means it rides Lakelink Fiber's own fiber.
- Margin data lives only in cdm_tmforum.revenue_assurance (tables with prefix margin_) and cdm_tmforum._metrics (metric views with prefix margin_). Do not answer margin questions from oracle_erp_source, salesforce_source, ironclad_clm_source, mdm_source or tmf_* raw tables.
- Amounts are US dollars per month unless stated. Percentages are stored as fractions (0.2000 = 20%).
```

## 2. Assets to certify once validated

Certify only after the stated check passes. Status checked 2026-11-13 by SQL on information_schema.

| Asset | Exists (2026-11-13) | Certify when |
|---|---|---|
| `cdm_tmforum._metrics.margin_ledger_mv` | NO (P2-MV-MARGIN-LEDGER open) | P2-MV-VALIDATION: MEASURE(contribution_margin) = raw SQL (baseline total 2,375,095,704.83 at MGN-ALR-v1) |
| `cdm_tmforum._metrics.margin_segment_growth_mv` | NO | DEC-013 definition matches raw SQL |
| `cdm_tmforum.revenue_assurance.margin_ledger` | YES (gold, 517,032 rows) | GL tie-out within 0.5% (already shown by @qa/@data-analyst) |
| `margin_customers`, `margin_products`, `margin_contracts`, `margin_circuits`, `margin_vendors` | YES | PK/FK present (P1-PK-FK-ONTOLOGY) |
| `margin_billing`, `margin_carrier_invoices`, `margin_gl_actuals`, `margin_allocation_rules` | YES | Comments 100% (verified: 0 uncommented columns on all 10 margin_ tables) |
| Margin Genie agent | NO (P3-MARGIN-GENIE) | 4 persona benchmarks pass (DEC-017) |
| AI/BI dashboard Lakelink Fiber Margin Truth | NO (P3-DASHBOARD) | Tiles equal metric view values |
| App lakelink-margin-truth | YES | Explorer numbers equal metric view |

## 3. Glossary text (16 terms) for comments, MV synonyms and Margin Genie instructions

Source of truth: `src/semantics/glossary_pages.json` v1.0. Coverage column = whether the definition is already in a live UC comment (checked 2026-11-13).

| Term | Definition (Lakelink Fiber) | Synonyms | Lives in | Already in UC comments |
|---|---|---|---|---|
| Contribution Margin | Revenue minus network expense minus cost to serve, US dollars, defined once in the metric view | CM, margin, profit after cost to serve | margin_ledger_mv.contribution_margin, cm_pct | Table comment of margin_ledger points to the MV; MV not built |
| Revenue | Billed revenue for the circuit in the month | billed revenue, billings, sales, top line | margin_ledger.revenue_usd | Yes |
| Network Expense | Carrier paid amount (off-net) or on-net network cost (contract rate x 0.25 strategic / 0.60 legacy) | network cost, access cost, carrier cost | margin_ledger.network_expense_usd | Yes |
| Cost to Serve | Indirect pools (field_ops, noc, customer_care, billing_ops) allocated by active rules | CTS, allocated cost, servicing cost | margin_ledger.cost_to_serve_usd | Yes |
| Allocation Rule | Finance rule spreading one cost pool by driver and weight; weights per pool sum to 1 | cost allocation rule, allocation key | margin_allocation_rules | Yes (table + weight) |
| Cost Pool | Bucket of indirect cost allocated as cost to serve | overhead pool, indirect cost pool, CTS pool | margin_allocation_rules.cost_pool, margin_gl_actuals.cost_pool | Yes |
| Driver | Activity measure used to split a pool: circuit_count, ticket_count (synthetic proxy, DEC-016), bandwidth_mbps, billed_revenue | allocation driver, cost driver | margin_allocation_rules.driver | Yes |
| Margin Floor | Minimum acceptable CM % per product (default 0.2000) | minimum margin, floor, hurdle margin | margin_products.margin_floor_pct | Yes |
| On-Net | Circuit on Lakelink Fiber's own fiber; vendor_id NULL | on net, own fiber | margin_circuits.is_on_net | Yes |
| Off-Net | Circuit on a third-party carrier; Lakelink Fiber pays a carrier invoice | off net, leased circuit, third-party circuit | margin_circuits.is_on_net = FALSE | Yes |
| Legacy Family | family_class = legacy: IP-VPN and Legacy Voice | legacy products, legacy voice | margin_products.family_class | Yes |
| Strategic Family | family_class = strategic: Dedicated Internet, Wavelength, Ethernet, Managed, Colocation | strategic products, growth products | margin_products.family_class | Yes |
| Revenue Leakage | Expected revenue minus billed revenue; positive = under-billing | leakage, billing gap | margin_ledger.expected_revenue_usd, margin_billing | Yes |
| Rate Variance | Carrier invoiced rate minus contracted vendor rate; positive = overbilled | overbilling, invoice variance | margin_ledger.carrier_rate_variance_usd | Yes |
| Grooming | Moving an off-net circuit next to Lakelink fiber onto the own network; scored by margin_score_onnet_move | circuit grooming, on-net migration | margin_circuits.is_parallel_to_onnet_fiber, UC function | Yes (column comment + margin_score_onnet_move function comment names the grooming agent) |
| $1B Wall | Target of USD 1,000,000,000 annualized margin improvement, tracked by lever | billion dollar wall, margin improvement target | Dashboard $1B Wall page, margin_ledger_mv | No (no asset yet) |

## 4. Canonical persona answers Genie One must route to (DEC-017)

* Finance: product_family contribution margin for the last full quarter from margin_ledger_mv.
* Ops: off-net circuits with is_parallel_to_onnet_fiber AND margin_score_onnet_move savings > 0 (same filter as the grooming agent).
* Sales: term_end within 90 days of the demo as-of date AND cm_pct from margin_ledger_mv < margin_products.margin_floor_pct.
* Marketing: DEC-013 room to grow (cm_pct above portfolio average AND revenue share below customer-count share), margin_segment_growth_mv.

## 5. Remaining gaps (filed as tasks)

* MV metadata: every measure/dimension in margin_ledger_mv needs comment, display name, format, synonyms from section 3 (DP-MV-GLOSSARY-FIELDS, @data-analyst).
* margin_circuits table comment says "12 off-net 1G circuits"; under DEC-017 12 is a sub-view and the Ops hero count is defined by the score filter. Comment must not state a conflicting hero count (DP-FIX-CIRCUITS-COMMENT-HERO, @data-engineer).
* $1B Wall and Grooming definitions must appear in Margin Genie instructions (DP-GENIE-GLOSSARY-INSTR, @data-analyst).
