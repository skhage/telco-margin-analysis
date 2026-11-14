-- Lakelink Fiber - Margin Truth (telco_project=margin_analysis)
-- P4-UC-FN-ONNET-SCORE DRAFT. Not deployed yet: waits on margin_circuits and margin_carrier_invoices
-- (P1-SYNTH-CONTRACTS-CIRCUITS, DE-REQ-ONNET-SCORE-FIELDS, P1-SYNTH-BILLING-CARRIER-GL).
-- Columns follow src/semantics/STANDARDS.md v1.0 (circuit_id BIGINT, *_usd money, is_* booleans).
-- Schema: existing cdm_tmforum.revenue_assurance only (no new schemas, directive 1).
-- monthly_offnet_cost_usd = paid_amount_usd for the latest carrier invoice month of the circuit.
-- est_monthly_savings_usd = monthly_offnet_cost_usd minus the on-net carry cost proxy
--   (USD 2.00 per Mbps per month + USD 0.50 per metre to nearest Lakelink fiber, amortised over 36 months).
-- Not contribution margin: CM stays in cdm_tmforum._metrics.margin_ledger_mv (DEC-002).

-- 2026-11-14 ML-FN-PARAM-COMMENTS: param COMMENT added, body unchanged (regression 47 / 34,378.33 per month = 412,539.96 per year before and after).
CREATE OR REPLACE FUNCTION cdm_tmforum.revenue_assurance.margin_score_onnet_move(p_circuit_id BIGINT COMMENT 'Lakelink Fiber off-net circuit_id to score (margin_circuits.circuit_id). NULL scores all off-net circuits.')
RETURNS TABLE (
  circuit_id BIGINT,
  vendor_id STRING,
  is_parallel_to_onnet_fiber BOOLEAN,
  onnet_distance_m DECIMAL(12,2),
  monthly_offnet_cost_usd DECIMAL(18,2),
  est_monthly_savings_usd DECIMAL(18,2),
  score INT
)
COMMENT 'Lakelink Fiber Margin Truth: scores off-net circuits for a move onto Lakelink Fiber. Pass NULL to score all off-net circuits. Returns monthly off-net cost (latest carrier invoice paid amount, USD) and estimated monthly savings (USD). Tool for the off-net grooming agent. telco_project=margin_analysis'
RETURN
  WITH latest AS (
    SELECT ci.circuit_id, ci.vendor_id, ci.paid_amount_usd,
           ROW_NUMBER() OVER (PARTITION BY ci.circuit_id ORDER BY ci.invoice_month DESC) AS rn
    FROM cdm_tmforum.revenue_assurance.margin_carrier_invoices ci
  ),
  base AS (
    SELECT c.circuit_id, c.vendor_id, c.is_parallel_to_onnet_fiber, c.onnet_distance_m,
           CAST(l.paid_amount_usd AS DECIMAL(18,2)) AS monthly_offnet_cost_usd,
           CAST(l.paid_amount_usd
                - (2.00 * COALESCE(c.bandwidth_mbps, 0) + 0.50 * COALESCE(c.onnet_distance_m, 0) / 36)
                AS DECIMAL(18,2)) AS est_monthly_savings_usd
    FROM cdm_tmforum.revenue_assurance.margin_circuits c
    JOIN latest l ON l.circuit_id = c.circuit_id AND l.rn = 1
    WHERE c.is_on_net = FALSE
      AND (p_circuit_id IS NULL OR c.circuit_id = p_circuit_id)
  )
  SELECT circuit_id, vendor_id, is_parallel_to_onnet_fiber, onnet_distance_m,
         monthly_offnet_cost_usd, est_monthly_savings_usd,
         CAST(LEAST(100, GREATEST(0,
              CASE WHEN is_parallel_to_onnet_fiber THEN 50 ELSE 0 END
              + CASE WHEN monthly_offnet_cost_usd > 0
                     THEN 50 * GREATEST(est_monthly_savings_usd, 0) / monthly_offnet_cost_usd ELSE 0 END)) AS INT) AS score
  FROM base
