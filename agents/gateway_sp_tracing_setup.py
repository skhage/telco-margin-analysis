"""Lakelink Fiber - Margin Truth: P4-GATEWAY-SP-TRACING setup (idempotent).

Owner: @ml-engineer. telco_project=margin_analysis.
Creates/verifies:
  1. Unity Gateway model service cfg('gateway_service')
     (routes 100% to cfg('gateway_backing_model')) with guardrails:
       rank 10 detect_sensitive_data (block, pre+post), rank 20 block_jailbreak (pre),
       rank 30 block_unsafe_content (pre+post); judges use cfg('gateway_fallback_model').
  2. MLflow experiment agents/margin_grooming_agent_traces for tracing every agent step.
  3. Service principal lakelink-margin-grooming-agent (creation needs human confirmation;
     run create_service_principal() only after CEO approval) + least-privilege grants.
No schemas are created. UC objects live only in the configured <catalog>.<schema> with margin_ prefix.
CONFIG: all names come from bundle/project_config.yml via src/project_config.py.
"""
import json
import os
import sys
import mlflow
from databricks.sdk import WorkspaceClient

_d = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
while not os.path.isfile(os.path.join(_d, "src", "project_config.py")) and os.path.dirname(_d) != _d:
    _d = os.path.dirname(_d)
sys.path.insert(0, os.path.join(_d, "src"))
from project_config import cfg, fq, schema_fq  # noqa: E402

w = WorkspaceClient()
SVC_FQN = cfg("gateway_service")
SCHEMA, SERVICE_ID = SVC_FQN.rsplit(".", 1)
JUDGE = cfg("gateway_fallback_model")
BACKING_MODEL = cfg("gateway_backing_model")
# Experiment lives next to this file (agents/margin_grooming_agent_traces); id is cfg('mlflow_experiment_id').
EXP_PATH = os.path.join(_d, "agents", "margin_grooming_agent_traces").replace("/Workspace/", "/", 1)
SP_NAME = cfg("agent_name")
TAG_KEY, TAG_VALUE = cfg("project_tag_key"), cfg("project_tag")

POLICIES = [
    {"name": "block-sensitive-data", "policy_type": "POLICY_TYPE_BUILTIN", "handler": "system.ai.detect_sensitive_data", "rank": 10,
     "options": {"action": "block", "phases": "pre_call,post_call",
                 "categories": "class.credit_card,class.us_ssn,class.us_bank_number,class.iban_code"}},
    {"name": "block-jailbreak", "policy_type": "POLICY_TYPE_BUILTIN", "handler": "system.ai.block_jailbreak", "rank": 20,
     "options": {"model_service": JUDGE, "phases": "pre_call"}},
    {"name": "block-unsafe-content", "policy_type": "POLICY_TYPE_BUILTIN", "handler": "system.ai.block_unsafe_content", "rank": 30,
     "options": {"model_service": JUDGE, "phases": "pre_call,post_call"}},
]


def ensure_model_service():
    path = f"/api/2.1/unity-catalog/model-services/{SVC_FQN}"
    try:
        return w.api_client.do("GET", path)
    except Exception:
        body = {
            "comment": f"{cfg('company_name')} Margin Truth: approved model for the off-net grooming agent ({TAG_KEY}={TAG_VALUE}).",
            "config": {
                "routing": {"destinations": [{
                    "name": "primary",
                    "destination_type": "DESTINATION_TYPE_PAY_PER_TOKEN_FOUNDATION_MODEL",
                    "pay_per_token_config": {"model": f"models/{BACKING_MODEL}"},
                    "traffic_percentage": 100}]},
                "service_policies": POLICIES,
            },
        }
        return w.api_client.do("POST", "/api/2.1/unity-catalog/model-services",
                               query={"parent": f"schemas/{SCHEMA}", "model_service_id": SERVICE_ID}, body=body)


def chat(msg, max_tokens=60):
    return w.api_client.do("POST", "/ai-gateway/mlflow/v1/chat/completions",
                           body={"model": SVC_FQN, "messages": [{"role": "user", "content": msg}], "max_tokens": max_tokens})


def guardrail_tests():
    ok = chat("In one sentence, what is an off-net circuit for Lakelink Fiber?")
    blocked = chat("Customer card 4111 1111 1111 1111 should be added to the ticket.")
    assert ok["choices"][0]["finish_reason"] == "stop"
    assert blocked.get("databricks_service_policy", {}).get("name") == "block-sensitive-data"
    return ok, blocked


def ensure_experiment():
    mlflow.set_tracking_uri("databricks")
    exp = mlflow.get_experiment_by_name(EXP_PATH)
    exp_id = exp.experiment_id if exp else mlflow.create_experiment(
        EXP_PATH, tags={TAG_KEY: TAG_VALUE, "company": cfg("company_name"), "agent": "offnet_grooming"})
    mlflow.set_experiment(experiment_id=exp_id)
    return exp_id


@mlflow.trace(name="gateway_smoke_test", span_type="CHAT_MODEL")
def smoke():
    return chat("Reply with the single word READY.", 40)["choices"][0]["message"]["content"]


def create_service_principal():
    """Requires human confirmation (IAM change). Run only after CEO approval."""
    found = list(w.service_principals.list(filter=f'displayName eq "{SP_NAME}"'))
    return found[0] if found else w.service_principals.create(display_name=SP_NAME, active=True)


def least_privilege_grants(app_id):
    """Grants for the grooming agent SP. Run after the SP exists and the margin_ objects exist."""
    stmts = [
        f"GRANT USE CATALOG ON CATALOG {cfg('catalog')} TO `{app_id}`",
        f"GRANT USE SCHEMA ON SCHEMA {schema_fq('schema')} TO `{app_id}`",
        f"GRANT USE SCHEMA ON SCHEMA {schema_fq('metrics_schema')} TO `{app_id}`",
        f"GRANT SELECT ON VIEW {fq('margin_ledger_mv')} TO `{app_id}`",
        f"GRANT SELECT ON TABLE {fq('margin_circuits')} TO `{app_id}`",
        f"GRANT SELECT ON TABLE {fq('margin_vendors')} TO `{app_id}`",
        f"GRANT EXECUTE ON FUNCTION {fq('margin_score_onnet_move')} TO `{app_id}`",
        f"GRANT EXECUTE ON MODEL SERVICE {SVC_FQN} TO `{app_id}`",
    ]
    for s in stmts:
        spark.sql(s)  # noqa: F821 (Databricks runtime)
    return stmts


if __name__ == "__main__":
    svc = ensure_model_service()
    print(json.dumps({"service": svc["name"], "policies": [p["name"] for p in svc["config"]["service_policies"]]}))
    guardrail_tests()
    exp_id = ensure_experiment()
    print("experiment", exp_id, "smoke", smoke(), "trace", mlflow.get_last_active_trace_id())
