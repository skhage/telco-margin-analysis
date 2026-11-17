// Lakelink Fiber Margin Truth - ONE app: Approval Queue | Margin Explorer | Margin Genie (+ evidence panel after approval)
import { useCallback, useEffect, useRef, useState, type KeyboardEvent, type ReactNode } from "react";

type Ticket = {
  ticket_id: string; ticket_type: string; approver_role: string; title: string;
  circuit_id: string | null; vendor_id: string | null; vendor_name?: string | null; customer_id: string | null;
  monthly_cost: string | null; est_monthly_savings: string | null; rationale: string | null;
  agent_name: string; agent_sp_name: string | null; trace_id: string | null;
  status: string; created_at: string; decided_by: string | null; decided_at: string | null;
};
type Evidence = {
  ticket: Ticket; traceUrl: string | null; traceId: string | null; experimentId: string | null;
  agentIdentity: { name: string; servicePrincipal: string | null; applicationId: string | null; identityMode: "service_principal" | "user_fallback"; runAs: string | null };
  audit: { action: string; actor: string; actor_role: string | null; details: Record<string, unknown> | null; at: string }[];
};
// APP-TRACE-VIEW-PREBUILD: short, readable summary of an audit row's details JSON (comment, identity mode, score)
const auditDetail = (d: Record<string, unknown> | null): ReactNode => {
  if (!d) return <NotAvailable />;
  const parts: string[] = [];
  if (typeof d.comment === "string" && d.comment) parts.push(`Comment: ${d.comment}`);
  // DSN-TRACE-PANEL-R1 item 2: one identity phrase, matching the evidence panel wording
  if (d.identity_mode === "user_fallback") parts.push(typeof d.run_as === "string" && d.run_as ? `User identity (fallback): ran as ${d.run_as}` : "User identity (fallback)");
  else if (typeof d.run_as === "string" && d.run_as) parts.push(`Ran as ${d.run_as}`);
  if (d.score != null) parts.push(`On-net score ${String(d.score)}`);
  return parts.length ? parts.join("; ") : <NotAvailable />;
};
type ExplorerRow = Record<string, string | null>;
type Config = { genieSpaceId: string; workspaceHost: string; mlflowExperimentId: string; metricView: string };

const ROLES = ["Ops", "AP", "FP&A"] as const;
const DIMENSIONS: [string, string][] = [
  ["product_family", "Product Family"], ["family_class", "Legacy or Strategic"], ["segment", "Customer Segment"],
  ["region", "Sales Region"], ["network_type", "Network Type"], ["ledger_quarter", "Quarter"], ["vendor_id", "Vendor ID"],
];
// DEC-030: every USD value to the cent (2 dp) so the CM string matches Genie/dashboard/agent exactly
const usd = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD", minimumFractionDigits: 2, maximumFractionDigits: 2 });
// Missing values: em dash announced as 'not available' (DS-APP-UX-POLISH item 2)
const NotAvailable = () => <span role="img" aria-label="not available">—</span>;
const orNA = (v: ReactNode | null | undefined): ReactNode => (v == null || v === "" ? <NotAvailable /> : v);
const fmtUsd = (v: string | null): ReactNode => (v == null ? <NotAvailable /> : usd.format(Number(v)));
const fmtPct = (v: string | null): ReactNode => (v == null ? <NotAvailable /> : `${(Number(v) * 100).toFixed(1)}%`);
// Status badge in sentence case (DS-APP-UX-POLISH item 1)
const sentence = (s: string) => (s ? s.charAt(0).toUpperCase() + s.slice(1).toLowerCase() : s);
const StatusBadge = ({ status }: { status: string }) => (
  <span className={`llf-badge llf-badge--${status.toLowerCase()}`}>{sentence(status)}</span>
);
const plural = (n: number, one: string, many: string) => `${n} ${n === 1 ? one : many}`;
// DSN-TRACE-PANEL-R1 item 3: evidence timestamps always show the time zone
const DATE_FMT: Intl.DateTimeFormatOptions = { dateStyle: "medium", timeStyle: "short", timeZoneName: "short" };
const fmtWhen = (v: string) => new Date(v).toLocaleString(undefined, DATE_FMT);
// DSN-TRACE-PANEL-R1 item 5: Lucide ExternalLink (16px, 1.5px stroke), inlined so no new dependency
const ExternalLinkIcon = () => (
  <svg aria-hidden="true" focusable="false" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" style={{ verticalAlign: "-3px", marginLeft: 4 }}>
    <path d="M15 3h6v6" /><path d="M10 14 21 3" /><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6" />
  </svg>
);

// Workbook grid columns (A..K). Row 1 is the header row, so data rows start at 2, like a spreadsheet.
const Q_COLS = ["Ticket ID", "Title", "Rationale", "Circuit", "Vendor", "Monthly cost", "Est. monthly savings", "Agent", "Status", "Comment (optional)", "Action"] as const;
const Q_NUM_COLS = new Set([5, 6]);
const colLetter = (i: number) => String.fromCharCode(65 + i);
const usdText = (v: string | null) => (v == null ? "" : usd.format(Number(v)));
const GRID_KEYS: Record<string, [number, number]> = { ArrowUp: [-1, 0], ArrowDown: [1, 0], ArrowLeft: [0, -1], ArrowRight: [0, 1] };

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
  // DSN-SCENE5-R1 item 2: optional approver comment per ticket (server caps at 2000 chars)
  const [comments, setComments] = useState<Record<string, string>>({});
  const evidenceHeading = useRef<HTMLHeadingElement>(null);
  const focusEvidence = useRef(false);
  // Workbook grid: selected cell drives the formula bar; arrow keys move between cells, Enter/F2 enters a cell's control, Esc returns
  const [sel, setSel] = useState<{ r: number; c: number }>({ r: 0, c: 0 });
  const gridRef = useRef<HTMLTableElement>(null);
  useEffect(() => {
    if (evidence && focusEvidence.current) { focusEvidence.current = false; evidenceHeading.current?.focus(); }
  }, [evidence]);

  // DSN-APP-QUEUE-LIVE-R1: loading state is announced through the single persistent role=status region (designer note 247).
  // announceLoad=false after a decision so the decision announcement is not overwritten.
  const load = useCallback((announceLoad: boolean = true) => {
    setTickets(null); setError(null); setEvidence(null); // DSN-TRACE-PANEL-R1 item 4: never show a stale panel
    if (announceLoad) setAnnounce("Loading tickets...");
    api<Ticket[]>(`/api/tickets?role=${encodeURIComponent(role)}&status=${status}`)
      .then((rows) => { setTickets(rows); setSel({ r: 0, c: 0 }); if (announceLoad) setAnnounce(`${plural(rows.length, "ticket", "tickets")} loaded.`); })
      .catch((e) => setError(`Approval queue unavailable. Try again, or check that the Lakebase approval database is reachable. (${e.message})`));
  }, [role, status]);
  useEffect(() => { load(); }, [load]);

  const showEvidence = (id: string) => { setEvidence(null); return api<Evidence>(`/api/tickets/${encodeURIComponent(id)}/evidence`).then(setEvidence).catch((e) => setError(`Evidence could not be loaded. Try again in a moment. (${e.message})`)); };
  const decide = async (id: string, title: string, decision: "approved" | "rejected") => {
    if (savingId) return; // prevents double submit
    setSavingId(id); setAnnounce("");
    try {
      await api(`/api/tickets/${encodeURIComponent(id)}/decision`, { method: "POST", body: JSON.stringify({ decision, role, comment: (comments[id] ?? "").trim() }) });
      setComments((c) => { const { [id]: _done, ...rest } = c; return rest; });
      setAnnounce(`${title} ${decision === "approved" ? "approved" : "rejected"} by ${role}. Decision recorded in the audit log.`);
      load(false);
      if (decision === "approved") { focusEvidence.current = true; await showEvidence(id); }
    } catch (e) {
      setError(`Decision not saved for ${title}. Try again; if it repeats, the ticket may already be decided. (${(e as Error).message})`);
      setAnnounce(`Could not save the decision for ${title}. Try again.`);
    } finally { setSavingId(null); }
  };

  // Plain-text value per column for the formula bar (same formatting as the cells)
  const cellText = (t: Ticket, c: number): string => {
    switch (c) {
      case 0: return t.ticket_id;
      case 1: return t.title;
      case 2: return t.rationale ?? "";
      case 3: return t.circuit_id ?? "";
      case 4: return t.vendor_name ? `${t.vendor_name} (${t.vendor_id ?? ""})` : t.vendor_id ?? "";
      case 5: return usdText(t.monthly_cost);
      case 6: return usdText(t.est_monthly_savings);
      case 7: return t.agent_name;
      case 8: return sentence(t.status);
      case 9: return comments[t.ticket_id] ?? "";
      default: return t.status === "pending" ? "Approve or reject" : "View evidence";
    }
  };
  const moveTo = (r: number, c: number) => {
    if (!tickets?.length) return;
    const rr = Math.max(0, Math.min(tickets.length - 1, r));
    const cc = Math.max(0, Math.min(Q_COLS.length - 1, c));
    setSel({ r: rr, c: cc });
    requestAnimationFrame(() => gridRef.current?.querySelector<HTMLElement>(`td[data-r="${rr}"][data-c="${cc}"]`)?.focus());
  };
  const onGridKey = (e: KeyboardEvent<HTMLTableElement>) => {
    const el = e.target as HTMLElement;
    if (e.key === "Escape" && el.tagName !== "TD") { el.closest<HTMLElement>("td")?.focus(); return; }
    if (el.tagName !== "TD") return;
    const d = GRID_KEYS[e.key];
    if (d) { e.preventDefault(); moveTo(sel.r + d[0], sel.c + d[1]); return; }
    if (e.key === "Enter" || e.key === "F2") {
      const ctl = el.querySelector<HTMLElement>("input:not([disabled]), button:not([disabled])");
      if (ctl) { e.preventDefault(); ctl.focus(); }
    }
  };
  const cell = (r: number, c: number, extra = "") => {
    const on = sel.r === r && sel.c === c;
    return {
      "data-r": r, "data-c": c, tabIndex: on ? 0 : -1,
      className: `llf-cell ${extra}${on ? " llf-cell--sel" : ""}`,
      onMouseDown: () => setSel({ r, c }), onFocus: () => setSel({ r, c }),
    };
  };
  const selTicket = tickets?.[sel.r];

  return (
    <section aria-labelledby="queue-h" className="llf-sheet">
      <h2 id="queue-h" className="llf-sr-only">Approval queue</h2>
      <div className="llf-toolbar">
        <label>Approver role
          <select value={role} onChange={(e) => setRole(e.target.value as (typeof ROLES)[number])}>
            {ROLES.map((r) => <option key={r}>{r}</option>)}
          </select>
        </label>
        <label>Status
          <select value={status} onChange={(e) => setStatus(e.target.value)}>
            <option value="pending">Pending</option><option value="approved">Approved</option>
            <option value="rejected">Rejected</option><option value="all">All</option>
          </select>
        </label>
        <span className="llf-toolbar-sep" aria-hidden="true" />
        <button type="button" className="llf-btn llf-btn--sm" onClick={() => load()} disabled={tickets === null && !error}>Refresh</button>
        <span className="llf-toolbar-note">{tickets ? `${plural(tickets.length, "ticket", "tickets")} · ` : ""}Agents draft. People approve. Every decision is recorded with your identity.</span>
      </div>
      <div className="llf-fbar">
        <span className="llf-fbar-ref" aria-label="Selected cell">{selTicket ? `${colLetter(sel.c)}${sel.r + 2}` : "A1"}</span>
        <span className="llf-fbar-fx" aria-hidden="true">fx</span>
        <span className="llf-fbar-val" title={selTicket ? cellText(selTicket, sel.c) : undefined}>
          {selTicket ? cellText(selTicket, sel.c) : Q_COLS[sel.c]}
        </span>
      </div>
      <p className="llf-sr-only" aria-live="polite" role="status">{announce}</p>
      <div className="llf-sheet-body">
        <div className="llf-grid-wrap">
          {error && <p role="alert" className="llf-error llf-grid-msg">{error}</p>}
          {tickets === null && !error && <p className="llf-state">Loading tickets...</p>}
          {tickets?.length === 0 && <p className="llf-state">No {status === "all" ? "" : status} tickets for {role}.</p>}
          {tickets && tickets.length > 0 && (
            <table className="llf-grid" ref={gridRef} onKeyDown={onGridKey}
              aria-describedby="llf-grid-help">
              <caption className="llf-sr-only">{plural(tickets.length, "ticket", "tickets")}</caption>
              <thead><tr>
                <td className="llf-rownum llf-corner" aria-hidden="true"><span className="llf-colletter" /><span className="llf-colname">1</span></td>
                {Q_COLS.map((h, i) => (
                  <th key={h} scope="col" className={`llf-colhead${Q_NUM_COLS.has(i) ? " num" : ""}${sel.c === i ? " llf-colhead--sel" : ""}`}>
                    <span className="llf-colletter" aria-hidden="true">{colLetter(i)}</span><span className="llf-colname">{h}</span>
                  </th>
                ))}
              </tr></thead>
              <tbody>
                {tickets.map((t, r) => (
                  <tr key={t.ticket_id}>
                    <td className={`llf-rownum${sel.r === r ? " llf-rownum--sel" : ""}`} aria-hidden="true">{r + 2}</td>
                    <td {...cell(r, 0, "llf-mono")}>{t.ticket_id}</td>
                    <td {...cell(r, 1, "llf-cell--title")} title={t.title}><strong>{t.title}</strong></td>
                    <td {...cell(r, 2, "llf-cell--wide")} title={t.rationale ?? undefined}>{orNA(t.rationale)}</td>
                    <td {...cell(r, 3)}>{orNA(t.circuit_id)}</td>
                    <td {...cell(r, 4)} title={cellText(t, 4) || undefined}>{t.vendor_name ? <>{t.vendor_name} <span className="llf-muted llf-mono">{t.vendor_id}</span></> : orNA(t.vendor_id)}</td>
                    <td {...cell(r, 5, "num")}>{fmtUsd(t.monthly_cost)}</td>
                    <td {...cell(r, 6, "num")}>{fmtUsd(t.est_monthly_savings)}</td>
                    <td {...cell(r, 7)}>{t.agent_name}</td>
                    <td {...cell(r, 8)}><StatusBadge status={t.status} /></td>
                    <td {...cell(r, 9, "llf-cell--ctl")}>
                      {t.status === "pending" ? (
                        <input type="text" className="llf-cell-input" maxLength={2000} placeholder="Optional"
                          aria-label={`Comment (optional) for ${t.title}`} value={comments[t.ticket_id] ?? ""} disabled={savingId !== null}
                          onChange={(e) => { const v = e.target.value; setComments((c) => ({ ...c, [t.ticket_id]: v })); }} />
                      ) : <NotAvailable />}
                    </td>
                    <td {...cell(r, 10, "llf-cell--ctl")}><div className="llf-actions">
                      {t.status === "pending" ? (savingId === t.ticket_id ? (
                        <button className="llf-btn" disabled aria-disabled="true">Saving...</button>
                      ) : (<>
                        <button className="llf-btn llf-btn--approve" disabled={savingId !== null} onClick={() => decide(t.ticket_id, t.title, "approved")} aria-label={`Approve ${t.title}`}>Approve</button>
                        <button className="llf-btn llf-btn--reject" disabled={savingId !== null} onClick={() => decide(t.ticket_id, t.title, "rejected")} aria-label={`Reject ${t.title}`}>Reject</button>
                      </>)) : (
                        <button className="llf-btn" aria-label={`View evidence for ${t.title}`} onClick={() => { focusEvidence.current = true; showEvidence(t.ticket_id); }}>View evidence</button>
                      )}
                    </div></td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
          <p id="llf-grid-help" className="llf-sr-only">Use arrow keys to move between cells. Press Enter to jump to the comment field or first button in a cell, and Escape to return to the cell. Tab moves through the comment fields and buttons.</p>
        </div>
      {evidence && (
        <aside className="llf-side" aria-labelledby="ev-h">
          <div className="llf-side-head">
            <h3 id="ev-h" ref={evidenceHeading} tabIndex={-1}>Evidence for {evidence.ticket.ticket_id}</h3>
            <button type="button" className="llf-btn llf-btn--sm" onClick={() => setEvidence(null)} aria-label="Close evidence panel">Close</button>
          </div>
          <dl className="llf-evidence">
            <dt>Agent</dt><dd>{evidence.agentIdentity.name}</dd>
            <dt>Agent identity</dt>
            <dd>{evidence.agentIdentity.identityMode === "service_principal"
              ? <>{orNA(evidence.agentIdentity.servicePrincipal)}{evidence.agentIdentity.applicationId ? ` (application ID ${evidence.agentIdentity.applicationId})` : ""}</>
              : <>User identity (fallback){evidence.agentIdentity.runAs ? `: ran as ${evidence.agentIdentity.runAs}` : ""}</>}</dd>
            <dt>MLflow trace</dt>
            <dd>{evidence.traceId
              ? (evidence.traceUrl
                ? <a href={evidence.traceUrl} target="_blank" rel="noreferrer">Open trace {evidence.traceId}<ExternalLinkIcon /><span className="llf-sr-only"> (opens in a new tab)</span></a>
                : evidence.traceId)
              : "No trace recorded"}</dd>
            <dt>MLflow experiment</dt><dd>{orNA(evidence.experimentId)}</dd>
            <dt>Decision</dt><dd><StatusBadge status={evidence.ticket.status} />{evidence.ticket.decided_by ? ` by ${evidence.ticket.decided_by}` : ""}{evidence.ticket.decided_at ? ` on ${fmtWhen(evidence.ticket.decided_at)}` : ""}</dd>
          </dl>
          <div className="llf-table-wrap"><table><caption className="llf-caption">Audit record ({plural(evidence.audit.length, "entry", "entries")})</caption><thead><tr><th scope="col">When</th><th scope="col">Action</th><th scope="col">Actor</th><th scope="col">Role</th><th scope="col">Details</th></tr></thead>
            <tbody>{evidence.audit.map((a, i) => <tr key={i}><td>{fmtWhen(a.at)}</td><td>{sentence(a.action)}</td><td>{a.actor}</td><td>{orNA(a.actor_role)}</td><td>{auditDetail(a.details)}</td></tr>)}</tbody>
          </table></div>
        </aside>
      )}
      </div>
    </section>
  );
}

// DSN-APP-EXPLORER-PENDING-R1: one persistent live region, Genie-aware pending copy, select disabled while pending
const PENDING_MSG_ID = "llf-explorer-pending";
function MarginExplorer({ metricView, genieSpaceId }: { metricView: string; genieSpaceId: string }) {
  const [dim, setDim] = useState("product_family");
  const [rows, setRows] = useState<ExplorerRow[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);
  // APP-EXPLORER-TOTAL-ROW: portfolio total comes from the server's ungrouped MEASURE() query, never summed here
  const [total, setTotal] = useState<ExplorerRow | null>(null);
  useEffect(() => {
    setRows(null); setTotal(null); setError(null); setPending(false);
    api<{ rows: ExplorerRow[]; total?: ExplorerRow | null }>(`/api/explorer?dim=${dim}`).then((r) => { setRows(r.rows); setTotal(r.total ?? null); })
      .catch((e) => (e.message === "pending_mv" ? setPending(true) : setError(e.message)));
  }, [dim]);
  const dimLabel = DIMENSIONS.find(([k]) => k === dim)?.[1] ?? dim;
  const pendingMsg = genieSpaceId
    ? "The margin explorer goes live when the governed metric view is published. Until then, ask in Margin Genie."
    : "The margin explorer goes live when the governed metric view is published.";
  const liveText = pending ? pendingMsg
    : error ? ""
    : rows === null ? "Loading margin"
    : `Margin by ${dimLabel} loaded, ${plural(rows.length, "row", "rows")}`;
  return (
    <section aria-labelledby="exp-h">
      <h2 id="exp-h">Margin explorer</h2>
      <p>Contribution margin comes from the governed metric view <code>{metricView}</code>. This app never recalculates it.</p>
      <div className="llf-card"><label>Break down by{" "}
        <select value={dim} onChange={(e) => setDim(e.target.value)} disabled={pending}
          aria-describedby={pending ? PENDING_MSG_ID : undefined}>{DIMENSIONS.map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select>
      </label></div>
      <p className="llf-sr-only" role="status" aria-live="polite">{liveText}</p>
      {pending && <p id={PENDING_MSG_ID} className="llf-state">{pendingMsg}</p>}
      {error && <p role="alert" className="llf-error">Metric view unavailable. Try again or ask in Margin Genie. <small>({error})</small></p>}
      {rows === null && !error && !pending && <p className="llf-state">Loading margin...</p>}
      {rows?.length === 0 && <p className="llf-state">No ledger rows yet.</p>}
      {rows && rows.length > 0 && (
        <div className="llf-card llf-table-wrap"><table>
          <caption className="llf-caption">Margin by {DIMENSIONS.find(([k]) => k === dim)?.[1]}</caption>
          <thead><tr><th scope="col">{DIMENSIONS.find(([k]) => k === dim)?.[1]}</th><th scope="col" className="num">Revenue</th><th scope="col" className="num">Network Expense</th><th scope="col" className="num">Cost to Serve</th><th scope="col" className="num">Contribution Margin</th><th scope="col" className="num">CM %</th><th scope="col" className="num">Circuits</th></tr></thead>
          <tbody>{rows.map((r, i) => (
            <tr key={i}>
              <td>{orNA(r.dimension)}</td><td className="num">{fmtUsd(r.revenue)}</td><td className="num">{fmtUsd(r.network_expense)}</td>
              <td className="num">{fmtUsd(r.cost_to_serve)}</td>
              <td className={`num ${Number(r.contribution_margin) < 0 ? "neg" : ""}`}>{fmtUsd(r.contribution_margin)}{Number(r.contribution_margin) < 0 ? " (loss)" : ""}</td>
              <td className="num">{fmtPct(r.cm_pct)}</td><td className="num">{orNA(r.circuits)}</td>
            </tr>))}</tbody>
          {total && (
            <tfoot><tr className="llf-total">
              <th scope="row">Portfolio total</th><td className="num">{fmtUsd(total.revenue)}</td><td className="num">{fmtUsd(total.network_expense)}</td>
              <td className="num">{fmtUsd(total.cost_to_serve)}</td>
              <td className={`num ${Number(total.contribution_margin) < 0 ? "neg" : ""}`}>{fmtUsd(total.contribution_margin)}{Number(total.contribution_margin) < 0 ? " (loss)" : ""}</td>
              <td className="num">{fmtPct(total.cm_pct)}</td><td className="num">{orNA(total.circuits)}</td>
            </tr></tfoot>
          )}
        </table></div>
      )}
    </section>
  );
}

// Margin Genie: native chat over the Genie Conversation API (server proxies /api/genie/*). No iframe.
type GenieAttachment = {
  id: string | null; text: string | null; sql: string | null; description: string | null; title: string | null;
  suggestions: string[]; columns: string[]; rows: (string | null)[][]; rowCount: number; resultError: string | null;
};
type GenieTurn = { question: string; status: "thinking" | "done" | "error"; progress?: string; attachments: GenieAttachment[]; error?: string };
const GENIE_PROGRESS: Record<string, string> = {
  SUBMITTED: "Sending question", FILTERING_CONTEXT: "Reading the margin metric views", FETCHING_METADATA: "Reading the margin metric views",
  ASKING_AI: "Thinking", PENDING_WAREHOUSE: "Waiting for the SQL warehouse", EXECUTING_QUERY: "Running the query",
};
const GENIE_STARTERS = [
  "What is contribution margin by product family this quarter?",
  "Which vendors have the lowest contribution margin?",
  "How does margin compare for legacy versus strategic products?",
];
const isNum = (v: string | null) => v != null && /^-?\d+(\.\d+)?(E-?\d+)?$/i.test(v);

function GenieAnswer({ a }: { a: GenieAttachment }) {
  return (
    <div className="llf-genie-answer">
      {a.text && <p className="llf-genie-text">{a.text}</p>}
      {a.sql && (
        <>
          {a.description && <p className="llf-muted">{a.description}</p>}
          {a.resultError && <p role="alert" className="llf-error">The result could not be loaded. Try asking again. <small>({a.resultError})</small></p>}
          {!a.resultError && a.columns.length === 0 && <p className="llf-muted">No rows returned.</p>}
          {a.columns.length > 0 && (
            <div className="llf-table-wrap"><table>
              <caption className="llf-caption">{a.title ?? "Result"} ({plural(a.rowCount, "row", "rows")}{a.rowCount > a.rows.length ? `, first ${a.rows.length} shown` : ""})</caption>
              <thead><tr>{a.columns.map((c, i) => <th key={i} scope="col" className={a.rows.length && isNum(a.rows[0][i]) ? "num" : undefined}>{c}</th>)}</tr></thead>
              <tbody>{a.rows.map((r, i) => (
                <tr key={i}>{r.map((v, j) => <td key={j} className={isNum(v) ? "num" : undefined}>{orNA(v)}</td>)}</tr>
              ))}</tbody>
            </table></div>
          )}
          <details className="llf-genie-sql"><summary>Show SQL</summary><pre><code>{a.sql}</code></pre></details>
        </>
      )}
    </div>
  );
}

function MarginGenie({ cfg }: { cfg: Config }) {
  const [turns, setTurns] = useState<GenieTurn[]>([]);
  const [question, setQuestion] = useState("");
  const [conversationId, setConversationId] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [announce, setAnnounce] = useState("");
  const endRef = useRef<HTMLDivElement>(null);
  const alive = useRef(true);
  useEffect(() => () => { alive.current = false; }, []);
  useEffect(() => { if (turns.length) endRef.current?.scrollIntoView({ block: "end", behavior: "smooth" }); }, [turns]);

  if (!cfg.genieSpaceId) return <p className="llf-state">Margin Genie is being set up. It will appear here when it is published.</p>;

  const update = (i: number, patch: Partial<GenieTurn>) => setTurns((t) => t.map((x, j) => (j === i ? { ...x, ...patch } : x)));
  const ask = async (q: string) => {
    const text = q.trim();
    if (!text || busy) return;
    const i = turns.length;
    setBusy(true); setQuestion("");
    setTurns((t) => [...t, { question: text, status: "thinking", progress: "Sending question", attachments: [] }]);
    setAnnounce("Question sent to Margin Genie.");
    try {
      const started = await api<{ conversationId: string; messageId: string }>("/api/genie/ask", { method: "POST", body: JSON.stringify({ question: text, conversationId }) });
      setConversationId(started.conversationId);
      const t0 = Date.now();
      for (;;) {
        await new Promise((r) => setTimeout(r, 1500));
        if (!alive.current) return;
        const m = await api<{ status: string; done: boolean; error: string | null; attachments: GenieAttachment[] }>(
          `/api/genie/conversations/${encodeURIComponent(started.conversationId)}/messages/${encodeURIComponent(started.messageId)}`,
        );
        if (!m.done) {
          update(i, { progress: GENIE_PROGRESS[m.status] ?? "Thinking" });
          if (Date.now() - t0 > 180_000) throw new Error("Genie took longer than 3 minutes");
          continue;
        }
        if (m.status !== "COMPLETED") throw new Error(m.error ?? `Genie ${m.status.toLowerCase()}`);
        update(i, { status: "done", attachments: m.attachments });
        setAnnounce("Margin Genie answered.");
        break;
      }
    } catch (e) {
      update(i, { status: "error", error: (e as Error).message });
      setAnnounce("Margin Genie could not answer. Try again.");
    } finally {
      setBusy(false);
    }
  };
  const newConversation = () => { setTurns([]); setConversationId(null); setAnnounce("New conversation started."); };

  const last = turns[turns.length - 1];
  const suggestions = turns.length === 0 ? GENIE_STARTERS
    : last?.status === "done" ? last.attachments.flatMap((a) => a.suggestions).slice(0, 3) : [];

  return (
    <section aria-labelledby="genie-h">
      <h2 id="genie-h">Margin Genie</h2>
      <p>Ask in plain English. Finance, Ops, Sales and Marketing share one Genie and one definition of margin.</p>
      <p className="llf-sr-only" role="status" aria-live="polite">{announce}</p>
      <div className="llf-card llf-genie-thread" aria-label="Margin Genie conversation">
        {turns.length === 0 && <p className="llf-state">Ask a margin question to start.</p>}
        {turns.map((t, i) => (
          <div key={i} className="llf-genie-turn">
            <p className="llf-genie-q"><span className="llf-sr-only">You asked: </span>{t.question}</p>
            {t.status === "thinking" && <p className="llf-muted">{t.progress ?? "Thinking"}...</p>}
            {t.status === "error" && <p role="alert" className="llf-error">Margin Genie could not answer. Try again. <small>({t.error})</small></p>}
            {t.status === "done" && (t.attachments.length
              ? t.attachments.map((a, k) => <GenieAnswer key={a.id ?? k} a={a} />)
              : <p className="llf-muted">No answer returned. Try rephrasing the question.</p>)}
          </div>
        ))}
        <div ref={endRef} />
      </div>
      {suggestions.length > 0 && (
        <div className="llf-genie-suggest" role="group" aria-label="Suggested questions">
          {suggestions.map((s) => <button key={s} type="button" className="llf-btn" disabled={busy} onClick={() => ask(s)}>{s}</button>)}
        </div>
      )}
      <form className="llf-genie-form" onSubmit={(e) => { e.preventDefault(); ask(question); }}>
        <label htmlFor="llf-genie-input" className="llf-sr-only">Ask Margin Genie</label>
        <input id="llf-genie-input" value={question} onChange={(e) => setQuestion(e.target.value)} maxLength={4000} disabled={busy}
          placeholder="Ask about margin, for example: which product families lost margin last quarter?" />
        <button type="submit" className="llf-btn llf-btn--approve" disabled={busy || !question.trim()}>{busy ? "Asking..." : "Ask"}</button>
        {conversationId && <button type="button" className="llf-btn" disabled={busy} onClick={newConversation}>New conversation</button>}
      </form>
      <p className="llf-muted"><small>Answers come from the governed margin metric views.{" "}
        <a className="llf-link" href={`${cfg.workspaceHost}/genie/rooms/${cfg.genieSpaceId}`} target="_blank" rel="noreferrer">Open in Genie<ExternalLinkIcon /></a></small></p>
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
  const [cfg, setCfg] = useState<Config>({ genieSpaceId: "", workspaceHost: "", mlflowExperimentId: "", metricView: "" }); // filled from /api/config (app.yaml env)
  useEffect(() => { api<Config>("/api/config").then(setCfg).catch(() => undefined); }, []);
  return (
    <div className="llf-app">
      <header className="llf-header"><span className="llf-mark" aria-hidden="true" /><h1>Lakelink Fiber | Margin Truth</h1><span className="llf-header-sub">{tab}</span></header>
      <main>
        <div role="tabpanel" id={panelId(active)} aria-labelledby={tabId(active)} tabIndex={0} className="llf-panel">
          {tab === "Approval queue" && <ApprovalQueue />}
          {tab === "Margin explorer" && <div className="llf-doc"><MarginExplorer metricView={cfg.metricView} genieSpaceId={cfg.genieSpaceId} /></div>}
          {tab === "Margin Genie" && <div className="llf-doc"><MarginGenie cfg={cfg} /></div>}
        </div>
      </main>
      <nav className="llf-tabs" role="tablist" aria-label="Sheets">
        {TABS.map((t, i) => (
          <button key={t} ref={(el) => { tabRefs.current[i] = el; }} id={tabId(i)} role="tab" className="llf-tab"
            aria-selected={tab === t} aria-controls={tab === t ? panelId(i) : undefined} tabIndex={tab === t ? 0 : -1}
            onClick={() => setTab(t)} onKeyDown={onTabKey}>{t}</button>
        ))}
      </nav>
    </div>
  );
}
