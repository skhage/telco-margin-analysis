"""Lakelink Fiber - Margin Truth: off-net grooming agent loop (ML-GROOMING-AGENT-STUB-RUN -> P4-GROOMING-AGENT).

Tag: telco_project=margin_analysis. Owner: @ml-engineer.
Tool specs + SYSTEM_PROMPT: agents/margin_grooming_agent_tools.py (keep in sync; Auto Mode refuses exec() of
workspace files, so paste inline when running from executeCode).
Model: Unity Gateway service cdm_tmforum.revenue_assurance.margin_grooming_agent_llm (guardrails on).
Tracing: MLflow experiment 1235449331932066. Approval queue: Lakebase telco-margin-analysis-app public.approval_tickets.
STUB MODE: ask_margin_genie and score_onnet_move return stubbed values until P3-MARGIN-GENIE and
P4-UC-FN-ONNET-SCORE land; swap in real tools for P4-GROOMING-AGENT. Stub tickets use ticket_id TEST-GROOM-* and
rationale prefixed TEST.
"""
import json, uuid
import mlflow, psycopg
from mlflow.entities import SpanType
from databricks.sdk import WorkspaceClient

STUB_MODE = True
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


def _stub_score(c):  # same formula as agents/margin_score_onnet_move.sql
    sav = round(c["paid_amount_usd"] - (2.00 * c["bandwidth_mbps"] + 0.50 * c["onnet_distance_m"] / 36), 2)
    sc = int(min(100, max(0, (50 if c["is_parallel_to_onnet_fiber"] else 0)
                         + (50 * max(sav, 0) / c["paid_amount_usd"] if c["paid_amount_usd"] > 0 else 0))))
    return sav, sc


@mlflow.trace(name="ask_margin_genie", span_type=SpanType.TOOL)
def ask_margin_genie(question):
    if STUB_MODE:
        return {"stub": True, "answer": "STUB: Off-net circuit 45040 runs 51 m from Lakelink Fiber fiber; latest monthly carrier cost USD 2,400.00."}
    raise NotImplementedError("Wire Genie Conversation API once P3-MARGIN-GENIE sets the space id")


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
    raise NotImplementedError(f"Call SELECT * FROM {SCORE_FUNCTION}(:circuit_id) via Statement Execution API")


@mlflow.trace(name="draft_savings_ticket", span_type=SpanType.TOOL)
def draft_savings_ticket(circuit_id, vendor_id, monthly_cost, est_monthly_savings, rationale):
    prefix = "TEST-GROOM-" if STUB_MODE else "GROOM-"
    tid = prefix + uuid.uuid4().hex[:10]
    trace_id = mlflow.get_current_active_span().trace_id
    if STUB_MODE and not rationale.startswith("TEST"):
        rationale = "TEST: " + rationale
    me = w.current_user.me().user_name
    with app_conn() as conn, conn.cursor() as cur, conn.transaction():
        cur.execute(
            """INSERT INTO public.approval_tickets (ticket_id, ticket_type, approver_role, title, circuit_id, vendor_id,
                 monthly_cost, est_monthly_savings, rationale, payload, agent_name, agent_sp_app_id, agent_sp_name,
                 mlflow_experiment_id, trace_id)
               VALUES (%s,'offnet_grooming','Ops',%s,%s,%s,%s,%s,%s,%s::jsonb,%s,%s,%s,%s,%s)""",
            (tid, f"Move circuit {circuit_id} on-net (Lakelink Fiber)", str(circuit_id), vendor_id, monthly_cost,
             est_monthly_savings, rationale,
             json.dumps({"stub_run": STUB_MODE, "run_as": me, "telco_project": "margin_analysis"}),
             AGENT_NAME, AGENT_SP_APP_ID, AGENT_NAME if AGENT_SP_APP_ID else None, MLFLOW_EXPERIMENT_ID, trace_id))
        cur.execute("INSERT INTO public.approval_audit (ticket_id, action, actor, actor_role, details) VALUES (%s,'created',%s,'agent',%s::jsonb)",
                    (tid, me, json.dumps({"agent": AGENT_NAME, "trace_id": trace_id, "stub_run": STUB_MODE})))
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
                                      "stub_run": str(STUB_MODE).lower()})
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
                    "for good candidates. Start by asking Margin Genie, then score circuit 45040."))
