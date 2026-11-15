-- Lakelink Fiber Margin Truth - Scene 3 SELECT-only allocation simulator (COO-Q-20261114-104, DEC-027(3))
-- Owner: @data-engineer. READ-ONLY: no DML, no temp view. Inline copy of the margin_ledger_allocated
-- view CTEs (SHOW CREATE TABLE 2026-11-15) with ONE change: the weight of rule
-- 'MGN-ALR-customer_care-ticket_count-v1' is overridden by :ticket_weight.
-- Verified 2026-11-15 ~00:15 UTC on warehouse bf0baa637e887c80:
--   :ticket_weight = 0.70 -> CM 2,375,095,705.09 / CTS 360,273,982.31 / 517,032 rows (stmt 01f1e089-6481-15b1-82a9-1fcf02120530)
--                            = MEASURE(contribution_margin) from _metrics.margin_ledger_mv (stmt 01f1e089-5ac8-1ba2-90aa-2415b077118c)
--   :ticket_weight = 0.90 -> CM 2,360,713,702.39 / CTS 374,655,985.01 (stmt 01f1e089-65dc-1e91-9d03-912932800f51)
--   back to 0.70           -> CM 2,375,095,705.09 (stmt 01f1e089-671c-16c8-9a20-b55704f6c6ae)
-- If the view definition changes, regenerate this file from SHOW CREATE TABLE.

SELECT CAST(SUM(revenue_usd - network_expense_usd - cost_to_serve_usd) AS DECIMAL(20,2)) AS contribution_margin_usd,
       CAST(SUM(cost_to_serve_usd) AS DECIMAL(20,2)) AS cost_to_serve_usd,
       COUNT(*) AS ledger_rows
FROM (
WITH active_rules AS (
  SELECT m.ledger_month, r.cost_pool, r.driver, CASE WHEN r.rule_id = 'MGN-ALR-customer_care-ticket_count-v1' THEN CAST(:ticket_weight AS DECIMAL(10,6)) ELSE r.weight END AS weight
  FROM (SELECT DISTINCT ledger_month FROM cdm_tmforum.revenue_assurance.margin_ledger_v2) m
  JOIN cdm_tmforum.revenue_assurance.margin_allocation_rules r
    ON r.is_active AND m.ledger_month >= r.effective_from
   AND m.ledger_month <= COALESCE(r.effective_to, DATE'9999-12-31')
),
pools AS (
  SELECT period_month AS ledger_month, cost_pool, SUM(amount_usd) AS pool_usd
  FROM cdm_tmforum.revenue_assurance.margin_gl_actuals
  WHERE account_class = 'cost_to_serve_pool' GROUP BY 1,2
),
driver_totals AS (
  SELECT ledger_month,
         SUM(circuit_count) AS t_circuit_count, SUM(bandwidth_mbps) AS t_bandwidth_mbps,
         SUM(ticket_count) AS t_ticket_count, SUM(billed_revenue_usd) AS t_billed_revenue
  FROM cdm_tmforum.revenue_assurance.margin_ledger_v2 GROUP BY 1
),
coef AS (
  SELECT a.ledger_month,
    SUM(CASE WHEN a.driver='circuit_count'  THEN CAST(p.pool_usd AS DOUBLE)*CAST(a.weight AS DOUBLE)/d.t_circuit_count  ELSE 0 END) AS k_circuit_count,
    SUM(CASE WHEN a.driver='bandwidth_mbps' THEN CAST(p.pool_usd AS DOUBLE)*CAST(a.weight AS DOUBLE)/CAST(d.t_bandwidth_mbps AS DOUBLE) ELSE 0 END) AS k_bandwidth_mbps,
    SUM(CASE WHEN a.driver='ticket_count'   THEN CAST(p.pool_usd AS DOUBLE)*CAST(a.weight AS DOUBLE)/d.t_ticket_count   ELSE 0 END) AS k_ticket_count,
    SUM(CASE WHEN a.driver='billed_revenue' THEN CAST(p.pool_usd AS DOUBLE)*CAST(a.weight AS DOUBLE)/CAST(d.t_billed_revenue AS DOUBLE) ELSE 0 END) AS k_billed_revenue
  FROM active_rules a
  JOIN pools p ON p.ledger_month=a.ledger_month AND p.cost_pool=a.cost_pool
  JOIN driver_totals d ON d.ledger_month=a.ledger_month
  GROUP BY a.ledger_month
)
SELECT l.ledger_month, l.customer_id, l.product_id, l.circuit_id, l.contract_id, l.vendor_id, l.is_on_net,
       l.product_family, l.family_class, l.segment, l.region, l.revenue_usd, l.network_expense_usd,
       CAST(ROUND(COALESCE(
            l.circuit_count*c.k_circuit_count + CAST(l.bandwidth_mbps AS DOUBLE)*c.k_bandwidth_mbps
          + l.ticket_count*c.k_ticket_count + CAST(l.billed_revenue_usd AS DOUBLE)*c.k_billed_revenue, 0), 2) AS DECIMAL(18,2)) AS cost_to_serve_usd,
       l.expected_revenue_usd, l.carrier_rate_variance_usd, l.circuit_count, l.bandwidth_mbps, l.ticket_count,
       l.billed_revenue_usd, l.allocation_rule_version, l.origin, l.source_system
FROM cdm_tmforum.revenue_assurance.margin_ledger_v2 l
LEFT JOIN coef c ON c.ledger_month = l.ledger_month
) s;
