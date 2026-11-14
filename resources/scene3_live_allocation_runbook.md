# Scene 3 live allocation runbook (DRAFT) - Lakelink Fiber Margin Truth

Owner: @data-analyst. Task: COO-Q-20261112-7. Status: DRAFT, 2026-11-12. Not yet executable: margin_ledger, margin_allocation_rules, margin_gl_actuals and margin_ledger_mv do not exist yet.

## (a) Dependency path: rules -> ledger -> metric view

Problem: STANDARDS.md v1.0 stores `cost_to_serve_usd` as a column in the gold table `margin_ledger`. If that table is materialized, an UPDATE to `margin_allocation_rules.weight` does not change `MEASURE(contribution_margin)` until the ledger is rebuilt. Scene 3 would then need a live rebuild on stage.

Recommended plumbing (query-time allocation, no refresh step):

1. `margin_ledger` (gold table, fast path or SDP) keeps revenue, network expense and the allocation DRIVER columns per row: `circuit_count` (1), `bandwidth_mbps`, `ticket_count`, `revenue_usd`.
2. Cost pool amounts per month come from `margin_gl_actuals` (account_class = cost_to_serve_pool, by cost_pool).
3. A UC view `cdm_tmforum.revenue_assurance.margin_ledger_allocated` joins each ledger row to the ACTIVE rules and computes
   `cost_to_serve_usd = SUM over (cost_pool, driver) of pool_amount(month, pool) * weight * row_driver / SUM(driver over the month)`.
4. `margin_ledger_mv` uses `source: cdm_tmforum.revenue_assurance.margin_ledger_allocated`. Contribution margin is still defined only in the metric view (DEC-002). Cost to serve is defined only in the allocated view.

Result: a weight change is visible on the next query. No refresh command is needed.

Fallback if the ledger must stay fully materialized: the refresh command is the fast-path rebuild (INSERT OVERWRITE margin_ledger ...) or an SDP update of lakelink_margin_truth_sdp. Measure its duration before choosing this path. Not measured yet because the ledger does not exist.

### Prototype evidence (2026-11-12)

The allocation SQL ran on the real `margin_circuits` table (43,086 circuits, all joined to contracts and products, 0 NULL bandwidth). It used one TEST pool `field_ops` = 1,000,000 USD (placeholder, not data) with drivers circuit_count and bandwidth_mbps.

| Product family | CTS at weight cc=0.5 / bw=0.5 | CTS at weight cc=0.8 / bw=0.2 |
| --- | --- | --- |
| Colocation | 67,286.10 | 102,697.76 |
| Dedicated Internet | 168,720.53 | 216,464.68 |
| Ethernet | 65,654.02 | 100,206.74 |
| IP-VPN | 62,281.23 | 99,163.99 |
| Legacy Voice | 2,088.92 | 3,342.18 |
| Managed | 63,637.48 | 99,400.13 |
| Wavelength | 570,331.72 | 378,724.53 |

* Query time: 1.22 s and 1.17 s on serverless.
* The pool is conserved: totals are 1,000,000.00 and 1,000,000.01 (rounding).
* An independent pandas recomputation matched every family to the cent.
* Takeaway: raising the circuit_count weight increases allocated cost for per-circuit families and reduces it for bandwidth-heavy families (Wavelength). Use this to tune the demo rule.

## (b) Live-demo runbook (fill in once the tables exist)

1. Before: run the reference SQL (tests/cm_cross_surface_reconciliation.sql). Record CM by product_family. Screenshot it.
2. The rule: `UPDATE cdm_tmforum.revenue_assurance.margin_allocation_rules SET weight = <new> WHERE rule_id IN (<pair in one cost_pool>)`. The pool's weights must still sum to 1. Candidate: the field_ops pool, circuit_count 0.5 -> 0.8 and bandwidth_mbps 0.5 -> 0.2. Confirm the final rule after P1-ALLOCATION-RULES lands. Choose a weight that makes Legacy Voice / IP-VPN CM visibly worse.
3. Expected CM delta per family = -(CTS_new - CTS_old). Precompute it with the reference SQL and print it on a cue card.
4. Confirm within 60 s (no refresh step, because the allocation runs at query time):
   * Genie: ask the Finance starter question again. Check that the generated SQL uses MEASURE(contribution_margin) FROM _metrics.margin_ledger_mv.
   * Dashboard: refresh the CFO scorecard page. Datasets read only the metric views, and no dataset cache is pinned.
   * App: reload the margin explorer tab (it queries the metric view through the SQL warehouse).
   * Agent: the grooming agent calls Margin Genie, so it reflects the change on its next call.
5. Reset: put the original weights back and re-run step 1 to confirm the numbers match the baseline.

## (b2) Canonical scene-3 statements (DEC-027) - verified read-only 2026-11-14 by @data-engineer (DE-S3-READONLY-PRECHECK)

This section supersedes the field_ops candidate in (b) step 2. Run each statement in its own call. Run the change as the CEO (stephen.hage@databricks.com), interactively. Scheduled runs are blocked by the Auto Mode DML guardrail.

Before: `margin_allocation_rules` has 8 rows. md5 checksum = `b16ddece39b066c1bc51c0a3d13e27ca`. customer_care/ticket_count = 0.700000 and customer_care/circuit_count = 0.300000. `MEASURE(contribution_margin)` from `cdm_tmforum._metrics.margin_ledger_mv` = 2,375,095,705.09.

Change:

    UPDATE cdm_tmforum.revenue_assurance.margin_allocation_rules SET weight = 0.900000 WHERE rule_id = 'MGN-ALR-customer_care-ticket_count-v1';

Expected CM after the change: 2,360,713,702.39, a delta of -14,382,002.70. Cost to serve goes from 360,273,982.31 to 374,655,985.01.

Revert:

    UPDATE cdm_tmforum.revenue_assurance.margin_allocation_rules SET weight = 0.700000 WHERE rule_id = 'MGN-ALR-customer_care-ticket_count-v1';

Expected CM after the revert: 2,375,095,705.09, to the cent. The checksum must be `b16ddece39b066c1bc51c0a3d13e27ca` again.

Checksum SQL:

    SELECT md5(concat_ws('||', collect_list(r))) FROM (SELECT concat_ws('|', *) r FROM cdm_tmforum.revenue_assurance.margin_allocation_rules ORDER BY rule_id)

Note for the talk track: this change does not conserve the pool. The customer_care weights sum to 1.20 after the change, so allocated care cost rises by 20% of the 71,910,000.00 customer_care pool (14,382,000.00 plus 2.70 of per-row rounding). Present it as "Finance raises the care-cost weight", not as moving the same cost between drivers. A pool-conserving variant (ticket 0.90 and circuit 0.10) moves CM by only -26.06, which is too small to show on stage.

## (c) MV depth - pending deployment
Counts of comment, display_name, format and synonyms must be read from the DEPLOYED view, not from the YAML. Status 2026-11-12: 0 margin_ objects in cdm_tmforum._metrics. Suite MVs (offnet_spend, renewal_floor, segment_growth): not deployed. They are blocked on P2-MV-MARGIN-LEDGER, which waits on P1-LEDGER-GOLD-FASTPATH.

## (d) Genie One object choice - pending
Plan: certify margin_ledger_mv. Give the raw margin_ledger table a comment that says: use margin_ledger_mv for margin. Curate only the MVs in the Margin domain. Proposed Genie One workspace-instruction text goes in resources/ for CEO approval. Verify this with the generated SQL once the MV is deployed.
