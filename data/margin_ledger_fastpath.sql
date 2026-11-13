-- Lakelink Fiber Margin Truth: gold margin_ledger, SQL fast path (DEC-008), P1-LEDGER-GOLD-FASTPATH + DA-REQ-LEDGER-DRIVER-COLS
-- Owner @data-engineer, built 2026-11-13. Contract: src/semantics/STANDARDS.md v1.0 plus driver columns.
-- Grain: customer x product x circuit x month (one row per margin_billing row). Target: cdm_tmforum.revenue_assurance.margin_ledger
-- Network rule (note 182): on-net = contract_rate_usd x 0.25 strategic / 0.60 legacy; off-net = carrier paid_amount_usd.
-- cost_to_serve_usd = baseline with active margin_allocation_rules (MGN-ALR-v1); live changes go through margin_ledger_allocated.
-- ticket_count is a SYNTHETIC deterministic proxy (tmf_enterprise.ra_trouble_ticket has only 87 matched tickets in window).
-- Table DDL with column comments was run once; reload with the INSERT OVERWRITE below.

INSERT OVERWRITE cdm_tmforum.revenue_assurance.margin_ledger
WITH base AS (
  SELECT b.billing_month AS ledger_month, b.customer_id, k.product_id, b.circuit_id, b.contract_id,
         c.vendor_id, c.is_on_net, p.product_family, p.family_class, u.segment, u.region,
         CAST(b.billed_amount_usd AS DECIMAL(18,2)) AS revenue_usd,
         CAST(b.expected_amount_usd AS DECIMAL(18,2)) AS expected_revenue_usd,
         CAST(CASE WHEN c.is_on_net THEN k.contract_rate_usd * CASE WHEN p.family_class = 'legacy' THEN 0.60 ELSE 0.25 END
                   ELSE coalesce(ci.paid_amount_usd, 0) END AS DECIMAL(18,2)) AS network_expense_usd,
         CAST(CASE WHEN c.is_on_net OR ci.circuit_id IS NULL THEN 0
                   ELSE ci.invoiced_rate_usd - ci.vendor_contract_rate_usd END AS DECIMAL(18,2)) AS carrier_rate_variance_usd,
         1 AS circuit_count,
         CAST(c.bandwidth_mbps AS DECIMAL(12,2)) AS bandwidth_mbps,
         CAST(CASE WHEN p.family_class = 'legacy' THEN floor(pmod(xxhash64(b.circuit_id, b.billing_month), 1000) / 250)
                   ELSE CASE WHEN pmod(xxhash64(b.circuit_id, b.billing_month), 100) < 25 THEN 1 ELSE 0 END END AS INT) AS ticket_count
  FROM cdm_tmforum.revenue_assurance.margin_billing b
  JOIN cdm_tmforum.revenue_assurance.margin_circuits c ON c.circuit_id = b.circuit_id
  JOIN cdm_tmforum.revenue_assurance.margin_contracts k ON k.contract_id = b.contract_id
  JOIN cdm_tmforum.revenue_assurance.margin_products p ON p.product_id = k.product_id
  JOIN cdm_tmforum.revenue_assurance.margin_customers u ON u.customer_id = b.customer_id
  LEFT JOIN cdm_tmforum.revenue_assurance.margin_carrier_invoices ci
    ON ci.circuit_id = b.circuit_id AND ci.invoice_month = b.billing_month
),
tot AS (
  SELECT ledger_month, SUM(circuit_count) s_cc, SUM(bandwidth_mbps) s_bw, SUM(ticket_count) s_tk, SUM(revenue_usd) s_rev
  FROM base GROUP BY ledger_month
),
pools AS (
  SELECT g.period_month AS ledger_month, r.driver, SUM(g.amount_usd * r.weight) AS amt
  FROM cdm_tmforum.revenue_assurance.margin_gl_actuals g
  JOIN cdm_tmforum.revenue_assurance.margin_allocation_rules r
    ON r.cost_pool = g.cost_pool AND r.is_active AND g.period_month >= r.effective_from
   AND (r.effective_to IS NULL OR g.period_month <= r.effective_to)
  WHERE g.account_class = 'cost_to_serve_pool'
  GROUP BY 1, 2
),
pw AS (
  SELECT ledger_month,
         SUM(CASE WHEN driver = 'circuit_count' THEN amt END) a_cc,
         SUM(CASE WHEN driver = 'bandwidth_mbps' THEN amt END) a_bw,
         SUM(CASE WHEN driver = 'ticket_count' THEN amt END) a_tk,
         SUM(CASE WHEN driver = 'billed_revenue' THEN amt END) a_rev
  FROM pools GROUP BY 1
)
SELECT b.ledger_month, b.customer_id, b.product_id, b.circuit_id, b.contract_id, b.vendor_id, b.is_on_net,
       b.product_family, b.family_class, b.segment, b.region,
       b.revenue_usd, b.network_expense_usd,
       CAST(coalesce(pw.a_cc, 0) * b.circuit_count / t.s_cc
          + coalesce(pw.a_bw, 0) * b.bandwidth_mbps / t.s_bw
          + coalesce(pw.a_tk, 0) * b.ticket_count / nullif(t.s_tk, 0)
          + coalesce(pw.a_rev, 0) * b.revenue_usd / t.s_rev AS DECIMAL(18,2)) AS cost_to_serve_usd,
       b.expected_revenue_usd, b.carrier_rate_variance_usd,
       b.circuit_count, b.bandwidth_mbps, b.ticket_count, b.revenue_usd AS billed_revenue_usd,
       'MGN-ALR-v1' AS allocation_rule_version,
       'MIXED' AS origin, 'margin_fastpath_sql' AS source_system
FROM base b
JOIN tot t USING (ledger_month)
LEFT JOIN pw USING (ledger_month)
