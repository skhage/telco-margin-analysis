-- Lakelink Fiber Margin Truth: Sales own-accounts row filter (P5-ROW-FILTERS, @data-engineer, 2026-11-13)
-- Sales principals (account group lakelink_margin_sales) see only customers in their assigned region.
-- Everyone else (Finance, Ops, Marketing, QA, agents) is unfiltered, so MEASURE(contribution_margin) stays 2,375,095,705.09.
-- Region is derived from customer_id with the same rule that built margin_customers.region (verified 10,000/10,000 and 517,032/517,032 ledger rows),
-- so the filter never reads a row-filtered table.

CREATE TABLE IF NOT EXISTS cdm_tmforum.revenue_assurance.margin_sales_territory (
  region STRING NOT NULL COMMENT 'Lakelink Fiber sales region (Northeast, Southeast, Central, Mountain, West); matches margin_customers.region. Synonyms: territory, market.',
  rep_principal STRING NOT NULL COMMENT 'Unity Catalog principal (user email) of the Sales rep who owns every account in this region. SYNTHETIC demo rep identities at lakelinkfiber.example. Synonyms: account owner, sales rep.',
  rep_display_name STRING COMMENT 'Display name of the synthetic Sales rep, for UI and Genie answers.',
  origin STRING COMMENT 'Data origin flag: SYNTHETIC for every row (no account-owner master exists in salesforce_source).',
  CONSTRAINT margin_sales_territory_pk PRIMARY KEY (region, rep_principal)
) COMMENT 'Sales territory assignment for the Lakelink Fiber Margin Truth demo. Grain: one row per region x Sales rep. Drives the Sales own-accounts row filter (margin_sales_row_filter). SYNTHETIC because salesforce_source.account has no OwnerId.'
TBLPROPERTIES ('telco_project'='margin_analysis');

INSERT OVERWRITE cdm_tmforum.revenue_assurance.margin_sales_territory VALUES
 ('Northeast','sales.northeast@lakelinkfiber.example','Northeast Sales Rep','SYNTHETIC'),
 ('Southeast','sales.southeast@lakelinkfiber.example','Southeast Sales Rep','SYNTHETIC'),
 ('Central','sales.central@lakelinkfiber.example','Central Sales Rep','SYNTHETIC'),
 ('Mountain','sales.mountain@lakelinkfiber.example','Mountain Sales Rep','SYNTHETIC'),
 ('West','sales.west@lakelinkfiber.example','West Sales Rep','SYNTHETIC');
-- For a live demo, replace one rep_principal with a real workspace test user and add that user to lakelink_margin_sales.

CREATE OR REPLACE FUNCTION cdm_tmforum.revenue_assurance.margin_sales_can_see(p_customer_id BIGINT, p_principal STRING, p_is_sales BOOLEAN)
RETURNS BOOLEAN
COMMENT 'Pure, testable visibility rule behind the Sales own-accounts row filter. telco_project=margin_analysis (DP-FN-TAG-COMMENT; UC functions cannot carry governed tags or TBLPROPERTIES).'
RETURN NOT p_is_sales OR EXISTS (
  SELECT 1 FROM cdm_tmforum.revenue_assurance.margin_sales_territory t
  WHERE t.rep_principal = p_principal
    AND t.region = element_at(array('Northeast','Southeast','Central','Mountain','West'), CAST(pmod(xxhash64(p_customer_id),5)+1 AS INT)));

CREATE OR REPLACE FUNCTION cdm_tmforum.revenue_assurance.margin_sales_row_filter(p_customer_id BIGINT)
RETURNS BOOLEAN
COMMENT 'Row filter for margin_ tables: Sales (account group lakelink_margin_sales) sees only its own accounts; everyone else is unfiltered. telco_project=margin_analysis (DP-FN-TAG-COMMENT; UC functions cannot carry governed tags or TBLPROPERTIES).'
RETURN cdm_tmforum.revenue_assurance.margin_sales_can_see(p_customer_id, current_user(), is_account_group_member('lakelink_margin_sales'));

ALTER TABLE cdm_tmforum.revenue_assurance.margin_ledger    SET ROW FILTER cdm_tmforum.revenue_assurance.margin_sales_row_filter ON (customer_id);
ALTER TABLE cdm_tmforum.revenue_assurance.margin_customers SET ROW FILTER cdm_tmforum.revenue_assurance.margin_sales_row_filter ON (customer_id);
ALTER TABLE cdm_tmforum.revenue_assurance.margin_contracts SET ROW FILTER cdm_tmforum.revenue_assurance.margin_sales_row_filter ON (customer_id);
-- margin_ledger_v2 (SDP MV, pipeline 20960984) binds the same filter inline via WITH ROW FILTER in pipeline/margin_truth_pipeline.sql.

-- Rollback:
-- ALTER TABLE cdm_tmforum.revenue_assurance.margin_ledger    DROP ROW FILTER;
-- ALTER TABLE cdm_tmforum.revenue_assurance.margin_customers DROP ROW FILTER;
-- ALTER TABLE cdm_tmforum.revenue_assurance.margin_contracts DROP ROW FILTER;

-- Verification (simulated West rep; expect 2001 customers, 103176 ledger rows, 0 out-of-region rows):
-- SELECT count_if(cdm_tmforum.revenue_assurance.margin_sales_can_see(customer_id,'sales.west@lakelinkfiber.example',true)) FROM cdm_tmforum.revenue_assurance.margin_customers;
