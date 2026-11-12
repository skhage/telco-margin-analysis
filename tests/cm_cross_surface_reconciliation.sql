-- Lakelink Fiber Margin Truth: contribution margin cross-surface reconciliation (answers COO-Q-20261111-2)
-- Owner @data-analyst. Rerun by @qa in P5-QA-BENCHMARK-REGRESSION. Tolerance: EXACT to the cent (abs diff = 0.00).
-- Results land in Lakebase agent_tasks.status_notes of P2-MV-VALIDATION and P5-QA-BENCHMARK-REGRESSION (query text + values).

-- (a) REFERENCE: raw SQL over the gold ledger (independent of the metric view)
SELECT product_family,
       CAST(SUM(revenue_usd - network_expense_usd - cost_to_serve_usd) AS DECIMAL(18,2)) AS cm_ref
FROM cdm_tmforum.revenue_assurance.margin_ledger
GROUP BY product_family;

-- (b1) SURFACE: metric view (used by Genie, Genie One, dashboard datasets, app API, agent tool)
SELECT product_family, CAST(MEASURE(contribution_margin) AS DECIMAL(18,2)) AS cm_mv
FROM cdm_tmforum._metrics.margin_ledger_mv
GROUP BY ALL;

-- (b2) CHECK: must return 0 rows
WITH ref AS (
  SELECT product_family, CAST(SUM(revenue_usd - network_expense_usd - cost_to_serve_usd) AS DECIMAL(18,2)) AS cm_ref
  FROM cdm_tmforum.revenue_assurance.margin_ledger GROUP BY product_family),
mv AS (
  SELECT product_family, CAST(MEASURE(contribution_margin) AS DECIMAL(18,2)) AS cm_mv
  FROM cdm_tmforum._metrics.margin_ledger_mv GROUP BY ALL)
SELECT COALESCE(r.product_family, m.product_family) AS product_family, r.cm_ref, m.cm_mv
FROM ref r FULL OUTER JOIN mv m ON r.product_family <=> m.product_family
WHERE NOT (r.cm_ref <=> m.cm_mv);

-- (b3) NO-LOCAL-RECOMPUTE lint (run by @qa on source files): grep apps/, agents/, dashboards/, genie/ for
--      "network_expense_usd" combined with "cost_to_serve_usd" in one expression. Allowed only in
--      src/metric_views/margin_ledger_mv.yaml (as MEASURE composition) and this tests/ file.
--      Genie: query history must show MEASURE(contribution_margin). Dashboard: every dataset FROM cdm_tmforum._metrics.margin_*.
--      App + agent: SQL in code must use MEASURE(contribution_margin) via margin_ledger_mv.

-- (c) SCENE-3 ALLOCATION CHANGE: record (b1) totals, update one margin_allocation_rules weight, rebuild/refresh
--     margin_ledger cost_to_serve, rerun (a), (b1), (b2). Expect cm totals to move and (b2) to still return 0 rows.
--     Then revert the weight and confirm totals return to the baseline values.
SELECT CAST(MEASURE(contribution_margin) AS DECIMAL(18,2)) AS cm_total, MEASURE(cost_to_serve) AS cts_total
FROM cdm_tmforum._metrics.margin_ledger_mv;
