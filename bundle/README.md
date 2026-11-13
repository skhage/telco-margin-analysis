# Lakelink Fiber Margin Truth: Declarative Automation Bundle

This bundle deploys the Margin Truth demo into a dev workspace using **existing** schemas only.

| Variable | Default | Used for |
| --- | --- | --- |
| `catalog` | `cdm_tmforum` | All project assets |
| `schema` | `revenue_assurance` | `margin_` tables, UC functions, `margin_documents` volume, SDP target |
| `metrics_schema` | `_metrics` | `margin_` metric views |
| `project_tag` | `margin_analysis` | `telco_project` tag |

## Rules
* No `schemas:` or `catalogs:` resources. The bundle never creates a schema.
* Lakelink Fiber branding only.
* No secrets or tokens in any file. Use secret scopes or app resources.

## Planned resources (P6-DAB-DEPLOY)
Each goes in `resources/<name>.<resource_type>.yml` once its source asset exists:
* `margin_pipeline.pipeline.yml`: the one SDP pipeline (source under `../pipeline/`)
* `margin_functions.job.yml`: creates the `margin_` UC functions (SQL under `../src/`)
* `margin_scorecard.dashboard.yml`: the one AI/BI dashboard (`../dashboards/`)
* `margin_app.app.yml`: the one Databricks App (`../apps/`)
* Margin Genie: the space config is exported to `../genie/` and applied by a job task
* `margin_jobs.job.yml`: refresh and benchmark jobs

## Commands (run from this folder)
* `databricks bundle validate --strict --target dev`
* `databricks bundle deploy --target dev`

## WARNING: read before you deploy (dev target creates `[dev <user>]` copies)
The default target `dev` uses `mode: development`. There is no `mode: production` target yet.
* Development mode adds the prefix `[dev <your_user>]` to the dashboard, the pipeline, and the 4 jobs, and it pauses job schedules. Apps get no prefix.
* Plain `databricks bundle deploy` (no `-t`) uses `dev`, because `dev` is the default target.
* **Fresh workspace** (nothing deployed before): you get 1 app (`lakelink-margin-truth`), 1 dashboard (`[dev <user>] Lakelink Fiber Margin Truth`), 1 pipeline (`[dev <user>] Lakelink Fiber Margin Truth Pipeline`), and 4 paused jobs (`[dev <user>] lakelink-margin-*`). The Genie space is not a bundle resource; create it once with the title guard in `DEPLOY_RUNBOOK.md` section 8.
* **Workspace that already has the live assets** (for example the original demo workspace): an unbound `-t dev` deploy creates a SECOND dashboard and a SECOND pipeline next to the originals (2 of each), and the app create conflicts with the existing app. Use `-t jobs_only` there (4 jobs, 0 apps/dashboards/pipelines), or bind the live assets first (`DEPLOY_RUNBOOK.md` section 3).
* Each additional user who deploys `-t dev` gets their own `[dev <user>]` copies.
* Clean up a dev deploy with `databricks bundle destroy -t dev` only if nothing is bound (never on a bound target).

Full procedure, live asset IDs, and rollback: `DEPLOY_RUNBOOK.md`.
