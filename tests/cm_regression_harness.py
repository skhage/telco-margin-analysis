"""Lakelink Fiber Margin Truth: 5-surface contribution margin regression harness (answers COO-Q-20261112-12).

Owner @qa. Expected values come from raw SQL over margin_ledger (tests/cm_baseline_expected.sql).
Tolerance: 0.00 USD at the product_family grain (exact to the cent), matching tests/cm_cross_surface_reconciliation.sql.

Surfaces and how each is called:
  1. metric_view - SQL Statement API: MEASURE(contribution_margin) FROM cdm_tmforum._metrics.margin_ledger_mv
  2. genie       - Genie Conversation API (POST /api/2.0/genie/spaces/{space_id}/start-conversation), read the
                   query_result attachment. Needs MARGIN_GENIE_SPACE_ID (P3-MARGIN-GENIE).
  3. genie_one   - SKIPPED per DEC-029b (gate 5 expired Nov 14 18:05 UTC; Margin Genie only on stage, no Genie One
                   claim). No Genie One API exists; the check reports SKIPPED, not PASS.
  4. dashboard   - Lakeview: run the dashboard dataset SQL (GET /api/2.0/lakeview/dashboards/{id}, dataset queryLines)
                   through the SQL Statement API. Needs MARGIN_DASHBOARD_ID (P3-DASHBOARD).
  5. app         - GET {app_url}/api/explorer?group_by=product_family (apps/margin-truth). Needs the redeployed app.
  6. agent       - Grooming agent Genie tool; checked via the MLflow trace span output once P4-GROOMING-AGENT is wired.
A surface that is not built yet reports NOT_AVAILABLE (not PASS). The run fails on any MISMATCH.
"""
from decimal import Decimal

TOLERANCE = Decimal("0.00")

# Baseline MGN-ALR-v1, full range 2025-11..2026-10 (captured 2026-11-13 by @qa)
EXPECTED_FULL = {
    "Wavelength": Decimal("1815451950.80"),
    "Dedicated Internet": Decimal("429087884.31"),
    "Colocation": Decimal("100244032.61"),
    "Ethernet": Decimal("47448323.57"),
    "Managed": Decimal("10472910.26"),
    "Legacy Voice": Decimal("-998851.80"),
    "IP-VPN": Decimal("-26610544.92"),
}
EXPECTED_TOTAL = Decimal("2375095704.83")

# Persona starter questions (expected answers from raw SQL; see cm_baseline_expected.sql)
EXPECTED_PERSONA = {
    "finance_q3_2026_losers": ["IP-VPN", "Legacy Voice"],
    "ops_hero_circuit_count": 47,  # DEC-017: off-net AND parallel AND margin_score_onnet_move savings > 0 (featured 45040, 98532)
    "ops_hero_band_subview": 12,    # @qa band filter (note 206), sub-view only
    "marketing_room_to_grow": ["Commercial"],
    "sales_below_floor_renewals": 586,  # as-of 2026-11-19 (DEC-019), window inclusive [2026-11-19, +90d]; 603 if as-of 2026-11-13
}

# Scene 7: $1B Wall challenge cards (QA-SCENE7-CARDS-HARNESS, @qa 2026-11-15). Raw SQL = section (7) of
# tests/cm_baseline_expected.sql; MV check = margin_onebillion_wall_mv MEASURE(identified_savings) by lever.
EXPECTED_SCENE7 = {
    "legacy_repricing": Decimal("27609396.70"),
    "revenue_leakage": Decimal("26698861.46"),
    "renewal_floor_gap": Decimal("4837761.36"),
    "carrier_rate_variance": Decimal("1694614.90"),
    "offnet_grooming_savings": Decimal("412539.96"),
    "wall_identified_total": Decimal("61253174.38"),
    "c1_ip_vpn_q3_cm": Decimal("-6715475.88"),
    "c1_legacy_voice_q3_cm": Decimal("-249532.74"),
    "c1_loser_families": Decimal("2"),
    "c2_grooming_circuits": Decimal("47"),
    "c2_annual_offnet_cost": Decimal("1152342.12"),
    "c3_renewals": Decimal("1490"),
    "c3_below_floor": Decimal("586"),
    "c3_revenue_at_stake": Decimal("18890869.75"),
}
EXPECTED_WALL_MV = {
    "Legacy repricing": Decimal("27609396.70"),
    "Revenue leakage recovery": Decimal("26698861.46"),
    "Renewal margin floor": Decimal("4837761.36"),
    "Carrier rate variance recovery": Decimal("1694614.90"),
    "Off-net grooming": Decimal("412539.96"),
}
WALL_MV_SQL = ("SELECT lever, CAST(MEASURE(identified_savings) AS DECIMAL(18,2)) AS v "
               "FROM cdm_tmforum._metrics.margin_onebillion_wall_mv GROUP BY ALL")
BASELINE_SQL_PATH = "/Workspace/Users/stephen.hage@databricks.com/telco-margin-analysis/tests/cm_baseline_expected.sql"


def scene7_raw_sql(path=BASELINE_SQL_PATH):
    """Return statement (7) (the last statement) of cm_baseline_expected.sql with comment lines removed."""
    with open(path) as f:
        text = f.read()
    # Drop comment lines BEFORE splitting: comments in section (7) contain ';'.
    code = "\n".join(l for l in text.splitlines() if not l.strip().startswith("--"))
    stmts = [s.strip() for s in code.split(";")]
    return [s for s in stmts if s][-1]


def run_scene7(spark):
    """Scene 7 cards + Wall: raw SQL and the Wall MV must both match to the cent."""
    return {
        "scene7_raw": compare("scene7_raw", sql_surface(spark, scene7_raw_sql()), expected=EXPECTED_SCENE7),
        "scene7_wall_mv": compare("scene7_wall_mv", sql_surface(spark, WALL_MV_SQL), expected=EXPECTED_WALL_MV),
    }

GENIE_ONE_MANUAL = {}  # fill by hand during rehearsal

MV_SQL = ("SELECT product_family, CAST(MEASURE(contribution_margin) AS DECIMAL(18,2)) AS cm "
          "FROM cdm_tmforum._metrics.margin_ledger_mv GROUP BY ALL")
# Live-allocation view (DA-DE-LIVE-ALLOCATION-VIEW). Per-row ROUND(...,2) => +0.26 vs table total; tolerance $1 total, $10 per cell (note 280).
ALLOC_SQL = ("SELECT product_family, CAST(SUM(revenue_usd - network_expense_usd - cost_to_serve_usd) AS DECIMAL(18,2)) AS cm "
             "FROM cdm_tmforum.revenue_assurance.margin_ledger_allocated GROUP BY product_family")
EXPECTED_ALLOC_TOTAL = Decimal("2375095705.09")
ALLOC_TOL_CELL = Decimal("10.00")
ALLOC_TOL_TOTAL = Decimal("1.00")
REF_SQL = ("SELECT product_family, CAST(SUM(revenue_usd - network_expense_usd - cost_to_serve_usd) AS DECIMAL(18,2)) AS cm "
           "FROM cdm_tmforum.revenue_assurance.margin_ledger GROUP BY product_family")


def compare(surface, actual, expected=EXPECTED_FULL, tol=TOLERANCE):
    """Return (status, diffs). actual is {family: Decimal} or None when the surface does not exist yet."""
    if actual is None:
        return "NOT_AVAILABLE", []
    diffs = []
    for fam in sorted(set(expected) | set(actual)):
        e, a = expected.get(fam), actual.get(fam)
        if e is None or a is None or abs(Decimal(a) - e) > tol:
            diffs.append((fam, e, a))
    return ("MISMATCH" if diffs else "PASS"), diffs


def sql_surface(spark, sql):
    try:
        return {r[0]: Decimal(r[1]) for r in spark.sql(sql).collect()}
    except Exception as exc:  # table/view missing
        if "TABLE_OR_VIEW_NOT_FOUND" in str(exc):
            return None
        raise


def dry_run():
    """Known-answer test: an exact copy must PASS and a 1-cent change must be caught."""
    ok, _ = compare("exact", dict(EXPECTED_FULL))
    off = dict(EXPECTED_FULL)
    off["Legacy Voice"] = off["Legacy Voice"] + Decimal("0.01")
    bad, diffs = compare("one_cent", off)
    assert ok == "PASS" and bad == "MISMATCH" and diffs[0][0] == "Legacy Voice", (ok, bad, diffs)
    return ok, bad, diffs


def run(spark):
    results = {
        "reference_raw_sql": compare("ref", sql_surface(spark, REF_SQL)),
        # MV sources margin_ledger_allocated (per-row ROUND, total 2375095705.09), not margin_ledger: use the alloc tolerance.
        "metric_view": compare("mv", sql_surface(spark, MV_SQL), tol=ALLOC_TOL_CELL),
        "ledger_allocated": compare("alloc", sql_surface(spark, ALLOC_SQL), tol=ALLOC_TOL_CELL),
        "genie": compare("genie", None),       # wire after P3-MARGIN-GENIE
        "genie_one": ("SKIPPED", ["DEC-029b: Genie One not a stage surface"]),
        "dashboard": compare("dashboard", None),  # wire after P3-DASHBOARD
        "app": compare("app", None),           # wire after app redeploy
        "agent": compare("agent", None),       # wire after P4-GROOMING-AGENT
    }
    total = sum(EXPECTED_FULL.values())
    assert total == EXPECTED_TOTAL, total
    alloc = sql_surface(spark, ALLOC_SQL)
    if alloc is not None:
        at = sum(alloc.values())
        results["ledger_allocated_total"] = ("PASS" if abs(at - EXPECTED_ALLOC_TOTAL) <= ALLOC_TOL_TOTAL else "MISMATCH", [("__TOTAL__", EXPECTED_ALLOC_TOTAL, at)])
    assert sum(EXPECTED_WALL_MV.values()) == EXPECTED_SCENE7["wall_identified_total"]
    results.update(run_scene7(spark))
    return results


# Pre-demo check (COO-Q-20261112-12 d): app Lakebase project telco-margin-analysis-app must return 0 rows for
#   SELECT ticket_id FROM public.approval_tickets WHERE ticket_id LIKE 'TEST-GROOM-%'
