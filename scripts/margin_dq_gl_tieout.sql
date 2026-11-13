-- Lakelink Fiber Margin Truth: P1-DQ-MONITORING (@data-engineer, 2026-11-13)
-- (1) Ledger-to-GL tie-out check view (scene 2/3 'tie-out shown as green').
-- (2) Freshness/completeness: schema-level Data Quality Monitoring (anomaly detection) on
--     cdm_tmforum.revenue_assurance (schema_id 08c8c09a-15dd-4e40-9c8b-f70694a77239),
--     created via POST /api/data-quality/v1/monitors {object_type: schema, anomaly_detection_config:{publish_health_indicator:true}}
--     -> workflow 1072631171198327. Covers margin_ledger, margin_ledger_v2 and all margin_ tables (views excluded by the product).

CREATE OR REPLACE VIEW cdm_tmforum.revenue_assurance.margin_dq_gl_tieout (
  period_month COMMENT 'Accounting period (first day of month) shared by the margin ledger and GL actuals. Synonyms: GL month, ledger month.',
  account_class COMMENT 'Margin bucket compared: revenue, network_expense or cost_to_serve_pool (ledger cost_to_serve_usd).',
  ledger_usd COMMENT 'Sum of the bucket in margin_ledger_v2 (the ledger behind margin_ledger_mv), US dollars.',
  gl_usd COMMENT 'Sum of posted margin_gl_actuals amount_usd for the bucket and month, US dollars.',
  diff_usd COMMENT 'ledger_usd minus gl_usd, US dollars.',
  pct_diff COMMENT 'Absolute difference as a percent of GL (0.5 means 0.5 percent).',
  tolerance_pct COMMENT 'Tie-out tolerance in percent (0.5), per the margin_gl_actuals contract.',
  tie_out_status COMMENT 'GREEN when pct_diff <= tolerance_pct, RED otherwise or when either side is missing. Synonyms: tie-out, reconciliation status.'
)
COMMENT 'Lakelink Fiber Margin Truth data quality check: ledger-to-GL tie-out. One row per accounting month x margin bucket comparing margin_ledger_v2 with margin_gl_actuals. All rows GREEN means the margin ledger ties to the general ledger within 0.5 percent. Owner @data-engineer (P1-DQ-MONITORING).'
TBLPROPERTIES ('telco_project'='margin_analysis')
AS
WITH l AS (
  SELECT ledger_month AS m, SUM(revenue_usd) AS revenue, SUM(network_expense_usd) AS network_expense, SUM(cost_to_serve_usd) AS cost_to_serve
  FROM cdm_tmforum.revenue_assurance.margin_ledger_v2 GROUP BY ledger_month),
lu AS (SELECT m, stack(3,'revenue',revenue,'network_expense',network_expense,'cost_to_serve_pool',cost_to_serve) AS (account_class, ledger_usd) FROM l),
g AS (SELECT period_month AS m, account_class, SUM(amount_usd) AS gl_usd FROM cdm_tmforum.revenue_assurance.margin_gl_actuals GROUP BY period_month, account_class)
SELECT COALESCE(lu.m, g.m) AS period_month,
       COALESCE(lu.account_class, g.account_class) AS account_class,
       lu.ledger_usd, g.gl_usd,
       lu.ledger_usd - g.gl_usd AS diff_usd,
       ROUND(ABS(lu.ledger_usd - g.gl_usd) / NULLIF(g.gl_usd, 0) * 100, 4) AS pct_diff,
       CAST(0.5 AS DECIMAL(4,2)) AS tolerance_pct,
       CASE WHEN lu.ledger_usd IS NULL OR g.gl_usd IS NULL THEN 'RED'
            WHEN ABS(lu.ledger_usd - g.gl_usd) / NULLIF(g.gl_usd, 0) * 100 <= 0.5 THEN 'GREEN' ELSE 'RED' END AS tie_out_status
FROM lu FULL OUTER JOIN g ON lu.m = g.m AND lu.account_class = g.account_class;

-- Demo check (expect 36 GREEN, 0 RED):
-- SELECT tie_out_status, COUNT(*) FROM cdm_tmforum.revenue_assurance.margin_dq_gl_tieout GROUP BY 1;
-- Freshness results: Catalog Explorer > revenue_assurance > Data Quality, or system.data_quality_monitoring.table_results.
