-- Lakelink Fiber Margin Truth: swarm stall detector (Lakebase Postgres, telco-margin-analysis-project, public schema)
-- Owner: @devops (DEVOPS-STALL-RCA). Run every @qa / @pm / @coo run.
-- A role is STALLED when it has written nothing to the board for more than 3 hours.
-- Activity = status_updates, agent_notes, asset_ledger rows by the role, tasks it assigned, tasks it completed.
-- Known-answer check (2026-11-12): evaluated as of 2026-11-12 12:00 UTC, all 12 roles are STALLED (9.1-10.0 h);
-- evaluated at 23:42 UTC, all 12 roles are OK.
WITH act AS (
  SELECT agent_role, created_at AS ts FROM status_updates
  UNION ALL SELECT agent_role, created_at FROM agent_notes
  UNION ALL SELECT agent_role, created_at FROM asset_ledger
  UNION ALL SELECT assigned_by, created_at FROM agent_tasks WHERE assigned_by IS NOT NULL
  UNION ALL SELECT agent_role, completed_date FROM agent_tasks WHERE completed_date IS NOT NULL
), last AS (
  SELECT s.agent_role, MAX(a.ts) AS last_activity
  FROM agent_schedule s LEFT JOIN act a ON a.agent_role = s.agent_role
  GROUP BY s.agent_role
)
SELECT agent_role,
       last_activity,
       ROUND(EXTRACT(EPOCH FROM NOW() - last_activity) / 3600.0, 1) AS hours_silent,
       CASE WHEN last_activity IS NULL OR NOW() - last_activity > INTERVAL '3 hours'
            THEN 'STALLED' ELSE 'OK' END AS state
FROM last
ORDER BY hours_silent DESC NULLS FIRST
-- Swarm-wide stall: COUNT(*) FILTER (WHERE state = 'STALLED') >= 6 means a scheduler problem, not one agent.
-- Escalate to @pm (ceo_escalation) instead of retrying.
