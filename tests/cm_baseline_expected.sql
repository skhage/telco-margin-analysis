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
FROM cdm_tmforum.revenue_assurance.margin_ledger
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
FROM cdm_tmforum.revenue_assurance.margin_ledger
WHERE ledger_month BETWEEN DATE'2026-07-01' AND DATE'2026-09-01'
GROUP BY product_family
ORDER BY contribution_margin_usd;

-- (3) Source tie-outs for the same 12 months (independent of the ledger build):
--     revenue = SUM(margin_billing.billed_amount_usd) = 4387270143.94 (exact)
--     cost_to_serve vs margin_gl_actuals account_class='cost_to_serve_pool' = 360274000.00 (diff 17.43)
--     network_expense vs margin_gl_actuals account_class='network_expense' = 1651978299.56 (diff 77843.02, 0.005%)
SELECT 'billing_revenue' AS check_name, CAST(SUM(billed_amount_usd) AS DECIMAL(18,2)) AS amount_usd
FROM cdm_tmforum.revenue_assurance.margin_billing
WHERE billing_month BETWEEN DATE'2025-11-01' AND DATE'2026-10-01'
UNION ALL
SELECT account_class, CAST(SUM(amount_usd) AS DECIMAL(18,2))
FROM cdm_tmforum.revenue_assurance.margin_gl_actuals
WHERE period_month BETWEEN DATE'2025-11-01' AND DATE'2026-10-01'
GROUP BY account_class;

-- (4) Ops starter question (hero set, note 206 definition): expected 12 circuits
SELECT COUNT(*) AS hero_circuits
FROM cdm_tmforum.revenue_assurance.margin_circuits
WHERE NOT is_on_net AND is_parallel_to_onnet_fiber AND bandwidth_mbps = 1000
  AND onnet_distance_m BETWEEN 51 AND 172;

-- (5) Marketing starter question (DEC-013 room to grow): expected exactly one segment, Commercial
--     (cm_pct 0.5435 > portfolio 0.5414; revenue share 0.3443 < customer share 0.3446). Margin is thin, see QA-F-MKT-ROOM-TO-GROW-THIN.
WITH s AS (
  SELECT segment, SUM(revenue_usd) AS rev,
         SUM(revenue_usd - network_expense_usd - cost_to_serve_usd) AS cm,
         COUNT(DISTINCT customer_id) AS cust
  FROM cdm_tmforum.revenue_assurance.margin_ledger GROUP BY segment),
t AS (SELECT SUM(rev) AS trev, SUM(cm) AS tcm, SUM(cust) AS tcust FROM s)
SELECT segment, cm / rev AS cm_pct, rev / trev AS revenue_share, cust / tcust AS customer_share
FROM s CROSS JOIN t
WHERE cm / rev > tcm / trev AND rev / trev < cust / tcust;

-- (6) Sales starter question (renewals next 90 days below margin floor): PENDING canonical definition
--     (QA-LEDGER-STORY-COUNTS: 180 by Discount__c>=30 vs 598 by ledger CM% < margin_floor_pct). Not yet a regression gate.
