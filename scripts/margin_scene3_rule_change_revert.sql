-- Lakelink Fiber Margin Truth - Scene 3 live allocation rule change + revert
-- Owner: @data-engineer (COO-Q-20261117-67, DEC-027). telco_project = margin_analysis
-- GATE: DEC-112 change control. Run the UPDATE steps ONLY under a numbered @pm DEC naming
--       cdm_tmforum.revenue_assurance.margin_allocation_rules, or a direct CEO instruction.
-- Path: margin_allocation_rules -> VIEW margin_ledger_allocated (reads rules live in CTE active_rules)
--       -> metric view cdm_tmforum._metrics.margin_ledger_mv. NO pipeline update is involved
--       (pipeline 20960984 only builds margin_ledger_v2; ccea7e91 is not in the path).

-- 0. PRE-CHECK (read-only): expect 2,375,095,705.09 and rules md5 cb6aea0bd90855b35993f9a15d9bdd1a
SELECT MEASURE(contribution_margin) AS cm FROM cdm_tmforum._metrics.margin_ledger_mv;
SELECT md5(concat_ws('|', collect_list(concat_ws(',', rule_id, CAST(weight AS STRING), CAST(is_active AS STRING)))))
FROM (SELECT * FROM cdm_tmforum.revenue_assurance.margin_allocation_rules ORDER BY rule_id);

-- 1. CHANGE (gated DML): customer_care / ticket_count 0.70 -> 0.90
UPDATE cdm_tmforum.revenue_assurance.margin_allocation_rules
SET weight = 0.90
WHERE rule_id = 'MGN-ALR-customer_care-ticket_count-v1' AND weight = 0.70;

-- 2. ASK AGAIN: expect 2,360,713,702.39 (delta -14,382,002.70)
SELECT MEASURE(contribution_margin) AS cm FROM cdm_tmforum._metrics.margin_ledger_mv;

-- 3. REVERT (gated DML)
UPDATE cdm_tmforum.revenue_assurance.margin_allocation_rules
SET weight = 0.70
WHERE rule_id = 'MGN-ALR-customer_care-ticket_count-v1' AND weight = 0.90;

-- 4. POST-CHECK: expect 2,375,095,705.09 over 517,032 rows and the same md5 as step 0
SELECT MEASURE(contribution_margin) AS cm FROM cdm_tmforum._metrics.margin_ledger_mv;
SELECT COUNT(*) AS n,
       ROUND(SUM(revenue_usd) - SUM(network_expense_usd) - SUM(cost_to_serve_usd), 2) AS raw_cm
FROM cdm_tmforum.revenue_assurance.margin_ledger_allocated;

-- READ-ONLY SIMULATION (no UC writes; used for evidence 2026-11-17):
-- CREATE OR REPLACE TEMP VIEW s3_rules AS SELECT rule_id, cost_pool, driver,
--   CASE WHEN rule_id='MGN-ALR-customer_care-ticket_count-v1' THEN CAST(0.90 AS DECIMAL(9,6)) ELSE weight END AS weight,
--   effective_from, effective_to, is_active FROM cdm_tmforum.revenue_assurance.margin_allocation_rules;
-- then run the margin_ledger_allocated view_definition (information_schema.views) with the rules table
-- swapped for s3_rules and compute raw CM as in step 4.
