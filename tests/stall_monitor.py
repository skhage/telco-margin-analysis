"""Lakelink Fiber Margin Truth: live swarm stall monitor (COO-Q-20261112-22, owner @devops).

Runs tests/stall_detector.sql against the Lakebase task board (telco-margin-analysis-project,
public schema) from a Lakeflow Job that is independent of the Genie Code scheduler, so a
scheduler-side stall (like 11-12 02:56-22:42 UTC) is still detected.

Behavior:
  * 0-5 roles STALLED (>3h silent): prints the table, exits 0.
  * >=6 roles STALLED: writes one status_updates row (agent_role='@devops',
    update_type='stall_alert') unless one was written in the last 3h, then raises so the job
    run FAILS and the job's on_failure email notification fires.

No secrets: the Lakebase password is a short-lived OAuth token minted at run time for the
job's run-as identity via w.postgres.generate_database_credential.
"""
import os
import sys

import psycopg
from databricks.sdk import WorkspaceClient

ENDPOINT = os.environ.get(
    "MARGIN_LAKEBASE_ENDPOINT",
    "projects/telco-margin-analysis-project/branches/production/endpoints/primary",
)
HOST = os.environ.get(
    "MARGIN_LAKEBASE_HOST", "ep-orange-lab-d2tt5nll.database.us-east-1.cloud.databricks.com"
)
STALL_ROLE_THRESHOLD = int(os.environ.get("MARGIN_STALL_ROLE_THRESHOLD", "6"))


def _detector_sql() -> str:
    here = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
    with open(os.path.join(here, "stall_detector.sql")) as f:
        return f.read()


def main() -> int:
    w = WorkspaceClient()
    token = w.postgres.generate_database_credential(endpoint=ENDPOINT).token
    with psycopg.connect(
        host=HOST,
        dbname="databricks_postgres",
        user=w.current_user.me().user_name,
        password=token,
        sslmode="require",
        autocommit=True,
    ) as conn, conn.cursor() as cur:
        cur.execute(_detector_sql())
        rows = cur.fetchall()
        for role, last_activity, hours_silent, state in rows:
            print(f"{role:20s} {state:8s} {hours_silent!s:>6} h  last={last_activity}")
        stalled = [r[0] for r in rows if r[3] == "STALLED"]
        print(f"STALLED roles: {len(stalled)}/{len(rows)} (threshold {STALL_ROLE_THRESHOLD})")
        if len(stalled) < STALL_ROLE_THRESHOLD:
            return 0

        cur.execute(
            "SELECT COUNT(*) FROM status_updates WHERE update_type = 'stall_alert' "
            "AND created_at > NOW() - INTERVAL '3 hours'"
        )
        if cur.fetchone()[0] == 0:
            cur.execute(
                "INSERT INTO status_updates (update_date, agent_role, update_type, summary, "
                "blockers, human_attention, critical_path) "
                "VALUES (CURRENT_DATE, '@devops', 'stall_alert', %s, %s, %s, %s)",
                (
                    f"Swarm stall detected by lakelink-margin-stall-monitor job: "
                    f"{len(stalled)}/{len(rows)} roles silent >3h.",
                    ", ".join(stalled),
                    "Scheduler-level stall likely (see DEVOPS-STALL-RCA). CEO: check Genie Code "
                    "scheduled tasks; @pm: log ceo_escalation.",
                    "All hero-path work paused while stalled.",
                ),
            )
    raise SystemExit(
        f"SWARM STALL: {len(stalled)} roles silent >3h: {', '.join(stalled)}"
    )


if __name__ == "__main__":
    sys.exit(main())
