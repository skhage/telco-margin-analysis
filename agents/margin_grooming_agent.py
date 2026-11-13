"""Lakelink Fiber - Margin Truth: off-net grooming agent loop (ML-GROOMING-AGENT-STUB-RUN -> P4-GROOMING-AGENT).

Tag: telco_project=margin_analysis. Owner: @ml-engineer.
Tool specs + SYSTEM_PROMPT: agents/margin_grooming_agent_tools.py (keep in sync; Auto Mode refuses exec() of
workspace files, so paste inline when running from executeCode).
Model: Unity Gateway service cdm_tmforum.revenue_assurance.margin_grooming_agent_llm (guardrails on).
Tracing: MLflow experiment 1235449331932066. Approval queue: Lakebase telco-margin-analysis-app public.approval_tickets.
STUB MODE: ask_margin_genie and score_onnet_move return stubbed values until P3-MARGIN-GENIE and
P4-UC-FN-ONNET-SCORE land; swap in real tools for P4-GROOMING-AGENT. Stub tickets use ticket_id TEST-GROOM-* and
rationale prefixed TEST.

FALLBACK PATH (ML-GROOMING-FALLBACK-PATH, 2026-11-13) - used when STUB_MODE=False:
* Identity: runs as the calling USER until SP lakelink-margin-grooming-agent exists (payload identity_mode=user_fallback).
* Genie: if MARGIN_GENIE_SPACE_ID is None, ask_margin_genie answers from GENIE_FALLBACK_SQL
  (margin_circuits + margin_vendors + margin_carrier_invoices; no margin figures), payload genie_basis=sql_fallback.
* Scoring: real UC function margin_score_onnet_move (score_basis=carrier_invoice); if it errors or returns no rows
  (e.g. margin_carrier_invoices absent), PROXY_SQL rate card by bandwidth tier (score_basis=proxy).
  Proxy rate card = median latest paid_amount_usd per bandwidth tier from margin_carrier_invoices, frozen 2026-11-13.
  CAUTION: proxy savings for hero circuits 45040/98532 are about -714 USD, so proxy never drafts hero tickets.
* draft_savings_ticket re-checks values against score_onnet_move and refuses savings <= 0.
Known answers (carrier_invoice basis): 45040 cost 2880.05 savings 879.34 score 65; 98532 cost 2469.86 savings 469.00 score 59.

DRY RUN (ML-GROOMING-DRYRUN-TOOLS, 2026-11-13):
* GENIE SWITCH (one line): set MARGIN_GENIE_SPACE_ID to the Margin Genie space id. None -> GENIE_STANDIN_SQL
  (margin_score_onnet_move + MEASURE(contribution_margin) from margin_ledger_mv, genie_basis=sql_standin);
  set -> real Genie Conversation API (genie_basis=margin_genie).
* DRY_RUN=True: draft_savings_ticket runs every guard but writes NOTHING to the app queue (returns would_insert).
  Stand-in known answers: 47 candidates (DEC-017); MV total 2,375,095,705.09 (DEC-020).

LIVE GENIE RUN (P4-GROOMING-AGENT, 2026-11-13): real Margin Genie returned total_row_count=47; trace
tr-f09d04073ced6c20fad2e0100ad00eb2. DEDUP GUARD: draft_savings_ticket returns existing_ticket when a non-TEST pending
offnet_grooming ticket already exists for the circuit, so re-runs never duplicate GROOM-44c3612b69 / GROOM-6d8f8ce31e.
"""
import json, time, uuid
import mlflow, psycopg
from mlflow.entities import SpanType
from databricks.sdk import WorkspaceClient
from databricks.sdk.service.sql import StatementParameterListItem

STUB_MODE = False
DRY_RUN = True  # True = validate tickets but never INSERT into the app approval queue
MARGIN_GENIE_SPACE_ID = "01f1df115a08164aab3ae5f6faac807c"  # Lakelink Fiber Margin Genie (P3-MARGIN-GENIE); None -> sql_standin
WAREHOUSE_ID = "bf0baa637e887c80"
_last_basis = {}

GENIE_FALLBACK_SQL = """
WITH latest AS (SELECT circuit_id, paid_amount_usd, ROW_NUMBER() OVER (PARTITION BY circuit_id ORDER BY invoice_month DESC) rn
                FROM cdm_tmforum.revenue_assurance.margin_carrier_invoices)
SELECT c.circuit_id, v.vendor_name, c.vendor_id, c.onnet_distance_m, c.bandwidth_mbps, l.paid_amount_usd AS latest_monthly_paid_usd
FROM cdm_tmforum.revenue_assurance.margin_circuits c
JOIN cdm_tmforum.revenue_assurance.margin_vendors v ON v.vendor_id = c.vendor_id
LEFT JOIN latest l ON l.circuit_id = c.circuit_id AND l.rn = 1
WHERE c.is_on_net = FALSE AND c.is_parallel_to_onnet_fiber AND c.circuit_id IN (45040, 98532)
ORDER BY l.paid_amount_usd DESC NULLS LAST"""

# Genie stand-in (ML-GROOMING-DRYRUN-TOOLS): margin figures come ONLY from margin_ledger_mv MEASURE() (DEC-002/020);
# candidate filter = DEC-017 Ops hero filter (parallel to own fiber AND savings > 0) -> 47 rows.
GENIE_STANDIN_SQL = """
WITH s AS (SELECT * FROM cdm_tmforum.revenue_assurance.margin_score_onnet_move(CAST(NULL AS BIGINT))
           WHERE is_parallel_to_onnet_fiber AND est_monthly_savings_usd > 0),
cm AS (SELECT circuit_id, MEASURE(contribution_margin) AS contribution_margin_usd,
              MEASURE(offnet_network_expense) AS offnet_network_expense_usd
       FROM cdm_tmforum._metrics.margin_ledger_mv
       WHERE is_on_net = FALSE AND circuit_id IN (SELECT circuit_id FROM s) GROUP BY circuit_id)
SELECT s.circuit_id, s.vendor_id, s.monthly_offnet_cost_usd, s.est_monthly_savings_usd, s.score,
       cm.contribution_margin_usd, cm.offnet_network_expense_usd
FROM s LEFT JOIN cm ON cm.circuit_id = s.circuit_id
ORDER BY s.score DESC, s.est_monthly_savings_usd DESC
LIMIT 10"""

PROXY_SQL = """
SELECT c.circuit_id, c.vendor_id, c.is_parallel_to_onnet_fiber, c.onnet_distance_m,
       CAST(rc.proxy_cost AS DECIMAL(18,2)) AS monthly_offnet_cost_usd,
       CAST(rc.proxy_cost - (2.00*COALESCE(c.bandwidth_mbps,0) + 0.50*COALESCE(c.onnet_distance_m,0)/36) AS DECIMAL(18,2)) AS est_monthly_savings_usd
FROM cdm_tmforum.revenue_assurance.margin_circuits c
JOIN cdm_tmforum.revenue_assurance.margin_vendors v ON v.vendor_id = c.vendor_id
JOIN (VALUES (0.06,1364.58),(1.54,909.72),(100.00,1187.69),(500.00,492.01),(1000.00,1286.96),(10000.00,5614.77),(100000.00,20383.93)) AS rc(bw, proxy_cost)
  ON rc.bw = c.bandwidth_mbps
WHERE c.is_on_net = FALSE AND (:cid IS NULL OR c.circuit_id = :cid)"""
GATEWAY_SERVICE = "cdm_tmforum.revenue_assurance.margin_grooming_agent_llm"
SCORE_FUNCTION = "cdm_tmforum.revenue_assurance.margin_score_onnet_move"
MLFLOW_EXPERIMENT_ID = "1235449331932066"
APP_ENDPOINT = "projects/telco-margin-analysis-app/branches/production/endpoints/primary"
APP_HOST = "ep-calm-king-d2mq878u.database.us-east-1.cloud.databricks.com"
AGENT_NAME = "lakelink-margin-grooming-agent"
AGENT_SP_APP_ID = None  # set when SP lakelink-margin-grooming-agent exists (P4-GATEWAY-SP-TRACING)

w = WorkspaceClient()
mlflow.set_tracking_uri("databricks")
mlflow.set_experiment(experiment_id=MLFLOW_EXPERIMENT_ID)

# SYSTEM_PROMPT and TOOLS: copy from agents/margin_grooming_agent_tools.py
from margin_grooming_agent_tools import SYSTEM_PROMPT, TOOLS  # noqa: E402  (when run as a module)


def app_conn():
    tok = w.postgres.generate_database_credential(endpoint=APP_ENDPOINT).token
    return psycopg.connect(host=APP_HOST, dbname="databricks_postgres", user=w.current_user.me().user_name,
                           password=tok, sslmode="require", autocommit=True)


# Stub inputs: real attributes of hero circuit 45040 from margin_circuits; paid amount stubbed (carrier invoices pending)
STUB_CIRCUITS = {45040: {"vendor_id": "00100000000265pAAA", "is_parallel_to_onnet_fiber": True,
                         "onnet_distance_m": 51.0, "bandwidth_mbps": 1000.0, "paid_amount_usd": 2400.00}}


def existing_pending(cid):
    """Dedup guard: non-TEST pending grooming tickets already in the app queue for this circuit."""
    with app_conn() as c, c.cursor() as cur:
        cur.execute("SELECT ticket_id FROM public.approval_tickets WHERE circuit_id=%s AND ticket_type='offnet_grooming' "
                    "AND status='pending' AND ticket_id NOT LIKE 'TEST-%%'", (str(cid),))
        return [r[0] for r in cur.fetchall()]


def _stub_score(c):  # same formula as agents/margin_score_onnet_move.sql
    sav = round(c["paid_amount_usd"] - (2.00 * c["bandwidth_mbps"] + 0.50 * c["onnet_distance_m"] / 36), 2)
    sc = int(min(100, max(0, (50 if c["is_parallel_to_onnet_fiber"] else 0)
                         + (50 * max(sav, 0) / c["paid_amount_usd"] if c["paid_amount_usd"] > 0 else 0))))
    return sav, sc


def run_sql(sql, params=None):
    """Parameterized Statement Execution on the project warehouse. params: {name: (value, type)}."""
    r = w.statement_execution.execute_statement(
        warehouse_id=WAREHOUSE_ID, statement=sql, wait_timeout="50s",
        parameters=[StatementParameterListItem(name=k, value=None if v is None else str(v), type=t)
                    for k, (v, t) in (params or {}).items()])
    while r.status.state.value in ("PENDING", "RUNNING"):
        time.sleep(2)
        r = w.statement_execution.get_statement(r.statement_id)
    if r.status.state.value != "SUCCEEDED":
        raise RuntimeError(f"{r.status.state.value}: {r.status.error.message if r.status.error else ''}")
    cols = [c.name for c in r.manifest.schema.columns]
    return [dict(zip(cols, row)) for row in (r.result.data_array or [])]


def real_score(cid):
    rows = run_sql(f"SELECT * FROM {SCORE_FUNCTION}(:cid)", {"cid": (cid, "BIGINT")})
    for r in rows:
        r["score_basis"] = "carrier_invoice"
    return rows


def proxy_score(cid):
    rows = run_sql(PROXY_SQL, {"cid": (cid, "BIGINT")})
    for r in rows:
        sav, cost = float(r["est_monthly_savings_usd"]), float(r["monthly_offnet_cost_usd"])
        r["score"] = int(min(100, max(0, (50 if r["is_parallel_to_onnet_fiber"] == "true" else 0)
                                     + (50 * max(sav, 0) / cost if cost > 0 else 0))))
        r["score_basis"] = "proxy"
    return rows


@mlflow.trace(name="ask_margin_genie", span_type=SpanType.TOOL)
def ask_margin_genie(question):
    if STUB_MODE:
        return {"stub": True, "answer": "STUB: Off-net circuit 45040 runs 51 m from Lakelink Fiber fiber; latest monthly carrier cost USD 2,400.00."}
    if MARGIN_GENIE_SPACE_ID is None:
        _last_basis["genie_basis"] = "sql_standin"
        return {"genie_basis": "sql_standin",
                "note": "Margin Genie space not yet available; answered with margin_score_onnet_move + MEASURE(contribution_margin) from margin_ledger_mv (top 10 of the DEC-017 candidates).",
                "rows": run_sql(GENIE_STANDIN_SQL)}
    _last_basis["genie_basis"] = "margin_genie"
    out = genie_ask(question)
    mlflow.get_current_active_span().set_attributes({
        "genie_conversation_id": out["conversation_id"], "genie_message_id": out["message_id"],
        "genie_total_row_count": str(out.get("total_row_count")), "genie_sql": out.get("sql") or ""})
    return out


def genie_ask(question, timeout_s=120):
    """Real Margin Genie via Genie Conversation API: start conversation, poll, fetch query result."""
    base = f"/api/2.0/genie/spaces/{MARGIN_GENIE_SPACE_ID}"
    m = w.api_client.do("POST", f"{base}/start-conversation", body={"content": question})
    cid, mid = m["conversation_id"], m["message_id"]
    t0 = time.time()
    while True:
        msg = w.api_client.do("GET", f"{base}/conversations/{cid}/messages/{mid}")
        if msg.get("status") in ("COMPLETED", "FAILED", "CANCELLED", "QUERY_RESULT_EXPIRED") or time.time() - t0 > timeout_s:
            break
        time.sleep(3)
    out = {"genie_basis": "margin_genie", "status": msg.get("status"), "conversation_id": cid, "message_id": mid}
    for att in msg.get("attachments") or []:
        if att.get("text"):
            out["text"] = att["text"].get("content")
        if att.get("query"):
            out["sql"] = att["query"].get("query")
            res = w.api_client.do("GET", f"{base}/conversations/{cid}/messages/{mid}/attachments/{att['attachment_id']}/query-result")
            sr = res.get("statement_response", {})
            cols = [c["name"] for c in sr.get("manifest", {}).get("schema", {}).get("columns", [])]
            out["total_row_count"] = sr.get("manifest", {}).get("total_row_count")
            out["rows"] = [dict(zip(cols, r)) for r in (sr.get("result", {}).get("data_array") or [])[:20]]
    return out


@mlflow.trace(name="score_onnet_move", span_type=SpanType.TOOL)
def score_onnet_move(circuit_id):
    if STUB_MODE:
        ids = [circuit_id] if circuit_id is not None else list(STUB_CIRCUITS)
        out = []
        for cid in ids:
            c = STUB_CIRCUITS.get(int(cid))
            if not c:
                continue
            sav, sc = _stub_score(c)
            out.append({"circuit_id": int(cid), "vendor_id": c["vendor_id"],
                        "is_parallel_to_onnet_fiber": c["is_parallel_to_onnet_fiber"],
                        "onnet_distance_m": c["onnet_distance_m"], "monthly_offnet_cost_usd": c["paid_amount_usd"],
                        "est_monthly_savings_usd": sav, "score": sc, "stub": True})
        return out
    try:
        rows = real_score(circuit_id)
        if rows:
            _last_basis["score_basis"] = "carrier_invoice"
            return rows
    except Exception as e:  # e.g. margin_carrier_invoices absent
        mlflow.get_current_active_span().set_attribute("real_score_error", str(e)[:300])
    _last_basis["score_basis"] = "proxy"
    return proxy_score(circuit_id)


@mlflow.trace(name="draft_savings_ticket", span_type=SpanType.TOOL)
def draft_savings_ticket(circuit_id, vendor_id, monthly_cost, est_monthly_savings, rationale):
    prefix = "TEST-GROOM-" if STUB_MODE else "GROOM-"
    tid = prefix + uuid.uuid4().hex[:10]
    trace_id = mlflow.get_current_active_span().trace_id
    if STUB_MODE and not rationale.startswith("TEST"):
        rationale = "TEST: " + rationale
    me = w.current_user.me().user_name
    extra = {}
    if not STUB_MODE:  # guard: agent must copy tool values, never invent them
        chk = score_onnet_move(int(circuit_id))
        if (not chk or float(est_monthly_savings) <= 0
                or abs(float(chk[0]["est_monthly_savings_usd"]) - float(est_monthly_savings)) > 0.01):
            return {"error": "values do not match score_onnet_move or savings <= 0; ticket not drafted"}
        extra = {"identity_mode": "sp" if AGENT_SP_APP_ID else "user_fallback", "score_basis": chk[0]["score_basis"],
                 "genie_basis": _last_basis.get("genie_basis", "margin_genie"), "score": int(chk[0]["score"])}
    if not STUB_MODE:
        ex = existing_pending(circuit_id)
        if ex:  # never duplicate a pending ticket for the same circuit
            mlflow.get_current_active_span().set_attribute("dedup_existing_ticket", ex[0])
            return {"existing_ticket": ex[0], "status": "pending",
                    "note": "pending ticket already exists for this circuit; not re-inserted", **extra}
    if DRY_RUN:  # all guards passed; never write to the app queue in a dry run
        mlflow.get_current_active_span().set_attribute("dry_run", True)
        return {"dry_run": True, "would_insert": {"ticket_id": tid, "circuit_id": int(circuit_id), "vendor_id": vendor_id,
                "monthly_cost": float(monthly_cost), "est_monthly_savings": float(est_monthly_savings), **extra}}
    with app_conn() as conn, conn.cursor() as cur, conn.transaction():
        cur.execute(
            """INSERT INTO public.approval_tickets (ticket_id, ticket_type, approver_role, title, circuit_id, vendor_id,
                 monthly_cost, est_monthly_savings, rationale, payload, agent_name, agent_sp_app_id, agent_sp_name,
                 mlflow_experiment_id, trace_id)
               VALUES (%s,'offnet_grooming','Ops',%s,%s,%s,%s,%s,%s,%s::jsonb,%s,%s,%s,%s,%s)""",
            (tid, f"Move circuit {circuit_id} on-net (Lakelink Fiber)", str(circuit_id), vendor_id, monthly_cost,
             est_monthly_savings, rationale,
             json.dumps({"stub_run": STUB_MODE, "run_as": me, "telco_project": "margin_analysis", **extra}),
             AGENT_NAME, AGENT_SP_APP_ID, AGENT_NAME if AGENT_SP_APP_ID else None, MLFLOW_EXPERIMENT_ID, trace_id))
        cur.execute("INSERT INTO public.approval_audit (ticket_id, action, actor, actor_role, details) VALUES (%s,'created',%s,'agent',%s::jsonb)",
                    (tid, me, json.dumps({"agent": AGENT_NAME, "trace_id": trace_id, "stub_run": STUB_MODE, **extra})))
    return {"ticket_id": tid, "status": "pending"}


DISPATCH = {"ask_margin_genie": ask_margin_genie, "score_onnet_move": score_onnet_move,
            "draft_savings_ticket": draft_savings_ticket}


@mlflow.trace(name="gateway_chat", span_type=SpanType.CHAT_MODEL)
def gateway_chat(messages):
    return w.api_client.do("POST", "/ai-gateway/mlflow/v1/chat/completions",
                           body={"model": GATEWAY_SERVICE, "messages": messages, "tools": TOOLS, "max_tokens": 800})


@mlflow.trace(name="lakelink_offnet_grooming_agent", span_type=SpanType.AGENT)
def run_agent(task, max_turns=8):
    mlflow.update_current_trace(tags={"telco_project": "margin_analysis", "company": "Lakelink Fiber",
                                      "stub_run": str(STUB_MODE).lower(), "dry_run": str(DRY_RUN).lower(),
                                      "genie_mode": "margin_genie" if MARGIN_GENIE_SPACE_ID else "sql_standin",
                                      "genie_space_id": str(MARGIN_GENIE_SPACE_ID),
                                      "identity_mode": "sp" if AGENT_SP_APP_ID else "user_fallback",
                                      "run_as": w.current_user.me().user_name, "gateway_service": GATEWAY_SERVICE})
    messages = [{"role": "system", "content": SYSTEM_PROMPT}, {"role": "user", "content": task}]
    calls = []
    for _ in range(max_turns):
        msg = gateway_chat(messages)["choices"][0]["message"]
        messages.append({k: v for k, v in msg.items() if k in ("role", "content", "tool_calls")})
        tcs = msg.get("tool_calls") or []
        if not tcs:
            return {"final": msg.get("content"), "tool_calls": calls}
        for tc in tcs:
            fn = tc["function"]["name"]
            res = DISPATCH[fn](**json.loads(tc["function"]["arguments"] or "{}"))
            calls.append(fn)
            messages.append({"role": "tool", "tool_call_id": tc["id"], "content": json.dumps(res, default=str)})
    return {"final": "max_turns reached", "tool_calls": calls}


if __name__ == "__main__":
    print(run_agent("Find Lakelink Fiber off-net circuits that run next to our own fiber and draft savings tickets "
                    "for good candidates. Start by asking Margin Genie which off-net circuits run next to our own "
                    "fiber and what we pay for them, then score circuits 45040 and 98532 individually."))
