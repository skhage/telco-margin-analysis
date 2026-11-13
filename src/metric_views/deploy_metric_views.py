"""Lakelink Fiber Margin Truth - metric view deployer (DEVOPS-BUNDLE-LIVE-ASSETS, @devops).

Deploys src/metric_views/<name>.yaml into the EXISTING schema <catalog>.<metrics_schema>
(default cdm_tmforum._metrics). It never creates schemas or catalogs (directive 1, DEC-001).

* Default is a DRY RUN: it prints the plan only. Pass --execute to run the SQL.
* Existing view  -> ALTER VIEW ... AS $$ <yaml> $$ (keeps grants; never CREATE OR REPLACE).
* Missing view   -> CREATE VIEW ... WITH METRICS LANGUAGE YAML AS $$ <yaml> $$, then sets
  TBLPROPERTIES telco_project=margin_analysis (the governed tag value is rejected, directive 5).
* The leading '#' header comment block of each YAML file is stripped before deploy.
* Contribution margin is defined only in margin_ledger_mv (DEC-002); this script does not edit YAML.

Usage (bundle job lakelink-margin-metric-views or a notebook):
  python deploy_metric_views.py --views margin_ledger_mv [--execute]
"""
import argparse
import os
import re
import sys

DEFAULT_CATALOG = "cdm_tmforum"
DEFAULT_METRICS_SCHEMA = "_metrics"
# Live in cdm_tmforum._metrics (DEC-022). margin_rate_variance_mv is STRETCH (DEC-007): pass it via --views.
DEFAULT_VIEWS = [
    "margin_ledger_mv",
    "margin_offnet_spend_mv",
    "margin_segment_growth_mv",
    "margin_renewal_floor_mv",
    "margin_onebillion_wall_mv",
]
IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()


def ident(value: str, what: str) -> str:
    if not IDENT.match(value):
        raise SystemExit(f"invalid {what}: {value!r}")
    return value


def load_body(path: str) -> str:
    with open(path, encoding="utf-8") as f:
        lines = f.read().splitlines()
    i = 0
    while i < len(lines) and (lines[i].lstrip().startswith("#") or not lines[i].strip()):
        i += 1
    body = "\n".join(lines[i:]).strip() + "\n"
    if "$$" in body:
        raise SystemExit(f"{path}: body contains '$$' and cannot be dollar-quoted")
    return body


def get_spark():
    try:
        return spark  # noqa: F821 (notebook / job global)
    except NameError:
        from pyspark.sql import SparkSession
        return SparkSession.builder.getOrCreate()


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Lakelink Fiber Margin Truth metric view deployer")
    ap.add_argument("--catalog", default=DEFAULT_CATALOG)
    ap.add_argument("--metrics-schema", default=DEFAULT_METRICS_SCHEMA, help="EXISTING schema only; never created")
    ap.add_argument("--views", nargs="*", default=DEFAULT_VIEWS)
    ap.add_argument("--yaml-dir", default=HERE)
    ap.add_argument("--project-tag", default="margin_analysis")
    ap.add_argument("--execute", action="store_true", help="run the SQL (default is a dry run)")
    args = ap.parse_args(argv)

    cat = ident(args.catalog, "catalog")
    sch = ident(args.metrics_schema, "metrics schema")
    tag = args.project_tag.replace("'", "")
    plan = []
    for v in args.views:
        name = ident(v, "view")
        if not name.startswith("margin_"):
            raise SystemExit(f"{name}: project metric views must use the margin_ prefix")
        plan.append((name, load_body(os.path.join(args.yaml_dir, f"{name}.yaml"))))

    print(f"target {cat}.{sch}; views {[n for n, _ in plan]}; execute={args.execute}")
    if not args.execute:
        for n, body in plan:
            print(f"[dry-run] {n}: {len(body.splitlines())} YAML lines")
        return 0

    sp = get_spark()
    # DEVOPS-FIX-MV-DEPLOYER: SHOW SCHEMAS LIKE / SHOW VIEWS IN raise
    # CROSS_CATALOG_SCHEMA_REFERENCE_NOT_SUPPORTED on serverless; use the catalog's information_schema.
    info = f"`{cat}`.information_schema"
    if sp.sql(f"SELECT 1 FROM {info}.schemata WHERE schema_name = :s", args={"s": sch}).count() == 0:
        print(f"schema {cat}.{sch} does not exist; refusing to create it (directive 1)")
        return 1
    existing = {
        r["table_name"]
        for r in sp.sql(
            f"SELECT table_name FROM {info}.tables WHERE table_schema = :s AND table_type IN ('VIEW', 'METRIC_VIEW')",
            args={"s": sch},
        ).collect()
    }
    for n, body in plan:
        fq = f"`{cat}`.`{sch}`.`{n}`"
        if n in existing:
            sp.sql(f"ALTER VIEW {fq} AS $$\n{body}$$")
            print(f"altered {fq}")
        else:
            sp.sql(f"CREATE VIEW {fq} WITH METRICS LANGUAGE YAML AS $$\n{body}$$")
            sp.sql(f"ALTER VIEW {fq} SET TBLPROPERTIES ('telco_project' = '{tag}')")
            print(f"created {fq}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
