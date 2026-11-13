-- Lakelink Fiber Margin Truth: DE-REPOINT-ALLOCATED-V2 (DEC-023), @data-engineer 2026-11-13
-- Repoints the live-allocation view margin_ledger_allocated from the SQL fast-path table
-- margin_ledger (DEC-008) to the SDP pipeline gold margin_ledger_v2 (pipeline 20960984-a9d3-46f4-826a-6301155bc79a).
-- Columns, column comments and the telco_project tag are unchanged. Only the 3 FROM references and two comments differ.
-- Rollback: re-run with margin_ledger_v2 -> margin_ledger in the three FROM clauses.
-- Verified after apply: MEASURE(contribution_margin) on cdm_tmforum._metrics.margin_ledger_mv = 2,375,095,705.09 (unchanged).

CREATE OR REPLACE VIEW cdm_tmforum.revenue_assurance.margin_ledger_allocated (
  ledger_month COMMENT 'Ledger month, first day of the month. Part of the primary key. Synonyms: month, period, fiscal month.',
  customer_id COMMENT 'Lakelink Fiber customer (TMF customer id). Part of the primary key; references margin_customers. Synonyms: account, customer number.',
  product_id COMMENT 'Product of the contract line (Salesforce product2 Id or MGN-PRD- synthetic legacy voice id). Part of the primary key; references margin_products. Synonyms: product, sku.',
  circuit_id COMMENT 'Circuit (TMF customer facing service id). Part of the primary key; references margin_circuits. Synonyms: circuit, service id.',
  contract_id COMMENT 'Contract line that bills this circuit (Salesforce contract_line_item Id); references margin_contracts. Synonyms: contract, contract line.',
  vendor_id COMMENT 'Third-party carrier the circuit rides when off-net; NULL when on-net. References margin_vendors. Synonyms: carrier, supplier.',
  is_on_net COMMENT 'TRUE = circuit rides the Lakelink Fiber network; FALSE = off-net on a third-party vendor. Synonyms: on-net flag, own network.',
  product_family COMMENT 'Product family: Dedicated Internet, Wavelength, Ethernet, IP-VPN, Managed, Colocation, Legacy Voice. Synonyms: family, product line.',
  family_class COMMENT 'strategic or legacy, from the product family (legacy = IP-VPN and Legacy Voice). Synonyms: legacy vs strategic.',
  segment COMMENT 'Customer segment: Strategic Enterprise, Enterprise, Commercial, Small Business. Synonyms: market segment, customer tier.',
  region COMMENT 'Sales region of the customer. Synonyms: territory, geography.',
  revenue_usd COMMENT 'Billed revenue for the circuit in the month, US dollars (margin_billing.billed_amount_usd). Synonyms: sales, billings, top line.',
  network_expense_usd COMMENT 'Network cost for the circuit in the month, US dollars. Off-net = carrier paid amount; on-net = contract rate x 0.25 (strategic) or x 0.60 (legacy). Synonyms: network cost, access cost.',
  cost_to_serve_usd COMMENT 'Cost to serve in USD for this ledger row, computed at QUERY TIME (live allocation). Equals the sum over the active margin_allocation_rules of pool amount for the month (margin_gl_actuals, account_class = cost_to_serve_pool) x rule weight x this row\'s driver value / that driver\'s total for the month. Drivers: circuit_count, bandwidth_mbps, ticket_count (synthetic proxy, DEC-016), billed_revenue (billed_revenue_usd). Changing a rule weight changes this value on the next query, with no rebuild. Synonyms: CTS, allocated cost, overhead allocation, operating cost to serve.',
  expected_revenue_usd COMMENT 'Revenue the contract rate says should have been billed, US dollars. Expected minus revenue = revenue leakage. Synonyms: contracted revenue, should-bill.',
  carrier_rate_variance_usd COMMENT 'Carrier invoiced rate minus agreed vendor contract rate, US dollars; 0 on-net or with no carrier invoice. Positive = vendor overbilled. Synonyms: rate variance, overbilling.',
  circuit_count COMMENT 'Allocation driver: always 1 (one circuit per ledger row). Used by circuit_count rules. Synonyms: circuits.',
  bandwidth_mbps COMMENT 'Allocation driver: nominal circuit bandwidth in megabits per second (margin_circuits.bandwidth_mbps). Used by bandwidth_mbps rules.',
  ticket_count COMMENT 'Allocation driver: trouble tickets for the circuit in the month. Synthetic proxy for customer care tickets (DEC-016): deterministic, legacy avg 1.5 and strategic avg 0.25 per month, because the real ticket source has too few tickets in the ledger window. Drives the customer_care cost pool via ticket_count rules in margin_allocation_rules. Synonyms: tickets, trouble tickets, care tickets.',
  billed_revenue_usd COMMENT 'Allocation driver: billed revenue in US dollars, same value as revenue_usd. Used by billed_revenue rules.',
  allocation_rule_version COMMENT 'Rule-set version the stored baseline ledger was built with (MGN-ALR-v1). The live cost_to_serve_usd in this view always uses the CURRENT active weights in margin_allocation_rules, so it can differ from this baseline after a rule change.',
  origin COMMENT 'Data origin: MIXED (real Salesforce/TMF keys with synthetic amounts and drivers).',
  source_system COMMENT 'Build that produced the row: margin_truth_pipeline SDP gold margin_ledger_v2 (DEC-023 repoint; replaced the DEC-008 SQL fast path).')
COMMENT 'Lakelink Fiber margin ledger with LIVE cost-to-serve allocation. Grain: customer x product x circuit x contract x month (reads SDP gold margin_ledger_v2, same rows and columns as the margin_ledger fast path, STANDARDS v1.0). cost_to_serve_usd is recomputed at query time from margin_gl_actuals cost-to-serve pools and the active weights in margin_allocation_rules, so an allocation rule change flows to every answer immediately (demo scene 3). Source for metric view cdm_tmforum._metrics.margin_ledger_mv; for margin answers use that metric view (contribution margin is defined only there, DEC-002). Synonyms: allocated margin ledger, live ledger.'
TBLPROPERTIES ('telco_project' = 'margin_analysis')
WITH SCHEMA COMPENSATION
AS WITH active_rules AS (
  SELECT m.ledger_month, r.cost_pool, r.driver, r.weight
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
LEFT JOIN coef c ON c.ledger_month = l.ledger_month;
