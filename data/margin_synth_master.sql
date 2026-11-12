-- Lakelink Fiber Margin Truth | P1-SYNTH-MASTER | @data-engineer
-- Builds margin_customers, margin_products, margin_vendors in cdm_tmforum.revenue_assurance
-- Contract: src/semantics/STANDARDS.md v1.0. Keys reused per DEC-003. Idempotent (CREATE OR REPLACE).
-- Statements are separated by a double semicolon for the runner (scripts strip comment lines first).

CREATE OR REPLACE TABLE cdm_tmforum.revenue_assurance.margin_products (
  product_id STRING NOT NULL COMMENT 'Unique product identifier. Reuses the Salesforce product catalog Id; Lakelink-only legacy voice products use the MGN-PRD- prefix. Synonyms: SKU id, offer id.',
  product_code STRING NOT NULL COMMENT 'Short product code, e.g. FIBER-DIA-1G. Synonyms: SKU, product code.',
  product_name STRING NOT NULL COMMENT 'Customer-facing product name.',
  product_family STRING NOT NULL COMMENT 'Product family: Dedicated Internet, Wavelength, Ethernet, IP-VPN, Managed, Colocation, Legacy Voice. Synonyms: product line, family.',
  family_class STRING NOT NULL COMMENT 'strategic or legacy. Legacy = IP-VPN (MPLS) and Legacy Voice; all other families are strategic. Synonyms: portfolio class, legacy vs strategic.',
  list_mrr_usd DECIMAL(18,2) NOT NULL COMMENT 'List monthly recurring charge, US dollars per month. Synonyms: list price, MRC.',
  margin_floor_pct DECIMAL(9,4) NOT NULL COMMENT 'Minimum acceptable contribution margin percent for this product, owned by Finance (0.2000 = 20%). Synonyms: margin floor, hurdle margin.',
  origin STRING NOT NULL COMMENT 'Data origin: REAL (reused source record), SYNTHETIC (generated for the demo), or MIXED.',
  source_system STRING NOT NULL COMMENT 'System the row was derived from.'
) COMMENT 'Lakelink Fiber product catalog with legacy vs strategic classification and Finance margin floor. Grain: one row per product. Source: salesforce_source.product2 plus synthetic legacy voice products. Synonyms: products, offers, SKUs. Lakelink Fiber Margin Truth.'
AS SELECT * FROM (
  SELECT Id, ProductCode, Name, Family,
         CASE WHEN Family IN ('IP-VPN','Legacy Voice') THEN 'legacy' ELSE 'strategic' END,
         CAST(list_mrr AS DECIMAL(18,2)), CAST(0.2000 AS DECIMAL(9,4)), 'REAL', 'salesforce_source.product2'
  FROM cdm_tmforum.salesforce_source.product2
  UNION ALL
  SELECT * FROM VALUES
    ('MGN-PRD-001','VOICE-PRI-T1','PRI Voice Trunk (T1)','Legacy Voice','legacy',CAST(420.00 AS DECIMAL(18,2)),CAST(0.2000 AS DECIMAL(9,4)),'SYNTHETIC','margin_synthetic'),
    ('MGN-PRD-002','VOICE-POTS-BIZ','Business Analog Voice Line (POTS)','Legacy Voice','legacy',CAST(95.00 AS DECIMAL(18,2)),CAST(0.2000 AS DECIMAL(9,4)),'SYNTHETIC','margin_synthetic')
);;

CREATE OR REPLACE TABLE cdm_tmforum.revenue_assurance.margin_vendors (
  vendor_id STRING NOT NULL COMMENT 'Unique third-party carrier identifier, format MGN-VND-###. Synonyms: carrier id, supplier id.',
  vendor_name STRING NOT NULL COMMENT 'Fictional third-party carrier name that Lakelink Fiber leases off-net access from. Synonyms: carrier, supplier, provider.',
  vendor_type STRING NOT NULL COMMENT 'Carrier type: ILEC (incumbent local exchange carrier), CLEC (competitive local exchange carrier), or wholesale (long-haul / transport wholesaler).',
  origin STRING NOT NULL COMMENT 'Data origin: REAL, SYNTHETIC, or MIXED. All vendors are SYNTHETIC (no supplier master in source schemas).',
  source_system STRING NOT NULL COMMENT 'System the row was derived from.'
) COMMENT 'Third-party carriers whose circuits Lakelink Fiber leases for off-net access. Grain: one row per carrier. Source: synthetic (no supplier master exists in tmf_businesspartner). Synonyms: carriers, suppliers, off-net vendors. Lakelink Fiber Margin Truth.'
AS SELECT * FROM VALUES
  ('MGN-VND-001','Prairie Gateway Telephone','ILEC','SYNTHETIC','margin_synthetic'),
  ('MGN-VND-002','Summit Valley Exchange','ILEC','SYNTHETIC','margin_synthetic'),
  ('MGN-VND-003','Granite Ridge Telco','ILEC','SYNTHETIC','margin_synthetic'),
  ('MGN-VND-004','Northridge Access Networks','CLEC','SYNTHETIC','margin_synthetic'),
  ('MGN-VND-005','Cedar Point Metro Connect','CLEC','SYNTHETIC','margin_synthetic'),
  ('MGN-VND-006','Riverbend Local Fiber','CLEC','SYNTHETIC','margin_synthetic'),
  ('MGN-VND-007','Bluewater Wholesale Transport','wholesale','SYNTHETIC','margin_synthetic'),
  ('MGN-VND-008','Ironline Carrier Services','wholesale','SYNTHETIC','margin_synthetic')
  AS v(vendor_id, vendor_name, vendor_type, origin, source_system);;

CREATE OR REPLACE TABLE cdm_tmforum.revenue_assurance.margin_customers (
  customer_id BIGINT NOT NULL COMMENT 'Unique Lakelink Fiber customer identifier. Reuses the TMF customer id (salesforce account TMF_Customer_Id__c = tmf_customer.customer.customer_id). Synonyms: account id, customer number.',
  sf_account_id STRING NOT NULL COMMENT 'Salesforce CRM account Id for the customer (account.Id). Used by the Sales row filter.',
  customer_name STRING NOT NULL COMMENT 'Customer legal / account name. Synonyms: account name, client.',
  segment STRING NOT NULL COMMENT 'Commercial segment: Strategic Enterprise, Enterprise, Commercial, Small Business (Salesforce Segment__c). Synonyms: customer segment, tier.',
  region STRING NOT NULL COMMENT 'Lakelink Fiber sales region: Northeast, Southeast, Central, Mountain, West. SYNTHETIC deterministic assignment (no usable region field in source). Synonyms: territory, market.',
  is_legacy_voice_heavy BOOLEAN NOT NULL COMMENT 'TRUE for the few large Strategic Enterprise customers whose spend is concentrated in legacy voice / MPLS (planted story). Synonyms: legacy-heavy account, legacy voice customer.',
  origin STRING NOT NULL COMMENT 'Data origin: MIXED = real Salesforce account keys and attributes with synthetic region and legacy flag.',
  source_system STRING NOT NULL COMMENT 'System the row was derived from.'
) COMMENT 'Lakelink Fiber customers for margin analysis. Grain: one row per customer. Source: salesforce_source.account (keys, name, segment) with synthetic region and legacy-voice flag. Synonyms: accounts, clients, customers. Lakelink Fiber Margin Truth.'
AS
WITH ipvpn AS (
  SELECT l.AccountId, count(*) AS ipvpn_lines
  FROM cdm_tmforum.salesforce_source.contract_line_item l
  WHERE l.ProductCode = 'ELAN-MPLS' GROUP BY l.AccountId
), legacy_heavy AS (
  SELECT a.Id FROM cdm_tmforum.salesforce_source.account a JOIN ipvpn i ON a.Id = i.AccountId
  WHERE a.Segment__c = 'Strategic Enterprise'
  ORDER BY i.ipvpn_lines DESC, a.AnnualRevenue DESC, a.Id LIMIT 6
)
SELECT a.TMF_Customer_Id__c, a.Id, a.Name, a.Segment__c,
  element_at(array('Northeast','Southeast','Central','Mountain','West'), CAST(pmod(xxhash64(a.TMF_Customer_Id__c), 5) AS INT) + 1),
  (lh.Id IS NOT NULL), 'MIXED', 'salesforce_source.account'
FROM cdm_tmforum.salesforce_source.account a LEFT JOIN legacy_heavy lh ON a.Id = lh.Id;;
