-- Lakelink Fiber Margin Truth - CANONICAL checksum of margin_allocation_rules (COO-Q-20261114-49)
-- Owner: @data-engineer. Read-only. Answers: is the rules table at default weights?
--
-- Why this form: it sorts the row strings with array_sort, so the result does not depend on
-- physical row order. The old runbook (b2) form, collect_list over a subquery ORDER BY,
-- returns rows in file order (verified 2026-11-14: rows came back field_ops, noc, customer_care,
-- billing_ops). An UPDATE that rewrites the Delta file can change that order, so the old form
-- could report a false mismatch after a correct revert.
-- Each row string starts with rule_id (column 1), so a full-string sort equals rule_id order.
--
-- Default-weight value (8 rows, 2026-11-14): 6ce4db5c669a8ca287b4df7dffa5a32f
-- Retired, not comparable: b16ddece39b066c1bc51c0a3d13e27ca (file-order form),
--                          04a86a01dc107f47adeee27011f8b786 (note 1479 form).

SELECT md5(concat_ws('||', array_sort(collect_list(concat_ws('|', *))))) AS rules_checksum
FROM cdm_tmforum.revenue_assurance.margin_allocation_rules;

-- Direct weight read (always pair with the checksum):
-- expected billing_ops 0.5/0.5, customer_care ticket_count 0.70 / circuit_count 0.30,
-- field_ops 0.5/0.5, noc bandwidth_mbps 0.40 / circuit_count 0.60
SELECT rule_id, cost_pool, driver, weight
FROM cdm_tmforum.revenue_assurance.margin_allocation_rules
ORDER BY rule_id;
