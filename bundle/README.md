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
