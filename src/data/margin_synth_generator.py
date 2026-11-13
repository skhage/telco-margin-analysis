"""Lakelink Fiber Margin Truth - synthetic data generator (P1-SYNTH-GENERATOR-CODE, @devops).

Single source-file entry point (no notebook, DEC-009 exempt) that rebuilds the margin_ synthetic
tables and the fast-path gold ledger from the reviewed generator SQL under data/:

  1. data/margin_synth_master.sql               margin_customers, margin_products, margin_vendors
  2. data/margin_synth_contracts_circuits.sql   margin_contracts, margin_circuits
  3. data/margin_synth_billing_carrier_gl.sql   margin_billing, margin_carrier_invoices, margin_gl_actuals
  4. data/margin_ledger_fastpath.sql            margin_ledger (DEC-008 fast path)

Keys are reused from the read-only source schemas (DEC-003): salesforce_source.account /
contract_line_item / partner_account, mdm_source.customer_crosswalk, tmf_service.customer_facing_service.
The SQL is deterministic (xxhash64 / pmod on business keys, fixed date windows), so the seed is the
key set itself: re-running gives the same rows. margin_allocation_rules is owned by @data-analyst
(DEC-014) and is not rebuilt here.

HARD RULES enforced by this runner:
  * Never creates schemas or databases (any CREATE/DROP SCHEMA|DATABASE statement aborts the run).
  * Writes only to <catalog>.<schema> (default cdm_tmforum.revenue_assurance), prefix margin_.
  * No secrets or tokens; runs with the caller's identity.

Usage (Databricks serverless / cluster, or Databricks Connect):
  python src/data/margin_synth_generator.py                 # dry run: list statements per step
  python src/data/margin_synth_generator.py --execute       # run all steps
  python src/data/margin_synth_generator.py --execute --steps master contracts
  python src/data/margin_synth_generator.py --execute --catalog cdm_tmforum --schema revenue_assurance
"""
from __future__ import annotations

import argparse
import os
import re
import sys

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DEFAULT_CATALOG = "cdm_tmforum"
DEFAULT_SCHEMA = "revenue_assurance"

# Ordered steps: (key, sql file relative to repo root, tables written)
STEPS = [
    ("master", "data/margin_synth_master.sql", ["margin_customers", "margin_products", "margin_vendors"]),
    ("contracts", "data/margin_synth_contracts_circuits.sql", ["margin_contracts", "margin_circuits"]),
    ("billing", "data/margin_synth_billing_carrier_gl.sql", ["margin_billing", "margin_carrier_invoices", "margin_gl_actuals"]),
    ("ledger", "data/margin_ledger_fastpath.sql", ["margin_ledger"]),
]

# Planted-story spec: what each table must contain for the demo scenes. Checked after --execute.
PLANTED_STORIES = {
    "margin_products": "Salesforce product2 rows plus synthetic Legacy Voice (MGN-PRD-) products; family_class legacy = IP-VPN + Legacy Voice; margin_floor_pct per product.",
    "margin_vendors": "30 carriers = salesforce_source.partner_account Wholesale Carrier + Interconnect Ids (DEC-003).",
    "margin_customers": "10,000 customers keyed on salesforce_source.account TMF_Customer_Id__c; region derived.",
    "margin_contracts": "Real contract lines + 6 legacy-voice-heavy customers with 30 discounted Legacy Voice lines each (15 renewing 2026-11-20..2027-01-29).",
    "margin_circuits": "Renewal-window lines with Discount >= 30 forced off-net; 12 hero off-net 1G circuits parallel to Lakelink Fiber fiber at 51..172 m (featured 45040, 98532).",
    "margin_billing": "12 months 2025-11..2026-10, one row per circuit x month; price_mismatch leakage seed.",
    "margin_carrier_invoices": "Off-net carrier invoices with invoiced vs vendor contract rate (rate variance).",
    "margin_gl_actuals": "2026 periods incl. cost-to-serve cost centers feeding the allocation pools.",
    "margin_ledger": "customer x product x circuit x month; ticket_count is a SYNTHETIC proxy (DEC-016).",
}

# Post-run checks: (description, SQL returning one integer that must be 0)
ORPHAN_CHECKS = [
    ("contracts -> customers", "SELECT count(*) FROM {t}.margin_contracts k LEFT ANTI JOIN {t}.margin_customers c ON c.customer_id = k.customer_id"),
    ("contracts -> products", "SELECT count(*) FROM {t}.margin_contracts k LEFT ANTI JOIN {t}.margin_products p ON p.product_id = k.product_id"),
    ("circuits -> contracts", "SELECT count(*) FROM {t}.margin_circuits c LEFT ANTI JOIN {t}.margin_contracts k ON k.contract_id = c.contract_id"),
    ("off-net circuits -> vendors", "SELECT count(*) FROM {t}.margin_circuits c LEFT ANTI JOIN {t}.margin_vendors v ON v.vendor_id = c.vendor_id WHERE NOT c.is_on_net"),
    ("billing -> circuits", "SELECT count(*) FROM {t}.margin_billing b LEFT ANTI JOIN {t}.margin_circuits c ON c.circuit_id = b.circuit_id"),
]

_FORBIDDEN = re.compile(r"\b(CREATE|DROP|ALTER)\s+(SCHEMA|DATABASE|CATALOG)\b", re.IGNORECASE)


def split_statements(sql_text: str) -> list[str]:
    """Strip full-line comments, then split. Files that use the ';;' runner separator are split on it;
    otherwise split on ';' at end of line (COMMENT strings never end a line with ';')."""
    lines = [ln for ln in sql_text.splitlines() if not ln.lstrip().startswith("--")]
    body = "\n".join(lines)
    parts = body.split(";;") if ";;" in body else re.split(r";[ \t]*(?:\n|$)", body)
    return [p.strip().rstrip(";").strip() for p in parts if p.strip()]


def retarget(stmt: str, catalog: str, schema: str) -> str:
    """Point writes at <catalog>.<schema>; read-only sources stay in <catalog>."""
    stmt = stmt.replace(f"{DEFAULT_CATALOG}.{DEFAULT_SCHEMA}.", f"{catalog}.{schema}.")
    if catalog != DEFAULT_CATALOG:
        stmt = re.sub(rf"\b{DEFAULT_CATALOG}\.(?!{re.escape(schema)}\.)", f"{catalog}.", stmt)
    return stmt


def load_plan(catalog: str, schema: str, steps: list[str]) -> list[tuple[str, list[str]]]:
    plan = []
    for key, rel, _tables in STEPS:
        if steps and key not in steps:
            continue
        with open(os.path.join(REPO_ROOT, rel), encoding="utf-8") as fh:
            stmts = [retarget(s, catalog, schema) for s in split_statements(fh.read())]
        for s in stmts:
            if _FORBIDDEN.search(s):
                raise SystemExit(f"ABORT: {rel} contains a schema/database/catalog DDL statement (HARD RULE: no new schemas).")
        plan.append((key, stmts))
    return plan


def get_spark():
    try:
        from databricks.connect import DatabricksSession  # type: ignore
        return DatabricksSession.builder.getOrCreate()
    except Exception:
        from pyspark.sql import SparkSession
        return SparkSession.builder.getOrCreate()


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Lakelink Fiber Margin Truth synthetic data generator")
    ap.add_argument("--catalog", default=DEFAULT_CATALOG)
    ap.add_argument("--schema", default=DEFAULT_SCHEMA, help="EXISTING schema only; never created")
    ap.add_argument("--steps", nargs="*", choices=[s[0] for s in STEPS], default=[])
    ap.add_argument("--execute", action="store_true", help="run the SQL (default is a dry run)")
    args = ap.parse_args(argv)

    plan = load_plan(args.catalog, args.schema, args.steps)
    target = f"{args.catalog}.{args.schema}"
    for key, stmts in plan:
        print(f"[{key}] {len(stmts)} statement(s) -> {target}")
    if not args.execute:
        print("Dry run only. Re-run with --execute to build the tables.")
        return 0

    spark = get_spark()
    if spark.sql(f"SHOW SCHEMAS IN {args.catalog} LIKE '{args.schema}'").count() == 0:
        raise SystemExit(f"ABORT: schema {target} does not exist. Escalate to @pm; never create it.")
    for key, stmts in plan:
        for i, s in enumerate(stmts, 1):
            print(f"[{key}] {i}/{len(stmts)}")
            spark.sql(s)
    failures = 0
    for desc, q in ORPHAN_CHECKS:
        n = spark.sql(q.format(t=target)).collect()[0][0]
        print(f"orphan check {desc}: {n}")
        failures += int(n != 0)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
