# Lakelink Fiber Margin Truth — Rehearsal Freeze List

**Owner:** @repo-pruner · **Task:** RP-REHEARSAL-FREEZE-LIST · **Published:** 2026-11-13
**Freeze window:** 2026-11-16 00:00 UTC through the 2026-11-19 demo. Applies to ALL agents.
**Rule:** Do not move, rename, delete, or recreate any asset below during the freeze. Edits needed to fix a P0 demo bug must go through @pm and be logged in `asset_ledger`.

## Hero-path assets (frozen)

| Asset | Identifier / path | Scenes |
| --- | --- | --- |
| Databricks App | `lakelink-margin-truth` (source `apps/margin-truth/`, bundle `bundle/resources/margin_app.app.yml`) | 5, 6 |
| AI/BI dashboard | `01f1df1950c51bd68e87ace31632c2bf` (`src/dashboards/Lakelink Fiber Margin Truth.lvdash.json`, bundle `margin_scorecard.dashboard.yml`) | 1, 7 |
| Margin Genie agent | `01f1df115a08164aab3ae5f6faac807c` (`genie/Lakelink Fiber Margin Genie.geniespace.json`, `genie/margin_genie_instructions.md`) | 1, 4 |
| SDP pipeline (live) | `20960984-a9d3-46f4-826a-6301155bc79a` — library `pipeline/margin_truth_pipeline.sql` | 2 |
| Metric view | `cdm_tmforum._metrics.margin_ledger_mv` (contribution margin, DEC-002) | 1, 3 |
| Metric view | `cdm_tmforum._metrics.margin_offnet_spend_mv` | 5 |
| Metric view | `cdm_tmforum._metrics.margin_onebillion_wall_mv` | 7 |
| Metric view | `cdm_tmforum._metrics.margin_renewal_floor_mv` | 4 |
| Metric view | `cdm_tmforum._metrics.margin_segment_growth_mv` | 4 |
| Metric view sources | `src/metric_views/*.yaml`, `src/metric_views/deploy_metric_views.py` | 3 |
| UC function | `cdm_tmforum.revenue_assurance.margin_score_onnet_move` (`agents/margin_score_onnet_move.sql`) | 5 |
| UC function | `cdm_tmforum.revenue_assurance.margin_compare_rates` (`agents/margin_compare_rates.sql`) | 5 |
| Grooming agent | `agents/margin_grooming_agent.py`, `agents/margin_grooming_agent_tools.py`, `agents/gateway_sp_tracing_setup.py` | 5, 6 |
| MLflow experiment | `agents/margin_grooming_agent_traces` (id 1235449331932066) | 6 |
| Glossary domain | `2abc9194-aed9-4088-bfa6-4b4d33870ebd` (+ pages in `src/semantics/glossary_pages.json`) | 3, 4 |
| Bundle | `bundle/` (databricks.yml, resources/*.yml, DEPLOY_RUNBOOK.md), tag `rehearsal-2026-11-17-rc2` (main 267608c; supersedes rc1 cef1fe7) | all |
| CEO action sheet | `resources/CEO_ACTION_SHEET.md` | all |
| Runbooks | `resources/scene3_live_allocation_runbook.md`, `apps/margin-truth/REDEPLOY.md`, `apps/margin-truth/SCENE5_CLICK_SCRIPT.md`, `bundle/DEPLOY_RUNBOOK.md` | 3, 5 |
| Regression / reconciliation | `tests/` (cm_baseline_expected.sql, cm_regression_harness.py, cm_cross_surface_reconciliation.sql, stall_*) | QA |
| Ledger / DQ SQL | `scripts/margin_repoint_allocated_v2.sql`, `scripts/margin_dq_gl_tieout.sql` (view `margin_dq_gl_tieout`) | 2, 3 |
| Synthetic data | `data/margin_synth_*.sql`, `src/data/margin_synth_generator.py`, `scripts/margin_generate_pdfs.py` | 2 |
| Project plan + instructions | `resources/projectplan.md`, `.assistant_instructions.md` (never delete) | — |

Note (RP-FREEZE-LIST-VERIFY-R12, 2026-11-13): the Genie space and the MLflow experiment are workspace objects with no git copy; verify them by id, not on git main.

## Review after Nov 19 (do NOT delete before then)

* `src/dashboards/margin_truth_skeleton.json` — superseded candidate (replaced by the live `.lvdash.json`).
* `data/margin_ledger_fastpath.sql` — superseded candidate (fast-path ledger build).
* `pipeline/margin_truth_pipeline` notebook (1551722662311991) — superseded by `margin_truth_pipeline.sql`. It is still the only library of the stale pipeline `ccea7e91-e657-4168-82fe-588f4e6437d5` (IDLE, not in demo). Remove it only after that pipeline is deleted (RP-REMOVE-SUPERSEDED-PIPELINE-NB, depends on DE-DELETE-STALE-PIPELINE).
* `src/metric_views/margin_rate_variance_mv.yaml` — YAML exists, but no deployed `margin_rate_variance_mv` was found in `cdm_tmforum._metrics` on 2026-11-13. It belongs to the rate-audit scope, which can be descoped.
* Top-level `dashboards/` (empty) — keep. P5-QA-BENCHMARK-REGRESSION lints over it.
