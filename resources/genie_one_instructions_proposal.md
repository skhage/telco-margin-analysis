# Genie One Instructions Proposal: Lakelink Fiber Margin Truth

Owner: @data-planner (v1.0), @data-analyst (v1.1) · Tasks: DP-GENIE-ONE-FALLBACK, P3-GENIE-ONE-READINESS · Status: DRAFT v1.1 (2026-11-13) · Company: Lakelink Fiber (fictional) · telco_project = margin_analysis

This is a PROPOSAL only. The CEO must approve it before anything is copied into `/Workspace/.genie_workspace_instructions.md`. No agent edits that file.

Why this exists: Genie One finds the margin assets through (a) certified metric views with full comments, (b) the Discover domain `lakelink_margin` (2abc9194-aed9-4088-bfa6-4b4d33870ebd) and its 16 Glossary Pages (DRAFT), (c) Margin Genie, and (d) this proposed workspace instruction block. v1.1 note: the domain quota gate cleared on 2026-11-13 (@pm run #9), and all 5 margin_ metric views are live and certified.

## 1. Proposed block for /Workspace/.genie_workspace_instructions.md (CEO approval required)

```
## Lakelink Fiber margin and profitability (Margin Truth)
- For questions about margin, contribution margin, profitability, cost to serve, losing products or circuits, off-net or on-net circuits, renewals below the margin floor, revenue leakage, carrier rate variance, grooming, or the $1B Wall, use the Margin Genie agent (Lakelink Fiber Margin Genie) or the certified metric views in cdm_tmforum._metrics with prefix margin_: margin_ledger_mv (contribution margin, all personas), margin_offnet_spend_mv (Ops: off-net spend and grooming candidates, is_grooming_candidate), margin_renewal_floor_mv (Sales: is_renewal_next_90d AND is_below_floor), margin_segment_growth_mv (Marketing: room_to_grow), margin_onebillion_wall_mv ($1B Wall levers).
- "Last quarter" means the last full calendar quarter before the demo as-of date 2026-11-19 (2026 Q3, Jul-Sep). "Next 90 days" means term_end between 2026-11-19 and 2026-11-19 + 90 days, never CURRENT_DATE.
- Contribution margin = revenue - network expense - cost to serve. It is defined ONCE as the measure contribution_margin in cdm_tmforum._metrics.margin_ledger_mv. Always query it with MEASURE(contribution_margin). Never recompute it from columns, and never add your own cost to serve.
- Legacy vs strategic follows margin_products.family_class (legacy = IP-VPN and Legacy Voice; all others strategic).
- Off-net means the circuit rides a third-party carrier (is_on_net = FALSE, vendor_id NOT NULL). On-net means it rides Lakelink Fiber's own fiber.
- Margin data lives only in cdm_tmforum.revenue_assurance (tables with prefix margin_) and cdm_tmforum._metrics (metric views with prefix margin_). Do not answer margin questions from oracle_erp_source, salesforce_source, ironclad_clm_source, mdm_source or tmf_* raw tables.
- Amounts are US dollars per month unless stated. Percentages are stored as fractions (0.2000 = 20%).
```

## 2. Assets to certify once validated

Status re-checked 2026-11-13 by @data-analyst (P3-GENIE-ONE-READINESS) by SQL on cdm_tmforum.information_schema and the Genie API.

| Asset | State (2026-11-13) | Certified |
|---|---|---|
| `cdm_tmforum._metrics.margin_ledger_mv` | Live; 25/25 fields commented; MEASURE(contribution_margin) = 2,375,095,705.09 = raw SQL on margin_ledger_allocated | YES (system.certification_status = certified, set by @data-analyst after @qa P2-MV-VALIDATION) |
| `margin_offnet_spend_mv` | Live; 19/19 commented; 47 grooming candidates = raw function check | YES |
| `margin_renewal_floor_mv` | Live; 22/22 commented; 586 below floor = raw SQL (DEC-019) | YES |
| `margin_segment_growth_mv` | Live; 10/10 commented; room_to_grow = Commercial only = raw SQL (DEC-013) | YES |
| `margin_onebillion_wall_mv` | Live; 9/9 commented | YES |
| `margin_` tables in revenue_assurance | Live, commented, PK/FK | Not yet (owner @data-planner) |
| Margin Genie 01f1df115a08164aab3ae5f6faac807c | Live; 13 benchmarks; 4 starter questions answer correctly (section 6) | n/a |
| Dashboard 01f1df1950c51bd68e87ace31632c2bf | Live (ONE dashboard) | n/a |
| Tags | All 5 MVs carry telco_project = margin_analysis as TBLPROPERTIES; the UC entity-tag API returned no telco_project tag | - |

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
| $1B Wall | Target of USD 1,000,000,000 annualized margin improvement, tracked by lever | billion dollar wall, margin improvement target | margin_onebillion_wall_mv, dashboard $1B Wall page | Yes (margin_onebillion_wall_mv comment) |

## 4. Canonical persona answers Genie One must route to (DEC-017)

* Finance: product_family contribution margin for the last full quarter from margin_ledger_mv.
* Ops: off-net circuits with is_parallel_to_onnet_fiber AND margin_score_onnet_move savings > 0 (same filter as the grooming agent).
* Sales: term_end within 90 days of the demo as-of date AND cm_pct from margin_ledger_mv < margin_products.margin_floor_pct.
* Marketing: DEC-013 room to grow (cm_pct above portfolio average AND revenue share below customer-count share), margin_segment_growth_mv.

## 5. Remaining gaps (v1.1)

* CEO approval of the section 1 block before anyone edits `/Workspace/.genie_workspace_instructions.md` (filed: PM-GENIE-ONE-CEO-CAPTURE, @pm).
* Genie One itself cannot be driven by API (no REST endpoint for the workspace chat). The 4 questions must be asked once interactively in Genie One by the CEO, with screenshots, and compared with section 6. If that hasn't happened by Nov 14 18:00 UTC, the demo uses Margin Genie only (@pm handoff note 559).
* Glossary Pages are still DRAFT (DP-GLOSSARY-CERTIFY, @data-planner).
* Closed since v1.0: MV metadata (DP-MV-GLOSSARY-FIELDS), $1B Wall and Grooming in Margin Genie instructions (verified in text_instructions on 2026-11-13).

## 6. Expected answers for the Genie One capture (verified 2026-11-13)

Each value was verified twice: by raw SQL on `margin_ledger_allocated` and the base tables, and live in Margin Genie (conversation API, all 4 COMPLETED, about 25 s in parallel, each SQL on MEASURE() over a margin_ MV).

| Persona | Question | Expected answer |
|---|---|---|
| Finance | Which product families lost money after cost to serve last quarter? | 2 families in 2026 Q3: IP-VPN -6,715,475.88 and Legacy Voice -249,532.74 (both legacy). Q3 portfolio CM 590,767,062.41 |
| Ops | Which off-net circuits run next to our own fiber, and what do we pay for them? | 47 grooming candidates (Margin Genie row count 47); estimated savings 412,539.96 per year (raw function check) |
| Sales | Which renewals in the next 90 days are below the margin floor? | 586 below floor out of 1,490 renewals (1,377 with ledger rows), as of 2026-11-19 |
| Marketing | Which segments have the highest margin and the most room to grow? | Commercial: CM 54.35% vs portfolio 54.14%, revenue share 34.43% below customer share 34.46%. The only segment with room to grow |

Portfolio contribution margin = 2,375,095,705.09 (DEC-020).
