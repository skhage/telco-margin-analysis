"""Lakelink Fiber - Margin Truth: off-net grooming agent tool spec (P4-GROOMING-AGENT, COO-Q-20261111-9 d).

Tag: telco_project=margin_analysis. Owner: @ml-engineer.

Design rule: the agent NEVER computes contribution margin itself. Contribution margin
(revenue - network_expense - cost_to_serve) is defined ONCE in
the metric view fq('margin_ledger_mv') (DEC-002) and reaches the agent only through
the ask_margin_genie tool (Margin Genie -> margin_ledger_mv). Circuit scoring comes
only from the UC function margin_score_onnet_move. The agent only copies tool
outputs into the ticket; it has no calculator tool.

Model: Unity Gateway service cfg('gateway_service')
(guardrails: block-sensitive-data, block-jailbreak, block-unsafe-content).
Tracing: MLflow experiment cfg('mlflow_experiment_id') (agents/margin_grooming_agent_traces).
CONFIG: all names come from bundle/project_config.yml via src/project_config.py.
Identity: service principal lakelink-margin-grooming-agent (pending human creation,
see P4-GATEWAY-SP-TRACING).
"""

import os as _os, sys as _sys
_d = _os.path.dirname(_os.path.abspath(__file__)) if "__file__" in globals() else _os.getcwd()
while not _os.path.isfile(_os.path.join(_d, "src", "project_config.py")) and _os.path.dirname(_d) != _d:
    _d = _os.path.dirname(_d)
_sys.path.insert(0, _os.path.join(_d, "src"))
from project_config import cfg, fq  # noqa: E402

CATALOG = cfg("catalog")
SCHEMA = cfg("schema")
GATEWAY_SERVICE = cfg("gateway_service")
SCORE_FUNCTION = fq("margin_score_onnet_move")
CM_METRIC_VIEW = fq("margin_ledger_mv")
MLFLOW_EXPERIMENT_ID = str(cfg("mlflow_experiment_id"))
MARGIN_GENIE_SPACE_ID = cfg("genie_space_id")  # Margin Genie (P3-MARGIN-GENIE)
APPROVAL_DB_HOST = cfg("app_lakebase_host")  # Lakebase app project (cfg('app_lakebase_endpoint'))

SYSTEM_PROMPT = """You are the Lakelink Fiber off-net grooming agent.
Goal: find off-net circuits that run next to Lakelink Fiber's own fiber and draft a savings
ticket for each good candidate so that Ops can approve it.
Rules:
1. Get every margin or contribution margin figure by calling ask_margin_genie. Never compute,
   estimate, or restate a margin number that a tool did not return.
2. Get circuit scores, monthly off-net cost, and estimated savings only from score_onnet_move.
3. Draft a ticket only for circuits where score_onnet_move returns is_parallel_to_onnet_fiber = true
   and est_monthly_savings_usd > 0. Copy circuit_id, vendor_id, monthly_offnet_cost_usd and
   est_monthly_savings_usd exactly as returned.
4. Tickets are drafts. A person in Ops approves them in the Margin Truth app. Never mark a ticket approved.
5. Use the company name Lakelink Fiber only.
6. If draft_savings_ticket returns dry_run=true or existing_ticket, say so plainly; do not claim a new ticket was created.
7. If ask_margin_genie returns genie_basis = sql_standin, Margin Genie did NOT answer. Never call that result a
   Margin Genie answer and never use a heading such as 'Margin Genie Results'. Label it
   'SQL stand-in (Margin Genie did not answer in time)' (DEC-057)."""

# OpenAI-style function tool specs passed to the Unity Gateway chat/completions call.
TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "ask_margin_genie",
            "description": (
                f"Ask Margin Genie (Genie Agent over {CM_METRIC_VIEW}) a natural-language "
                "question. This is the ONLY source of contribution margin, revenue, network expense and cost to "
                "serve. Example: 'Which off-net circuits run next to our own fiber, and what do we pay for them?'"
            ),
            "parameters": {
                "type": "object",
                "properties": {"question": {"type": "string", "description": "Plain-English question for Margin Genie"}},
                "required": ["question"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "score_onnet_move",
            "description": (
                f"Calls UC function {SCORE_FUNCTION}(circuit_id BIGINT). "
                "Returns circuit_id, vendor_id, is_parallel_to_onnet_fiber, onnet_distance_m, "
                "monthly_offnet_cost_usd, est_monthly_savings_usd, score (0-100). Pass NULL to score all off-net circuits."
            ),
            "parameters": {
                "type": "object",
                "properties": {"circuit_id": {"type": ["integer", "null"], "description": "margin_circuits.circuit_id, or null for all"}},
                "required": ["circuit_id"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "draft_savings_ticket",
            "description": (
                "Insert a DRAFT savings ticket into the Margin Truth app approval queue "
                "(Lakebase app database public.approval_tickets, ticket_type='offnet_grooming', "
                "approver_role='Ops') plus an approval_audit row with action='created'. Values must be copied from score_onnet_move."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "circuit_id": {"type": "integer"},
                    "vendor_id": {"type": "string"},
                    "monthly_cost": {"type": "number", "description": "monthly_offnet_cost_usd from score_onnet_move"},
                    "est_monthly_savings": {"type": "number", "description": "est_monthly_savings_usd from score_onnet_move"},
                    "rationale": {"type": "string", "description": "One or two sentences citing the Genie answer and the score"},
                },
                "required": ["circuit_id", "vendor_id", "monthly_cost", "est_monthly_savings", "rationale"],
            },
        },
    },
]

TOOL_NAMES = [t["function"]["name"] for t in TOOLS]
# There is intentionally no calculator or SQL tool: margin math cannot happen inside the agent.
assert "calculator" not in TOOL_NAMES and "run_sql" not in TOOL_NAMES
