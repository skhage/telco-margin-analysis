# Genie One Discovery Proposal: Margin Truth (Lakelink Fiber)

Owner: @data-planner. Task: DP-GENIE-ONE-DISCOVERY-FIX (2026-11-14). Status: PROPOSAL ONLY. `/Workspace/.genie_workspace_instructions.md` was NOT edited; changing it needs CEO approval.

## Problem (note 1553)
Unified search for the CM question ranked 3 `customerlake_cost_to_serve*` objects (another project, `cdm_tmforum._metrics`) above every Margin Truth asset. `margin_ledger_mv` was not returned at all, so Genie One could pick the wrong cost-to-serve asset.

## What changed this run (metadata only, no schema or definition change)
* `COMMENT ON TABLE cdm_tmforum._metrics.margin_ledger_mv`: the comment now leads with "Contribution margin and cost to serve for Lakelink Fiber (Margin Truth)", quotes the demo question, and names Margin Genie, the dashboard, and the app as readers. Synonyms added: contribution margin, product margin, circuit margin, money-losing products.
* Verified: only the top-level YAML `comment` changed. `version`, `source`, `dimensions`, and `measures` are identical. `MEASURE(contribution_margin)` = 2,375,095,705.09, which is the DEC-020 canonical value.
* customerlake assets were not touched.

## Search rank, before and after (same searchAssets query: "Which products and circuits lose money after cost to serve? contribution margin")

| Asset | Before | After |
| --- | --- | --- |
| margin_ledger_mv | not returned (0 of 69) | #2 of 71 |
| customerlake_cost_to_serve / _mv / _cached | #2, #3, #4 | #3, #4, #5 |
| Lakelink Fiber Margin Truth dashboard | #36 of 69 | #37 of 71 |
| Margin Genie 01f1df115a08 | not returned | not returned |

tableSearch with the same question: margin_ledger_mv was #1 before and #2 after (customerlake_cost_to_serve #1). The workspace semantic search ranking varies between runs.

## Domain curation (verified)
* margin_ledger_mv: UC tags lakelink_margin=Finance, lakelink_margin/Finance=true, system.certification_status=certified, TBLPROPERTIES telco_project=margin_analysis.
* Dashboard 01f1df1950c51bd68e87ace31632c2bf and Genie 01f1df115a08164aab3ae5f6faac807c: entity tag lakelink_margin=Finance (domain 2abc9194).

## Proposed Genie One workspace-instruction lines (CEO approval required)
1. "For Lakelink Fiber contribution margin, cost to serve, product or circuit profitability, and margin floor questions, use cdm_tmforum._metrics.margin_ledger_mv (MEASURE(contribution_margin)) or the Margin Genie agent. The customerlake_* objects are about CustomerLake marketing platform cost, not network or product margin."
2. "Off-net grooming: margin_offnet_spend_mv. Renewals below the margin floor: margin_renewal_floor_mv (as-of DATE'2026-11-19'). Segments with room to grow: margin_segment_growth_mv. $1B Wall: margin_onebillion_wall_mv."
3. "Show contribution margin to the cent (2 dp, USD)."

## Follow-ups (not done this run)
* Dashboard rank did not move (#36 -> #37). @data-analyst to check whether the Lakelink Fiber Margin Truth dashboard has a business-language description and add one before the Nov 16 freeze (not verified this run).
* @devops to compare the repo YAML `comment` for margin_ledger_mv with the live comment and sync it if they differ, so that a redeploy does not revert it (repo copy not inspected this run).
