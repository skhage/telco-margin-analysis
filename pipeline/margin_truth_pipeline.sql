-- ============================================================
-- Lakelink Fiber — Margin Truth SDP Pipeline
-- Target: cdm_tmforum.revenue_assurance (no new schemas)
-- Layers: Bronze (Auto Loader) → Silver (ai_parse/ai_extract) → Gold (margin_ledger)
-- Tag: telco_project = margin_analysis
-- Task: P1-SDP-PIPELINE (column COMMENTs added 2026-11-13 for QA-F-PIPELINE-COMMENTS; 100% columns)
-- ============================================================

-- ============================================================
-- BRONZE: Auto Loader ingests carrier invoice PDFs
-- ============================================================
CREATE OR REFRESH STREAMING TABLE margin_bronze_invoice_docs (
  path STRING COMMENT 'Full UC volume path of the carrier invoice PDF (file name = <invoice_number>_CKT-<circuit_id>.pdf). Lineage key from silver and ledger back to the source document. Synonyms: file path, document path, source pdf.',
  content BINARY COMMENT 'Raw binary bytes of the carrier invoice PDF as read by Auto Loader (binaryFile format). Input to ai_parse_document in margin_silver_invoice_parsed. Synonyms: file content, pdf bytes.',
  length BIGINT COMMENT 'Size of the PDF file in bytes. Synonyms: file size.',
  modificationTime TIMESTAMP COMMENT 'Last modified timestamp of the PDF file in the volume (UTC). Used by Auto Loader for incremental ingest. Synonyms: file timestamp, landed at.'
)
COMMENT 'Raw carrier invoice PDFs ingested via Auto Loader from the margin_documents UC volume. Grain: one row per PDF file. Source: /Volumes/cdm_tmforum/revenue_assurance/margin_documents/carrier_invoices/'
TBLPROPERTIES ('telco_project' = 'margin_analysis')
AS SELECT
  path,
  content,
  length,
  modificationTime
FROM STREAM(read_files(
  '/Volumes/cdm_tmforum/revenue_assurance/margin_documents/carrier_invoices/',
  format => 'binaryFile'
));

-- ============================================================
-- SILVER: Parse and extract structured fields from invoice PDFs
-- ============================================================
CREATE OR REFRESH MATERIALIZED VIEW margin_silver_invoice_parsed (
  path STRING COMMENT 'Full UC volume path of the source carrier invoice PDF; joins to margin_bronze_invoice_docs.path and margin_carrier_invoices.source_pdf_path. Synonyms: document path, source pdf.',
  extracted VARIANT COMMENT 'VARIANT of fields extracted by ai_extract from the parsed PDF: invoice_number, vendor_name, circuit_id, invoice_month (YYYY-MM), invoiced_rate_usd, vendor_contract_rate_usd, paid_amount_usd (US dollars). Synonyms: parsed invoice fields, extracted fields.'
)
COMMENT 'Parsed carrier invoice PDFs with structured fields extracted via ai_parse_document and ai_extract. Grain: one row per PDF. Enables scene 2 lineage trace from ledger back to source document.'
TBLPROPERTIES ('telco_project' = 'margin_analysis')
AS
WITH parsed AS (
  SELECT
    path,
    ai_parse_document(content) AS parsed_doc
  FROM margin_bronze_invoice_docs
)
SELECT
  path,
  ai_extract(
    parsed_doc,
    '{
      "invoice_number": {"type": "string", "description": "Carrier invoice number (LLF-CI-... format)"},
      "vendor_name":    {"type": "string", "description": "Third-party carrier or vendor name"},
      "circuit_id":     {"type": "string", "description": "Circuit identifier (CKT-XXXXX format)"},
      "invoice_month":  {"type": "string", "description": "Invoice period in YYYY-MM format"},
      "invoiced_rate_usd":        {"type": "number", "description": "Rate invoiced by the carrier in USD"},
      "vendor_contract_rate_usd": {"type": "number", "description": "Contracted rate with the carrier in USD"},
      "paid_amount_usd":          {"type": "number", "description": "Amount paid to the carrier in USD"}
    }',
    MAP('version', '2.1', 'instructions', 'Extract carrier invoice fields from a Lakelink Fiber carrier invoice PDF. Each PDF contains one invoice line for one circuit.')
  ) AS extracted
FROM parsed;

-- ============================================================
-- GOLD: margin_ledger with expectations
-- Same schema and logic as fast-path SQL (DEC-008), now pipeline-managed.
-- Expectations:
--   pk_not_null: composite PK columns must be non-null (FAIL)
--   no_carrier_overcharge: carrier_rate_variance_usd <= 0 (WARN: planted story, ~4500 rows)
--   billed_revenue_present: revenue_usd > 0 (WARN only: planted revenue-leakage story, 1,439 zero-billed rows).
--     Was ON VIOLATION DROP ROW until 2026-11-13; dropping removed -5,239,443.24 CM and broke tie-out to
--     the fast-path ledger (COO-Q-20261113-8). Rows must be KEPT so v2 = margin_ledger to 0.00 (DEC-020/023).
--   revenue_not_null: revenue_usd IS NOT NULL (WARN)
-- ============================================================
CREATE OR REFRESH MATERIALIZED VIEW margin_ledger_v2 (
  ledger_month DATE COMMENT 'Ledger month, first day of the month. Part of the primary key. Synonyms: month, period, fiscal month.',
  customer_id BIGINT COMMENT 'Lakelink Fiber customer (TMF customer id). Part of the primary key; references margin_customers. Synonyms: account, customer number.',
  product_id STRING COMMENT 'Product of the contract line (Salesforce product2 Id or MGN-PRD- synthetic legacy voice id). Part of the primary key; references margin_products. Synonyms: product, sku.',
  circuit_id BIGINT COMMENT 'Circuit (TMF customer facing service id). Part of the primary key; references margin_circuits. Synonyms: circuit, service id.',
  contract_id STRING COMMENT 'Contract line that bills this circuit (Salesforce contract_line_item Id); references margin_contracts. Synonyms: contract, contract line.',
  vendor_id STRING COMMENT 'Third-party carrier the circuit rides when off-net; NULL when on-net. References margin_vendors. Synonyms: carrier, supplier.',
  is_on_net BOOLEAN COMMENT 'TRUE = circuit rides the Lakelink Fiber network; FALSE = off-net on a third-party vendor. Synonyms: on-net flag, own network.',
  product_family STRING COMMENT 'Product family: Dedicated Internet, Wavelength, Ethernet, IP-VPN, Managed, Colocation, Legacy Voice. Synonyms: family, product line.',
  family_class STRING COMMENT 'strategic or legacy, from the product family (legacy = IP-VPN and Legacy Voice). Synonyms: legacy vs strategic, legacy family, strategic family.',
  segment STRING COMMENT 'Customer segment: Strategic Enterprise, Enterprise, Commercial, Small Business. Synonyms: market segment, customer tier.',
  region STRING COMMENT 'Sales region of the customer. Synonyms: territory, geography.',
  revenue_usd DECIMAL(18,2) COMMENT 'Billed revenue for the circuit in the month, US dollars (margin_billing.billed_amount_usd). Synonyms: sales, billings, top line.',
  network_expense_usd DECIMAL(18,2) COMMENT 'Network cost for the circuit in the month, US dollars. Off-net = carrier paid amount; on-net = contract rate x 0.25 (strategic) or x 0.60 (legacy). Synonyms: network cost, access cost.',
  cost_to_serve_usd DECIMAL(18,2) COMMENT 'Baseline operating cost allocated by margin_allocation_rules version MGN-ALR-v1 (GL cost-to-serve pool x driver share x weight), US dollars. Live rule changes are applied at query time in margin_ledger_allocated. Synonyms: CTS, servicing cost.',
  expected_revenue_usd DECIMAL(18,2) COMMENT 'Revenue the contract rate says should have been billed, US dollars. Expected minus revenue = revenue leakage. Synonyms: contracted revenue, should-bill.',
  carrier_rate_variance_usd DECIMAL(18,2) COMMENT 'Carrier invoiced rate minus agreed vendor contract rate, US dollars; 0 on-net or with no carrier invoice. Positive = vendor overbilled. Synonyms: rate variance, overbilling.',
  circuit_count INT COMMENT 'Allocation driver: always 1 (one circuit per ledger row). Used by circuit_count rules. Synonyms: circuits.',
  bandwidth_mbps DECIMAL(12,2) COMMENT 'Allocation driver: nominal circuit bandwidth in megabits per second (margin_circuits.bandwidth_mbps). Used by bandwidth_mbps rules.',
  ticket_count INT COMMENT 'Allocation driver: trouble tickets for the circuit in the month. Synthetic proxy for customer care tickets (DEC-016): deterministic, legacy avg 1.5 and strategic avg 0.25 per month, because the real ticket source has too few tickets in the ledger window. Drives the customer_care cost pool via ticket_count rules in margin_allocation_rules. Synonyms: tickets, trouble tickets, care tickets.',
  billed_revenue_usd DECIMAL(18,2) COMMENT 'Allocation driver: billed revenue in US dollars, same value as revenue_usd. Used by billed_revenue rules.',
  allocation_rule_version STRING COMMENT 'Allocation rule set used for cost_to_serve_usd (MGN-ALR-v1 = active margin_allocation_rules at build time). Synonyms: rule set.',
  origin STRING COMMENT 'Data origin: MIXED (real Salesforce/TMF keys with synthetic amounts and drivers).',
  source_system STRING COMMENT 'Build that produced the row: margin_sdp_pipeline (Lakeflow Spark Declarative Pipeline gold, same logic as the margin_fastpath_sql fast path, DEC-008/DEC-023).',
  CONSTRAINT pk_not_null EXPECT (ledger_month IS NOT NULL AND customer_id IS NOT NULL AND product_id IS NOT NULL AND circuit_id IS NOT NULL) ON VIOLATION FAIL UPDATE,
  CONSTRAINT no_carrier_overcharge EXPECT (carrier_rate_variance_usd <= 0),
  CONSTRAINT billed_revenue_present EXPECT (revenue_usd > 0),
  CONSTRAINT revenue_not_null EXPECT (revenue_usd IS NOT NULL)
)
COMMENT 'Lakelink Fiber margin ledger (gold, pipeline build). Same schema and logic as fast-path margin_ledger (DEC-008). Rename to margin_ledger after dropping the fast-path table. Grain: customer x product x circuit x month. Source: margin_billing, margin_carrier_invoices, margin_contracts, margin_circuits, margin_products, margin_customers, margin_gl_actuals, margin_allocation_rules.'
TBLPROPERTIES ('telco_project' = 'margin_analysis')
AS
WITH base AS (
  SELECT
    b.billing_month                          AS ledger_month,
    b.customer_id,
    k.product_id,
    b.circuit_id,
    b.contract_id,
    c.vendor_id,
    c.is_on_net,
    p.product_family,
    p.family_class,
    u.segment,
    u.region,
    CAST(b.billed_amount_usd   AS DECIMAL(18,2)) AS revenue_usd,
    CAST(b.expected_amount_usd AS DECIMAL(18,2)) AS expected_revenue_usd,
    CAST(
      CASE
        WHEN c.is_on_net
          THEN k.contract_rate_usd * CASE WHEN p.family_class = 'legacy' THEN 0.60 ELSE 0.25 END
        ELSE COALESCE(ci.paid_amount_usd, 0)
      END AS DECIMAL(18,2)
    ) AS network_expense_usd,
    CAST(
      CASE
        WHEN c.is_on_net OR ci.circuit_id IS NULL THEN 0
        ELSE ci.invoiced_rate_usd - ci.vendor_contract_rate_usd
      END AS DECIMAL(18,2)
    ) AS carrier_rate_variance_usd,
    1 AS circuit_count,
    CAST(c.bandwidth_mbps AS DECIMAL(12,2)) AS bandwidth_mbps,
    CAST(
      CASE
        WHEN p.family_class = 'legacy'
          THEN FLOOR(PMOD(XXHASH64(b.circuit_id, b.billing_month), 1000) / 250)
        ELSE
          CASE WHEN PMOD(XXHASH64(b.circuit_id, b.billing_month), 100) < 25 THEN 1 ELSE 0 END
      END AS INT
    ) AS ticket_count
  FROM      cdm_tmforum.revenue_assurance.margin_billing          b
  JOIN      cdm_tmforum.revenue_assurance.margin_circuits          c  ON c.circuit_id  = b.circuit_id
  JOIN      cdm_tmforum.revenue_assurance.margin_contracts         k  ON k.contract_id = b.contract_id
  JOIN      cdm_tmforum.revenue_assurance.margin_products          p  ON p.product_id  = k.product_id
  JOIN      cdm_tmforum.revenue_assurance.margin_customers         u  ON u.customer_id = b.customer_id
  LEFT JOIN cdm_tmforum.revenue_assurance.margin_carrier_invoices ci  ON ci.circuit_id = b.circuit_id
                                                                    AND ci.invoice_month = b.billing_month
),
tot AS (
  SELECT ledger_month,
         SUM(circuit_count)   AS s_cc,
         SUM(bandwidth_mbps)  AS s_bw,
         SUM(ticket_count)    AS s_tk,
         SUM(revenue_usd)     AS s_rev
  FROM base
  GROUP BY ALL
),
pools AS (
  SELECT g.period_month AS ledger_month,
         r.driver,
         SUM(g.amount_usd * r.weight) AS amt
  FROM cdm_tmforum.revenue_assurance.margin_gl_actuals        g
  JOIN cdm_tmforum.revenue_assurance.margin_allocation_rules  r
    ON r.cost_pool = g.cost_pool
   AND r.is_active
   AND g.period_month >= r.effective_from
   AND (r.effective_to IS NULL OR g.period_month <= r.effective_to)
  WHERE g.account_class = 'cost_to_serve_pool'
  GROUP BY ALL
),
pw AS (
  SELECT ledger_month,
         SUM(CASE WHEN driver = 'circuit_count'  THEN amt END) AS a_cc,
         SUM(CASE WHEN driver = 'bandwidth_mbps' THEN amt END) AS a_bw,
         SUM(CASE WHEN driver = 'ticket_count'   THEN amt END) AS a_tk,
         SUM(CASE WHEN driver = 'billed_revenue' THEN amt END) AS a_rev
  FROM pools
  GROUP BY ALL
)
SELECT
  b.ledger_month, b.customer_id, b.product_id, b.circuit_id, b.contract_id,
  b.vendor_id, b.is_on_net, b.product_family, b.family_class, b.segment, b.region,
  b.revenue_usd,
  b.network_expense_usd,
  CAST(
    COALESCE(pw.a_cc, 0) * b.circuit_count  / t.s_cc
  + COALESCE(pw.a_bw, 0) * b.bandwidth_mbps / t.s_bw
  + COALESCE(pw.a_tk, 0) * b.ticket_count   / NULLIF(t.s_tk, 0)
  + COALESCE(pw.a_rev,0) * b.revenue_usd    / t.s_rev
  AS DECIMAL(18,2)) AS cost_to_serve_usd,
  b.expected_revenue_usd,
  b.carrier_rate_variance_usd,
  b.circuit_count,
  b.bandwidth_mbps,
  b.ticket_count,
  b.revenue_usd AS billed_revenue_usd,
  'MGN-ALR-v1'          AS allocation_rule_version,
  'MIXED'               AS origin,
  'margin_sdp_pipeline' AS source_system
FROM base b
JOIN tot  t  USING (ledger_month)
LEFT JOIN pw USING (ledger_month);
