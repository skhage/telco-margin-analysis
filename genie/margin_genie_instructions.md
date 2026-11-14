# Margin Genie - instructions v1.0 LIVE (P3-MARGIN-GENIE, @data-analyst, 2026-11-13)

Company: Lakelink Fiber (fictional). ONE Margin Genie for Finance, Ops, Sales, Marketing (DEC-005).

## Live space
* space_id `01f1df115a08164aab3ae5f6faac807c`, warehouse telco_cdm_model (`bf0baa637e887c80`), asset_ledger row 65.
* The live serialized space is the source of truth. It holds the text instructions (10 core rules + 16-term glossary), 5 example SQLs, join specs, the UC function `margin_score_onnet_move`, and 5 benchmarks. The SQL below is the draft history.
* Tables in the space: `_metrics.margin_ledger_mv` (primary), plus the dims `margin_circuits`, `margin_contracts`, `margin_products`, `margin_vendors`. Raw source tables and the `margin_ledger` table are not in the space.
* Fixed as-of date DATE'2026-11-19' (DEC-019). Last quarter = Q3 2026.

## Space title and description (DSN-GENIE-COPY-R1, DESIGN_TOKENS section 9)
* Title: Lakelink Fiber Margin Genie
* Description: "Ask Lakelink Fiber margin questions in plain English. One space for Finance, Ops, Sales, and Marketing. Margin always means contribution margin (revenue minus network expense minus cost to serve) from the governed metric view margin_ledger_mv, so every team gets the same number."
* Sample questions, in order: Finance, Ops, Sales, Marketing (the plan starters, using "our own fiber").

## Verified answers 2026-11-13 (Genie conversation API vs independent raw SQL on margin_ledger_allocated)
| Persona | Expected | Genie |
| --- | --- | --- |
| Finance Q3-2026 | IP-VPN -6,715,475.88; Legacy Voice -249,532.74 | match |
| Ops | 47 circuits, cost 96,028.51/mo, savings 34,378.33/mo; 45040 879.34, 98532 469.00 | match (after OPS RULE) |
| Sales @2026-11-19 | 586 below floor | match |
| Marketing | Commercial = only room-to-grow segment (CM % 54.4% vs 54.1% portfolio) | match |
| Total CM | 2,375,095,705.09 | match |
Note: -998,851.80 (Legacy Voice) and -26,610,544.90 (IP-VPN) are full-ledger 12-month totals, not last-quarter figures.

## Data sources (metric views + ledger only, never raw source tables)
* `cdm_tmforum._metrics.margin_ledger_mv` (primary; defines contribution margin)
* `cdm_tmforum.revenue_assurance.margin_ledger` (gold; for row-level drill-through only)
* Suite views as they land (P2-MV-SUITE): `margin_offnet_spend_mv`, `margin_renewal_floor_mv`, `margin_segment_growth_mv`, `margin_rate_variance_mv`, `margin_revenue_leakage_mv`, `margin_gl_tieout_mv`, `margin_onebillion_wall_mv`

## General instructions (paste into the space)
1. You answer for Lakelink Fiber. Never name another real company.
2. "Margin", "CM", "profit" always means contribution margin = `MEASURE(contribution_margin)` from `margin_ledger_mv`. Never compute revenue - network expense - cost to serve yourself, and never sum columns of the ledger to get margin.
3. Margin % = `MEASURE(cm_pct)`. Present money in USD with no decimals, percentages with 1 decimal.
4. Legacy vs strategic follows the product family (`family_class`): legacy = IP-VPN (MPLS) and Legacy Voice; everything else strategic.
5. "Off-net" means the circuit rides a third-party vendor (`is_on_net = FALSE`, `vendor_id` not null). "On-net" means it rides Lakelink Fiber's own network.
6. "Loses money" / "unprofitable" means contribution margin < 0. "Below the margin floor" means cm_pct < the product's `margin_floor_pct` (default 20%).
7. "Last quarter" = the most recent complete calendar quarter in `ledger_quarter`. "Next 90 days" = `term_end` in [as_of_date, as_of_date + 90 days).
8. Always query metric views with `MEASURE()` and `GROUP BY ALL`; never `SELECT *` from a metric view.
9. If a question needs data that is not in these views, say so instead of guessing.

## Join specs (Genie ontology; mirrors informational PK/FK from P1-PK-FK-ONTOLOGY)
* customer 1-N contract: `margin_contracts.customer_id = margin_customers.customer_id`
* contract 1-N circuit: `margin_circuits.contract_id = margin_contracts.contract_id`
* circuit N-1 vendor: `margin_circuits.vendor_id = margin_vendors.vendor_id` (NULL = on-net)
* contract N-1 product: `margin_contracts.product_id = margin_products.product_id`
* Ledger grain customer x product x circuit x month; ledger joins all four on their ids.

## Synonyms (space-level)
contribution margin: margin, CM, profit after cost to serve · cost to serve: CTS, servicing cost · network expense: access cost, carrier cost · off-net: leased, third-party, vendor circuit · on-net: own fiber, Lakelink Fiber network · grooming: move on-net · margin floor: minimum margin · revenue leakage: under-billing · rate variance: overbilling · $1B Wall: billion-dollar margin target.

## Persona starter questions + expected-answer SQL (benchmarks for P3-GENIE-BENCHMARKS)
Expected values are filled in after P2-MV-MARGIN-LEDGER deploys and P2-MV-VALIDATION ties them to raw SQL.

### Finance - "Which product families lost money after cost to serve last quarter?"
```sql
SELECT product_family, family_class, MEASURE(contribution_margin) AS contribution_margin, MEASURE(cm_pct) AS cm_pct
FROM cdm_tmforum._metrics.margin_ledger_mv
WHERE ledger_quarter = (SELECT MAX(DATE_TRUNC('QUARTER', ledger_month)) FROM cdm_tmforum.revenue_assurance.margin_ledger
                        WHERE ADD_MONTHS(DATE_TRUNC('QUARTER', ledger_month), 3) <= DATE_TRUNC('MONTH', CURRENT_DATE()))
GROUP BY ALL
HAVING contribution_margin < 0
ORDER BY contribution_margin;
```
Planted answer: the legacy family (Legacy Voice and/or IP-VPN) is negative.

### Ops - "Which off-net circuits run next to our own fiber, and what do we pay for them?"
Needs `is_parallel_to_onnet_fiber` (margin_circuits), not in the ledger contract. Served by `margin_offnet_spend_mv` (P2-MV-SUITE), which joins margin_circuits many-to-one and reads spend as `MEASURE(offnet_network_expense)` semantics.
```sql
SELECT circuit_id, vendor_id, MEASURE(offnet_network_expense) AS monthly_offnet_spend
FROM cdm_tmforum._metrics.margin_offnet_spend_mv
WHERE is_parallel_to_onnet_fiber AND ledger_month = (SELECT MAX(ledger_month) FROM cdm_tmforum.revenue_assurance.margin_ledger)
GROUP BY ALL ORDER BY monthly_offnet_spend DESC;
```

### Sales - "Which renewals in the next 90 days are below the margin floor?"
Needs `term_end` (margin_contracts) and `margin_floor_pct` (margin_products). Served by `margin_renewal_floor_mv`.
```sql
SELECT contract_id, customer_id, product_family, term_end, MEASURE(cm_pct) AS cm_pct, ANY_VALUE(margin_floor_pct) AS margin_floor_pct
FROM cdm_tmforum._metrics.margin_renewal_floor_mv
WHERE term_end >= CURRENT_DATE() AND term_end < DATE_ADD(CURRENT_DATE(), 90)
GROUP BY ALL HAVING cm_pct < margin_floor_pct ORDER BY term_end;
```

### Marketing - "Which segments have the highest margin and the most room to grow?"
"Room to grow" (DEC-013) = segments whose cm_pct is above the portfolio average AND whose revenue share is below their customer-count share. Source: the deployed metric view `cdm_tmforum._metrics.margin_segment_growth_mv` (CM comes from margin_ledger_mv, DEC-002). Base query (same as live example SQL and benchmark; no date filter, full ledger range 2025-11 to 2026-10):
```sql
SELECT segment, room_to_grow, ROUND(MEASURE(contribution_margin),2) AS contribution_margin_usd,
  ROUND(MEASURE(cm_pct)*100,1) AS contribution_margin_pct, ROUND(ANY_VALUE(portfolio_cm_pct)*100,1) AS portfolio_cm_pct,
  ROUND(MEASURE(revenue_share)*100,1) AS revenue_share_pct, ROUND(MEASURE(customer_share)*100,1) AS customer_share_pct,
  MEASURE(customer_count) AS customers
FROM cdm_tmforum._metrics.margin_segment_growth_mv GROUP BY ALL ORDER BY contribution_margin_pct DESC;
```
**Thin-lead framing (DEC-032, live instruction 8a since 2026-11-14):** Commercial is the only room-to-grow segment, and the lead is thin. Exact numbers: CM % 54.35% vs portfolio 54.14% (+0.21 pts); revenue share 34.43% vs customer share 34.46% (-0.03 pts); 3,424 customers; CM 821,108,369.20. The table shows 1 dp (54.4 / 54.1 / 34.4 / 34.5), per the design token standard. Talk track: "Commercial is a thin lead, not a big gap: it earns slightly above the portfolio margin and still has a slightly smaller share of revenue than of customers. That is where Marketing looks first." Never call it a large or decisive gap. No data change before Nov 19 (DEC-032).

## Variants to add as benchmarks (8)
1. What was total contribution margin last quarter? 2. Margin % for legacy vs strategic? 3. Top 10 customers by negative contribution margin. 4. Off-net spend by vendor this month. 5. How many off-net circuits are grooming candidates? 6. Revenue leakage by region. 7. Carrier rate variance by vendor. 8. Contribution margin trend by month for Legacy Voice.
