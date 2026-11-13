# Margin Truth — Semantic Standards and Frozen Column Contract

Owner: @data-planner · Status: FROZEN v1.1 (2026-11-13; v1.0 2026-11-12) · Tasks: P0-SEMANTIC-STANDARDS, v1.1: COO-Q-20261112-11, DP-MV-FORMAT-GAPS, DP-STANDARDS-VENDOR-ID, DP-STANDARDS-V11-ALLOCATED-VIEW · Company: Lakelink Fiber (fictional)

v1.1 changes (no column name or type changes, so no new DEC row needed): (1) section 5 format rule: `format` is required on numeric/currency/percent/date fields and N/A by design on ID/string/boolean dimensions; (2) `vendor_id` = `salesforce_source.partner_account.Id`, `vendor_type` in (`wholesale`, `CLEC`); (3) `margin_ledger_allocated` is the cost-to-serve source of truth for metric views (section 3a).

This document is the single contract that the fast-path ledger (DEC-008), the SDP pipeline, metric views, Margin Genie, the dashboard, the app and the agents build against. Changing a frozen column name or type requires a new `decisions` row (DEC-*) approved by @pm, and a version bump here.

## 1. Placement, naming, tagging (hard rules)

* Tables, UC functions, volume: `cdm_tmforum.revenue_assurance`, prefix `margin_` (volume `margin_documents`). Metric views: `cdm_tmforum._metrics`, prefix `margin_`, suffix `_mv`. Never CREATE SCHEMA (DEC-001).
* Source schemas `oracle_erp_source`, `salesforce_source`, `ironclad_clm_source`, `mdm_source`, `tmf_*` are read-only.
* Column names: `snake_case`; money columns end in `_usd` (DECIMAL(18,2), US dollars, monthly unless the name says otherwise); percentages end in `_pct` (DECIMAL(9,4), 0.2000 = 20%); booleans start with `is_`; month grain columns are DATE set to the first day of the month and end in `_month`.
* Every table carries `origin STRING` (`REAL` | `SYNTHETIC` | `MIXED`) and `source_system STRING`.
* Tag every UC asset: `ALTER ... SET TAGS ('telco_project' = 'margin_analysis')`. If the governed tag policy rejects it: `SET TBLPROPERTIES ('telco_project'='margin_analysis')` and escalate once to @pm.
* Branding: Lakelink Fiber only, in comments, data values, synonyms, instructions and pages. Never real company names.

## 2. Ontology (informational PK/FK, Genie joins)

```
margin_customers (customer_id) 1 ──< N margin_contracts (contract_id) >── N:1 margin_products (product_id)
margin_contracts (contract_id) 1 ──< N margin_circuits (circuit_id) >── N:1 margin_vendors (vendor_id)   [vendor_id NULL when on-net]
margin_ledger: customer x product x circuit x month, FKs to all four dimensions
```

* A "contract" in this project is a **contract line** (one product for one customer under one agreement). The agreement header number is the attribute `agreement_number`.
* Declare constraints as informational: `ALTER TABLE ... ADD CONSTRAINT <table>_pk PRIMARY KEY (...) NOT ENFORCED` and `... ADD CONSTRAINT <child>_<parent>_fk FOREIGN KEY (col) REFERENCES <parent>(col) NOT ENFORCED`. PK columns must be `NOT NULL`.
* Key reuse (DEC-003, verified 2026-11-12):
  * `customer_id` = `salesforce_source.account.TMF_Customer_Id__c` (10,000 accounts, 10,000 distinct ids). `sf_account_id` = `account.Id`.
  * `product_id` = `salesforce_source.product2.Id` (8 products). Legacy products not in product2 are added in `margin_products` with `origin='SYNTHETIC'` and id prefix `MGN-PRD-`.
  * `contract_id` = `salesforce_source.contract_line_item.Id` (56,088 lines; every line joins to `contract`, every line's `Product2Id` exists in product2, every contract's `AccountId` exists in account).
  * `circuit_id` = `contract_line_item.Service_Circuit_Id__c` = `tmf_service.customer_facing_service.customer_facing_service_id` (all 42,906 distinct line circuit ids match).
  * `vendor_id` = `salesforce_source.partner_account.Id` (v1.1, DEC-003 / DP-GAP-VENDOR-PARTNER-KEYS). `margin_vendors` holds the 30 partner accounts with `Partner_Type__c` Wholesale Carrier (-> `vendor_type='wholesale'`, 15) or Interconnect (-> `vendor_type='CLEC'`, 15). Verified 2026-11-13: 30/30 ids exist in partner_account, 0 use the retired `MGN-VND-` prefix. No ILEC vendors.
  * Never invent a FK value that is absent from its parent table.

## 3. Frozen column contract v1.1 (column names/types unchanged from v1.0)

All tables in `cdm_tmforum.revenue_assurance`. `PK` = primary key, `FK→` = foreign key. Null rule: columns are NOT NULL unless marked *nullable*.

### margin_customers — grain: one row per customer
| Column | Type | Notes |
|---|---|---|
| customer_id | BIGINT | PK. Reused TMF customer id |
| sf_account_id | STRING | Salesforce account Id |
| customer_name | STRING | |
| segment | STRING | `Strategic Enterprise`, `Enterprise`, `Commercial`, `Small Business` (salesforce `Segment__c`) |
| region | STRING | Sales region |
| is_legacy_voice_heavy | BOOLEAN | Planted story: a few large legacy-voice customers |
| origin, source_system | STRING | |

### margin_products — grain: one row per product
| Column | Type | Notes |
|---|---|---|
| product_id | STRING | PK |
| product_code | STRING | e.g. `FIBER-DIA-1G` |
| product_name | STRING | |
| product_family | STRING | Source family: Dedicated Internet, Wavelength, Ethernet, IP-VPN, Managed, Colocation, Legacy Voice |
| family_class | STRING | `strategic` or `legacy`. Legacy = IP-VPN (MPLS) and Legacy Voice; all others strategic |
| list_mrr_usd | DECIMAL(18,2) | List monthly recurring charge |
| margin_floor_pct | DECIMAL(9,4) | Minimum acceptable contribution margin % (Finance-owned; default 0.2000) |
| origin, source_system | STRING | |

### margin_vendors — grain: one row per third-party carrier
| Column | Type | Notes |
|---|---|---|
| vendor_id | STRING | PK, `salesforce_source.partner_account.Id` (v1.1; was `MGN-VND-###` in v1.0) |
| vendor_name | STRING | Fictional carrier names only |
| vendor_type | STRING | `wholesale` (Wholesale Carrier) or `CLEC` (Interconnect) (v1.1; ILEC not used) |
| origin, source_system | STRING | |

### margin_contracts — grain: one row per contract line
| Column | Type | Notes |
|---|---|---|
| contract_id | STRING | PK |
| agreement_number | STRING | Header contract number |
| customer_id | BIGINT | FK→margin_customers |
| product_id | STRING | FK→margin_products |
| contract_rate_usd | DECIMAL(18,2) | Contracted monthly rate for the line |
| term_start | DATE | |
| term_end | DATE | Renewal date; drives "renewals in next 90 days" `[as_of, as_of+90d)` |
| is_auto_renew | BOOLEAN | |
| origin, source_system | STRING | |

### margin_circuits — grain: one row per circuit
| Column | Type | Notes |
|---|---|---|
| circuit_id | BIGINT | PK |
| contract_id | STRING | FK→margin_contracts |
| customer_id | BIGINT | FK→margin_customers (denormalized for Genie) |
| is_on_net | BOOLEAN | TRUE = rides Lakelink Fiber; FALSE = off-net |
| vendor_id | STRING | FK→margin_vendors; *nullable*, NULL iff is_on_net |
| route_a_location | STRING | A-end site |
| route_z_location | STRING | Z-end site |
| route_description | STRING | |
| bandwidth_mbps | DECIMAL(12,2) | |
| is_parallel_to_onnet_fiber | BOOLEAN | Off-net circuit running next to Lakelink fiber (grooming candidate) |
| onnet_distance_m | DECIMAL(12,2) | *nullable*; distance to nearest Lakelink fiber |
| origin, source_system | STRING | |

### margin_billing — grain: invoice line by month (customer x circuit x month)
| Column | Type | Notes |
|---|---|---|
| billing_line_id | STRING | PK |
| billing_month | DATE | |
| customer_id | BIGINT | FK→margin_customers |
| contract_id | STRING | FK→margin_contracts |
| circuit_id | BIGINT | FK→margin_circuits |
| expected_amount_usd | DECIMAL(18,2) | Contract rate x period |
| billed_amount_usd | DECIMAL(18,2) | Planted: small leakage gap |
| origin, source_system | STRING | |

### margin_carrier_invoices — grain: carrier invoice line by month (vendor x circuit x month)
| Column | Type | Notes |
|---|---|---|
| carrier_invoice_line_id | STRING | PK |
| invoice_number | STRING | |
| invoice_month | DATE | |
| vendor_id | STRING | FK→margin_vendors |
| circuit_id | BIGINT | FK→margin_circuits (off-net only) |
| vendor_contract_rate_usd | DECIMAL(18,2) | Agreed carrier rate |
| invoiced_rate_usd | DECIMAL(18,2) | Planted: some above contract rate |
| paid_amount_usd | DECIMAL(18,2) | |
| source_pdf_path | STRING | *nullable*; `/Volumes/cdm_tmforum/revenue_assurance/margin_documents/...` |
| extraction_method | STRING | `ai_extract` or `structured` |
| origin, source_system | STRING | |

### margin_gl_actuals — grain: GL account x cost center x month
| Column | Type | Notes |
|---|---|---|
| gl_actual_id | STRING | PK |
| period_month | DATE | |
| gl_account | STRING | |
| cost_center | STRING | |
| account_class | STRING | `revenue`, `network_expense`, `cost_to_serve_pool` |
| cost_pool | STRING | *nullable*; set when account_class = cost_to_serve_pool |
| amount_usd | DECIMAL(18,2) | Ties to ledger within tolerance (0.5%) |
| origin, source_system | STRING | |

### margin_allocation_rules — grain: one row per rule version
| Column | Type | Notes |
|---|---|---|
| rule_id | STRING | PK |
| cost_pool | STRING | e.g. `field_ops`, `noc`, `customer_care`, `billing_ops` |
| driver | STRING | e.g. `circuit_count`, `ticket_count`, `bandwidth_mbps`, `billed_revenue` |
| weight | DECIMAL(9,6) | Share of the pool allocated by this driver; weights per cost_pool sum to 1 |
| effective_from | DATE | |
| effective_to | DATE | *nullable*; NULL = open |
| is_active | BOOLEAN | The live-demo rule is changed by updating weight |
| rule_owner | STRING | `Finance` |
| origin, source_system | STRING | |

### margin_ledger (gold) — grain: customer x product x circuit x month
| Column | Type | Notes |
|---|---|---|
| ledger_month | DATE | PK part |
| customer_id | BIGINT | PK part, FK→margin_customers |
| product_id | STRING | PK part, FK→margin_products |
| circuit_id | BIGINT | PK part, FK→margin_circuits |
| contract_id | STRING | FK→margin_contracts |
| vendor_id | STRING | FK→margin_vendors, *nullable* (on-net) |
| is_on_net | BOOLEAN | |
| product_family | STRING | |
| family_class | STRING | |
| segment | STRING | |
| region | STRING | |
| revenue_usd | DECIMAL(18,2) | Billed revenue for the month |
| network_expense_usd | DECIMAL(18,2) | Carrier paid amount (off-net) + on-net network cost |
| cost_to_serve_usd | DECIMAL(18,2) | Allocated via margin_allocation_rules |
| expected_revenue_usd | DECIMAL(18,2) | For revenue leakage |
| carrier_rate_variance_usd | DECIMAL(18,2) | invoiced - vendor contract rate (0 on-net) |
| allocation_rule_version | STRING | Rule set used to compute cost_to_serve |
| origin, source_system | STRING | |

The ledger does NOT store contribution margin; it is defined once in `cdm_tmforum._metrics.margin_ledger_mv` (DEC-002). Cost to serve must be recomputed when allocation rules change (view or rebuild), so scene 3 updates every answer.

### 3a. margin_ledger_allocated (VIEW) — cost-to-serve source of truth (v1.1)

* `cdm_tmforum.revenue_assurance.margin_ledger_allocated` has the same grain and columns as `margin_ledger`, but recomputes `cost_to_serve_usd` at query time from the active rows of `margin_allocation_rules` and the cost pools in `margin_gl_actuals`. Changing a rule weight updates every answer with no rebuild (scene 3).
* Stored `margin_ledger.cost_to_serve_usd` is the baseline from the `MGN-ALR-v1` rules only. Do not use it for answers.
* Every metric view that reports cost to serve or contribution margin must source `margin_ledger_allocated`, never `margin_ledger`. `margin_ledger_mv` already does this.
* Canonical total (DEC-020): MEASURE(contribution_margin) = 2,375,095,705.09 at default rules. `margin_ledger` gives 2,375,095,704.83 (+0.26 per-row rounding gap), so only use it as an independent raw-SQL check.
* It is a view, so column comments come from its SELECT definition or a redeploy; `ALTER COLUMN ... COMMENT` does not apply.

## 4. Comment standard

* Table comment: `<What it is>. Grain: <grain>. Source: <system or synthetic>. Synonyms: <a, b>. Lakelink Fiber Margin Truth.`
* Column comment: business meaning first, then unit, then allowed values or synonyms. Example `revenue_usd`: "Billed revenue for the circuit in the month, US dollars. Synonyms: sales, billings, top line."
* Coverage target 100% of tables and columns. Audit SQL:

```sql
SELECT COUNT_IF(c.comment IS NOT NULL AND trim(c.comment) <> '') AS commented, COUNT(*) AS total
FROM cdm_tmforum.information_schema.columns c
WHERE c.table_schema IN ('revenue_assurance','_metrics') AND c.table_name ILIKE 'margin%';
```

## 5. Metric view YAML convention

* One file per view in `src/metric_views/<name>.yaml`; deployed as `cdm_tmforum._metrics.margin_<subject>_mv`.
* Every dimension and measure has `comment`, `display_name`, `synonyms`.
* `format` (v1.1): required on every measure and on every numeric, currency, percent, or date/datetime dimension. Money: `currency` USD, 0 decimals in dashboards; percentages: `percentage`, 1 decimal; counts: `number`, 0 decimals; months/quarters: `date`. The metric view spec only has numeric, currency, percentage, byte, date, and date_time format types, with no format type for text or boolean. So `format` is **N/A by design** for ID, string, and boolean dimensions, and the audit counts those as passing. Text values are made readable through `expr` (for example `network_type` maps `is_on_net` to 'On-net'/'Off-net') and through `display_name`.
* Format-N/A register (each must have comment + display_name + synonyms):
  * `margin_ledger_mv` (12): customer_id, segment, region, product_id, product_family, family_class, contract_id, circuit_id, is_on_net, network_type, vendor_id, allocation_rule_version.
  * `margin_offnet_spend_mv` YAML: circuit_id, contract_id, customer_id, vendor_id, vendor_name, vendor_type, route_description, is_parallel_to_onnet_fiber, is_grooming_candidate are N/A. `bandwidth_mbps` (number), `onnet_distance_m` (number), and `score` (number, 2 decimals) are numeric and carry a format (added 2026-11-13).
  * `margin_rate_variance_mv` YAML (8): vendor_id, vendor_name, vendor_type, circuit_id, invoice_number, is_overbilled, extraction_method, source_pdf_path.
* Add any new ID/string/boolean dimension to this register in the same change that adds it.
* Contribution margin is defined only in `margin_ledger_mv`; other views must not redefine it.

Worked example:

```yaml
version: 1.1
comment: "Lakelink Fiber margin ledger. Grain customer x product x circuit x month."
source: cdm_tmforum.revenue_assurance.margin_ledger
dimensions:
  - name: product_family
    expr: product_family
    comment: "Product family of the circuit's contract line."
    display_name: Product Family
    synonyms: [family, product line]
measures:
  - name: contribution_margin
    expr: SUM(revenue_usd) - SUM(network_expense_usd) - SUM(cost_to_serve_usd)
    comment: "Revenue minus network expense minus cost to serve, US dollars. Defined once (DEC-002)."
    display_name: Contribution Margin
    format:
      type: currency
      currency_code: USD
      decimal_places: {type: exact, places: 0}
    synonyms: [margin, CM, profit after cost to serve]
```

Audit: @data-planner reads each view with `DESCRIBE TABLE EXTENDED ... AS JSON` and fails any measure/dimension missing comment, display_name, format or synonyms.

## 6. Glossary page template (UC Glossary)

Title = term. Sections: Definition (one sentence) · Formula / rule · Owner (Finance, Ops, Sales, Marketing) · Linked assets (metric view measure, table columns) · Example question for Margin Genie · Certification criterion (value from metric view matches raw SQL in P2-MV-VALIDATION).

Terms (16): contribution margin, revenue, network expense, cost to serve, allocation rule, cost pool, driver, margin floor, on-net, off-net, legacy family, strategic family, revenue leakage (expected - billed revenue), rate variance (carrier invoiced - contracted rate), grooming (moving off-net circuits on-net), $1B Wall (Lakelink Fiber's target of 1 billion US dollars in annualized margin improvement, tracked by lever).

## 7. Discover domain structure

Domain `Margin` (governed tag `telco_project = margin_analysis`) with groupings: Finance (ledger, gl_actuals, allocation_rules, margin_ledger_mv, dashboard), Ops (circuits, vendors, carrier_invoices, grooming views), Sales (contracts, customers, renewal views), Marketing (customers/segments views). Shared: Margin Genie, the app.
