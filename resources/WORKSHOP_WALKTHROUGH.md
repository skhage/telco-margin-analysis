# Lakelink Fiber Margin Truth: Workshop Walkthrough

**Format:** 4-hour hands-on workshop (includes kickoff, intros and two breaks)
**Company in all assets:** Lakelink Fiber (fictional, synthetic data)
**The one question:** "Which products and circuits lose money after cost to serve?"
**Flow:** Genie -> Lineage -> Semantics (+ Genie Code) -> Controls / SOX -> Dashboard + App -> Genie One as AI coworker

This is the presenter's script. Each module lists a time block, what to show and in what order, what to say, prompts for the room, expected answers, and a fallback. About half of every block is buffer for questions. Timings are relative (T+h:mm), so they work with any start time.

---

## 1. Agenda at a glance

| Clock | Min | Module | Live demo | Buffer / hands-on |
| --- | --- | --- | --- | --- |
| T+0:00 - 0:15 | 15 | Kickoff, intros, goals | 5 | 10 |
| T+0:15 - 0:55 | 40 | Module 1: Margin Genie (interactive) | 15 | 25 |
| T+0:55 - 1:20 | 25 | Module 2: Lineage, from answer to source PDF | 12 | 13 |
| T+1:20 - 1:35 | 15 | **Break** | | |
| T+1:35 - 2:20 | 45 | Module 3: Semantics, and Genie Code building on them | 25 | 20 |
| T+2:20 - 2:50 | 30 | Module 4: Controls and governance (SOX, Scott shares his screen) | 15 | 15 |
| T+2:50 - 3:00 | 10 | **Break** | | |
| T+3:00 - 3:30 | 30 | Module 5: AI/BI dashboard and the Margin Truth app | 15 | 15 |
| T+3:30 - 3:50 | 20 | Module 6: Genie One as an AI coworker | 10 | 10 |
| T+3:50 - 4:00 | 10 | Wrap-up, $1B Wall challenge, next steps | 5 | 5 |

**If you run long:** cut Module 6 to 10 minutes and run the Genie One prompts as a leave-behind. Then cut Module 5 to one dashboard page plus the approve click. **Do not cut** the SOX module or the Genie Code segment, because those are the two things the customer cannot do in their own deployment today.

---

## 2. Asset map (open these tabs before you start)

| Surface | Name / location | Notes |
| --- | --- | --- |
| Genie agent | **Lakelink Fiber Margin Genie** (space `01f1df115a08164aab3ae5f6faac807c`) | Sources: `_metrics.margin_ledger_mv` plus 4 dims (circuits, contracts, products, vendors) and the other margin metric views |
| Metric views | `cdm_tmforum._metrics.margin_ledger_mv`, `margin_offnet_spend_mv`, `margin_renewal_floor_mv`, `margin_segment_growth_mv`, `margin_onebillion_wall_mv` | Contribution margin is defined once, in `margin_ledger_mv` |
| Gold ledger | `cdm_tmforum.revenue_assurance.margin_ledger_allocated` (view) over `margin_ledger_v2` (pipeline gold) | Grain: customer x product x circuit x contract x month |
| Pipeline | **Lakelink Fiber Margin Truth Pipeline** (`20960984-a9d3-46f4-826a-6301155bc79a`) | The only pipeline you show. Ignore `ccea7e91`, an old draft that owns no tables |
| Source PDFs | Volume `/Volumes/cdm_tmforum/revenue_assurance/margin_documents` | Carrier invoice PDFs, parsed by `ai_parse_document` and `ai_extract` |
| Allocation rules | `cdm_tmforum.revenue_assurance.margin_allocation_rules` | Cost pool x driver x weight, owned by Finance |
| Dashboard | **Lakelink Fiber Margin Truth** (`01f1df1950c51bd68e87ace31632c2bf`) | Page 1: CFO margin scorecard. Page 2: $1B Wall. Has an embedded Genie |
| App | **lakelink-margin-truth** (open by name) | Approval queue, margin explorer, Genie tab, trace/audit view |
| Agent traces | MLflow experiment **margin_grooming_agent_traces** | Hero trace `tr-2b088edfed85d22b2db662a6c0a7c68e` |
| UC functions | `margin_score_onnet_move`, `margin_compare_rates` | Agent tools |
| SOX policies | ABAC: `margin_sox_contract_rates` (mask), `margin_sox_detail_rows`, `margin_sox_key_accounts` (row filters) | Exempt group: `lakelink-sox-finance` |
| Sales row filter | `margin_sales_row_filter` on ledger, customers, contracts | Group `lakelink_margin_sales` sees only its own territory |
| Discover | Domain **Lakelink Fiber**: Finance Margin, Operations Margin, Sales Margin, Marketing Margin | Glossary pages for every margin term |

---

## 3. Numbers to know (verified against the metric view on 2026-11-17)

| Fact | Value | Where it shows |
| --- | --- | --- |
| Contribution margin, all time (Nov 2025 - Oct 2026) | **USD 2,375,095,705.09** | Margin Genie, dashboard at default filter (Quarter = All) |
| Contribution margin, Q3 2026 (last full quarter) | **USD 590,767,062.41** | Dashboard page 1 with Quarter = 2026-07-01 |
| Families that lost money in Q3 2026 | **IP-VPN -6,715,475.88; Legacy Voice -249,532.74** | Finance starter question |
| Off-net circuits next to our own fiber | **47 circuits**, about 96,028.51 a month paid (1,152,342.12 a year), about 34,378.33 a month savings (412,539.96 a year) | Ops starter question |
| Renewals in the next 90 days below the margin floor | **586** | Sales starter question |
| Room-to-grow segment | **Commercial** (CM 54.4% vs portfolio 54.1%). It is a thin lead, so do not call it a big gap | Marketing starter question |
| Allocation simulation | Care-cost weight 0.70 -> 0.90 moves CM to **2,360,713,702.39** | Module 3 |
| Sales row filter example | West rep sees **103,176 of 517,032** ledger rows | Module 4 |
| Hero approval ticket | **GROOM-1e655052ef**: circuit 10211, cost 1,364.58 a month, savings 1,357.85 a month. Backup: GROOM-44c3612b69 (circuit 45040) | Module 5 |

**Same-number rule:** quote the cent-exact figure only from Margin Genie or the dashboard. The app explorer shows whole dollars and all-time CM. Say: "The explorer shows all-time contribution margin from the same metric view."

---

## 4. Pre-workshop checklist (T-60 to T-10)

* [ ] Warm SQL warehouse `bf0baa637e887c80` (it auto-stops). Run one Genie question to warm it.
* [ ] Open the app **lakelink-margin-truth** and confirm it is RUNNING. Load the queue once to wake its Lakebase database.
* [ ] Dashboard: confirm page 1 CM tile reads **$2,375,095,705.09** at Quarter = All.
* [ ] Margin Genie: run all 4 starter questions and screenshot the answers (fallbacks).
* [ ] **Run the SOX check as Scott (critical, see Module 4).** So far every same-number proof has run as a SOX-exempt identity. Before the session, have Scott log in and run the Module 4 script, so you know exactly what he will see.
* [ ] Confirm Scott is **not** in `lakelink-sox-finance` and **not** in `lakelink_margin_sales`, unless you want to demo the Sales filter on him too.
* [ ] Open the MLflow trace `tr-2b088edf...` in a tab.
* [ ] Have the recorded scene 5 walkthrough clip ready as a network fallback.
* [ ] Confirm attendees can reach **their own** Genie deployment. You will contrast it with ours.

---

## 5. Kickoff and intros (T+0:00 - 0:15)

**Goal:** set the frame and get the room talking early.

1. Intros: name, role, and "the margin question you can't answer quickly today." Write the answers on a whiteboard. You will come back to them in Module 6.
2. Frame: "Today we answer one question, which products and circuits lose money after cost to serve, and follow it from the answer, back to its source, to the controls around it, and on to an action a person approves."
3. Ground rules: interrupt at any time, and everything is synthetic data for the fictional Lakelink Fiber.
4. Show the architecture slide: Sources -> Auto Loader + AI functions -> SDP Bronze/Silver/Gold -> Metric views + allocation rules -> Genie, Dashboard, Agents, App on Lakebase -> Unity Catalog governance.

---

## 6. Module 1: Margin Genie, interactive (T+0:15 - 0:55)

**Pillar:** Genie. **Talk track:** "This takes days today. Here it takes seconds."

### 6.1 Live demo (15 min)

1. Open **Lakelink Fiber Margin Genie**. Point out the description: one space for Finance, Ops, Sales and Marketing.
2. **Finance (CFO):** "Which product families lost money after cost to serve last quarter?"
   * Expected: IP-VPN -6,715,475.88 and Legacy Voice -249,532.74 for Q3 2026. Say "lost", not "minus".
   * Click **Show code**: it uses `MEASURE(contribution_margin)` from `margin_ledger_mv` and does not recompute margin.
3. Follow-up: "What is total contribution margin?" Expected: USD 2,375,095,705.09.
4. **Ops:** "Which off-net circuits run next to our own fiber, and what do we pay for them?" Expected: 47 circuits.
5. **Sales:** "Which renewals in the next 90 days are below the margin floor?" Expected: 586.
6. **Marketing:** "Which segments have the highest margin and the most room to grow?" Expected: Commercial, a thin lead.
7. Message: "One Genie, not a Genie per team. Every team gets the same contribution margin."

### 6.2 Hands-on: the room asks (25 min buffer)

Invite attendees to ask the same questions **in their own deployed Genie** and in ours, side by side. Encourage them to compare answers.

Prompt cards to hand out:
* "Top 10 customers by negative contribution margin."
* "Margin % for legacy vs strategic families."
* "Contribution margin trend by month for Legacy Voice."
* "How many off-net circuits are grooming candidates?"
* "Off-net spend by vendor this month."
* "What does cost to serve mean here?" (tests the instructions and glossary)

Facilitation tips:
* If their Genie gives a different number, don't explain it yet. Say: "Hold that thought. In Module 3 we'll see exactly why the numbers differ." That sets up the semantics contrast.
* If a question can't be answered, Genie should say so (instruction 9) rather than guess. Point this out as a trust feature.
* Give a thumbs up to good answers, and use "Ask for review" on a wrong one to show the feedback loop.

**Likely questions:**
* *Is Genie using raw tables?* No. It uses metric views plus four dimension tables, never the raw sources.
* *How do you know it's right?* There are 13 benchmark questions with expected answers, rerun before every demo.
* *Can it hallucinate a number?* The SQL is visible for every answer, and the measure is defined in the metric view, not by the LLM.

**Fallback:** if Genie gives an unexpected answer, show the pre-taken screenshot and the benchmark result.

---

## 7. Module 2: Lineage, from answer to source PDF (T+0:55 - 1:20)

**Pillar:** Data. **Talk track:** "One copy of the data, not five extracts."

### 7.1 Live demo (12 min)

1. From the Genie answer, open `margin_ledger_mv` in Catalog Explorer. Then open its source `margin_ledger_allocated` and select the **Lineage** tab.
2. Walk upstream: `margin_ledger_allocated` -> `margin_ledger_v2` (gold, pipeline) -> silver tables -> `margin_silver_invoice_parsed` -> `margin_bronze_invoice_docs`.
3. Open the pipeline **Lakelink Fiber Margin Truth Pipeline** (`20960984`). Show the Bronze -> Silver -> Gold graph in one pipeline, and an expectation catching a bad record (data quality tab).
4. In `margin_silver_invoice_parsed`, show one row's structured fields (rates, circuit ID, terms) extracted by `ai_parse_document` and `ai_extract`.
5. Follow the row's **file path** column into the `margin_documents` volume and open the source carrier invoice PDF.
   * Be precise: the PDF hop is a file-path column, not a lineage edge. Say: "Lineage runs back to the bronze table, and its file path opens the source PDF."
6. Optional: open `margin_dq_gl_tieout` to show the ledger-to-GL tie-out is green.

### 7.2 Buffer (13 min)

**Likely questions:**
* *Why two pipelines in the list?* "One pipeline builds the ledger. The other entry is an earlier draft we retire after the demo, and it owns no tables."
* *How does Auto Loader handle new PDFs?* New files in the volume are picked up incrementally, and only new files are parsed.
* *Column-level lineage?* Yes. Click a column in the lineage graph to show it.
* *Trace one circuit end to end?* Pick circuit 10211 and trace it: contract -> order -> bill -> carrier invoice.

---

## 8. Break (T+1:20 - 1:35)

---

## 9. Module 3: Semantics, and Genie Code building on them (T+1:35 - 2:20)

**Pillar:** Semantics. **Talk track:** "Finance owns the definition once, and everyone gets the same answer."

**The contrast:** we have the semantic layer, and their deployment does not. Name it directly: "In Module 1 your Genie and ours disagreed. This is why."

### 9.1 The semantic layer tour (12 min)

1. **Metric view:** open `cdm_tmforum._metrics.margin_ledger_mv` on its **Overview / definition**, not the Sample Data preview.
   * Contribution margin = revenue - network expense - cost to serve, defined once.
   * Every measure and dimension has a comment, display name, format and synonyms ("profit after cost to serve", "CM").
2. **Allocation rule (simulation):** open `margin_allocation_rules`. "Finance raises the care-cost weight from 0.70 to 0.90, and contribution margin moves to USD 2,360,713,702.39, as this simulation shows." Use the read-only simulation, not a live UPDATE.
3. **Genie ontology:** show the informational PK/FK constraints: customer 1-N contract, contract 1-N circuit, circuit N-1 vendor, contract N-1 product. Genie uses these as joins, so it knows a customer has contracts, a contract covers circuits, and a circuit rides a vendor.
4. **Column comments:** open `margin_circuits`. Every column has a business-language comment (grain, units, synonyms).
5. **Glossary pages and Discover:** open Discover -> **Lakelink Fiber** domain -> Finance Margin. Show glossary pages (Contribution Margin, Cost to Serve, Off-net, On-net, Margin Floor, $1B Wall) linked to the metric views and tables.

**Contrast slide (say it out loud):**

| | Their deployment today | This workshop |
| --- | --- | --- |
| Margin definition | Re-derived per query by the LLM or analyst | Defined once in a metric view |
| Joins | Inferred from column names | Declared PK/FK ontology |
| Business terms | Tribal knowledge | Glossary pages, certified |
| Column meaning | Often blank | 100% comments with units and synonyms |
| Result | Different numbers per team | Same number to the cent |

### 9.2 Genie Code: development on top of the semantics (13 min)

**Message:** good semantics don't just help Genie. They make your developers faster, because Genie Code reads the same comments, metric views and glossary.

Run these in a **scratch notebook** (delete it afterwards; do not deploy new objects during the session):

1. *Discovery:* "Which metric view defines contribution margin for Lakelink Fiber, and how is cost to serve allocated?"
   * Expected: Genie Code finds `margin_ledger_mv` and `margin_allocation_rules` from comments and glossary, without being told the table names.
2. *Query authoring:* "Using margin_ledger_mv, write SQL for contribution margin % by region and family class for Q3 2026, and run it."
   * Point out that it uses `MEASURE()` and `GROUP BY ALL`, because the metric view tells it how.
3. *Build something new (the room's choice):* "Draft a metric view YAML for carrier rate variance using margin_compare_rates and margin_carrier_invoices, following the conventions in margin_ledger_mv. Don't deploy it."
   * Show it reuses the naming, comments, formats and synonyms from the existing views.
4. *Explain:* "Explain the margin_score_onnet_move function in plain English for an Ops manager."

Facilitation: ask the room for the next thing they would build, and let Genie Code try it live. If an output is wrong, show how to correct it in conversation. That is a realistic workflow.

### 9.3 Buffer (20 min)

**Likely questions:**
* *How long did the semantic layer take to build?* Walk through the order: column comments -> PK/FK -> metric views -> glossary -> Genie instructions.
* *Who owns the metric definition?* Finance owns `margin_ledger_mv`. The change process is a reviewed YAML change.
* *Can BI tools use metric views?* Yes. The dashboard, Genie and the app all read the same view.
* *What about our existing semantic model?* Talk about migration paths. Metric views are YAML in source control.

---

## 10. Module 4: Controls and governance, SOX (T+2:20 - 2:50)

**Pillar:** Governance. **Talk track:** "Same question, same governed answer, and only the right people see SOX detail."

**Setup:** Scott shares his screen. Scott is a normal account user, **not** in `lakelink-sox-finance`, so the three ABAC policies apply to him.

### 10.1 What is in place (explain first, 3 min)

| Policy | Type | Applies to columns tagged | Effect for Scott |
| --- | --- | --- | --- |
| `margin_sox_contract_rates` | Column mask | `fin_data_class = contract_rate` (contract rate, carrier contract and invoiced rates) | Values come back **NULL** |
| `margin_sox_detail_rows` | Row filter | `fin_data_class = sox_key_amount` (billing lines, carrier invoice paid amounts) | **No rows** in `margin_billing` and `margin_carrier_invoices` |
| `margin_sox_key_accounts` | Row filter | `fin_data_class = sox_key_account` (GL accounts) | GL accounts 4000, 5000 and 6100 hidden. Cost-to-serve pools stay visible |

Key point: the policies are **tag-driven (ABAC)**. Tag a new column `contract_rate` and it is masked automatically, without writing a new grant. Totals for non-SOX users come from the aggregate views `margin_sox_billing_monthly` and `margin_sox_carrier_spend_monthly`.

### 10.2 Scott's script (12 min)

1. **Genie (as Scott):** ask "What is total contribution margin?" and the Finance starter.
   * Expected: the same contribution margin, because the governed ledger is built by the pipeline identity and the metric view is shared.
2. **Genie (as Scott):** "Show me carrier invoice lines for circuit 10211" or "What is our contract rate on circuit 10211?"
   * Expected: no detail rows and NULL rates. Genie respects the policy because it runs as the viewer.
3. **SQL Editor (as Scott):**
   * `SELECT * FROM cdm_tmforum.revenue_assurance.margin_carrier_invoices LIMIT 10` returns 0 rows.
   * `SELECT contract_id, contract_rate_usd FROM cdm_tmforum.revenue_assurance.margin_contracts LIMIT 10` returns NULL rates.
   * `SELECT * FROM cdm_tmforum.revenue_assurance.margin_sox_carrier_spend_monthly` returns the totals he **is** allowed to see.
4. **App (as Scott):** open **lakelink-margin-truth** and show the explorer and queue under his identity.
5. **Presenter (exempt) side by side:** run the same SQL to show the rows and rates exist. "Same table, same query, different entitlement."
6. Close with audit: in `system.access.audit`, show Scott's queries logged with his identity.

**Pre-check results to record before the session (fill in from Scott's dry run):**

| Step | Expected | Observed in dry run |
| --- | --- | --- |
| Genie total CM | 2,375,095,705.09 | |
| Genie Ops question (47 circuits) | Circuit list; spend may be empty or masked | |
| SQL carrier invoices | 0 rows | |
| SQL contract rates | NULL | |
| SQL SOX aggregate | Rows returned | |
| App explorer CM | Whole-dollar CM | |
| App ticket cost fields | | |

**Caution for the presenter:** `margin_offnet_spend_mv` and the function `margin_score_onnet_move` read `margin_carrier_invoices`, so for Scott the **Ops question and grooming scores will likely return no spend**. Treat this as a governance point ("Ops spend detail is SOX data; Scott sees the circuit, not the money"), but confirm it in the dry run. Do not discover it live.

### 10.3 Optional: Sales row filter (if time)

`margin_sales_row_filter` limits group `lakelink_margin_sales` to its own territory. Example: a West rep sees 103,176 of 517,032 ledger rows. Do not quote a Sales-scoped contribution margin.

### 10.4 Buffer (15 min)

**Likely questions:**
* *Does the agent bypass SOX?* The agent runs under a named identity, and every step is traced (Module 5).
* *Who maintains the policies?* Governed tags plus three functions. Data stewards tag; the policy does the rest.
* *Can auditors prove who saw what?* Yes, from the audit system table, by identity and by time.

---

## 11. Break (T+2:50 - 3:00)

---

## 12. Module 5: AI/BI dashboard and the Margin Truth app (T+3:00 - 3:30)

**Pillars:** BI and Agents. **Talk track:** "Agents act, people approve. Every action has an identity and a record."

### 12.1 Dashboard (6 min)

1. Open **Lakelink Fiber Margin Truth**, page 1 (CFO margin scorecard), at Quarter = All. CM tile: **$2,375,095,705.09**.
   * Say: "Genie writes USD 2,375,095,705.09; the dashboard shows $2,375,095,705.09. It's the same number to the cent."
2. Set the **Quarter** filter (top-left) to **2026-07-01**. The tile changes to $590,767,062.41. From here on, quote Q3 figures only.
3. The family chart shows IP-VPN and Legacy Voice as negative, the same as the Genie answer in Module 1.
4. Open the embedded Genie and ask a follow-up from the dashboard.
5. Page 2: the **$1B Wall** tracker, which lists the margin-improvement levers against a USD 1B annualized target.

### 12.2 App: from insight to action (9 min)

1. Open the app **lakelink-margin-truth** by name.
2. **Margin explorer tab:** all-time CM from the same metric view, shown in whole dollars.
3. **Approval queue tab:** explain that the off-net grooming agent asked Margin Genie, scored circuits with `margin_score_onnet_move`, and drafted savings tickets.
   * If five untraced tickets from 15:26 on Nov 17 (GROOM-0a57924117, -d3dd7dd2c8, -695bb7c525, -00bf23be93, -36f2c510c9) are still at the top of the queue, **do not click or describe them**.
4. Open **GROOM-1e655052ef** by ticket ID (circuit 10211, 1,364.58 a month cost, 1,357.85 a month estimated savings). Say: "This is the ticket the agent drafted from the trace we just ran." Click **Approve** as Ops.
   * Backup: GROOM-44c3612b69 (circuit 45040).
5. **Trace and audit view:** open the MLflow trace `tr-2b088edf...`. Show each step: the Genie call, the UC function call, the ticket draft, the model from the approved list with guardrails on, and the audit row for the approve.
   * Say "user identity" and "guardrails are on". Don't say "service principal", and don't claim "we saw it block".
6. Optional live agent run, only if time and the network allow. If it hasn't printed after 75 seconds, stop and open the pre-run trace instead.

### 12.3 Buffer (15 min)

**Likely questions:**
* *Where does the queue live?* Lakebase (managed Postgres), so it is transactional and fast for app writes.
* *Can the agent approve its own ticket?* No. Approval is a human step in the app, recorded with the approver identity.
* *Can we deploy this ourselves?* Yes. The whole demo is a Declarative Automation Bundle (one app, one dashboard, one pipeline, jobs) that deploys into a dev workspace.

**Fallback:** if the app or network fails, play the recorded scene 5 walkthrough.

---

## 13. Module 6: Genie One as an AI coworker (T+3:30 - 3:50)

**Message:** "Business users don't need to know which space, dashboard or table to open. They ask, and Genie One finds the governed assets."

### 13.1 Live demo (10 min)

Open Genie One and ask, in this order:
1. "What is contribution margin at Lakelink Fiber, and where is it defined?" It should surface the glossary page and `margin_ledger_mv`.
2. "Which product families lost money after cost to serve last quarter?" Compare to the Module 1 answer.
3. "Is there a dashboard for margin? Summarize what it shows." It should surface **Lakelink Fiber Margin Truth**.
4. "Which renewals in the next 90 days are below the margin floor, and who should I talk to?"
5. Return to the whiteboard from kickoff: pick one or two of the room's questions and ask them live.

Presenter note: verify Genie One answers in the dry run. If a number differs from Margin Genie, show it as a discovery answer that points to Margin Genie and the dashboard, rather than quoting a different figure.

### 13.2 Buffer (10 min)

**Likely questions:**
* *How is Genie One different from a Genie space?* Genie One is the business-user chat across all governed assets. A Genie space is a curated agent for one domain.
* *Why do our assets surface?* Discover domains, certified glossary pages and full comments make them findable. This is the semantics payoff again.

---

## 14. Wrap-up (T+3:50 - 4:00)

1. Recap the chain: question -> source -> definition -> control -> action -> audit.
2. **$1B Wall challenge cards:** hand out the cards, or leave them behind. "Find your biggest lever."
3. Next steps: semantic layer assessment on their data, Genie benchmark set, and bundle deploy into their dev workspace.
4. Collect feedback.

---

## 15. Fallback matrix

| Risk | Fallback |
| --- | --- |
| Genie gives an unexpected answer | Show the pre-run benchmark screenshot. Open Show code to explain |
| Warehouse cold or slow | Pre-warm at T-60. Talk through the metric view while it starts |
| App or Lakebase slow | Load the queue at T-20. Use the recorded scene 5 clip |
| Agent run slow or fails | Use the pre-run ticket already in the queue and the pre-run trace |
| Scott sees something unexpected | Switch to the presenter's side-by-side SQL. Record it as a follow-up |
| Network or workspace access issue | Recorded walkthrough of the Genie, lineage, semantics and app scenes |

---

## 16. Presenter do and don't

* **Do** open the app by name, and select tickets by ticket ID.
* **Do** say "lost" for negative margins, and use USD with no decimals in narrative unless quoting the exact CM.
* **Do** show the metric view on its definition tab.
* **Don't** quote 2,375,095,705.09 after switching the dashboard to Q3.
* **Don't** open pipeline `ccea7e91`.
* **Don't** quote a Sales-scoped contribution margin.
* **Don't** name any real company. Everything is Lakelink Fiber.

*Export: open this file in the workspace and use the browser's Print -> Save as PDF.*
