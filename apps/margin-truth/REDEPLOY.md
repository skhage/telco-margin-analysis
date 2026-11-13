# Lakelink Fiber Margin Truth: one-step redeploy (CEO gate 2)

App: `lakelink-margin-truth` (the ONE app, DEC-015). Source: this folder.
App service principal (client id): `606dcc12-ad8e-423a-b7a5-407b87d84121`.
App Lakebase: project `telco-margin-analysis-app`, host `ep-calm-king-d2mq878u.database.us-east-1.cloud.databricks.com`, db `databricks_postgres`, schema `public` only.

## Precondition: gate 1 (GRANTs) is done
See `resources/CEO_ACTION_SHEET.md` gate 1 for the exact statements. The app code needs:
* `public.approval_tickets`: SELECT, UPDATE (queue + decision)
* `public.approval_audit`: SELECT, INSERT (audit trail + evidence)
* `public.approval_audit_audit_id_seq`: USAGE (audit insert)

On 2026-11-13 (app-developer run #11) the SP role exists but has no SELECT/UPDATE/INSERT on either table.

## The one step
```
databricks apps deploy lakelink-margin-truth --source-code-path /Workspace/Users/stephen.hage@databricks.com/telco-margin-analysis/apps/margin-truth
```
The platform runs `npm install` and `npm run build` (server `tsc` + client `vite build`), then starts `node dist/server/index.js` per `app.yaml`. Do not commit `node_modules/` or `dist/` to this folder.

## What the new deployment picks up
* `GENIE_SPACE_ID=01f1df115a08164aab3ae5f6faac807c` (Margin Genie iframe). The live deployment from 2026-11-12T23:29Z predates this value.
* `SHOW_TEST_TICKETS=false`: `TEST-*` tickets are hidden from the queue, decisions, and evidence. Rows are not deleted.
* `MARGIN_MV=cdm_tmforum._metrics.margin_ledger_mv`, `MLFLOW_EXPERIMENT_ID=1235449331932066`.

## Verify after deploy (2 minutes)
1. `databricks apps get lakelink-margin-truth`: `active_deployment.create_time` is later than the deploy command, and the status is RUNNING.
2. Open the app URL and go to the Approval queue with role Ops. You should see 2 pending tickets, GROOM-44c3612b69 (circuit 45040, savings 879.34) and GROOM-6d8f8ce31e (circuit 98532, savings 469.00), and no TEST-GROOM-4d4c099b0e.
3. Margin explorer, product_family, all quarters: the total contribution margin is 2,375,095,705.09 (DEC-020). Quarter 2026-07-01 is 590,767,062.41.
4. The Margin Genie panel loads (the iframe shows the space, not a sign-in or 404 page).

## Pre-checking the build without deploying (optional, serverless)
Node via PyPI: `pip install nodejs-wheel-binaries`. The wheel's `bin/npm` wrapper is broken, so put a wrapper `/tmp/npmbin/npm` that runs `<site-packages>/nodejs_wheel/bin/node <site-packages>/nodejs_wheel/lib/node_modules/npm/bin/npm-cli.js "$@"` FIRST on PATH, because `npm run build` calls `npm` again for each step. Copy this folder to `/tmp`, then run `npm install && npm run typecheck && npm run build`. Last result: PASS on 2026-11-13 (dist/server/index.js, dist/client/index.html, assets 153.70 kB js / 4.07 kB css).

## If gate 1 misses Nov 15 12:00 CT
DEC-018 applies: scene 5 is shown as the recording from `SCENE5_CLICK_SCRIPT.md`. If the redeploy misses Nov 16 12:00 CT, the explorer falls back to the dashboard explorer page.
