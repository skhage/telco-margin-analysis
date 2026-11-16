"""Lakelink Fiber Margin Truth - point the DASHBOARD and MARGIN GENIE at bundle/project_config.yml.

AI/BI dashboards and Genie spaces cannot read variables, so their JSON holds literal
catalog.schema.object names. This script rewrites those names (and the embedded Genie space id
and the Genie warehouse) from the config, so a customer changes names ONCE in project_config.yml.

How names are matched: any 3-part name <a>.<b>.<object> where <object> is a logical key or `name`
of an entry in `objects` (project_config.yml) is rewritten to fq(<key>). It is idempotent: running it
with unchanged config changes nothing (byte-identical files).

Surfaces:
  dashboard  - live AI/BI dashboard cfg('dashboard_id') (draft = src/dashboards/Lakelink Fiber Margin Truth.lvdash.json)
               + uiSettings.genieSpace.overrideId -> cfg('genie_space_id')
  skeleton   - src/dashboards/margin_truth_skeleton.json (plain file)
  genie      - live Genie space cfg('genie_space_id') serialized_space + warehouse,
               repo copy genie/margin_genie_space.serialized.json
  app        - apps/margin-truth/app.yaml env values (Lakebase endpoint/host/db, metric view, vendor table,
               Genie space, MLflow experiment). Redeploy the app after --apply.
  docs       - prose that keeps readable literal names: *.md, *.json, *.ipynb and YAML comments across the repo
               (runbooks, glossary pages, Genie instructions copy, bundle comments). Old values come from
               bundle/.config_sync_state.json (the values last applied); --apply rewrites old -> new and
               refreshes that state file. Code files (.py/.sql/.ts) are not touched: they read the config.

Usage (notebook / job / local with Databricks auth):
  python scripts/sync_config_surfaces.py              # CHECK (default): report drift, change nothing
  python scripts/sync_config_surfaces.py --apply      # rewrite repo files + update the dashboard DRAFT and the Genie space
  python scripts/sync_config_surfaces.py --apply --publish   # also publish the dashboard
  python scripts/sync_config_surfaces.py --pull-genie # refresh the repo Genie copy from the live space (no rewrite)
  --only dashboard,skeleton,genie,app,docs   limit the surfaces
Exit code 1 in CHECK mode when any surface is out of sync with the config.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys

_d = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
while not os.path.isfile(os.path.join(_d, "src", "project_config.py")) and os.path.dirname(_d) != _d:
    _d = os.path.dirname(_d)
REPO = _d
sys.path.insert(0, os.path.join(REPO, "src"))
from project_config import cfg, fq, objects, warehouse_id  # noqa: E402

DASHBOARD_FILE = os.path.join(REPO, "src", "dashboards", "Lakelink Fiber Margin Truth.lvdash.json")
SKELETON_FILE = os.path.join(REPO, "src", "dashboards", "margin_truth_skeleton.json")
GENIE_FILE = os.path.join(REPO, "genie", "margin_genie_space.serialized.json")
APP_YAML = os.path.join(REPO, "apps", "margin-truth", "app.yaml")
STATE_FILE = os.path.join(REPO, "bundle", ".config_sync_state.json")
HEX32 = re.compile(r"^[0-9a-f]{32}$")

# Scalar values tracked for the docs surface (old value in STATE_FILE -> new value in the config).
STATE_KEYS = ["catalog", "schema", "metrics_schema", "salesforce_schema", "erp_schema", "tmf_service_schema",
              "documents_volume", "genie_space_id", "dashboard_id", "pipeline_id", "mlflow_experiment_id",
              "gateway_service", "app_lakebase_endpoint", "app_lakebase_host", "taskboard_lakebase_endpoint",
              "taskboard_lakebase_host", "project_tag_key", "project_tag"]
SCHEMA_KEYS = ["schema", "metrics_schema", "salesforce_schema", "erp_schema", "tmf_service_schema"]
DOC_EXT = (".md", ".json", ".ipynb", ".yml", ".yaml", ".txt")
DOC_SKIP_DIRS = {".git", "node_modules", "dist", "metric_views"}


def _name_map(old_names=()) -> dict:
    """object name (logical key, configured name, or a previously applied name) -> configured fq name."""
    m = {}
    for key, o in objects().items():
        target = fq(key)
        m[key] = target
        m[o["name"]] = target
    for key, name in dict(old_names).items():
        if key in objects():
            m.setdefault(name, fq(key))
    return m


def rewrite_names(text: str, old_names=()) -> tuple[str, int]:
    names = _name_map(old_names)
    alt = "|".join(sorted((re.escape(n) for n in names), key=len, reverse=True))
    pat = re.compile(r"(?<![\w.`])([A-Za-z_]\w*)\.([A-Za-z_]\w*)\.(" + alt + r")(?![\w])")
    n = 0

    def sub(mo):
        nonlocal n
        new = names[mo.group(3)]
        if new != mo.group(0):
            n += 1
        return new

    return pat.sub(sub, text), n


def rewrite_dashboard(text: str) -> tuple[str, int]:
    out, n = rewrite_names(text)
    gid = cfg("genie_space_id") or ""
    old = (json.loads(out).get("uiSettings", {}).get("genieSpace") or {}).get("overrideId")
    if old and gid and old != gid:
        if not HEX32.match(gid):
            raise SystemExit(f"genie_space_id {gid!r} is not a 32-hex id")
        out, k = out.replace(f'"{old}"', f'"{gid}"'), out.count(f'"{old}"')
        n += k
    return out, n


def rewrite_genie(text: str) -> tuple[str, int]:
    out, n = rewrite_names(text)
    # Genie requires data_sources.tables sorted by identifier; re-serialize only if the order changed.
    j = json.loads(out)
    tabs = j.get("data_sources", {}).get("tables") or []
    if [t["identifier"] for t in tabs] != sorted(t["identifier"] for t in tabs):
        j["data_sources"]["tables"] = sorted(tabs, key=lambda t: t["identifier"])
        tail = out[len(out.rstrip("\n")):]  # keep the export's format: indent 2, UTF-8, same trailing newline
        out = json.dumps(j, indent=2, ensure_ascii=False) + tail
        n += 1
    return out, n


def app_env() -> dict:
    """app.yaml env name -> value from the config."""
    return {
        "LAKEBASE_ENDPOINT": cfg("app_lakebase_endpoint"),
        "LAKEBASE_HOST": cfg("app_lakebase_host"),
        "LAKEBASE_DB": cfg("lakebase_database"),
        "MARGIN_MV": fq("margin_ledger_mv"),
        "MARGIN_VENDORS": fq("margin_vendors"),
        "GENIE_SPACE_ID": cfg("genie_space_id") or "",
        "MLFLOW_EXPERIMENT_ID": str(cfg("mlflow_experiment_id") or ""),
    }


def rewrite_app(text: str) -> tuple[str, int]:
    """Set `- name: X` / `value: "..."` pairs in app.yaml; other lines are left byte-identical."""
    n = 0
    for name, val in app_env().items():
        pat = re.compile(r'(-\s+name:\s+' + re.escape(name) + r'\s*\n\s+value:\s+)"([^"\n]*)"')
        mo = pat.search(text)
        if not mo:
            raise SystemExit(f"app.yaml has no env entry {name}")
        if mo.group(2) != val:
            text = text[:mo.start()] + mo.group(1) + json.dumps(val) + text[mo.end():]
            n += 1
    return text, n


def current_state() -> dict:
    st = {k: str(cfg(k) or "") for k in STATE_KEYS}
    try:  # warehouse is a name lookup; track the resolved id so docs that quote it follow a warehouse change
        st["warehouse_id"] = str(warehouse_id() or "")
    except Exception:  # noqa: BLE001 (no auth / offline)
        st["warehouse_id"] = ""
    st["objects"] = {k: o["name"] for k, o in objects().items()}
    return st


def load_state() -> dict:
    if os.path.isfile(STATE_FILE):
        return json.loads(_read(STATE_FILE))
    return current_state()  # no baseline yet: treat current config as applied


def doc_pairs(old: dict, new: dict) -> list:
    """(regex, replacement) pairs for literal values that changed since the last apply."""
    pairs = []

    def add(o, n, word=True):
        if o and n and o != n:
            pat = re.escape(o)
            pairs.append((re.compile(r"(?<![\w.])" + pat + r"(?![\w])" if word else pat), n))

    add(f"/Volumes/{old['catalog']}/{old['schema']}/{old['documents_volume']}",
        f"/Volumes/{new['catalog']}/{new['schema']}/{new['documents_volume']}", word=False)
    for k in SCHEMA_KEYS:
        add(f"{old['catalog']}.{old[k]}", f"{new['catalog']}.{new[k]}")
    add(old["catalog"], new["catalog"])  # bare catalog name (e.g. GRANT USE CATALOG, tables in docs)
    add(old["project_tag_key"], new["project_tag_key"])  # tag key and value as whole words
    add(old["project_tag"], new["project_tag"])
    for k in STATE_KEYS:
        if k not in SCHEMA_KEYS + ["catalog", "documents_volume", "project_tag_key", "project_tag"]:
            add(old[k], new[k], word=False)
    if old.get("warehouse_id") and new.get("warehouse_id"):
        add(old["warehouse_id"], new["warehouse_id"])
    for k in ("app_lakebase_host", "taskboard_lakebase_host"):  # short endpoint id, e.g. ep-calm-king-d2mq878u
        add(old[k].split(".")[0], new[k].split(".")[0])
    return pairs


def doc_files() -> list:
    managed = {os.path.normpath(p) for p in (DASHBOARD_FILE, SKELETON_FILE, GENIE_FILE, APP_YAML, STATE_FILE,
                                             os.path.join(REPO, "bundle", "project_config.yml"))}
    out = []
    for root, dirs, files in os.walk(REPO):
        dirs[:] = [d for d in dirs if d not in DOC_SKIP_DIRS]
        for f in files:
            p = os.path.normpath(os.path.join(root, f))
            if f.endswith(DOC_EXT) and p not in managed and not f.endswith((".lvdash.json", ".geniespace.json")):
                out.append(p)
    return sorted(out)


def rewrite_doc(text: str, old: dict, new: dict) -> tuple[str, int]:
    out, n = rewrite_names(text, old.get("objects", {}))
    for pat, rep in doc_pairs(old, new):
        out, k = pat.subn(rep.replace("\\", "\\\\"), out)
        n += k
    return out, n


def do_docs(apply: bool) -> int:
    old, new = load_state(), current_state()
    total, files = 0, 0
    for p in doc_files():
        try:
            text = _read(p)
        except (UnicodeDecodeError, OSError):
            continue
        out, n = rewrite_doc(text, old, new)
        if n:
            files += 1
            total += n
            print(f"[docs] {os.path.relpath(p, REPO)}: {n}")
            if apply:
                _write(p, out)
    print(f"[docs] {total} reference(s) in {files} file(s) to update")
    if apply and (old != new or not os.path.isfile(STATE_FILE)):
        _write(STATE_FILE, json.dumps(new, indent=2, sort_keys=True) + "\n")
        print(f"[docs] state written to {os.path.relpath(STATE_FILE, REPO)}")
    return total


def do_app(apply: bool) -> int:
    new, n = rewrite_app(_read(APP_YAML))
    print(f"[app] {n} env value(s) to update" + (" - redeploy the app afterwards" if n else ""))
    if apply and n:
        _write(APP_YAML, new)
    return n


def _client():
    from databricks.sdk import WorkspaceClient
    return WorkspaceClient()


def _read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def _write(path, text):
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def do_dashboard(apply: bool, publish: bool) -> int:
    w = _client()
    did = cfg("dashboard_id")
    cur = w.lakeview.get(did)
    new, n = rewrite_dashboard(cur.serialized_dashboard)
    print(f"[dashboard {did}] {n} reference(s) to update")
    if apply and n:
        from databricks.sdk.service.dashboards import Dashboard
        w.lakeview.update(did, dashboard=Dashboard(display_name=cur.display_name, serialized_dashboard=new,
                                                   warehouse_id=warehouse_id(), etag=cur.etag))
        print(f"[dashboard {did}] draft updated")
    if apply and publish:
        w.lakeview.publish(did, warehouse_id=warehouse_id(), embed_credentials=True)
        print(f"[dashboard {did}] published")
    return n


def do_skeleton(apply: bool) -> int:
    if not os.path.isfile(SKELETON_FILE):
        return 0
    new, n = rewrite_names(_read(SKELETON_FILE))
    print(f"[skeleton] {n} reference(s) to update")
    if apply and n:
        _write(SKELETON_FILE, new)
    return n


def do_genie(apply: bool) -> int:
    w = _client()
    sid = cfg("genie_space_id")
    if not sid:
        print("[genie] genie_space_id is empty; create/import the space first, then set it in project_config.yml")
        return 0
    sp = w.api_client.do("GET", f"/api/2.0/genie/spaces/{sid}", query={"include_serialized_space": "true"})
    new, n = rewrite_genie(sp["serialized_space"])
    wh = warehouse_id()
    wh_drift = sp.get("warehouse_id") != wh
    print(f"[genie {sid}] {n} reference(s) to update; warehouse {'drift ' + str(sp.get('warehouse_id')) + ' -> ' + wh if wh_drift else 'ok'}")
    file_drift = os.path.isfile(GENIE_FILE) and _read(GENIE_FILE) != new
    if file_drift:
        print("[genie] repo copy differs from the (rewritten) live space")
    if apply and (n or wh_drift):
        body = {"serialized_space": new, "warehouse_id": wh, "etag": sp.get("etag")}
        w.api_client.do("PATCH", f"/api/2.0/genie/spaces/{sid}", body=body)
        print(f"[genie {sid}] space updated")
    if apply and file_drift:
        _write(GENIE_FILE, new)
        print("[genie] repo copy written")
    return n + int(wh_drift) + int(file_drift)


def pull_genie() -> None:
    sid = cfg("genie_space_id")
    sp = _client().api_client.do("GET", f"/api/2.0/genie/spaces/{sid}", query={"include_serialized_space": "true"})
    _write(GENIE_FILE, sp["serialized_space"])
    print(f"[genie] {GENIE_FILE} refreshed from space {sid}")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--apply", action="store_true", help="write changes (default: check only)")
    ap.add_argument("--publish", action="store_true", help="with --apply: publish the dashboard")
    ap.add_argument("--pull-genie", action="store_true", help="copy the live Genie space into the repo and exit")
    ap.add_argument("--only", default="dashboard,skeleton,genie,app,docs")
    a = ap.parse_args(argv)
    if a.pull_genie:
        pull_genie()
        return 0
    only = set(a.only.split(","))
    # Demo guard (COO-Q-20261116-61): until 2026-11-20 UTC, --apply must not write the LIVE dashboard or
    # Genie space unless MARGIN_SYNC_ALLOW_LIVE=1 is set explicitly. File-only surfaces are unaffected.
    import datetime as _dt
    live = only & {"dashboard", "genie"}
    if a.apply and live and _dt.datetime.now(_dt.timezone.utc) < _dt.datetime(2026, 11, 20, tzinfo=_dt.timezone.utc) \
            and os.environ.get("MARGIN_SYNC_ALLOW_LIVE") != "1":
        raise SystemExit(f"Refusing --apply on live surfaces {sorted(live)} before 2026-11-20 UTC. "
                         "Use --only skeleton,app,docs, or set MARGIN_SYNC_ALLOW_LIVE=1 with CEO approval.")
    drift = 0
    if "dashboard" in only:
        drift += do_dashboard(a.apply, a.publish)
    if "skeleton" in only:
        drift += do_skeleton(a.apply)
    if "genie" in only:
        drift += do_genie(a.apply)
    if "app" in only:
        drift += do_app(a.apply)
    if "docs" in only:
        drift += do_docs(a.apply)
    print("in sync with project_config.yml" if drift == 0 else f"{drift} change(s) {'applied' if a.apply else 'pending (run with --apply)'}")
    return 0 if (a.apply or drift == 0) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
