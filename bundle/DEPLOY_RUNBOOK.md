# Lakelink Fiber Margin Truth: rehearsal deploy runbook

Owner: @devops. Task: DEVOPS-REHEARSAL-DEPLOY-RUNBOOK (gates P6-DAB-DEPLOY). Bundle root: this folder (`bundle/`).

Hard rules: the bundle deploys into EXISTING schemas only (`cdm_tmforum.revenue_assurance`, `cdm_tmforum._metrics`), and it declares no `schemas:` or `catalogs:` resources. It holds ONE dashboard, ONE app, and ONE pipeline. No secrets or tokens are kept in this repo. Lakelink Fiber branding only.

## 0. Preconditions (check every time)

* P6-DAB-DEPLOY dependencies completed on the Lakebase board: P3-DASHBOARD, P3-APP-SCAFFOLD, P1-SDP-PIPELINE. Do NOT run steps 3-4 until all three are done.
* `git status` is clean on `main`, and `HEAD` equals `origin/main`.
* Variables (defaults in `databricks.yml`): `catalog=cdm_tmforum`, `schema=revenue_assurance`, `metrics_schema=_metrics`, `project_tag=margin_analysis`, `warehouse_id` = lookup of warehouse `telco_cdm_model`.

## 1. Validate

```
cd bundle
databricks bundle validate --strict
databricks bundle validate --output json   # confirm .resources has no "schemas" key
```

Expected resources: apps 1, dashboards 1, pipelines 1, jobs 4 (functions, metric views, synth generator, stall monitor), schemas 0.

## 2. Live asset IDs (bind targets)

| Bundle key | Resource type | Live workspace ID |
| --- | --- | --- |
| `margin_scorecard` | dashboard | `01f1df1950c51bd68e87ace31632c2bf` (object 3728290263738094, "Lakelink Fiber Margin Truth") |
| `margin_app` | app | `lakelink-margin-truth` |
| `margin_pipeline` | pipeline | `20960984-a9d3-46f4-826a-6301155bc79a` ("Lakelink Fiber Margin Truth Pipeline") |
| Margin Genie | Genie space (not a bundle resource) | `01f1df115a08164aab3ae5f6faac807c`, config in `../genie/margin_genie_instructions.md` |

## 3. Bind live assets (ONE-asset cap). Do this BEFORE any deploy

A deploy without these binds would CREATE a second dashboard, app, and pipeline. That breaks the consolidation directive and DEC-009.

```
databricks bundle deployment bind margin_scorecard 01f1df1950c51bd68e87ace31632c2bf --auto-approve
databricks bundle deployment bind margin_app lakelink-margin-truth --auto-approve
databricks bundle deployment bind margin_pipeline 20960984-a9d3-46f4-826a-6301155bc79a --auto-approve
databricks bundle validate --strict
```

WARNING: the only target is `dev` (`mode: development`). Development mode prefixes names with `[dev <user>]` and pauses schedules. After a bind, a deploy RENAMES the live dashboard and pipeline and overwrites any UI edits made since the last commit. Before you bind, commit the latest dashboard JSON (`src/dashboards/Lakelink Fiber Margin Truth.lvdash.json`), and get CEO OK for the rename during rehearsal. If the CEO does not approve the rename, use step 5.

## 4. Full deploy (after step 3)

```
databricks bundle deploy
databricks bundle summary
```

After the deploy, run these checks:
* Exactly one dashboard, one app, and one pipeline for the project (log any change in Lakebase `asset_ledger`).
* `lakelink-margin-stall-monitor` schedule state: check the DEPLOYED job (the yml sets UNPAUSED explicitly).
* @qa reruns P2-MV-VALIDATION: `MEASURE(contribution_margin)` = 2,375,095,705.09 (DEC-020).

## 5. Jobs-only fallback: target `jobs_only` (DEFAULT plan for P6-DAB-DEPLOY; no bind, live assets untouched)

The dashboard, app, and pipeline are declared under `targets.dev.resources` in their resource files, so the `jobs_only` target contains ONLY the 4 jobs plus synced source. Nothing is bound, created, or `[dev]`-renamed. The Genie space is never a bundle resource. `jobs_only` has no `mode`, so job names have no prefix and schedules follow the job yml (the stall monitor is UNPAUSED).

```
databricks bundle validate --strict -t jobs_only
databricks bundle summary -t jobs_only      # expect Jobs: 4, no Apps/Dashboards/Pipelines
databricks bundle deploy -t jobs_only
```

Expected `jobs_only` resources: jobs 4 (lakelink-margin-functions, lakelink-margin-metric-views, lakelink-margin-synth-generator, lakelink-margin-stall-monitor), apps 0, dashboards 0, pipelines 0, schemas 0. `bundle destroy -t jobs_only` only removes those 4 jobs.

The synth generator and metric-view jobs run as a dry run by default. Running them with `--execute` OVERWRITES live demo tables, so rerun the cm_regression_harness after any execute run.

## 6. Rollback

* Bound resources: `databricks bundle deployment unbind <key>` keeps the live asset and removes bundle management.
* Never run `bundle destroy` on a bound target: it would delete the ONE dashboard, app, and pipeline.
