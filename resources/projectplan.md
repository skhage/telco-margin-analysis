Margin Truth Demo Build
What we show on Nov 19, and which Databricks pieces make it work
The demo in one line
One question ("Which products and circuits lose money after cost to serve?") answered in plain English. The data and semantics behind the answer can be traced, and an agent turns the answer into an action that a person approves.
Architecture
The architecture diagram is the interactive artifact in the chat. It shows the end-state pattern, and the demo uses a scaled-down version of it on synthetic data.
Sources (synthetic): SAP GL extract, orders, billing, carrier invoices with PDFs, contracts, Salesforce renewals, network inventory, AR.
Ingest: Auto Loader with AI functions for the invoice and contract PDFs. Spark Declarative Pipelines for the rest.
Margin ledger: Bronze, Silver (shared customer, circuit, vendor, contract, and product keys), and Gold (the margin ledger), with data quality checks.
Semantics: UC Metric Views, Genie Ontology, and an allocation rules table.
Consumption: Margin Genie, an AI/BI dashboard, Agent Bricks agents, and a Databricks App backed by Lakebase as the approval queue.
Governance: Unity Catalog, Unity Gateway, a service principal per agent, and MLflow tracing.
Databricks components in the demo
Layer
Component
What it shows in the demo
Ingest
Auto Loader and AI functions (ai_parse_document, ai_extract)
A carrier invoice PDF becomes rows with rates, circuit IDs, and terms
Transform
Spark Declarative Pipelines
Bronze to Silver to Gold in one pipeline graph, with expectations catching a bad record
Quality
Data Quality Monitoring
Freshness check, plus a ledger-to-GL tie-out shown as green
Ledger
Delta tables in Unity Catalog
Trace one circuit from contract to order to bill to carrier invoice to cash
Semantics
UC Metric Views
Contribution margin is defined once. Genie, the dashboard, and the agent all return the same number
Semantics
Genie Ontology
Genie understands that a customer has contracts, a contract covers circuits, and a circuit rides a vendor
Semantics
Allocation rules table
Change one cost allocation rule and watch every answer update
Genie
Margin Genie (Genie Agent)
One persona question each from Finance, Ops, Sales, and Marketing
BI
AI/BI dashboard
CFO margin scorecard and the $1B Wall tracker
Agents
Agent Bricks with UC function tools
The off-net grooming agent asks Genie, finds circuits to move on-net, and drafts a savings ticket
Action
Databricks App backed by Lakebase
The ticket lands in an approval queue, and a person approves it
Model access
Unity Gateway
The agent uses a model from Lumen's approved list, with guardrails on
Trust
MLflow tracing
Every step the agent took, shown after the approval
Governance
Unity Catalog lineage, row filters, audit
Sales sees only its own accounts. Lineage runs from the answer back to the source table
Leave-behind
Asset Bundle and Genie Code
The whole demo deploys into their dev workspace, and they can extend it with Genie Code
Demo flow
Scene
Pillar
What happens on screen
Talk track
1. The question
Genie
The CFO persona asks which products lose money after cost to serve
"This takes days today. Here it takes seconds."
2. Where the answer comes from
Data
Click through from the answer to the ledger, then to the lineage graph, then to the source PDF
"One copy of the data, not five extracts."
3. Why the number is trusted
Semantics
Open the metric view, then change an allocation rule and ask again
"Finance owns the definition once, and everyone gets the same answer."
4. Every function, one space
Genie
Ops, Sales, and Marketing questions in the same Margin Genie
"No more Genie per team."
5. From insight to action
Agents
The grooming agent drafts a ticket, it shows up in the approval app, and someone approves it
"Agents act, people approve."
6. Prove it to audit
Agents
Show the MLflow trace, the agent's service principal, and the audit log
"Every action has an identity and a record."
7. Hands-on
All four
The $1B Wall challenge cards
"Find your biggest lever."
Synthetic data model
Table
Grain
Key columns
Planted story
customers
customer
customer_id, segment, region
A few large legacy-voice customers
products
product
product_id, family (strategic or legacy)
A legacy family that loses money after cost to serve
contracts
contract line
contract_id, customer_id, product_id, rate, term_end
Renewals coming up below the margin floor
circuits
circuit
circuit_id, contract_id, on_net flag, vendor_id, route
Off-net circuits that run next to Lumen fiber
billing
invoice line by month
customer_id, circuit_id, billed_amount
A small revenue leakage gap
carrier_invoices
invoice line by month
vendor_id, circuit_id, invoiced_rate, paid_amount
Rates billed above the contract rate
gl_actuals
account by month
account, cost_center, amount
Ties to the ledger within tolerance
allocation_rules
rule
cost_pool, driver, weight
One rule the room can change live
margin_ledger (gold)
customer x product x circuit x month
revenue, network_expense, cost_to_serve, contribution_margin
Everything above rolled up
Margin Genie setup
Data: the margin ledger plus the metric views, not the raw tables.
Instructions: margin is always contribution margin from the metric view. Legacy and strategic follow the product family. "Off-net" means the circuit rides a third-party vendor.
Persona starter questions:
Finance: "Which product families lost money after cost to serve last quarter?"
Ops: "Which off-net circuits run next to our own fiber, and what do we pay for them?"
Sales: "Which renewals in the next 90 days are below the margin floor?"
Marketing: "Which segments have the highest margin and the most room to grow?"
Benchmarks: each starter question has an expected answer, so the room can see Genie gets it right.
Agents in the demo
Agent
Tools it calls
Output
Approval step
Off-net grooming (hero)
Margin Genie, a UC function that scores circuits for on-net moves
A savings ticket with circuit, vendor, monthly cost, and estimated savings
Ops approves in the app
Rate audit
A UC function that compares contract, invoiced, and paid rates
A dispute draft per vendor
AP approves
Flux commentary
Margin Genie, metric views
Month-over-month margin variance narrative
FP&A edits and signs off
What can go wrong live
Risk
Fallback
Genie gives an unexpected answer
Run the benchmark questions beforehand, and keep a screenshot of each expected answer
Workspace access or network issues on the day
A recorded walkthrough of scenes 1 to 6
Agent run is slow
Pre-run one ticket so it's already in the queue, then show a second run live
