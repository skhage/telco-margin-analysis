-- Lakelink Fiber Margin Truth: margin_contracts + margin_circuits generator
-- Task P1-SYNTH-CONTRACTS-CIRCUITS (@data-engineer, 2026-11-12). Contract: src/semantics/STANDARDS.md v1.0
-- Run one statement per spark.sql call (RTAS with a column list is rejected). Strip comment lines before splitting.
-- Keys reused: contract_id = salesforce_source.contract_line_item.Id, circuit_id = tmf_service.customer_facing_service id,
-- customer_id via margin_customers.sf_account_id, vendor_id from margin_vendors. Synthetic legacy lines use MGN-CTR- ids
-- and circuit ids drawn only from unused customer_facing_service ids.
-- Planted: (1) 6 legacy-voice-heavy customers get 30 discounted Legacy Voice lines each (15 renew 2026-11-20..2027-01-29)
-- (2) renewal-window lines with Discount >= 30 are forced off-net (below-floor renewals once carrier cost lands)
-- (3) 12 hero off-net 1G circuits parallel to Lakelink Fiber fiber at 51..172 m (grooming candidates).

CREATE OR REPLACE TABLE cdm_tmforum.revenue_assurance.margin_contracts (
  contract_id STRING NOT NULL, agreement_number STRING NOT NULL, customer_id BIGINT NOT NULL, product_id STRING NOT NULL,
  contract_rate_usd DECIMAL(18,2) NOT NULL, term_start DATE NOT NULL, term_end DATE NOT NULL, is_auto_renew BOOLEAN NOT NULL,
  origin STRING NOT NULL, source_system STRING NOT NULL
) TBLPROPERTIES ('telco_project'='margin_analysis');
-- (table and column COMMENTs applied in the run; see information_schema for full text)

INSERT OVERWRITE cdm_tmforum.revenue_assurance.margin_contracts
WITH real_lines AS (
  SELECT l.Id contract_id, c.ContractNumber agreement_number, m.customer_id, l.Product2Id product_id,
         CAST(ROUND(l.TotalPrice,2) AS DECIMAL(18,2)) contract_rate_usd, c.StartDate term_start, c.EndDate term_end,
         COALESCE(CAST(c.Auto_Renew__c AS BOOLEAN), FALSE) is_auto_renew, 'REAL' origin, 'salesforce_source.contract_line_item' source_system
  FROM cdm_tmforum.salesforce_source.contract_line_item l JOIN cdm_tmforum.salesforce_source.contract c ON l.Contract__c=c.Id
  JOIN cdm_tmforum.revenue_assurance.margin_customers m ON l.AccountId=m.sf_account_id),
legacy_cust AS (
  SELECT m.customer_id, min(c.ContractNumber) agreement_number, row_number() OVER (ORDER BY m.customer_id) cn
  FROM cdm_tmforum.revenue_assurance.margin_customers m JOIN cdm_tmforum.salesforce_source.contract c ON c.AccountId=m.sf_account_id
  WHERE m.is_legacy_voice_heavy GROUP BY m.customer_id),
seq AS (SELECT explode(sequence(1,30)) n),
syn AS (
  SELECT lc.customer_id, lc.agreement_number, s.n, (lc.cn-1)*30+s.n gid,
         CASE WHEN s.n % 3 = 0 THEN 'MGN-PRD-001' ELSE 'MGN-PRD-002' END product_id
  FROM legacy_cust lc CROSS JOIN seq s)
SELECT * FROM real_lines
UNION ALL
SELECT concat('MGN-CTR-', lpad(gid,6,'0')), agreement_number, customer_id, product_id,
  CAST(CASE WHEN product_id='MGN-PRD-001' THEN 420 * (2 + pmod(gid,4)) * (0.55 + pmod(gid,5)*0.04)
            ELSE 95 * (12 + pmod(gid,5)*6) * (0.55 + pmod(gid,5)*0.04) END AS DECIMAL(18,2)),
  date_add(date'2023-12-01', pmod(gid,90)),
  CASE WHEN n <= 15 THEN date_add(date'2026-11-20', (n-1)*5) ELSE date_add(date'2027-06-01', n*17) END,
  FALSE, 'SYNTHETIC', 'margin_synth (P1-SYNTH-CONTRACTS-CIRCUITS)'
FROM syn;

CREATE OR REPLACE TABLE cdm_tmforum.revenue_assurance.margin_circuits (
  circuit_id BIGINT NOT NULL, contract_id STRING NOT NULL, customer_id BIGINT NOT NULL, is_on_net BOOLEAN NOT NULL, vendor_id STRING,
  route_a_location STRING NOT NULL, route_z_location STRING NOT NULL, route_description STRING NOT NULL, bandwidth_mbps DECIMAL(12,2) NOT NULL,
  is_parallel_to_onnet_fiber BOOLEAN NOT NULL, onnet_distance_m DECIMAL(12,2), origin STRING NOT NULL, source_system STRING NOT NULL
) TBLPROPERTIES ('telco_project'='margin_analysis');

INSERT OVERWRITE cdm_tmforum.revenue_assurance.margin_circuits
WITH rep AS (
  SELECT l.Service_Circuit_Id__c circuit_id, l.Id contract_id, m.customer_id, m.region, l.ProductCode code, l.Discount__c disc, c.EndDate term_end,
         row_number() OVER (PARTITION BY l.Service_Circuit_Id__c ORDER BY c.EndDate DESC, l.Id) rn
  FROM cdm_tmforum.salesforce_source.contract_line_item l JOIN cdm_tmforum.salesforce_source.contract c ON l.Contract__c=c.Id
  JOIN cdm_tmforum.revenue_assurance.margin_customers m ON l.AccountId=m.sf_account_id),
used AS (SELECT DISTINCT Service_Circuit_Id__c id FROM cdm_tmforum.salesforce_source.contract_line_item),
free_ids AS (
  SELECT f.customer_facing_service_id id, row_number() OVER (ORDER BY f.customer_facing_service_id) k
  FROM cdm_tmforum.tmf_service.customer_facing_service f LEFT ANTI JOIN used u ON f.customer_facing_service_id=u.id),
syn AS (
  SELECT fi.id circuit_id, mc.contract_id, mc.customer_id, cu.region,
         CASE WHEN mc.product_id='MGN-PRD-001' THEN 'VOICE-PRI-T1' ELSE 'VOICE-POTS-BIZ' END code, 0.0 disc, mc.term_end
  FROM cdm_tmforum.revenue_assurance.margin_contracts mc JOIN cdm_tmforum.revenue_assurance.margin_customers cu ON mc.customer_id=cu.customer_id
  JOIN free_ids fi ON fi.k = CAST(substr(mc.contract_id,9) AS INT)
  WHERE mc.origin='SYNTHETIC'),
base AS (
  SELECT circuit_id, contract_id, customer_id, region, code, disc, term_end, 'MIXED' origin FROM rep WHERE rn=1
  UNION ALL SELECT circuit_id, contract_id, customer_id, region, code, disc, term_end, 'SYNTHETIC' FROM syn),
flagged AS (
  SELECT *, pmod(xxhash64(circuit_id,'onnet'),100) h,
    (term_end >= date'2026-11-12' AND term_end < date'2027-02-10' AND disc >= 30) force_off
  FROM base),
net AS (
  SELECT *, CASE WHEN force_off THEN FALSE WHEN code='ELAN-MPLS' THEN h < 45 WHEN code LIKE 'VOICE-%' THEN h < 50 ELSE h < 62 END is_on_net FROM flagged),
hero AS (
  SELECT circuit_id, row_number() OVER (ORDER BY xxhash64(circuit_id,'hero')) hr FROM net
  WHERE NOT is_on_net AND code IN ('ELINE-1G','FIBER-DIA-1G') AND NOT force_off
  QUALIFY hr <= 12),
v AS (SELECT vendor_id, vendor_name, row_number() OVER (ORDER BY vendor_id) - 1 vn FROM cdm_tmforum.revenue_assurance.margin_vendors),
fin AS (
  SELECT n.*, hero.hr,
    CASE WHEN n.is_on_net THEN FALSE WHEN hero.hr IS NOT NULL THEN TRUE ELSE pmod(xxhash64(n.circuit_id,'par'),100) = 0 END par
  FROM net n LEFT JOIN hero ON n.circuit_id=hero.circuit_id)
SELECT f.circuit_id, f.contract_id, f.customer_id, f.is_on_net,
  CASE WHEN f.is_on_net THEN NULL ELSE v.vendor_id END,
  concat('Customer site ', f.customer_id, '-', pmod(f.circuit_id,7)+1, ' (', f.region, ')'),
  CASE WHEN f.is_on_net THEN concat('Lakelink Fiber ', f.region, ' POP ', pmod(f.circuit_id,12)+1)
       ELSE concat(v.vendor_name, ' handoff, ', f.region, ' CO ', pmod(f.circuit_id,20)+1) END,
  CASE WHEN f.is_on_net THEN concat('On-net ', f.code, ' over Lakelink Fiber fiber in ', f.region)
       WHEN f.par THEN concat('Off-net ', f.code, ' via ', v.vendor_name, '; runs next to Lakelink Fiber fiber in ', f.region)
       ELSE concat('Off-net ', f.code, ' via ', v.vendor_name, ' in ', f.region) END,
  CAST(CASE f.code WHEN 'FIBER-DIA-1G' THEN 1000 WHEN 'FIBER-DIA-10G' THEN 10000 WHEN 'WAVE-10G' THEN 10000 WHEN 'WAVE-100G' THEN 100000
       WHEN 'ELINE-1G' THEN 1000 WHEN 'ELAN-MPLS' THEN 100 WHEN 'SDWAN-EDGE' THEN 500 WHEN 'COLO-RACK' THEN 1000
       WHEN 'VOICE-PRI-T1' THEN 1.54 WHEN 'VOICE-POTS-BIZ' THEN 0.06 END AS DECIMAL(12,2)),
  f.par,
  CAST(CASE WHEN f.is_on_net THEN 0 WHEN f.hr IS NOT NULL THEN 40 + f.hr*11
            WHEN f.par THEN 220 + pmod(xxhash64(f.circuit_id,'d'),680)
            ELSE 1500 + pmod(xxhash64(f.circuit_id,'d'),23500) END AS DECIMAL(12,2)),
  f.origin,
  CASE WHEN f.origin='MIXED' THEN 'salesforce_source.contract_line_item + margin_synth network attributes' ELSE 'margin_synth (P1-SYNTH-CONTRACTS-CIRCUITS)' END
FROM fin f LEFT JOIN v ON v.vn = pmod(xxhash64(f.circuit_id,'vendor'),30);

ALTER TABLE cdm_tmforum.revenue_assurance.margin_contracts ADD CONSTRAINT margin_contracts_pk PRIMARY KEY (contract_id) NOT ENFORCED;
ALTER TABLE cdm_tmforum.revenue_assurance.margin_circuits ADD CONSTRAINT margin_circuits_pk PRIMARY KEY (circuit_id) NOT ENFORCED;
