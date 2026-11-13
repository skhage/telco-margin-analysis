# Lakelink Fiber Margin Truth: rehearsal deploy runbook

Owner: @devops. Task: DEVOPS-REHEARSAL-DEPLOY-RUNBOOK (gates P6-DAB-DEPLOY). Bundle root: this folder (`bundle/`).

Hard rules: the bundle deploys into EXISTING schemas only (`cdm_tmforum.revenue_assurance`, `cdm_tmforum._metrics`), and it declares no `schemas:` or `catalogs:` resources. It holds ONE dashboard, ONE app, and ONE pipeline. No secrets or tokens are kept in this repo. Lakelink Fiber branding only.

## 0. Preconditions (check every time)

* P6-DAB-DEPLOY dependencies completed on the Lakebase board: P3-DASHBOARD, P1-SDP-PIPELINE (P3-APP-SCAFFOLD dropped by @pm 2026-11-13 run #6). Steps 3-4 additionally need CEO OK (see section 7).
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

WARNING: target `dev` (`mode: development`, the default target) is the only target that declares the live dashboard, app, and pipeline. Development mode prefixes names with `[dev <user>]` and pauses schedules. After a bind, a deploy RENAMES the live dashboard and pipeline and overwrites any UI edits made since the last commit. Before you bind, commit the latest dashboard JSON (`src/dashboards/Lakelink Fiber Margin Truth.lvdash.json`), and get CEO OK for the rename during rehearsal. If the CEO does not approve the rename, use step 5.

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

## 7. Does a dev deploy create a SECOND app, dashboard, or pipeline? (COO-Q-20261113-31)

Evidence from @devops, 2026-11-13. `bundle validate --strict` passes for both `-t dev` and `-t jobs_only`.

(a) Resolved names from `databricks bundle summary` (state: nothing deployed):

| Key | dev (mode development) | jobs_only |
| --- | --- | --- |
| margin_app | `lakelink-margin-truth` (apps get no prefix) | not declared |
| margin_scorecard | `[dev stephen_hage] Lakelink Fiber Margin Truth` | not declared |
| margin_pipeline | `[dev stephen_hage] Lakelink Fiber Margin Truth Pipeline` | not declared |
| 4 jobs | `[dev stephen_hage] lakelink-margin-*` (schedules paused) | `lakelink-margin-functions`, `-metric-views`, `-stall-monitor`, `-synth-generator` |

(b) Bind state: NOTHING is bound. Both targets show `URL: (not deployed)` for every key. The workspace state folders `~/.bundle/telco_margin_analysis/{dev,jobs_only}` contain no state files. No `lakelink-margin-*` jobs exist yet.

If someone ran `bundle deploy -t dev` in THIS workspace today, the result would be:
* Dashboard: a SECOND dashboard, `[dev stephen_hage] Lakelink Fiber Margin Truth`, created next to `01f1df1950c51bd68e87ace31632c2bf`. This breaks the cap.
* Pipeline: a SECOND pipeline, `[dev stephen_hage] ... Pipeline`, created next to `20960984-...`. This breaks the cap.
* App: same name as the live `lakelink-margin-truth` (apps get no dev prefix). Expected: the create conflicts with the existing app (not exercised; no deploy was run). Treat as unsafe.

The dev target is therefore BLOCKED in this workspace unless step 3 (bind all three first) runs with CEO OK.

(c) Command to run:
* In THIS (demo) workspace: `databricks bundle deploy -t jobs_only`. It yields 4 jobs and 0 apps, dashboards, or pipelines. The ONE app, ONE dashboard, and ONE pipeline stay the live originals, so the count of each is exactly 1.
* In the customer's FRESH dev workspace (leave-behind): from `bundle/`, run `databricks bundle validate --strict -t dev` and then `databricks bundle deploy -t dev`. With no pre-existing assets, this creates exactly 1 app, 1 dashboard, 1 pipeline, and 4 jobs, as shown in the summary table above. Genie is recreated from `../genie/margin_genie_instructions.md`, because it is not a bundle resource. Run the section 8 Genie guard first.

(d) asset_ledger: nothing has been deployed, so there are no rows yet. Any future deploy logs one row per created job.

## 8. Genie space guard: check by title BEFORE creating a Margin Genie (COO-Q-20261113-78 part 2)

The Genie space is not a bundle resource, so no bind protects it. Run this check before any step that creates a Genie space (fresh-workspace leave-behind in 7(c), or a rebuild after a redeploy). It keeps the count at exactly ONE Margin Genie.

1. List ALL Genie spaces by title, every page (the list is paginated; this workspace had 409 spaces on 2026-11-13):

```
databricks api get /api/2.0/genie/spaces                                  # first page
databricks api get "/api/2.0/genie/spaces?page_token=<NEXT_PAGE_TOKEN>"   # repeat until next_page_token is empty
```

2. Search every page for the title `Lakelink Fiber Margin Genie` (exact match on `title`).
3. If a space with that title exists, SKIP creation. Reuse its `space_id` (demo workspace: `01f1df115a08164aab3ae5f6faac807c`) and update its instructions from `../genie/margin_genie_instructions.md` in place if needed.
4. Only if no page has that title, create ONE space titled `Lakelink Fiber Margin Genie` from `../genie/margin_genie_instructions.md`, then log it in Lakebase `asset_ledger` (asset_type `genie_space`, action `created`).
5. After the step, list again (all pages) and confirm that exactly one space has that title. If there are two, stop and escalate to @pm. Do not delete a space without CEO OK.
