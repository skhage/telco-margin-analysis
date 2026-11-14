# Lakelink Fiber Margin Truth — Post-Demo Retire List

**Owner:** @repo-pruner · **Task:** RP-PREFREEZE-SWEEP · **Published:** 2026-11-14
**Applies:** after the 2026-11-19 demo. Nothing below may be removed during the freeze (2026-11-16 00:00 UTC to Nov 19, see `resources/REHEARSAL_FREEZE_LIST.md`). Never delete UC data or Lakebase data. Log each removal in Lakebase `asset_ledger` and file a @devops git-rm task.

## Pre-freeze sweep result (2026-11-14 ~01:55 UTC)

* Files: 68 (os.walk 67, including MLflow experiment `agents/margin_grooming_agent_traces`, plus the Genie dataRoom). Target is under 200.
* Stale logs or scratch files: 0. md5 duplicates: 0. Empty folders: `dashboards/` only (kept, P5-QA-BENCHMARK-REGRESSION lints over it).
* Removed before the freeze: none. Every candidate below is still referenced by the bundle, a source file, or an open task.

## Retire after Nov 19

| # | Asset | Why superseded | Still referenced by (2026-11-14) | Retire condition |
| --- | --- | --- | --- | --- |
| 1 | Notebook `pipeline/margin_truth_pipeline` (1551722662311991) | Replaced by `pipeline/margin_truth_pipeline.sql`, the only library of live pipeline 20960984 | Only library of stale pipeline `ccea7e91-e657-4168-82fe-588f4e6437d5` (IDLE); tasks RP-REMOVE-SUPERSEDED-PIPELINE-NB, DE-DELETE-STALE-PIPELINE; CEO_ACTION_SHEET.md | Pipeline ccea7e91 deleted (PM-STALE-PIPELINE-FALLBACK / DE-DELETE-STALE-PIPELINE). Ledger: notebook removed + paired pipeline removed row (asset_path = bare id). |
| 2 | Pipeline `ccea7e91-e657-4168-82fe-588f4e6437d5` (workspace object, not a file) | Duplicate of live pipeline 20960984; 0 edges into the MV chain | Many open @pm / @data-engineer tasks | Owned by @pm / @data-engineer, not @repo-pruner. |
| 3 | `src/dashboards/margin_truth_skeleton.json` | Replaced by `src/dashboards/Lakelink Fiber Margin Truth.lvdash.json` | `bundle/resources/margin_scorecard.dashboard.yml` | Bundle reference removed first (@devops), then retire. |
| 4 | `data/margin_ledger_fastpath.sql` | Fast-path ledger build, superseded by the SDP pipeline | `src/data/margin_synth_generator.py` | Generator reference removed first (@data-engineer), then retire. |
| 5 | `src/metric_views/margin_rate_variance_mv.yaml` | No deployed `margin_rate_variance_mv` in `cdm_tmforum._metrics` (5 margin_ MVs deployed on 2026-11-14) | `bundle/resources/margin_metric_views.job.yml`, `deploy_metric_views.py`, STANDARDS.md, glossary_pages.json, skeleton json; tasks DA-RATE-VARIANCE-MV-DEPLOY, DP-RATE-VARIANCE-PAGE-CERTIFY, QA-VERIFY-DOMAIN-CURATION-R84 | Only if @pm descopes rate-audit. Otherwise it gets deployed and stays. |
| 6 | v1.2 additions in `src/metric_views/margin_ledger_mv.yaml` (6 fields, not deployed) | DEC-028 freezes the v1.1 MV for the demo | Hero-path MV source (frozen) | Not a file removal. After Nov 19 @data-analyst either deploys v1.2 or reverts the YAML to v1.1. |

## Discrepancy to check

* `resources/CEO_ACTION_SHEET.md` line 52 refers to a rollback file `margin_ledger_mv_v1_1_rollback.yaml`. No file with that name is in the project folder (2026-11-14 inventory). It could live in a UC volume. Check this before anyone relies on it for rollback.

## Keep (never retire)

* `resources/projectplan.md`, `.assistant_instructions.md`, `dashboards/` (empty), and every hero-path asset in `REHEARSAL_FREEZE_LIST.md`.
