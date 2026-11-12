-- Lakelink Fiber Margin Truth: synthetic margin_billing, margin_carrier_invoices, margin_gl_actuals
-- Task P1-SYNTH-BILLING-CARRIER-GL (+ DP-GAP-GL-2026-COST-CENTERS, DE-REQ-ONNET-SCORE-FIELDS). Owner @data-engineer.
-- Window: 12 months 2025-11-01 .. 2026-10-01. Contract STANDARDS.md v1.0. Statements are separated by a double semicolon (run one per call).
-- Keys reused from margin_circuits / margin_contracts / margin_vendors (no new FK values).
-- On-net network cost rule (ledger must reuse): contract_rate_usd x 0.25 (strategic) or 0.60 (legacy).
CREATE OR REPLACE TEMP VIEW mgn_base AS
SELECT c.circuit_id, c.contract_id, c.customer_id, c.is_on_net, c.vendor_id, c.bandwidth_mbps, c.onnet_distance_m,
       c.is_parallel_to_onnet_fiber, k.contract_rate_usd, k.term_end, k.origin AS contract_origin,
       p.product_family, p.family_class, COALESCE(cli.Discount__c, 0) AS discount_pct, cli.leakage_flag,
       c.circuit_id IN (45040,98532,106254,61166,104764,77560,47071,72455,108929,100947,20694,54378) AS is_hero,
       (NOT c.is_on_net AND k.origin = 'REAL' AND k.term_end >= DATE'2026-11-12' AND k.term_end < DATE'2027-02-10'
        AND COALESCE(cli.Discount__c, 0) >= 30) AS is_forced_renewal
FROM cdm_tmforum.revenue_assurance.margin_circuits c
JOIN cdm_tmforum.revenue_assurance.margin_contracts k ON k.contract_id = c.contract_id
JOIN cdm_tmforum.revenue_assurance.margin_products p ON p.product_id = k.product_id
LEFT JOIN cdm_tmforum.salesforce_source.contract_line_item cli ON cli.Id = c.contract_id
;;
CREATE OR REPLACE TEMP VIEW mgn_months AS
SELECT explode(sequence(DATE'2025-11-01', DATE'2026-10-01', INTERVAL 1 MONTH)) AS m
;;
CREATE OR REPLACE TABLE cdm_tmforum.revenue_assurance.margin_billing (
  billing_line_id STRING NOT NULL COMMENT 'Unique id of the customer invoice line, format MGN-BIL-<circuit_id>-<yyyyMM>. Synonyms: invoice line id, bill line.',
  billing_month DATE NOT NULL COMMENT 'Billing period, first day of the month. Synonyms: invoice month, bill period.',
  customer_id BIGINT NOT NULL COMMENT 'Lakelink Fiber customer billed (FK to margin_customers.customer_id). Synonyms: account, client.',
  contract_id STRING NOT NULL COMMENT 'Contract line the charge comes from (FK to margin_contracts.contract_id).',
  circuit_id BIGINT NOT NULL COMMENT 'Circuit billed (FK to margin_circuits.circuit_id). Synonyms: service id, circuit.',
  expected_amount_usd DECIMAL(18,2) NOT NULL COMMENT 'Amount that should have been billed: contracted monthly rate, US dollars. Synonyms: contracted revenue, expected billing.',
  billed_amount_usd DECIMAL(18,2) NOT NULL COMMENT 'Amount actually billed to the customer in the month, US dollars. Expected minus billed = revenue leakage. Synonyms: billings, invoiced revenue, revenue.',
  origin STRING NOT NULL COMMENT 'Data origin: REAL, SYNTHETIC or MIXED. MIXED = synthetic monthly rows priced from real contract rates.',
  source_system STRING NOT NULL COMMENT 'System or generator the row comes from.'
) COMMENT 'Lakelink Fiber customer billing lines. Grain: one row per customer x circuit x month (12 months Nov 2025 - Oct 2026). Source: synthetic monthly billing priced from salesforce contract rates; includes a small planted revenue leakage gap. Synonyms: billing, invoices, AR lines. Lakelink Fiber Margin Truth.'
TBLPROPERTIES ('telco_project' = 'margin_analysis')
;;
INSERT OVERWRITE cdm_tmforum.revenue_assurance.margin_billing
SELECT concat('MGN-BIL-', b.circuit_id, '-', date_format(mo.m, 'yyyyMM')),
       mo.m, b.customer_id, b.contract_id, b.circuit_id,
       CAST(b.contract_rate_usd AS DECIMAL(18,2)),
       CAST(CASE WHEN b.leakage_flag = 'price_mismatch' AND mo.m >= DATE'2026-04-01' THEN round(b.contract_rate_usd * 0.90, 2)
                 WHEN pmod(xxhash64(b.circuit_id, mo.m, 'leak'), 1000) < 3 THEN 0
                 ELSE b.contract_rate_usd END AS DECIMAL(18,2)),
       'MIXED', 'margin_synthetic (rates from salesforce_source.contract_line_item)'
FROM mgn_base b CROSS JOIN mgn_months mo
;;
CREATE OR REPLACE TABLE cdm_tmforum.revenue_assurance.margin_carrier_invoices (
  carrier_invoice_line_id STRING NOT NULL COMMENT 'Unique id of the carrier invoice line, format MGN-CIL-<circuit_id>-<yyyyMM>.',
  invoice_number STRING NOT NULL COMMENT 'Carrier invoice number (one invoice per vendor per month), format LLF-CI-<vendor suffix>-<yyyyMM>. Synonyms: vendor invoice, carrier bill.',
  invoice_month DATE NOT NULL COMMENT 'Invoice period, first day of the month. Synonyms: billing month, period.',
  vendor_id STRING NOT NULL COMMENT 'Third-party carrier that invoiced the circuit (FK to margin_vendors.vendor_id). Synonyms: carrier, supplier.',
  circuit_id BIGINT NOT NULL COMMENT 'Off-net circuit the carrier charges for (FK to margin_circuits.circuit_id). Only off-net circuits appear.',
  vendor_contract_rate_usd DECIMAL(18,2) NOT NULL COMMENT 'Monthly rate agreed with the carrier, US dollars. Synonyms: contracted carrier rate, agreed rate.',
  invoiced_rate_usd DECIMAL(18,2) NOT NULL COMMENT 'Monthly rate the carrier actually invoiced, US dollars. Above the contract rate = rate variance (overbilling). Synonyms: billed rate, charged rate.',
  paid_amount_usd DECIMAL(18,2) NOT NULL COMMENT 'Amount Lakelink Fiber paid the carrier for the circuit in the month, US dollars. Drives off-net network expense. Synonyms: carrier cost, off-net spend, paid.',
  source_pdf_path STRING COMMENT 'Path of the source carrier invoice PDF in volume /Volumes/cdm_tmforum/revenue_assurance/margin_documents; NULL until the PDF is generated.',
  extraction_method STRING NOT NULL COMMENT 'How the line was captured: ai_extract (parsed from PDF) or structured (EDI/feed).',
  origin STRING NOT NULL COMMENT 'Data origin: REAL, SYNTHETIC or MIXED.',
  source_system STRING NOT NULL COMMENT 'System or generator the row comes from.'
) COMMENT 'Lakelink Fiber third-party carrier invoice lines for off-net circuits. Grain: one row per vendor x circuit x month (12 months Nov 2025 - Oct 2026). Source: synthetic. Planted: some carriers invoice above the contract rate; hero grooming circuits cost more than an on-net move. Synonyms: carrier invoices, vendor bills, off-net costs, AP lines. Lakelink Fiber Margin Truth.'
TBLPROPERTIES ('telco_project' = 'margin_analysis')
;;
INSERT OVERWRITE cdm_tmforum.revenue_assurance.margin_carrier_invoices
WITH r AS (
  SELECT b.*, mo.m,
    CAST(CASE WHEN b.is_hero THEN round(2 * b.bandwidth_mbps + COALESCE(b.onnet_distance_m, 0) / 72 + 300 + pmod(xxhash64(b.circuit_id, 'hero'), 400), 2)
              WHEN b.is_forced_renewal THEN round(b.contract_rate_usd * 0.88, 2)
              WHEN b.product_family = 'Legacy Voice' THEN round(b.contract_rate_usd * 0.95, 2)
              WHEN b.product_family = 'IP-VPN' THEN round(b.contract_rate_usd * 0.92, 2)
              ELSE round(b.contract_rate_usd * (0.50 + pmod(xxhash64(b.circuit_id, 'vcr'), 100) / 1000.0), 2) END AS DECIMAL(18,2)) AS vcr,
    b.vendor_id IN ('001000000002659AAA', '00100000000264PAAA', '00100000000265pAAA') AND mo.m >= DATE'2026-05-01'
      AND pmod(xxhash64(b.circuit_id, mo.m, 'var'), 10) < 4 AS is_over
  FROM mgn_base b CROSS JOIN mgn_months mo
  WHERE NOT b.is_on_net
)
SELECT concat('MGN-CIL-', circuit_id, '-', date_format(m, 'yyyyMM')),
       concat('LLF-CI-', right(vendor_id, 6), '-', date_format(m, 'yyyyMM')),
       m, vendor_id, circuit_id, vcr,
       CAST(CASE WHEN is_over THEN round(vcr * 1.08, 2) ELSE vcr END AS DECIMAL(18,2)),
       CAST(CASE WHEN is_over THEN round(vcr * 1.08, 2) ELSE vcr END AS DECIMAL(18,2)),
       CAST(NULL AS STRING), 'structured', 'SYNTHETIC', 'margin_synthetic'
FROM r
;;
CREATE OR REPLACE TABLE cdm_tmforum.revenue_assurance.margin_gl_actuals (
  gl_actual_id STRING NOT NULL COMMENT 'Unique id of the GL balance, format MGN-GL-<account>-<cost center>-<yyyyMM>.',
  period_month DATE NOT NULL COMMENT 'Accounting period, first day of the month. Synonyms: fiscal period, GL month.',
  gl_account STRING NOT NULL COMMENT 'General ledger natural account: 4000 Recurring Service Revenue, 5000 Network Cost of Sales (on-net), 6100 Partner Settlement Expense (off-net carriers), 7100-7400 cost-to-serve pools (synthetic). Synonyms: account, natural account.',
  cost_center STRING NOT NULL COMMENT 'Cost center: 400 Revenue, 510 On-net Network, 520 Off-net Carrier, 610 Field Ops, 620 NOC, 630 Customer Care, 640 Billing Ops.',
  account_class STRING NOT NULL COMMENT 'Margin bucket of the account: revenue, network_expense or cost_to_serve_pool.',
  cost_pool STRING COMMENT 'Cost-to-serve pool allocated by margin_allocation_rules (field_ops, noc, customer_care, billing_ops); NULL unless account_class = cost_to_serve_pool.',
  amount_usd DECIMAL(18,2) NOT NULL COMMENT 'Posted GL amount for the period, US dollars (revenue positive, costs positive). Ties to the margin ledger within 0.5%. Synonyms: actuals, balance.',
  origin STRING NOT NULL COMMENT 'Data origin: REAL, SYNTHETIC or MIXED.',
  source_system STRING NOT NULL COMMENT 'System or generator the row comes from.'
) COMMENT 'Lakelink Fiber general ledger actuals. Grain: one row per GL account x cost center x month (12 months Nov 2025 - Oct 2026). Source: synthetic, accounts 4000/5000/6100 from oracle_erp_source.gl_code_combinations plus synthetic cost-to-serve pools. Used for the ledger-to-GL tie-out (tolerance 0.5%) and as cost-to-serve pool amounts. Synonyms: GL, actuals, general ledger. Lakelink Fiber Margin Truth.'
TBLPROPERTIES ('telco_project' = 'margin_analysis')
;;
INSERT OVERWRITE cdm_tmforum.revenue_assurance.margin_gl_actuals
WITH noise AS (SELECT m, (pmod(xxhash64(m, 'gl'), 7) - 3) * 0.0005 AS f FROM mgn_months),
rev AS (SELECT billing_month m, SUM(billed_amount_usd) a FROM cdm_tmforum.revenue_assurance.margin_billing GROUP BY 1),
onnet AS (SELECT mo.m, SUM(b.contract_rate_usd * CASE WHEN b.family_class = 'legacy' THEN 0.60 ELSE 0.25 END) a
          FROM mgn_base b CROSS JOIN mgn_months mo WHERE b.is_on_net GROUP BY 1),
offnet AS (SELECT invoice_month m, SUM(paid_amount_usd) a FROM cdm_tmforum.revenue_assurance.margin_carrier_invoices GROUP BY 1),
pools AS (SELECT * FROM VALUES ('7100','610','field_ops',12000000.0),('7200','620','noc',8000000.0),
                                ('7300','630','customer_care',6000000.0),('7400','640','billing_ops',4000000.0) AS t(acct, cc, pool, base)),
lines AS (
  SELECT r.m, '4000' acct, '400' cc, 'revenue' cls, CAST(NULL AS STRING) pool, r.a * (1 + n.f) amt FROM rev r JOIN noise n USING (m)
  UNION ALL SELECT o.m, '5000', '510', 'network_expense', NULL, o.a * (1 + n.f) FROM onnet o JOIN noise n USING (m)
  UNION ALL SELECT o.m, '6100', '520', 'network_expense', NULL, o.a * (1 - n.f) FROM offnet o JOIN noise n USING (m)
  UNION ALL SELECT mo.m, p.acct, p.cc, 'cost_to_serve_pool', p.pool, p.base * (1 + (pmod(xxhash64(mo.m, p.pool), 41) - 20) / 1000.0)
            FROM mgn_months mo CROSS JOIN pools p)
SELECT concat('MGN-GL-', acct, '-', cc, '-', date_format(m, 'yyyyMM')), m, acct, cc, cls, pool,
       CAST(round(amt, 2) AS DECIMAL(18,2)), 'SYNTHETIC', 'margin_synthetic (accounts from oracle_erp_source.gl_code_combinations)'
FROM lines
;;
-- Constraints (informational, NOT ENFORCED), run after the loads
ALTER TABLE cdm_tmforum.revenue_assurance.margin_billing ADD CONSTRAINT margin_billing_pk PRIMARY KEY (billing_line_id) NOT ENFORCED
;;
ALTER TABLE cdm_tmforum.revenue_assurance.margin_billing ADD CONSTRAINT margin_billing_customer_fk FOREIGN KEY (customer_id) REFERENCES cdm_tmforum.revenue_assurance.margin_customers(customer_id) NOT ENFORCED
;;
ALTER TABLE cdm_tmforum.revenue_assurance.margin_billing ADD CONSTRAINT margin_billing_contract_fk FOREIGN KEY (contract_id) REFERENCES cdm_tmforum.revenue_assurance.margin_contracts(contract_id) NOT ENFORCED
;;
ALTER TABLE cdm_tmforum.revenue_assurance.margin_billing ADD CONSTRAINT margin_billing_circuit_fk FOREIGN KEY (circuit_id) REFERENCES cdm_tmforum.revenue_assurance.margin_circuits(circuit_id) NOT ENFORCED
;;
ALTER TABLE cdm_tmforum.revenue_assurance.margin_carrier_invoices ADD CONSTRAINT margin_carrier_invoices_pk PRIMARY KEY (carrier_invoice_line_id) NOT ENFORCED
;;
ALTER TABLE cdm_tmforum.revenue_assurance.margin_carrier_invoices ADD CONSTRAINT margin_carrier_invoices_vendor_fk FOREIGN KEY (vendor_id) REFERENCES cdm_tmforum.revenue_assurance.margin_vendors(vendor_id) NOT ENFORCED
;;
ALTER TABLE cdm_tmforum.revenue_assurance.margin_carrier_invoices ADD CONSTRAINT margin_carrier_invoices_circuit_fk FOREIGN KEY (circuit_id) REFERENCES cdm_tmforum.revenue_assurance.margin_circuits(circuit_id) NOT ENFORCED
;;
ALTER TABLE cdm_tmforum.revenue_assurance.margin_gl_actuals ADD CONSTRAINT margin_gl_actuals_pk PRIMARY KEY (gl_actual_id) NOT ENFORCED
