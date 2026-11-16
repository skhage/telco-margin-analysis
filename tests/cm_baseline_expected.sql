-- Lakelink Fiber Margin Truth: contribution margin REGRESSION BASELINE (answers COO-Q-20261112-20)
-- Owner @qa. Every surface (Genie, Genie One, dashboard, app, agent) must match these values to the cent.
-- CM = revenue - network_expense - cost_to_serve (DEC-002). Raw SQL over gold margin_ledger, independent of the metric view.
-- Baseline captured 2026-11-13, allocation_rule_version MGN-ALR-v1, ledger_month 2025-11-01..2026-10-01, 517,032 rows.
-- If the allocation rule version changes (scene 3), recapture and update the expected values below.

-- (1) Product-family grain + overall total, full date range
SELECT COALESCE(product_family, '__TOTAL__')                                   AS product_family,
       CAST(SUM(revenue_usd) AS DECIMAL(18,2))                                  AS revenue_usd,
       CAST(SUM(network_expense_usd) AS DECIMAL(18,2))                          AS network_expense_usd,
       CAST(SUM(cost_to_serve_usd) AS DECIMAL(18,2))                            AS cost_to_serve_usd,
       CAST(SUM(revenue_usd - network_expense_usd - cost_to_serve_usd) AS DECIMAL(18,2)) AS contribution_margin_usd
FROM ${catalog}.${schema}.margin_ledger
GROUP BY ROLLUP(product_family)
ORDER BY contribution_margin_usd DESC;

-- Expected (MGN-ALR-v1):
-- product_family      revenue_usd     network_expense_usd  cost_to_serve_usd  contribution_margin_usd
-- __TOTAL__           4387270143.94   1651900456.54        360273982.57       2375095704.83
-- Wavelength          3135975969.14   1153284912.54        167239105.80       1815451950.80
-- Dedicated Internet   785081379.48    290692100.31         65301394.86        429087884.31
-- Colocation           202416565.50     74107772.01         28064760.88        100244032.61
-- Ethernet             118112487.75     43702654.25         26961509.93         47448323.57
-- Managed               58224531.27     21600675.66         26150945.35         10472910.26
-- Legacy Voice           2792797.80      2249496.68          1542152.92          -998851.80
-- IP-VPN                84666413.00     66262845.09         45014112.83        -26610544.92

-- (2) Finance starter question: "Which product families lost money after cost to serve last quarter?"
--     Last quarter = Q3 2026 (ledger_month 2026-07-01..2026-09-01). Expected losers: IP-VPN -6.715M, Legacy Voice -0.250M.
--     Full Q3 CM (USD M): Wavelength 451.716, Dedicated Internet 106.708, Colocation 24.933, Ethernet 11.798, Managed 2.577.
SELECT product_family,
       CAST(SUM(revenue_usd - network_expense_usd - cost_to_serve_usd) AS DECIMAL(18,2)) AS contribution_margin_usd
FROM ${catalog}.${schema}.margin_ledger
WHERE ledger_month BETWEEN DATE'2026-07-01' AND DATE'2026-09-01'
GROUP BY product_family
ORDER BY contribution_margin_usd;

-- (3) Source tie-outs for the same 12 months (independent of the ledger build):
--     revenue = SUM(margin_billing.billed_amount_usd) = 4387270143.94 (exact)
--     cost_to_serve vs margin_gl_actuals account_class='cost_to_serve_pool' = 360274000.00 (diff 17.43)
--     network_expense vs margin_gl_actuals account_class='network_expense' = 1651978299.56 (diff 77843.02, 0.005%)
SELECT 'billing_revenue' AS check_name, CAST(SUM(billed_amount_usd) AS DECIMAL(18,2)) AS amount_usd
FROM ${catalog}.${schema}.margin_billing
WHERE billing_month BETWEEN DATE'2025-11-01' AND DATE'2026-10-01'
UNION ALL
SELECT account_class, CAST(SUM(amount_usd) AS DECIMAL(18,2))
FROM ${catalog}.${schema}.margin_gl_actuals
WHERE period_month BETWEEN DATE'2025-11-01' AND DATE'2026-10-01'
GROUP BY account_class;

-- (4a) Ops starter question, CANONICAL (DEC-017): off-net AND parallel AND savings > 0. Expected 47 (verified @qa 2026-11-13; featured 45040 = 879.34, 98532 = 469.00)
SELECT COUNT(DISTINCT s.circuit_id) AS hero_circuits
FROM ${catalog}.${schema}.margin_score_onnet_move(NULL) s
JOIN ${catalog}.${schema}.margin_circuits c USING (circuit_id)
WHERE NOT c.is_on_net AND s.is_parallel_to_onnet_fiber AND s.est_monthly_savings_usd > 0;

-- (4b) Ops band sub-view only (note 206 definition, not the benchmark answer): expected 12 circuits
SELECT COUNT(*) AS hero_circuits
FROM ${catalog}.${schema}.margin_circuits
WHERE NOT is_on_net AND is_parallel_to_onnet_fiber AND bandwidth_mbps = 1000
  AND onnet_distance_m BETWEEN 51 AND 172;

-- (5) Marketing starter question (DEC-013 room to grow): expected exactly one segment, Commercial
--     (cm_pct 0.5435 > portfolio 0.5414; revenue share 0.3443 < customer share 0.3446). Margin is thin, see QA-F-MKT-ROOM-TO-GROW-THIN.
WITH s AS (
  SELECT segment, SUM(revenue_usd) AS rev,
         SUM(revenue_usd - network_expense_usd - cost_to_serve_usd) AS cm,
         COUNT(DISTINCT customer_id) AS cust
  FROM ${catalog}.${schema}.margin_ledger GROUP BY segment),
t AS (SELECT SUM(rev) AS trev, SUM(cm) AS tcm, SUM(cust) AS tcust FROM s)
SELECT segment, cm / rev AS cm_pct, rev / trev AS revenue_share, cust / tcust AS customer_share
FROM s CROSS JOIN t
WHERE cm / rev > tcm / trev AND rev / trev < cust / tcust;

-- (6) Sales starter question (DEC-017): contracts with term_end in [as_of, as_of + 90d] AND contract CM% (full ledger range) < margin_floor_pct.
--     PENDING the demo as-of date, which DEC-017 does not pin (QA-F-SALES-ASOF-DATE). @qa 2026-11-13 results:
--     as_of 2026-11-13: 1,506 renewals, 1,392 with ledger rows, 603 below floor; as_of 2026-11-19: 1,490 / 1,377 / 586. The board's 598 / 1,381 is neither.
--     Before the MV exists this uses raw SQL; switch to MEASURE() on margin_ledger_mv once deployed.
WITH r AS (SELECT c.contract_id, p.margin_floor_pct
           FROM ${catalog}.${schema}.margin_contracts c JOIN ${catalog}.${schema}.margin_products p USING (product_id)
           WHERE c.term_end BETWEEN DATE'2026-11-19' AND date_add(DATE'2026-11-19', 90)),
m AS (SELECT contract_id, SUM(revenue_usd - network_expense_usd - cost_to_serve_usd) / NULLIF(SUM(revenue_usd), 0) AS cm_pct
      FROM ${catalog}.${schema}.margin_ledger GROUP BY contract_id)
SELECT COUNT(*) AS renewals, COUNT(m.contract_id) AS with_ledger,
       SUM(CASE WHEN m.cm_pct < r.margin_floor_pct THEN 1 ELSE 0 END) AS below_floor
FROM r LEFT JOIN m USING (contract_id);

-- (7) Scene 7: $1B Wall challenge cards (QA-SCENE7-CARDS-HARNESS, added @qa 2026-11-15 ~15:45 UTC).
--     Raw SQL on margin_ledger_allocated (the MV source), independent of the metric views. As-of DATE'2026-11-19' (DEC-019).
--     Verified 2026-11-15: raw = margin_onebillion_wall_mv MEASURE = Margin Genie 01f1df11 (DA-SCENE7-CARDS-GENIE-RUN-1115).
--     Expected:
--     C1 Finance  legacy losses Q3 2026: IP-VPN -6715475.88, Legacy Voice -249532.74 (only 2 families < 0)
--     C2 Ops      off-net grooming: 172 parallel off-net circuits, 47 with savings > 0, annual cost 1152342.12, annual savings 412539.96
--                 (ROUND monthly to 2 dp, then x12; unrounded savings would be 412539.85)
--     C3 Sales    renewals [2026-11-19, +90d]: 1490 renewals, 1377 with ledger rows, 586 below floor, revenue at stake 18890869.75, floor gap 4837761.36
--     C4 Mktg     room to grow: Commercial only (cm_pct 0.5435 > 0.5414; revenue share 0.3443 < customer share 0.3446)
--     C5 Finance  revenue leakage: 26698861.46
--     C6 Ops      carrier rate variance: 1694614.90
--     WALL        identified 61253174.38 = legacy repricing 27609396.70 + leakage 26698861.46 + renewal floor 4837761.36
--                 + rate variance 1694614.90 + off-net grooming 412539.96; target 1000000000.00, gap 938746825.62
--     NOTE legacy repricing = -SUM of negative legacy-family CM at PRODUCT grain (27609396.70); contract/circuit grain gives 28765541.75.
WITH q3 AS (
  SELECT product_family, SUM(revenue_usd - network_expense_usd - cost_to_serve_usd) AS cm
  FROM ${catalog}.${schema}.margin_ledger_allocated
  WHERE ledger_month >= DATE'2026-07-01' AND ledger_month < DATE'2026-10-01' GROUP BY product_family),
groom AS (
  SELECT i.circuit_id, MAX_BY(i.paid_amount_usd, i.invoice_month) AS paid, MAX(c.bandwidth_mbps) AS bw, MAX(c.onnet_distance_m) AS d
  FROM ${catalog}.${schema}.margin_carrier_invoices i
  JOIN ${catalog}.${schema}.margin_circuits c ON i.circuit_id = c.circuit_id
  WHERE NOT c.is_on_net AND c.is_parallel_to_onnet_fiber GROUP BY i.circuit_id),
gs AS (SELECT ROUND(paid, 2) AS paid, ROUND(paid - (2 * bw + 0.5 * d / 36), 2) AS sav FROM groom),
ren AS (
  SELECT c.contract_id AS rid, p.margin_floor_pct AS f
  FROM ${catalog}.${schema}.margin_contracts c
  JOIN ${catalog}.${schema}.margin_products p ON c.product_id = p.product_id
  WHERE c.term_end BETWEEN DATE'2026-11-19' AND date_add(DATE'2026-11-19', 90)),
led AS (
  SELECT contract_id AS mid, SUM(revenue_usd) AS rev, SUM(revenue_usd - network_expense_usd - cost_to_serve_usd) AS cm
  FROM ${catalog}.${schema}.margin_ledger_allocated GROUP BY contract_id),
legacy AS (
  SELECT product_id, SUM(revenue_usd - network_expense_usd - cost_to_serve_usd) AS cm
  FROM ${catalog}.${schema}.margin_ledger_allocated WHERE family_class = 'legacy' GROUP BY product_id),
lev AS (
  SELECT 'legacy_repricing' AS check_name, CAST(-SUM(cm) AS DECIMAL(18,2)) AS v FROM legacy WHERE cm < 0
  UNION ALL SELECT 'revenue_leakage', CAST(SUM(expected_revenue_usd) - SUM(revenue_usd) AS DECIMAL(18,2)) FROM ${catalog}.${schema}.margin_ledger_allocated
  UNION ALL SELECT 'renewal_floor_gap', CAST(SUM(CASE WHEN l.cm / l.rev < r.f THEN (r.f - l.cm / l.rev) * l.rev END) AS DECIMAL(18,2)) FROM ren r LEFT JOIN led l ON r.rid = l.mid
  UNION ALL SELECT 'carrier_rate_variance', CAST(SUM(carrier_rate_variance_usd) AS DECIMAL(18,2)) FROM ${catalog}.${schema}.margin_ledger_allocated
  UNION ALL SELECT 'offnet_grooming_savings', CAST(SUM(sav) * 12 AS DECIMAL(18,2)) FROM gs WHERE sav > 0)
SELECT check_name, v FROM lev
UNION ALL SELECT 'wall_identified_total', CAST(SUM(v) AS DECIMAL(18,2)) FROM lev
UNION ALL SELECT 'c1_ip_vpn_q3_cm', CAST(SUM(cm) AS DECIMAL(18,2)) FROM q3 WHERE product_family = 'IP-VPN'
UNION ALL SELECT 'c1_legacy_voice_q3_cm', CAST(SUM(cm) AS DECIMAL(18,2)) FROM q3 WHERE product_family = 'Legacy Voice'
UNION ALL SELECT 'c1_loser_families', CAST(COUNT(*) AS DECIMAL(18,2)) FROM q3 WHERE cm < 0
UNION ALL SELECT 'c2_grooming_circuits', CAST(COUNT(*) AS DECIMAL(18,2)) FROM gs WHERE sav > 0
UNION ALL SELECT 'c2_annual_offnet_cost', CAST(SUM(paid) * 12 AS DECIMAL(18,2)) FROM gs WHERE sav > 0
UNION ALL SELECT 'c3_renewals', CAST(COUNT(*) AS DECIMAL(18,2)) FROM ren
UNION ALL SELECT 'c3_below_floor', CAST(COUNT_IF(l.cm / l.rev < r.f) AS DECIMAL(18,2)) FROM ren r LEFT JOIN led l ON r.rid = l.mid
UNION ALL SELECT 'c3_revenue_at_stake', CAST(SUM(CASE WHEN l.cm / l.rev < r.f THEN l.rev END) AS DECIMAL(18,2)) FROM ren r LEFT JOIN led l ON r.rid = l.mid;
