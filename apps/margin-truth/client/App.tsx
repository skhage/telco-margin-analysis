// Lakelink Fiber Margin Truth - ONE app: Approval Queue | Margin Explorer | Margin Genie (+ evidence panel after approval)
import { useCallback, useEffect, useRef, useState, type KeyboardEvent } from "react";

type Ticket = {
  ticket_id: string; ticket_type: string; approver_role: string; title: string;
  circuit_id: string | null; vendor_id: string | null; customer_id: string | null;
  monthly_cost: string | null; est_monthly_savings: string | null; rationale: string | null;
  agent_name: string; agent_sp_name: string | null; trace_id: string | null;
  status: string; created_at: string; decided_by: string | null; decided_at: string | null;
};
type Evidence = {
  ticket: Ticket; traceUrl: string | null;
  agentIdentity: { name: string; servicePrincipal: string | null; applicationId: string | null };
  audit: { action: string; actor: string; actor_role: string | null; at: string }[];
};
type ExplorerRow = Record<string, string | null>;
type Config = { genieSpaceId: string; workspaceHost: string; mlflowExperimentId: string; metricView: string };

const ROLES = ["Ops", "AP", "FP&A"] as const;
const DIMENSIONS: [string, string][] = [
  ["product_family", "Product Family"], ["family_class", "Legacy or Strategic"], ["segment", "Customer Segment"],
  ["region", "Sales Region"], ["network_type", "Network Type"], ["ledger_quarter", "Quarter"], ["vendor_id", "Vendor ID"],
];
const usd = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD", maximumFractionDigits: 0 });
const fmtUsd = (v: string | null) => (v == null ? "-" : usd.format(Number(v)));
const fmtPct = (v: string | null) => (v == null ? "-" : `${(Number(v) * 100).toFixed(1)}%`);

async function api<T>(url: string, init?: RequestInit): Promise<T> {
  const r = await fetch(url, { ...init, headers: { "Content-Type": "application/json" } });
  const j = await r.json();
  if (!r.ok) throw new Error(j.error ?? r.statusText);
  return j as T;
}

function ApprovalQueue() {
  const [role, setRole] = useState<(typeof ROLES)[number]>("Ops");
  const [status, setStatus] = useState("pending");
  const [tickets, setTickets] = useState<Ticket[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [evidence, setEvidence] = useState<Evidence | null>(null);
  const [savingId, setSavingId] = useState<string | null>(null);
  const [announce, setAnnounce] = useState("");
  const evidenceHeading = useRef<HTMLHeadingElement>(null);
  const focusEvidence = useRef(false);
  useEffect(() => {
    if (evidence && focusEvidence.current) { focusEvidence.current = false; evidenceHeading.current?.focus(); }
  }, [evidence]);

  const load = useCallback(() => {
    setTickets(null); setError(null);
    api<Ticket[]>(`/api/tickets?role=${encodeURIComponent(role)}&status=${status}`).then(setTickets).catch((e) => setError(e.message));
  }, [role, status]);
  useEffect(load, [load]);

  const showEvidence = (id: string) => api<Evidence>(`/api/tickets/${encodeURIComponent(id)}/evidence`).then(setEvidence).catch((e) => setError(e.message));
  const decide = async (id: string, title: string, decision: "approved" | "rejected") => {
    if (savingId) return; // prevents double submit
    setSavingId(id); setAnnounce("");
    try {
      await api(`/api/tickets/${encodeURIComponent(id)}/decision`, { method: "POST", body: JSON.stringify({ decision, role }) });
      setAnnounce(`${title} ${decision === "approved" ? "approved" : "rejected"} by ${role}. Decision recorded in the audit log.`);
      load();
      if (decision === "approved") { focusEvidence.current = true; await showEvidence(id); }
    } catch (e) {
      setError((e as Error).message);
      setAnnounce(`Could not save the decision for ${title}. Try again.`);
    } finally { setSavingId(null); }
  };

  return (
    <section aria-labelledby="queue-h">
      <h2 id="queue-h">Approval queue</h2>
      <p>Agents draft. People approve. Every decision is recorded with your identity.</p>
      <div className="llf-card" style={{ display: "flex", gap: 16, flexWrap: "wrap" }}>
        <label>Approver role{" "}
          <select value={role} onChange={(e) => setRole(e.target.value as (typeof ROLES)[number])}>
            {ROLES.map((r) => <option key={r}>{r}</option>)}
          </select>
        </label>
        <label>Status{" "}
          <select value={status} onChange={(e) => setStatus(e.target.value)}>
            <option value="pending">Pending</option><option value="approved">Approved</option>
            <option value="rejected">Rejected</option><option value="all">All</option>
          </select>
        </label>
      </div>
      <p className="llf-sr-only" aria-live="polite" role="status">{announce}</p>
      {error && <p role="alert" className="llf-error">{error}</p>}
      {tickets === null && !error && <p className="llf-state" aria-live="polite">Loading tickets...</p>}
      {tickets?.length === 0 && <p className="llf-state">No {status === "all" ? "" : status} tickets for {role}.</p>}
      {tickets && tickets.length > 0 && (
        <div className="llf-card llf-table-wrap">
          <table>
            <caption className="llf-state" style={{ textAlign: "left", padding: 0 }}>{tickets.length} ticket(s)</caption>
            <thead><tr><th>Ticket</th><th>Circuit</th><th>Vendor</th><th className="num">Monthly cost</th><th className="num">Est. monthly savings</th><th>Agent</th><th>Status</th><th>Action</th></tr></thead>
            <tbody>
              {tickets.map((t) => (
                <tr key={t.ticket_id}>
                  <td><strong>{t.title}</strong><br /><small>{t.ticket_id}</small></td>
                  <td>{t.circuit_id ?? "-"}</td><td>{t.vendor_id ?? "-"}</td>
                  <td className="num">{fmtUsd(t.monthly_cost)}</td><td className="num">{fmtUsd(t.est_monthly_savings)}</td>
                  <td>{t.agent_name}</td><td>{t.status}</td>
                  <td><div className="llf-actions">
                    {t.status === "pending" ? (savingId === t.ticket_id ? (
                      <button className="llf-btn" disabled aria-disabled="true">Saving...</button>
                    ) : (<>
                      <button className="llf-btn llf-btn--approve" disabled={savingId !== null} onClick={() => decide(t.ticket_id, t.title, "approved")} aria-label={`Approve ${t.title}`}>Approve</button>
                      <button className="llf-btn llf-btn--reject" disabled={savingId !== null} onClick={() => decide(t.ticket_id, t.title, "rejected")} aria-label={`Reject ${t.title}`}>Reject</button>
                    </>)) : (
                      <button className="llf-btn" onClick={() => { focusEvidence.current = true; showEvidence(t.ticket_id); }}>View evidence</button>
                    )}
                  </div></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {evidence && (
        <section className="llf-card" aria-labelledby="ev-h">
          <h3 id="ev-h" ref={evidenceHeading} tabIndex={-1}>Evidence for {evidence.ticket.ticket_id}</h3>
          <p><strong>Agent:</strong> {evidence.agentIdentity.name} | <strong>Service principal:</strong> {evidence.agentIdentity.servicePrincipal ?? "not recorded"} {evidence.agentIdentity.applicationId ? `(${evidence.agentIdentity.applicationId})` : ""}</p>
          <p><strong>MLflow trace:</strong> {evidence.traceUrl ? <a href={evidence.traceUrl} target="_blank" rel="noreferrer">Open trace {evidence.ticket.trace_id}</a> : "no trace recorded"}</p>
          <div className="llf-table-wrap"><table><caption className="llf-sr-only">Audit record</caption><thead><tr><th>When</th><th>Action</th><th>Actor</th><th>Role</th></tr></thead>
            <tbody>{evidence.audit.map((a, i) => <tr key={i}><td>{new Date(a.at).toLocaleString()}</td><td>{a.action}</td><td>{a.actor}</td><td>{a.actor_role ?? "-"}</td></tr>)}</tbody>
          </table></div>
        </section>
      )}
    </section>
  );
}

function MarginExplorer({ metricView }: { metricView: string }) {
  const [dim, setDim] = useState("product_family");
  const [rows, setRows] = useState<ExplorerRow[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  useEffect(() => {
    setRows(null); setError(null);
    api<{ rows: ExplorerRow[] }>(`/api/explorer?dim=${dim}`).then((r) => setRows(r.rows)).catch((e) => setError(e.message));
  }, [dim]);
  return (
    <section aria-labelledby="exp-h">
      <h2 id="exp-h">Margin explorer</h2>
      <p>Contribution margin comes from the governed metric view <code>{metricView}</code>. This app never recalculates it.</p>
      <div className="llf-card"><label>Break down by{" "}
        <select value={dim} onChange={(e) => setDim(e.target.value)}>{DIMENSIONS.map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select>
      </label></div>
      {error && <p role="alert" className="llf-error">Metric view unavailable: {error}</p>}
      {rows === null && !error && <p className="llf-state" aria-live="polite">Loading margin...</p>}
      {rows?.length === 0 && <p className="llf-state">No ledger rows yet.</p>}
      {rows && rows.length > 0 && (
        <div className="llf-card llf-table-wrap"><table>
          <caption className="llf-sr-only">Margin by {DIMENSIONS.find(([k]) => k === dim)?.[1]}</caption>
          <thead><tr><th>{DIMENSIONS.find(([k]) => k === dim)?.[1]}</th><th className="num">Revenue</th><th className="num">Network Expense</th><th className="num">Cost to Serve</th><th className="num">Contribution Margin</th><th className="num">CM %</th><th className="num">Circuits</th></tr></thead>
          <tbody>{rows.map((r, i) => (
            <tr key={i}>
              <td>{r.dimension ?? "(not set)"}</td><td className="num">{fmtUsd(r.revenue)}</td><td className="num">{fmtUsd(r.network_expense)}</td>
              <td className="num">{fmtUsd(r.cost_to_serve)}</td>
              <td className={`num ${Number(r.contribution_margin) < 0 ? "neg" : ""}`}>{fmtUsd(r.contribution_margin)}{Number(r.contribution_margin) < 0 ? " (loss)" : ""}</td>
              <td className="num">{fmtPct(r.cm_pct)}</td><td className="num">{r.circuits ?? "-"}</td>
            </tr>))}</tbody>
        </table></div>
      )}
    </section>
  );
}

function MarginGenie({ cfg }: { cfg: Config }) {
  if (!cfg.genieSpaceId) return <p className="llf-state">Margin Genie is being set up. It will appear here once the ONE Margin Genie space is published.</p>;
  return (
    <section aria-labelledby="genie-h">
      <h2 id="genie-h">Margin Genie</h2>
      <p>Ask in plain English. Finance, Ops, Sales and Marketing share one Genie and one definition of margin.</p>
      <iframe title="Margin Genie" className="llf-genie" src={`${cfg.workspaceHost}/genie/rooms/${cfg.genieSpaceId}?isEmbedded=true`} />
    </section>
  );
}

const TABS = ["Approval queue", "Margin explorer", "Margin Genie"] as const;
const tabId = (i: number) => `llf-tab-${i}`;
const panelId = (i: number) => `llf-panel-${i}`;
export default function App() {
  const [tab, setTab] = useState<(typeof TABS)[number]>("Approval queue");
  const tabRefs = useRef<(HTMLButtonElement | null)[]>([]);
  const active = TABS.indexOf(tab);
  const onTabKey = (e: KeyboardEvent<HTMLButtonElement>) => {
    const last = TABS.length - 1;
    const next = e.key === "ArrowRight" ? (active === last ? 0 : active + 1)
      : e.key === "ArrowLeft" ? (active === 0 ? last : active - 1)
      : e.key === "Home" ? 0 : e.key === "End" ? last : -1;
    if (next < 0) return;
    e.preventDefault();
    setTab(TABS[next]);
    tabRefs.current[next]?.focus();
  };
  const [cfg, setCfg] = useState<Config>({ genieSpaceId: "", workspaceHost: "", mlflowExperimentId: "", metricView: "cdm_tmforum._metrics.margin_ledger_mv" });
  useEffect(() => { api<Config>("/api/config").then(setCfg).catch(() => undefined); }, []);
  return (
    <>
      <header className="llf-header"><span className="llf-mark" aria-hidden="true" /><h1>Lakelink Fiber | Margin Truth</h1></header>
      <nav className="llf-tabs" role="tablist" aria-label="Sections">
        {TABS.map((t, i) => (
          <button key={t} ref={(el) => { tabRefs.current[i] = el; }} id={tabId(i)} role="tab" className="llf-tab"
            aria-selected={tab === t} aria-controls={panelId(i)} tabIndex={tab === t ? 0 : -1}
            onClick={() => setTab(t)} onKeyDown={onTabKey}>{t}</button>
        ))}
      </nav>
      <main>
        <div role="tabpanel" id={panelId(active)} aria-labelledby={tabId(active)} tabIndex={0} className="llf-panel">
          {tab === "Approval queue" && <ApprovalQueue />}
          {tab === "Margin explorer" && <MarginExplorer metricView={cfg.metricView} />}
          {tab === "Margin Genie" && <MarginGenie cfg={cfg} />}
        </div>
      </main>
    </>
  );
}
