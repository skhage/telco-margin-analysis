-- Lakelink Fiber Margin Truth | P1-SYNTH-MASTER | @data-engineer
-- Builds margin_customers, margin_products, margin_vendors in cdm_tmforum.revenue_assurance
-- Contract: src/semantics/STANDARDS.md v1.0. Keys reused per DEC-003. Idempotent (CREATE OR REPLACE + INSERT OVERWRITE).
-- Statements are separated by a double semicolon for the runner (scripts strip comment lines first).
-- NOTE (2026-11-12): Spark rejects a column list in CREATE OR REPLACE TABLE ... AS SELECT
-- ("Schema may not be specified in a Replace Table As Select"). Pattern = DDL with columns, then INSERT OVERWRITE.
-- Executed 2026-11-12: products 10, vendors 30, customers 10,000; orphan FK = 0.

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
TBLPROPERTIES ('telco_project'='margin_analysis');;

INSERT OVERWRITE cdm_tmforum.revenue_assurance.margin_products
SELECT * FROM (
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
  vendor_id STRING NOT NULL COMMENT 'Unique third-party carrier identifier. Reuses the Salesforce partner account Id (salesforce_source.partner_account.Id) per DEC-003. Synonyms: carrier id, supplier id.',
  vendor_name STRING NOT NULL COMMENT 'Fictional third-party carrier name (Salesforce partner account Name) that Lakelink Fiber leases off-net access from. Synonyms: carrier, supplier, provider.',
  vendor_type STRING NOT NULL COMMENT 'Carrier type: wholesale (Salesforce Partner_Type__c = Wholesale Carrier, long-haul and transport) or CLEC (Partner_Type__c = Interconnect, competitive local access). Synonyms: carrier class.',
  origin STRING NOT NULL COMMENT 'Data origin: REAL = reused Salesforce partner account record.',
  source_system STRING NOT NULL COMMENT 'System the row was derived from.'
) COMMENT 'Third-party carriers whose circuits Lakelink Fiber leases for off-net access. Grain: one row per carrier. Source: salesforce_source.partner_account rows with Partner_Type__c Wholesale Carrier or Interconnect (30 rows; Agent and Reseller partners excluded). Synonyms: carriers, suppliers, off-net vendors. Lakelink Fiber Margin Truth.'
TBLPROPERTIES ('telco_project'='margin_analysis');;

-- DP-GAP-VENDOR-PARTNER-KEYS: vendor_id reuses partner_account.Id (supersedes MGN-VND-### synthetic ids in STANDARDS v1.0 section 2).
INSERT OVERWRITE cdm_tmforum.revenue_assurance.margin_vendors
SELECT Id, Name, CASE Partner_Type__c WHEN 'Wholesale Carrier' THEN 'wholesale' ELSE 'CLEC' END, 'REAL', 'salesforce_source.partner_account'
FROM cdm_tmforum.salesforce_source.partner_account WHERE Partner_Type__c IN ('Wholesale Carrier','Interconnect');;

CREATE OR REPLACE TABLE cdm_tmforum.revenue_assurance.margin_customers (
  customer_id BIGINT NOT NULL COMMENT 'Unique Lakelink Fiber customer identifier. Reuses the TMF customer id (salesforce account TMF_Customer_Id__c = tmf_customer.customer.customer_id). Synonyms: account id, customer number.',
  sf_account_id STRING NOT NULL COMMENT 'Salesforce CRM account Id for the customer (account.Id). Used by the Sales row filter.',
  customer_name STRING NOT NULL COMMENT 'Customer legal / account name. Synonyms: account name, client.',
  segment STRING NOT NULL COMMENT 'Commercial segment: Strategic Enterprise, Enterprise, Commercial, Small Business (Salesforce Segment__c). Synonyms: customer segment, tier.',
  region STRING NOT NULL COMMENT 'Lakelink Fiber sales region: Northeast, Southeast, Central, Mountain, West. SYNTHETIC deterministic assignment: element pmod(xxhash64(customer_id),5)+1 of that list, because the source account has no region field. Synonyms: territory, market.',
  is_legacy_voice_heavy BOOLEAN NOT NULL COMMENT 'TRUE for the 6 Strategic Enterprise customers with the most MPLS IP-VPN (ELAN-MPLS) contract lines; these carry the legacy voice / MPLS planted story. Synonyms: legacy-heavy account, legacy voice customer.',
  origin STRING NOT NULL COMMENT 'Data origin: MIXED = real Salesforce account keys and attributes with synthetic region and legacy flag.',
  source_system STRING NOT NULL COMMENT 'System the row was derived from.'
) COMMENT 'Lakelink Fiber customers for margin analysis. Grain: one row per customer. Source: salesforce_source.account (keys, name, segment) with synthetic region and legacy-voice flag. Synonyms: accounts, clients, customers. Lakelink Fiber Margin Truth.'
TBLPROPERTIES ('telco_project'='margin_analysis');;

INSERT OVERWRITE cdm_tmforum.revenue_assurance.margin_customers
WITH ipvpn AS (
  SELECT l.AccountId, count(*) AS ipvpn_lines
  FROM cdm_tmforum.salesforce_source.contract_line_item l
  JOIN cdm_tmforum.salesforce_source.product2 p ON l.Product2Id = p.Id
  WHERE p.ProductCode = 'ELAN-MPLS' GROUP BY l.AccountId
), legacy_heavy AS (
  SELECT a.Id FROM cdm_tmforum.salesforce_source.account a JOIN ipvpn i ON a.Id = i.AccountId
  WHERE a.Segment__c = 'Strategic Enterprise'
  ORDER BY i.ipvpn_lines DESC, a.AnnualRevenue DESC, a.Id LIMIT 6
)
SELECT CAST(a.TMF_Customer_Id__c AS BIGINT), a.Id, a.Name, a.Segment__c,
  element_at(array('Northeast','Southeast','Central','Mountain','West'), CAST(pmod(xxhash64(CAST(a.TMF_Customer_Id__c AS BIGINT)), 5) AS INT) + 1),
  (lh.Id IS NOT NULL), 'MIXED', 'salesforce_source.account'
FROM cdm_tmforum.salesforce_source.account a LEFT JOIN legacy_heavy lh ON a.Id = lh.Id;;

ALTER TABLE cdm_tmforum.revenue_assurance.margin_products ADD CONSTRAINT margin_products_pk PRIMARY KEY (product_id) NOT ENFORCED;;
ALTER TABLE cdm_tmforum.revenue_assurance.margin_vendors ADD CONSTRAINT margin_vendors_pk PRIMARY KEY (vendor_id) NOT ENFORCED;;
ALTER TABLE cdm_tmforum.revenue_assurance.margin_customers ADD CONSTRAINT margin_customers_pk PRIMARY KEY (customer_id) NOT ENFORCED;;
