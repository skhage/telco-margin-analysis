# Margin Genie - instructions DRAFT v0.1 (P2-MV-YAML-DRAFT, @data-analyst, 2026-11-12)

Company: Lakelink Fiber (fictional). ONE Margin Genie for Finance, Ops, Sales, Marketing (DEC-005). Not yet created: P3-MARGIN-GENIE waits on P2-MV-MARGIN-LEDGER.

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
"Room to grow" is defined in `margin_segment_growth_mv` (proposal: high cm_pct with low share of revenue). Base query:
```sql
SELECT segment, MEASURE(contribution_margin) AS contribution_margin, MEASURE(cm_pct) AS cm_pct, MEASURE(customer_count) AS customers
FROM cdm_tmforum._metrics.margin_ledger_mv
WHERE ledger_month >= ADD_MONTHS(DATE_TRUNC('MONTH', CURRENT_DATE()), -12)
GROUP BY ALL ORDER BY cm_pct DESC;
```

## Variants to add as benchmarks (8)
1. What was total contribution margin last quarter? 2. Margin % for legacy vs strategic? 3. Top 10 customers by negative contribution margin. 4. Off-net spend by vendor this month. 5. How many off-net circuits are grooming candidates? 6. Revenue leakage by region. 7. Carrier rate variance by vendor. 8. Contribution margin trend by month for Legacy Voice.
