"""Lakelink Fiber Margin Truth - project config loader.

Single source of truth: bundle/project_config.yml (DAB `variables:` format, each entry documented).
Every Python file in this repo gets catalog/schema/table/asset names from here instead of hard-coding them.

Usage:
    # callers walk up from their own file to <repo>/src and add it to sys.path, e.g.
    #   d = os.path.dirname(os.path.abspath(__file__))
    #   while not os.path.isfile(os.path.join(d, "src", "project_config.py")): d = os.path.dirname(d)
    #   sys.path.insert(0, os.path.join(d, "src"))
    from project_config import cfg, fq, volume_path, warehouse_id, render
    cfg("catalog")             -> "cdm_tmforum"
    fq("margin_ledger")        -> "cdm_tmforum.revenue_assurance.margin_ledger"
    fq("margin_ledger_mv")     -> "cdm_tmforum._metrics.margin_ledger_mv"
    volume_path("carrier_invoices/") -> "/Volumes/cdm_tmforum/revenue_assurance/margin_documents/carrier_invoices/"
    render(sql_text)           -> replaces ${key} and {{key}} tokens (scalar variables and object keys)

Resolution order for a scalar variable <name>:
    1. env var MARGIN_CFG_<NAME upper>   (e.g. MARGIN_CFG_CATALOG=my_catalog) - per-run override
    2. `default:` in bundle/project_config.yml
The config file is found via env MARGIN_PROJECT_CONFIG, else by walking up from this file / cwd
looking for bundle/project_config.yml.
"""
from __future__ import annotations

import os
import re
from functools import lru_cache

CONFIG_RELPATH = os.path.join("bundle", "project_config.yml")
_IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_-]*$")


def _search_roots():
    roots = []
    if "__file__" in globals():
        roots.append(os.path.dirname(os.path.abspath(__file__)))
    roots.append(os.getcwd())
    return roots


def config_path() -> str:
    env = os.environ.get("MARGIN_PROJECT_CONFIG")
    if env:
        return env
    for start in _search_roots():
        d = start
        while True:
            cand = os.path.join(d, CONFIG_RELPATH)
            if os.path.isfile(cand):
                return cand
            parent = os.path.dirname(d)
            if parent == d:
                break
            d = parent
    raise FileNotFoundError(f"{CONFIG_RELPATH} not found above {_search_roots()}; set MARGIN_PROJECT_CONFIG")


@lru_cache(maxsize=1)
def _variables() -> dict:
    import yaml  # PyYAML ships with Databricks runtimes / serverless environments
    with open(config_path(), encoding="utf-8") as f:
        return yaml.safe_load(f)["variables"]


def cfg(name: str):
    """Value of a variable in project_config.yml (env MARGIN_CFG_<NAME> overrides)."""
    env = os.environ.get(f"MARGIN_CFG_{name.upper()}")
    if env is not None:
        return env
    v = _variables()[name]
    if "default" in v:
        return v["default"]
    if "lookup" in v:
        raise KeyError(f"{name} is a bundle lookup; use the matching helper (e.g. warehouse_id())")
    raise KeyError(name)


def describe(name: str) -> str:
    """Documentation string of a variable (for agents discovering datasets)."""
    return _variables()[name].get("description", "")


def objects() -> dict:
    return cfg("objects")


def ident(value: str, what: str = "identifier") -> str:
    if not _IDENT.match(str(value)):
        raise ValueError(f"invalid {what}: {value!r}")
    return value


def fq(key: str) -> str:
    """Fully qualified catalog.schema.name for a logical object key in `objects`."""
    o = objects()[key]
    return ".".join(ident(x) for x in (cfg("catalog"), cfg(o["schema_key"]), o["name"]))


def schema_fq(schema_key: str = "schema") -> str:
    return f"{ident(cfg('catalog'))}.{ident(cfg(schema_key))}"


def volume_path(sub: str = "") -> str:
    return f"/Volumes/{cfg('catalog')}/{cfg('schema')}/{cfg('documents_volume')}/{sub}"


def warehouse_id() -> str:
    """Env DATABRICKS_WAREHOUSE_ID (apps/jobs), else resolve `warehouse_name` with the SDK."""
    env = os.environ.get("DATABRICKS_WAREHOUSE_ID") or os.environ.get("MARGIN_CFG_WAREHOUSE_ID")
    if env:
        return env
    from databricks.sdk import WorkspaceClient
    name = cfg("warehouse_name")
    for wh in WorkspaceClient().warehouses.list():
        if wh.name == name:
            return wh.id
    raise LookupError(f"SQL warehouse named {name!r} not found (bundle/project_config.yml warehouse_name)")


def tokens() -> dict:
    """Substitution map: every scalar variable plus every object key -> fully qualified name."""
    out = {}
    for k, v in _variables().items():
        if "default" in v and not isinstance(v["default"], (dict, list)):
            out[k] = str(cfg(k))
    for k in objects():
        out[k] = fq(k)
    out["volume_path"] = volume_path()
    return out


_TOKEN = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}|\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}")


def render(text: str, extra: dict | None = None, strict: bool = True) -> str:
    """Replace ${key} / {{key}} tokens with config values. Unknown tokens raise when strict."""
    t = tokens()
    if extra:
        t.update({k: str(v) for k, v in extra.items()})

    def sub(m):
        k = m.group(1) or m.group(2)
        if k in t:
            return t[k]
        if strict:
            raise KeyError(f"unknown config token {m.group(0)}")
        return m.group(0)

    return _TOKEN.sub(sub, text)

