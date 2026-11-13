-- Lakelink Fiber Margin Truth - UC function margin_compare_rates (P4-UC-FN-RATE-COMPARE, @ml-engineer, 2026-11-13)
-- Deployed to cdm_tmforum.revenue_assurance. Tag telco_project=margin_analysis rejected by governed tag policy; recorded in COMMENT.
-- Known answers (2026-11-13): NULL -> 17,427 rows, 209,124 lines, 4,504 overbilled lines, rate_variance 1,694,614.90, paid 959,602,431.58;
--   circuit 45040 -> 12 months, 6 overbilled, variance 1,280.04; vendor 00100000000265pAAA -> 621 circuits, 597,884.80.
CREATE OR REPLACE FUNCTION cdm_tmforum.revenue_assurance.margin_compare_rates(p_vendor_id STRING)
RETURNS TABLE (
  vendor_id STRING COMMENT 'Third-party carrier (Salesforce partner_account Id).',
  vendor_name STRING COMMENT 'Fictional carrier name.',
  circuit_id BIGINT COMMENT 'Off-net circuit the carrier invoiced.',
  months_invoiced INT COMMENT 'Number of invoice months on file.',
  overbilled_months INT COMMENT 'Months where invoiced rate > vendor contract rate.',
  contract_total_usd DECIMAL(18,2) COMMENT 'Sum of agreed monthly contract rates, USD.',
  invoiced_total_usd DECIMAL(18,2) COMMENT 'Sum of invoiced monthly rates, USD.',
  paid_total_usd DECIMAL(18,2) COMMENT 'Sum of amounts paid, USD.',
  rate_variance_usd DECIMAL(18,2) COMMENT 'Invoiced minus contract, USD. Positive = vendor overbilled.',
  overpaid_usd DECIMAL(18,2) COMMENT 'Paid minus contract, USD. Positive = dispute candidate.',
  latest_contract_rate_usd DECIMAL(18,2) COMMENT 'Contract rate in the latest invoice month, USD.',
  latest_invoiced_rate_usd DECIMAL(18,2) COMMENT 'Invoiced rate in the latest invoice month, USD.')
COMMENT 'Lakelink Fiber rate audit: compares contract vs invoiced vs paid carrier rates per vendor x off-net circuit over all invoice months in margin_carrier_invoices. p_vendor_id NULL = all vendors. Filter rate_variance_usd > 0 for dispute candidates. telco_project=margin_analysis (P4-UC-FN-RATE-COMPARE, @ml-engineer).'
RETURN
  WITH ci AS (
    SELECT c.*, ROW_NUMBER() OVER (PARTITION BY c.vendor_id, c.circuit_id ORDER BY c.invoice_month DESC) AS rn
    FROM cdm_tmforum.revenue_assurance.margin_carrier_invoices c
    WHERE p_vendor_id IS NULL OR c.vendor_id = p_vendor_id)
  SELECT ci.vendor_id, MAX(v.vendor_name), ci.circuit_id,
         CAST(COUNT(1) AS INT), CAST(COUNT_IF(ci.invoiced_rate_usd > ci.vendor_contract_rate_usd) AS INT),
         CAST(SUM(ci.vendor_contract_rate_usd) AS DECIMAL(18,2)), CAST(SUM(ci.invoiced_rate_usd) AS DECIMAL(18,2)),
         CAST(SUM(ci.paid_amount_usd) AS DECIMAL(18,2)),
         CAST(SUM(ci.invoiced_rate_usd - ci.vendor_contract_rate_usd) AS DECIMAL(18,2)),
         CAST(SUM(ci.paid_amount_usd - ci.vendor_contract_rate_usd) AS DECIMAL(18,2)),
         CAST(MAX(CASE WHEN ci.rn = 1 THEN ci.vendor_contract_rate_usd END) AS DECIMAL(18,2)),
         CAST(MAX(CASE WHEN ci.rn = 1 THEN ci.invoiced_rate_usd END) AS DECIMAL(18,2))
  FROM ci LEFT JOIN cdm_tmforum.revenue_assurance.margin_vendors v ON v.vendor_id = ci.vendor_id
  GROUP BY ci.vendor_id, ci.circuit_id;
