// Lakelink Fiber Margin Truth - API server (Express + pg). ONE app for telco-margin-analysis.
// Approval queue: Lakebase project LAKEBASE_ENDPOINT, schema public only.
// Margin explorer: reads the MARGIN_MV metric view with MEASURE(); never recomputes margin (DEC-002).
// CONFIG: every name comes from app.yaml env, which scripts/sync_config_surfaces.py fills from bundle/project_config.yml.
import express, { Request, Response } from "express";
import pg from "pg";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HOST = (process.env.DATABRICKS_HOST ?? "").replace(/^(?!https?:\/\/)/, "https://");
const CLIENT_ID = process.env.DATABRICKS_CLIENT_ID ?? "";
const CLIENT_SECRET = process.env.DATABRICKS_CLIENT_SECRET ?? "";
const LAKEBASE_ENDPOINT = process.env.LAKEBASE_ENDPOINT ?? "";
const LAKEBASE_HOST = process.env.LAKEBASE_HOST ?? "";
const LAKEBASE_DB = process.env.LAKEBASE_DB ?? "databricks_postgres";
const WAREHOUSE_ID = process.env.DATABRICKS_WAREHOUSE_ID ?? "";
const MARGIN_MV = process.env.MARGIN_MV ?? "";
for (const [k, v] of Object.entries({ LAKEBASE_ENDPOINT, MARGIN_MV })) {
  if (!v) console.warn(`config: ${k} is not set (app.yaml env, from bundle/project_config.yml)`);
}
const GENIE_SPACE_ID = process.env.GENIE_SPACE_ID ?? "";
const MLFLOW_EXPERIMENT_ID = process.env.MLFLOW_EXPERIMENT_ID ?? "";
// Feature flag (APP-EXPLORER-PRESTAGE): auto = go live as soon as the metric view exists; on = always query; off = hide.
const EXPLORER_MODE = (process.env.MARGIN_EXPLORER_MODE ?? "auto").toLowerCase() as "auto" | "on" | "off";
const PORT = Number(process.env.DATABRICKS_APP_PORT ?? process.env.PORT ?? 8000);
// APP-HIDE-TEST-TICKETS (DEC-018 fallback): TEST-* tickets are hidden from queue, decisions and evidence unless SHOW_TEST_TICKETS=true. Rows are never deleted.
const SHOW_TEST_TICKETS = (process.env.SHOW_TEST_TICKETS ?? "false").toLowerCase() === "true";
const isHiddenTestTicket = (id: string) => !SHOW_TEST_TICKETS && id.toUpperCase().startsWith("TEST-");

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

// App SP token: ONLY for the app's own Lakebase credential. Never used to read Unity Catalog data (DEC-SOX-OBO).
async function dbx<T>(method: string, p: string, body?: unknown, bearer?: string): Promise<T> {
  const res = await fetch(`${HOST}${p}`, {
    method,
    headers: { Authorization: `Bearer ${bearer ?? (await workspaceToken())}`, "Content-Type": "application/json" },
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

// ---------- On-behalf-of user (DEC-SOX-OBO) ----------
// Every Unity Catalog read (SQL warehouse + Genie) runs as the signed-in user with the forwarded token, so the
// SOX ABAC policies (margin_sox_key_accounts, margin_sox_detail_rows, margin_sox_contract_rates) apply per user.
// Fail closed: no forwarded token = no UC data. There is no service-principal fallback.
class NoUserToken extends Error {}
function userToken(req: Request): string {
  const t = req.header("x-forwarded-access-token");
  if (!t) throw new NoUserToken("No forwarded user token. Enable user authorization (scopes sql, dashboards.genie) on the app.");
  return t;
}
const whoKey = (req: Request) => String(req.header("x-forwarded-email") ?? req.header("x-forwarded-user") ?? "unknown");

// ---------- SQL warehouse (metric views) ----------
type StatementResult = {
  status: { state: string; error?: { message: string } };
  manifest?: { schema: { columns: { name: string }[] } };
  result?: { data_array?: (string | null)[][] };
};
async function runSql(req: Request, statement: string, parameters: { name: string; value: string; type?: string }[] = []) {
  const r = await dbx<StatementResult>("POST", "/api/2.0/sql/statements", {
    warehouse_id: WAREHOUSE_ID,
    statement,
    parameters,
    wait_timeout: "50s",
    disposition: "INLINE",
    format: "JSON_ARRAY",
  }, userToken(req));
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

// APP-EXPLORER-TOTAL-ROW: portfolio total straight from the metric view (ungrouped MEASURE), never summed in the client (DEC-002/DEC-020).
export function explorerTotalSql(): string {
  if (!/^[a-z_]+\.[a-z_]+\.margin_[a-z_]+$/.test(MARGIN_MV)) throw new Error("bad metric view name");
  return `SELECT
  MEASURE(revenue) AS revenue,
  MEASURE(network_expense) AS network_expense,
  MEASURE(cost_to_serve) AS cost_to_serve,
  MEASURE(contribution_margin) AS contribution_margin,
  MEASURE(cm_pct) AS cm_pct,
  MEASURE(circuit_count) AS circuits
FROM ${MARGIN_MV}
WHERE (:quarter = '' OR ledger_quarter = TRY_CAST(:quarter AS DATE))`;
}

// DSN-SCENE5-R1 item 4: vendor display names (fictional Lakelink-safe carrier names) from the governed vendor table.
// Loaded once (30 rows), cached 10 min. If the warehouse or grant is unavailable, the UI falls back to the raw vendor_id.
const MARGIN_VENDORS = process.env.MARGIN_VENDORS ?? "";
// Cached per user (OBO): one user's result is never served to another.
const vendorCache = new Map<string, { names: Record<string, string>; at: number }>();
async function vendorNames(req: Request): Promise<Record<string, string>> {
  const k = whoKey(req);
  const hit = vendorCache.get(k);
  if (hit && Date.now() - hit.at < 600_000) return hit.names;
  try {
    if (!/^[a-z_]+\.[a-z_]+\.margin_[a-z_]+$/.test(MARGIN_VENDORS)) throw new Error("bad vendor table name");
    const rows = await runSql(req, `SELECT vendor_id, vendor_name FROM ${MARGIN_VENDORS}`);
    const names = Object.fromEntries(rows.filter((r) => r.vendor_id && r.vendor_name).map((r) => [String(r.vendor_id), String(r.vendor_name)]));
    vendorCache.set(k, { names, at: Date.now() });
    return names;
  } catch (e) {
    console.warn(`vendor name lookup failed: ${(e as Error).message}`);
    return hit?.names ?? {};
  }
}

// SOX detail access is decided by Unity Catalog, not by the app: run a 1-row probe on the SOX carrier invoice
// sub-ledger AS THE USER. If ABAC policy margin_sox_detail_rows hides every line, the user is not SOX-entitled and
// the app also redacts the carrier cost copied into Lakebase tickets (Lakebase is outside UC policies). Cached 5 min per user.
const SOX_PROBE_TABLE = MARGIN_VENDORS.replace(/\.margin_vendors$/, ".margin_carrier_invoices");
const soxCache = new Map<string, { sox: boolean; at: number }>();
async function soxDetailAccess(req: Request): Promise<boolean> {
  const k = whoKey(req);
  const hit = soxCache.get(k);
  if (hit && Date.now() - hit.at < 300_000) return hit.sox;
  let sox = false;
  try {
    if (!/^[a-z_]+\.[a-z_]+\.margin_carrier_invoices$/.test(SOX_PROBE_TABLE)) throw new Error("bad SOX probe table name");
    const rows = await runSql(req, `SELECT 1 AS ok FROM ${SOX_PROBE_TABLE} LIMIT 1`);
    sox = rows.length === 1;
  } catch (e) {
    console.warn(`SOX probe failed (treated as no access): ${(e as Error).message}`);
  }
  soxCache.set(k, { sox, at: Date.now() });
  return sox;
}
const redactSox = <T extends Record<string, unknown>>(row: T, sox: boolean) =>
  sox ? row : { ...row, monthly_cost: null, est_monthly_savings: null, sox_redacted: true };
const withVendorName = <T extends { vendor_id?: string | null }>(row: T, names: Record<string, string>) =>
  ({ ...row, vendor_name: row.vendor_id ? names[row.vendor_id] ?? null : null });

// Explorer readiness: in auto mode, check the metric view exists (cached 60s) so the tab goes live the moment it deploys.
let mvCheck: { ready: boolean; at: number } | null = null;
export async function explorerReady(req: Request): Promise<boolean> {
  if (EXPLORER_MODE === "off") return false;
  if (EXPLORER_MODE === "on") return true;
  if (mvCheck && Date.now() - mvCheck.at < 60_000) return mvCheck.ready;
  const [cat, sch, name] = MARGIN_MV.split(".");
  if (!/^[a-z_]+$/.test(cat ?? "")) throw new Error("bad metric view name");
  const rows = await runSql(
    req,
    `SELECT table_type FROM ${cat}.information_schema.tables WHERE table_schema = :sch AND table_name = :name`,
    [{ name: "sch", value: sch ?? "" }, { name: "name", value: name ?? "" }],
  );
  // Only cache a positive result: a user without access to the view must not mark it missing for everyone.
  if (rows.length === 1) mvCheck = { ready: true, at: Date.now() };
  return rows.length === 1;
}

// ---------- API ----------
const app = express();
app.use(express.json());

app.get("/api/health", (_req, res) => res.json({ ok: true, app: "lakelink-margin-truth" }));
app.get("/api/me", async (req, res) => {
  try {
    res.json({ ...approver(req), soxDetailAccess: await soxDetailAccess(req) });
  } catch (e) {
    res.json({ ...approver(req), soxDetailAccess: false, error: (e as Error).message });
  }
});
app.get("/api/config", (_req, res) => res.json({ genieSpaceId: GENIE_SPACE_ID, workspaceHost: HOST, mlflowExperimentId: MLFLOW_EXPERIMENT_ID, metricView: MARGIN_MV }));

// ---------- Margin Genie (Genie Conversation API, native chat - no iframe) ----------
// DEC-SOX-OBO: Genie always runs as the signed-in user (forwarded token, dashboards.genie scope), so each user's
// answers reflect their own SOX entitlements. The GENIE_AUTH env var is no longer read.
const GENIE_ID_RE = /^[0-9a-zA-Z-]+$/;
const GENIE_DONE = new Set(["COMPLETED", "FAILED", "CANCELLED", "QUERY_RESULT_EXPIRED"]);
type GenieAttachment = {
  attachment_id?: string;
  text?: { content?: string };
  query?: { query?: string; description?: string; title?: string };
  suggested_questions?: { questions?: string[] };
};
type GenieMessage = { id?: string; message_id?: string; status: string; attachments?: GenieAttachment[]; error?: { error?: string; type?: string } };
type GenieQueryResult = {
  statement_response?: {
    manifest?: { schema?: { columns?: { name: string }[] }; total_row_count?: number };
    result?: { data_array?: (string | null)[][] };
  };
};

async function genie<T>(req: Request, method: string, p: string, body?: unknown): Promise<T> {
  const token = userToken(req);
  const res = await fetch(`${HOST}/api/2.0/genie/spaces/${GENIE_SPACE_ID}${p}`, {
    method,
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`Genie ${res.status}: ${(await res.text()).slice(0, 500)}`);
  return (await res.json()) as T;
}

// Start a conversation, or add a follow-up to an existing one. Returns ids immediately; the client polls for the answer.
app.post("/api/genie/ask", async (req: Request, res: Response) => {
  if (!GENIE_SPACE_ID) return res.status(503).json({ error: "Margin Genie is not configured" });
  const question = String(req.body?.question ?? "").trim().slice(0, 4000);
  const conversationId = String(req.body?.conversationId ?? "");
  if (!question) return res.status(400).json({ error: "question is required" });
  if (conversationId && !GENIE_ID_RE.test(conversationId)) return res.status(400).json({ error: "bad conversation id" });
  try {
    if (conversationId) {
      const m = await genie<GenieMessage>(req, "POST", `/conversations/${conversationId}/messages`, { content: question });
      return res.json({ conversationId, messageId: m.message_id ?? m.id });
    }
    const r = await genie<{ conversation_id: string; message_id: string }>(req, "POST", "/start-conversation", { content: question });
    res.json({ conversationId: r.conversation_id, messageId: r.message_id });
  } catch (e) {
    console.warn(`genie ask failed: ${(e as Error).message}`);
    res.status(502).json({ error: (e as Error).message });
  }
});

// Poll a message. When finished, inline text answers, generated SQL, suggested questions and query results (first 200 rows).
app.get("/api/genie/conversations/:cid/messages/:mid", async (req: Request, res: Response) => {
  const { cid, mid } = req.params;
  if (!GENIE_SPACE_ID) return res.status(503).json({ error: "Margin Genie is not configured" });
  if (!GENIE_ID_RE.test(cid) || !GENIE_ID_RE.test(mid)) return res.status(400).json({ error: "bad id" });
  try {
    const m = await genie<GenieMessage>(req, "GET", `/conversations/${cid}/messages/${mid}`);
    const done = GENIE_DONE.has(m.status);
    const attachments = await Promise.all(
      (done ? m.attachments ?? [] : []).map(async (a) => {
        const out = {
          id: a.attachment_id ?? null,
          text: a.text?.content ?? null,
          sql: a.query?.query ?? null,
          description: a.query?.description ?? null,
          title: a.query?.title ?? null,
          suggestions: a.suggested_questions?.questions ?? [],
          columns: [] as string[],
          rows: [] as (string | null)[][],
          rowCount: 0,
          resultError: null as string | null,
        };
        if (a.query && a.attachment_id && m.status === "COMPLETED") {
          try {
            const qr = await genie<GenieQueryResult>(req, "GET", `/conversations/${cid}/messages/${mid}/attachments/${a.attachment_id}/query-result`);
            const sr = qr.statement_response;
            const data = sr?.result?.data_array ?? [];
            out.columns = sr?.manifest?.schema?.columns?.map((c) => c.name) ?? [];
            out.rowCount = sr?.manifest?.total_row_count ?? data.length;
            out.rows = data.slice(0, 200);
          } catch (e) {
            out.resultError = (e as Error).message;
          }
        }
        return out;
      }),
    );
    res.json({ status: m.status, done, error: m.error?.error ?? null, attachments });
  } catch (e) {
    console.warn(`genie poll failed: ${(e as Error).message}`);
    res.status(502).json({ error: (e as Error).message });
  }
});

app.get("/api/tickets", async (req: Request, res: Response) => {
  const role = String(req.query.role ?? "");
  const status = String(req.query.status ?? "pending");
  try {
    const { rows } = await pool.query(
      `SELECT ticket_id, ticket_type, approver_role, title, circuit_id, vendor_id, customer_id, monthly_cost, est_monthly_savings,
              rationale, agent_name, agent_sp_name, trace_id, status, created_at, decided_by, decided_at
         FROM public.approval_tickets
        WHERE ($1 = '' OR approver_role = $1) AND ($2 = 'all' OR status = $2)
          AND ($3::boolean OR ticket_id NOT ILIKE 'TEST-%')
        ORDER BY created_at DESC LIMIT 200`,
      [role, status, SHOW_TEST_TICKETS],
    );
    const [names, sox] = await Promise.all([vendorNames(req), soxDetailAccess(req)]);
    res.json(rows.map((r) => redactSox(withVendorName(r, names), sox)));
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
  if (isHiddenTestTicket(req.params.id)) return res.status(404).json({ error: "not found" });
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
  if (isHiddenTestTicket(req.params.id)) return res.status(404).json({ error: "not found" });
  try {
    const t = await pool.query("SELECT * FROM public.approval_tickets WHERE ticket_id = $1", [req.params.id]);
    if (t.rowCount !== 1) return res.status(404).json({ error: "not found" });
    const a = await pool.query("SELECT action, actor, actor_role, details, at FROM public.approval_audit WHERE ticket_id = $1 ORDER BY at", [req.params.id]);
    const ticket = redactSox(withVendorName(t.rows[0], await vendorNames(req)), await soxDetailAccess(req));
    // APP-TRACE-VIEW-PREBUILD: the agent's 'created' audit row carries run_as / identity_mode / trace_id (grooming agent writes these).
    const created = a.rows.find((r) => r.action === "created");
    const createdDetails = (created?.details ?? {}) as Record<string, unknown>;
    const traceId: string | null = ticket.trace_id || (typeof createdDetails.trace_id === "string" ? createdDetails.trace_id : null);
    const exp: string = ticket.mlflow_experiment_id || MLFLOW_EXPERIMENT_ID;
    // ML-GROOMING-FALLBACK-PATH: when no agent SP is recorded, the agent ran under a user identity.
    const identityMode = ticket.agent_sp_name || ticket.agent_sp_app_id ? "service_principal" : "user_fallback";
    res.json({
      ticket,
      audit: a.rows,
      agentIdentity: {
        name: ticket.agent_name,
        servicePrincipal: ticket.agent_sp_name,
        applicationId: ticket.agent_sp_app_id,
        identityMode,
        runAs: typeof createdDetails.run_as === "string" ? createdDetails.run_as : created?.actor ?? null,
      },
      traceId,
      experimentId: exp || null,
      traceUrl: traceId && exp ? `${HOST}/ml/experiments/${encodeURIComponent(exp)}/traces?selectedEvaluationId=${encodeURIComponent(traceId)}` : null,
    });
  } catch (e) {
    res.status(500).json({ error: (e as Error).message });
  }
});

app.get("/api/explorer/status", async (req: Request, res: Response) => {
  try {
    res.json({ mode: EXPLORER_MODE, ready: await explorerReady(req), metricView: MARGIN_MV });
  } catch (e) {
    res.status(502).json({ error: (e as Error).message, mode: EXPLORER_MODE, metricView: MARGIN_MV });
  }
});

app.get("/api/explorer", async (req: Request, res: Response) => {
  const dim = String(req.query.dim ?? "product_family");
  const quarter = String(req.query.quarter ?? "");
  try {
    if (!(await explorerReady(req))) return res.status(503).json({ error: "pending_mv", metricView: MARGIN_MV });
    const params = [{ name: "quarter", value: quarter, type: "STRING" }];
    const [rows, totals] = await Promise.all([runSql(req, explorerSql(dim), params), runSql(req, explorerTotalSql(), params)]);
    res.json({ metricView: MARGIN_MV, dimension: dim, rows, total: totals[0] ?? null });
  } catch (e) {
    res.status(502).json({ error: (e as Error).message, metricView: MARGIN_MV });
  }
});

const here = path.dirname(fileURLToPath(import.meta.url));
const clientDir = path.resolve(here, "../client");
app.use(express.static(clientDir));
app.get("*", (_req, res) => res.sendFile(path.join(clientDir, "index.html")));

app.listen(PORT, () => console.log(`Lakelink Fiber Margin Truth listening on ${PORT}`));
