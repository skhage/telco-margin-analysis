# Lakelink Fiber Margin Truth - synthetic PDF generator (P1-INVOICE-PDFS, @data-engineer 2026-11-13)
# Writes 20 carrier invoice statements (one margin_carrier_invoices line each, Oct 2026: heroes 45040 + 98532,
# 9 over-contract-rate lines, 9 at-contract lines) and 5 customer contract PDFs (margin_contracts) to
# /Volumes/cdm_tmforum/revenue_assurance/margin_documents/{carrier_invoices,contracts}/ and links
# margin_carrier_invoices.source_pdf_path. Requires: %pip install fpdf2. origin=SYNTHETIC. telco_project=margin_analysis
from fpdf import FPDF
import os

T = "cdm_tmforum.revenue_assurance."
VOL = "/Volumes/cdm_tmforum/revenue_assurance/margin_documents"
NAVY = (27, 49, 57)

SEL_SQL = f"""
WITH base AS (
 SELECT c.carrier_invoice_line_id, c.invoice_number, c.invoice_month, c.vendor_id, v.vendor_name, c.circuit_id,
        c.vendor_contract_rate_usd, c.invoiced_rate_usd, c.paid_amount_usd,
        ci.route_a_location, ci.route_z_location, ci.bandwidth_mbps,
        (c.invoiced_rate_usd > c.vendor_contract_rate_usd) AS over_rate
 FROM {T}margin_carrier_invoices c JOIN {T}margin_vendors v USING (vendor_id) JOIN {T}margin_circuits ci USING (circuit_id)
 WHERE c.invoice_month = DATE'2026-10-01'),
hero AS (SELECT *, 0 AS grp FROM base WHERE circuit_id IN (45040, 98532)),
overr AS (SELECT *, 1 AS grp FROM base WHERE over_rate AND circuit_id NOT IN (45040, 98532) ORDER BY circuit_id LIMIT 9),
norm AS (SELECT *, 2 AS grp FROM base WHERE NOT over_rate AND circuit_id NOT IN (45040, 98532) ORDER BY circuit_id LIMIT 9)
SELECT * FROM hero UNION ALL SELECT * FROM overr UNION ALL SELECT * FROM norm ORDER BY grp, circuit_id
"""


def _hdr(pdf, title):
    pdf.set_fill_color(*NAVY); pdf.rect(0, 0, 210, 28, 'F')
    pdf.set_text_color(255, 255, 255); pdf.set_font("Helvetica", "B", 16); pdf.set_xy(10, 8); pdf.cell(0, 8, title)
    pdf.set_font("Helvetica", "", 9); pdf.set_xy(10, 17)
    pdf.cell(0, 6, "Prepared for Lakelink Fiber - Accounts Payable / Network Finance  |  SYNTHETIC DEMO DOCUMENT")
    pdf.set_text_color(0, 0, 0); pdf.set_xy(10, 36)


def _kv(pdf, k, v):
    pdf.set_font("Helvetica", "B", 10); pdf.cell(60, 7, k)
    pdf.set_font("Helvetica", "", 10); pdf.cell(0, 7, str(v), new_x="LMARGIN", new_y="NEXT")


def carrier_invoice_pdf(r):
    pdf = FPDF(); pdf.add_page(); _hdr(pdf, f"{r['vendor_name']} - Circuit Invoice Statement")
    for k, v in [("Invoice Number", r['invoice_number']), ("Invoice Line ID", r['carrier_invoice_line_id']),
                 ("Billing Period", str(r['invoice_month'])[:7]), ("Vendor", r['vendor_name']), ("Vendor ID", r['vendor_id']),
                 ("Bill To", "Lakelink Fiber"), ("Circuit ID", r['circuit_id']), ("Service", "Off-net access circuit"),
                 ("Bandwidth (Mbps)", f"{float(r['bandwidth_mbps']):,.0f}"), ("A Location", r['route_a_location']),
                 ("Z Location", r['route_z_location'])]:
        _kv(pdf, k, v)
    pdf.ln(4); pdf.set_fill_color(249, 247, 244); pdf.set_font("Helvetica", "B", 10)
    for h, wd in [("Description", 80), ("Contract Rate (USD)", 37), ("Invoiced Rate (USD)", 37), ("Amount Due (USD)", 36)]:
        pdf.cell(wd, 8, h, border=1, fill=True)
    pdf.ln(); pdf.set_font("Helvetica", "", 10)
    pdf.cell(80, 8, f"Monthly recurring charge - circuit {r['circuit_id']}", border=1)
    for val, wd in [(r['vendor_contract_rate_usd'], 37), (r['invoiced_rate_usd'], 37), (r['paid_amount_usd'], 36)]:
        pdf.cell(wd, 8, f"{float(val):,.2f}", border=1, align="R")
    pdf.ln(12); _kv(pdf, "Total Amount Due (USD)", f"{float(r['paid_amount_usd']):,.2f}"); _kv(pdf, "Payment Terms", "Net 30")
    pdf.ln(6); pdf.set_font("Helvetica", "I", 8)
    pdf.multi_cell(0, 5, "Synthetic carrier invoice for the Lakelink Fiber Margin Truth demo. Values mirror cdm_tmforum.revenue_assurance.margin_carrier_invoices.")
    p = f"{VOL}/carrier_invoices/{r['invoice_number']}_CKT-{r['circuit_id']}.pdf"
    os.makedirs(os.path.dirname(p), exist_ok=True); pdf.output(p); return p


def contract_pdf(r):
    pdf = FPDF(); pdf.add_page(); _hdr(pdf, "Lakelink Fiber - Customer Service Agreement")
    for k, v in [("Contract ID", r['contract_id']), ("Agreement Number", r['agreement_number']), ("Customer", r['customer_name']),
                 ("Customer ID", r['customer_id']), ("Product", r['product_name']), ("Product ID", r['product_id']),
                 ("Circuit ID", r['circuit_id']), ("Monthly Contract Rate (USD)", f"{float(r['contract_rate_usd']):,.2f}"),
                 ("Term Start", r['term_start']), ("Term End", r['term_end']), ("Auto Renew", "Yes" if r['is_auto_renew'] else "No")]:
        _kv(pdf, k, v)
    pdf.ln(6); pdf.set_font("Helvetica", "", 10)
    pdf.multi_cell(0, 6, "Lakelink Fiber agrees to provide the service above to the Customer at the monthly contract rate for the stated term. Rates exclude taxes, usage and one-time charges.")
    pdf.ln(4); pdf.set_font("Helvetica", "I", 8)
    pdf.multi_cell(0, 5, "Synthetic contract for the Lakelink Fiber Margin Truth demo. Values mirror cdm_tmforum.revenue_assurance.margin_contracts.")
    p = f"{VOL}/contracts/{r['contract_id']}_CKT-{r['circuit_id']}.pdf"
    os.makedirs(os.path.dirname(p), exist_ok=True); pdf.output(p); return p


def run(spark):
    sel = spark.sql(SEL_SQL).toPandas()
    ids = ",".join(str(int(x)) for x in sel.circuit_id[:5])
    ctr = spark.sql(f"""SELECT k.contract_id, k.agreement_number, k.customer_id, cu.customer_name, k.product_id, p.product_name,
        k.contract_rate_usd, k.term_start, k.term_end, k.is_auto_renew, ci.circuit_id
        FROM {T}margin_contracts k JOIN {T}margin_customers cu USING (customer_id) JOIN {T}margin_products p USING (product_id)
        JOIN {T}margin_circuits ci ON ci.contract_id = k.contract_id WHERE ci.circuit_id IN ({ids})""").toPandas()
    paths = [carrier_invoice_pdf(r) for r in sel.to_dict('records')] + [contract_pdf(r) for r in ctr.to_dict('records')]
    vals = ",".join(f"('{r['carrier_invoice_line_id']}', '{VOL}/carrier_invoices/{r['invoice_number']}_CKT-{int(r['circuit_id'])}.pdf')"
                    for r in sel.to_dict('records'))
    spark.sql(f"""MERGE INTO {T}margin_carrier_invoices t USING (SELECT * FROM VALUES {vals} AS v(id, p)) s
        ON t.carrier_invoice_line_id = s.id WHEN MATCHED THEN UPDATE SET t.source_pdf_path = s.p""")
    return paths
