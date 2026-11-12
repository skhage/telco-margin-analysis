// Lakelink Fiber Margin Truth - API server (Express + pg). ONE app for telco-margin-analysis.
// Approval queue: Lakebase project telco-margin-analysis-app, schema public only.
// Margin explorer: reads cdm_tmforum._metrics.margin_* metric views with MEASURE(); never recomputes margin (DEC-002).
import express, { Request, Response } from "express";
import pg from "pg";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HOST = (process.env.DATABRICKS_HOST ?? "").replace(/^(?!https?:\/\/)/, "https://");
const CLIENT_ID = process.env.DATABRICKS_CLIENT_ID ?? "";
const CLIENT_SECRET = process.env.DATABRICKS_CLIENT_SECRET ?? "";
const LAKEBASE_ENDPOINT = process.env.LAKEBASE_ENDPOINT ?? "projects/telco-margin-analysis-app/branches/production/endpoints/primary";
const LAKEBASE_HOST = process.env.LAKEBASE_HOST ?? "";
const LAKEBASE_DB = process.env.LAKEBASE_DB ?? "databricks_postgres";
const WAREHOUSE_ID = process.env.DATABRICKS_WAREHOUSE_ID ?? "";
const MARGIN_MV = process.env.MARGIN_MV ?? "cdm_tmforum._metrics.margin_ledger_mv";
const GENIE_SPACE_ID = process.env.GENIE_SPACE_ID ?? "";
const MLFLOW_EXPERIMENT_ID = process.env.MLFLOW_EXPERIMENT_ID ?? "";
const PORT = Number(process.env.DATABRICKS_APP_PORT ?? process.env.PORT ?? 8000);

const APPROVER_ROLES = ["Ops", "AP", "FP&A"] as const;
type ApproverRole = (typeof APPROVER_ROLES)[number];

// ---------- workspace OAuth (app service principal) ----------
let cached: { token: string; exp: number } | null = null;
async function workspaceToken(): Promise<string> {
  if (cached && cached.exp > Date.now() + 60_000) return cached.token;
  const res = await fetch(`${HOST}/oidc/v1/token`, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      Authorization: "Basic " + Buffer.from(`${CLIENT_ID}:${CLIENT_SECRET}`).toString("base64"),
    },
    body: new URLSearchParams({ grant_type: "client_credentials", scope: "all-apis" }),
  });
  if (!res.ok) throw new Error(`OAuth token failed: ${res.status}`);
  const j = (await res.json()) as { access_token: string; expires_in: number };
  cached = { token: j.access_token, exp: Date.now() + j.expires_in * 1000 };
  return j.access_token;
}

async function dbx<T>(method: string, p: string, body?: unknown): Promise<T> {
  const res = await fetch(`${HOST}${p}`, {
    method,
    headers: { Authorization: `Bearer ${await workspaceToken()}`, "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`${method} ${p} -> ${res.status} ${await res.text()}`);
  return (await res.json()) as T;
}

// ---------- Lakebase pool (password = short-lived database credential) ----------
const pool = new pg.Pool({
  host: LAKEBASE_HOST,
  database: LAKEBASE_DB,
  user: CLIENT_ID,
  port: 5432,
  ssl: { rejectUnauthorized: true },
  max: 5,
  password: async () => (await dbx<{ token: string }>("POST", "/api/2.0/postgres/credentials", { endpoint: LAKEBASE_ENDPOINT })).token,
});

function approver(req: Request) {
  return {
    email: String(req.header("x-forwarded-email") ?? req.header("x-forwarded-preferred-username") ?? "unknown"),
    user: String(req.header("x-forwarded-user") ?? ""),
  };
}

// ---------- SQL warehouse (metric views) ----------
type StatementResult = {
  status: { state: string; error?: { message: string } };
  manifest?: { schema: { columns: { name: string }[] } };
  result?: { data_array?: (string | null)[][] };
};
async function runSql(statement: string, parameters: { name: string; value: string; type?: string }[] = []) {
  const r = await dbx<StatementResult>("POST", "/api/2.0/sql/statements", {
    warehouse_id: WAREHOUSE_ID,
    statement,
    parameters,
    wait_timeout: "50s",
    disposition: "INLINE",
    format: "JSON_ARRAY",
  });
  if (r.status.state !== "SUCCEEDED") throw new Error(r.status.error?.message ?? r.status.state);
  const cols = r.manifest?.schema.columns.map((c) => c.name) ?? [];
  return (r.result?.data_array ?? []).map((row) => Object.fromEntries(cols.map((c, i) => [c, row[i]])));
}

// Dimension whitelist (names from src/metric_views/margin_ledger_mv.yaml). Never interpolate user input otherwise.
const EXPLORER_DIMENSIONS = ["product_family", "family_class", "segment", "region", "network_type", "ledger_quarter", "ledger_month", "vendor_id"] as const;
export function explorerSql(dim: string): string {
  if (!(EXPLORER_DIMENSIONS as readonly string[]).includes(dim)) throw new Error("unsupported dimension");
  if (!/^[a-z_]+\.[a-z_]+\.margin_[a-z_]+$/.test(MARGIN_MV)) throw new Error("bad metric view name");
  return `SELECT ${dim} AS dimension,
  MEASURE(revenue) AS revenue,
  MEASURE(network_expense) AS network_expense,
  MEASURE(cost_to_serve) AS cost_to_serve,
  MEASURE(contribution_margin) AS contribution_margin,
  MEASURE(cm_pct) AS cm_pct,
  MEASURE(circuit_count) AS circuits
FROM ${MARGIN_MV}
WHERE (:quarter = '' OR ledger_quarter = TRY_CAST(:quarter AS DATE))
GROUP BY ALL
ORDER BY contribution_margin ASC`;
}

// ---------- API ----------
const app = express();
app.use(express.json());

app.get("/api/health", (_req, res) => res.json({ ok: true, app: "lakelink-margin-truth" }));
app.get("/api/me", (req, res) => res.json(approver(req)));
app.get("/api/config", (_req, res) => res.json({ genieSpaceId: GENIE_SPACE_ID, workspaceHost: HOST, mlflowExperimentId: MLFLOW_EXPERIMENT_ID, metricView: MARGIN_MV }));

app.get("/api/tickets", async (req: Request, res: Response) => {
  const role = String(req.query.role ?? "");
  const status = String(req.query.status ?? "pending");
  try {
    const { rows } = await pool.query(
      `SELECT ticket_id, ticket_type, approver_role, title, circuit_id, vendor_id, customer_id, monthly_cost, est_monthly_savings,
              rationale, agent_name, agent_sp_name, trace_id, status, created_at, decided_by, decided_at
         FROM public.approval_tickets
        WHERE ($1 = '' OR approver_role = $1) AND ($2 = 'all' OR status = $2)
        ORDER BY created_at DESC LIMIT 200`,
      [role, status],
    );
    res.json(rows);
  } catch (e) {
    res.status(500).json({ error: (e as Error).message });
  }
});

app.post("/api/tickets/:id/decision", async (req: Request, res: Response) => {
  const decision = String(req.body?.decision ?? "");
  const role = String(req.body?.role ?? "") as ApproverRole;
  const comment = String(req.body?.comment ?? "").slice(0, 2000);
  if (!["approved", "rejected"].includes(decision)) return res.status(400).json({ error: "decision must be approved or rejected" });
  if (!APPROVER_ROLES.includes(role)) return res.status(400).json({ error: "role must be Ops, AP or FP&A" });
  const who = approver(req);
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const upd = await client.query(
      `UPDATE public.approval_tickets SET status = $1, decided_by = $2, decided_role = $3, decided_at = NOW(), decision_comment = $4
        WHERE ticket_id = $5 AND status = 'pending' AND approver_role = $3 RETURNING *`,
      [decision, who.email, role, comment, req.params.id],
    );
    if (upd.rowCount !== 1) {
      await client.query("ROLLBACK");
      return res.status(409).json({ error: "ticket not pending for this approver role" });
    }
    await client.query(
      `INSERT INTO public.approval_audit (ticket_id, action, actor, actor_role, details) VALUES ($1, $2, $3, $4, $5)`,
      [req.params.id, decision, who.email, role, JSON.stringify({ comment, forwarded_user: who.user })],
    );
    await client.query("COMMIT");
    res.json(upd.rows[0]);
  } catch (e) {
    await client.query("ROLLBACK");
    res.status(500).json({ error: (e as Error).message });
  } finally {
    client.release();
  }
});

// Post-approval evidence: ticket + audit trail + agent identity + MLflow trace link (P3-APP-TRACE-VIEW extends this)
app.get("/api/tickets/:id/evidence", async (req: Request, res: Response) => {
  try {
    const t = await pool.query("SELECT * FROM public.approval_tickets WHERE ticket_id = $1", [req.params.id]);
    if (t.rowCount !== 1) return res.status(404).json({ error: "not found" });
    const a = await pool.query("SELECT action, actor, actor_role, details, at FROM public.approval_audit WHERE ticket_id = $1 ORDER BY at", [req.params.id]);
    const ticket = t.rows[0];
    const exp = ticket.mlflow_experiment_id || MLFLOW_EXPERIMENT_ID;
    res.json({
      ticket,
      audit: a.rows,
      agentIdentity: { name: ticket.agent_name, servicePrincipal: ticket.agent_sp_name, applicationId: ticket.agent_sp_app_id },
      traceUrl: ticket.trace_id && exp ? `${HOST}/ml/experiments/${exp}/traces?selectedEvaluationId=${encodeURIComponent(ticket.trace_id)}` : null,
    });
  } catch (e) {
    res.status(500).json({ error: (e as Error).message });
  }
});

app.get("/api/explorer", async (req: Request, res: Response) => {
  const dim = String(req.query.dim ?? "product_family");
  const quarter = String(req.query.quarter ?? "");
  try {
    const rows = await runSql(explorerSql(dim), [{ name: "quarter", value: quarter, type: "STRING" }]);
    res.json({ metricView: MARGIN_MV, dimension: dim, rows });
  } catch (e) {
    res.status(502).json({ error: (e as Error).message, metricView: MARGIN_MV });
  }
});

const here = path.dirname(fileURLToPath(import.meta.url));
const clientDir = path.resolve(here, "../client");
app.use(express.static(clientDir));
app.get("*", (_req, res) => res.sendFile(path.join(clientDir, "index.html")));

app.listen(PORT, () => console.log(`Lakelink Fiber Margin Truth listening on ${PORT}`));
