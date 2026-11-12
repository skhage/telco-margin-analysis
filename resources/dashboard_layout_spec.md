# Lakelink Fiber Margin Truth: dashboard and Genie layout spec v1.0

Owner: @designer. Task: DSN-DASHBOARD-SPEC (2026-11-12). Builder: @data-analyst (P3-DASHBOARD, P6-CHALLENGE-CARDS, P3-MARGIN-GENIE).
This spec is binding. It extends `apps/DESIGN_TOKENS.md` v1.2 (colors, type, voice). If they disagree, DESIGN_TOKENS wins for tokens and this file wins for layout.
Company name in every string: **Lakelink Fiber**. Never use a real company or carrier name (the plan file in `resources/projectplan.md` uses one; translate it).

## 0. Global rules

* ONE dashboard, display name exactly **Lakelink Fiber Margin Truth** (matches `bundle/resources/margin_scorecard.dashboard.yml`). File: `dashboards/margin_truth.lvdash.json`.
* Three pages, in this order and with these exact names (sentence case): **CFO margin scorecard**, **$1B Wall tracker**, **Challenge cards**. No persona pages: Ops, Sales, and Marketing are served by the embedded Margin Genie (DEC-012, consolidation rule).
* Data sources: metric views in `cdm_tmforum._metrics` only. Never raw tables. Every Contribution Margin number uses `MEASURE(contribution_margin)` (or `MEASURE(cm_pct)`) from `margin_ledger_mv` or a suite view that reuses it (DEC-002). @qa checks Genie = dashboard = app.
* Measures use their governed display names: Revenue, Network Expense, Cost to Serve, Contribution Margin, Contribution Margin %, Revenue Leakage, Carrier Rate Variance, Off-net Spend, Circuits, Customers. "CM %" only on axes and tile subtitles.
* Category values in title case: Legacy / Strategic, On-net / Off-net. Use `network_type`, never `is_on_net`. If `family_class` is still lowercase, wrap with `INITCAP()` in the dataset (see DSN-GENIE-COPY-R1).
* Each page has one global filter bar at the top: Quarter (default = last complete quarter), Customer Segment, Sales Region, Product Family. Filters apply to every widget on the page.
* Every widget has a title that states the question it answers and a description that names the metric view, e.g. "Source: margin_ledger_mv, Contribution Margin".

## 1. Grid and widget sizes

AI/BI uses a 6-column grid. Rows below are listed top to bottom.

| Slot | Width (cols) | Height (rows) | Use |
| --- | --- | --- | --- |
| Page header text | 6 | 1 | Page title (H1) + one-line purpose |
| Filter bar | 6 | 1 | Global filters |
| KPI tile | 1.5 (4 per row) or 2 (3 per row) | 2 | One counter each |
| Trend | 6 | 4 | Line or bar over time |
| Breakdown | 3 + 3 | 5 | Two side-by-side bar charts |
| Detail table | 6 | 6 | Sortable table |
| Embedded Genie | 6 | 8 | Margin Genie, last on the page |

Order on every page: KPI row (max 4 tiles) -> trend -> breakdown -> detail table -> Genie. At 720px or less AI/BI stacks widgets in this same order, so the reading order matches the visual order (SC 1.3.2).

## 2. Page 1: CFO margin scorecard (scenes 1 and 3)

Purpose line: "Which products and circuits lose money after cost to serve?"

| # | Widget | Type | Dataset (metric view: measures x dimensions) | Format and color |
| --- | --- | --- | --- | --- |
| 1.1 | Revenue | Counter | margin_ledger_mv: revenue | USD compact ($1.2M), #1B3139 |
| 1.2 | Contribution Margin | Counter | margin_ledger_mv: contribution_margin | USD compact; negative shown with minus sign and "(loss)" text, value color #B8200F |
| 1.3 | Contribution Margin % | Counter | margin_ledger_mv: cm_pct | Percent, 1 decimal |
| 1.4 | Cost to Serve | Counter | margin_ledger_mv: cost_to_serve | USD compact |
| 1.5 | How has contribution margin moved by month? | Line, 2 series | margin_ledger_mv: contribution_margin, revenue x ledger_month | Series 1 Contribution Margin #1B3139 (2px line), series 2 Revenue #5F7A8A; direct labels on last point |
| 1.6 | Which product families lose money after cost to serve? | Horizontal bar, sorted ascending | margin_ledger_mv: contribution_margin x product_family | Single-measure bar. Loss bars #B8200F, profit bars #007A52, data labels on every bar with sign |
| 1.7 | Where does the money go, by legacy or strategic? | Stacked bar | margin_ledger_mv: network_expense, cost_to_serve, contribution_margin x family_class | Order Network Expense #1B3139, Cost to Serve #FF3621, Contribution Margin #00A972 (fill); data labels on |
| 1.8 | Which circuits lose the most money? | Table, top 25 by contribution_margin ascending | margin_ledger_mv: contribution_margin, cm_pct, revenue, network_expense, cost_to_serve x circuit_id, customer_id, product_family, family_class, network_type, vendor_id | USD no decimals, % 1 decimal, numbers right-aligned; conditional format: negative CM text #B8200F plus minus sign (no fill) |
| 1.9 | Allocation rule in use | Text or small table | margin_ledger_mv: allocation_rule_version (distinct) | Muted #5A6B72 caption; this is the scene-3 proof that a rule change moved the answer |
| 1.10 | Ask Margin Genie | Embedded Genie | The ONE Lakelink Fiber Margin Genie | See section 5 |

Scene 3 note: widget 1.9 must sit directly below the KPI row on wide layouts or directly after 1.8 if space is tight, so the presenter can show the rule version change without scrolling past the Genie.

## 3. Page 2: $1B Wall tracker (scene 7 context)

Purpose line: "How close are we to the $1B Wall, and which levers move us?"
Dataset: `margin_onebillion_wall_mv` (P2-MV-SUITE). The exact $1B Wall definition comes from the glossary page for the term (P2-GLOSSARY-PAGES). @designer does not define it. Keep this layout; swap the measure names if the MV names differ.

| # | Widget | Type | Dataset | Format and color |
| --- | --- | --- | --- | --- |
| 2.1 | $1B Wall target | Counter | margin_onebillion_wall_mv: target measure | USD compact, #1B3139 |
| 2.2 | Identified so far | Counter | margin_onebillion_wall_mv: identified measure | USD compact |
| 2.3 | Gap to the Wall | Counter | target - identified (in the MV, not in the widget) | USD compact; text "remaining" in subtitle |
| 2.4 | Progress | Counter showing percent of target | identified / target (in the MV) | Percent, 1 decimal. Do not use a gauge: gauges have no accessible text value |
| 2.5 | Which levers add up to the Wall? | Horizontal bar, sorted descending | lever measures by lever (e.g. off-net grooming savings, revenue leakage, carrier rate variance, legacy repricing) | One color #1B3139; data labels on; max 5 bars plus "Other" |
| 2.6 | How has identified value grown? | Line or column by month | identified measure x ledger_month | #1B3139; target shown as a dashed reference line #5A6B72 with a text label "$1B target" |
| 2.7 | Lever detail | Table | lever, owner persona, measure, source metric view | USD no decimals |
| 2.8 | Ask Margin Genie | Embedded Genie | ONE Margin Genie | Section 5 |

Off-net grooming savings must use only rows where the score function says the circuit is parallel to our own fiber AND savings > 0. The unfiltered sum is negative and must never appear on a tile.

## 4. Page 3: Challenge cards (scene 7, P6-CHALLENGE-CARDS)

Purpose line: "Find your biggest lever. Pick a card, ask Margin Genie, check the answer."

* One text widget per card, 3 cards per row (width 2), 4 to 6 cards total. One card per persona at minimum: Finance, Ops, Sales, Marketing.
* Card layout (markdown text widget): H3 card title (the lever), one line "Persona: <Finance | Ops | Sales | Marketing>", the question to ask Margin Genie in quotes, one line "Check: <which widget on page 1 or 2 shows the same number>". No answers on the card.
* Card questions reuse governed words (Contribution Margin, Off-net, margin floor, Revenue Leakage, Carrier Rate Variance). Never a real carrier name.
* Below the cards: one full-width embedded Margin Genie (section 5), so the room can ask without leaving the page.
* Persona label is text, not color only (SC 1.4.1). If cards get a top color bar, use Finance #1B3139, Ops #5F7A8A, Sales #FF3621, Marketing #00A972 and keep the text label.

## 5. Embedded Margin Genie

* The same ONE space on every page: title **Lakelink Fiber Margin Genie**. Description and the four ordered sample questions exactly as in DESIGN_TOKENS section 9.
* Placement: last widget on each page, full width (6 cols), height 8 rows (about 640px, matches the app's `min(640px, 75vh)`).
* Widget title: "Ask Margin Genie". Description: "One Genie for Finance, Ops, Sales, and Marketing. Margin means contribution margin from margin_ledger_mv."
* Genie answers use the metric view formats: USD with no decimals, percent with 1 decimal, title-case categories.

## 6. Number formats

| Value | KPI tile | Table and chart labels |
| --- | --- | --- |
| Money | USD compact, e.g. $12.4M | USD, 0 decimals, thousands separator, e.g. $12,431,200 |
| Percent | 1 decimal, e.g. 18.4% | 1 decimal |
| Counts | compact, e.g. 42.9K | 0 decimals, thousands separator |
| Negative money | minus sign + #B8200F + "(loss)" in tile subtitle | minus sign + #B8200F text |
| Dates | Month: "Oct 2026". Quarter: "Q3 2026" | same |
| Missing | em dash | em dash |

## 7. Color use (from DESIGN_TOKENS section 2, verified 2026-11-12 with the WCAG formula)

* Series order: #1B3139 (13.59 vs white), #FF3621 (3.62), #00A972 (3.04, fills only), #5F7A8A (4.53), #D9603B (3.69). Max 5 series; group the rest as "Other".
* Semantic: loss #B8200F (6.46), profit #007A52 (5.38), benchmark #5A6B72 (5.55).
* Loss red and profit green are only 1.20:1 against each other, so red-green alone does not tell them apart (also a color-blind risk). Every loss/profit chart MUST show signed data labels, and the bar sort order must put losses first.
* Do not use #FF3621 or #00A972 for text. Do not use #D9D4CC as the only boundary of anything.

## 8. WCAG 2.1 AA checklist for the dashboard (@designer verifies in P3-DESIGN-REVIEW-DASH)

1. Every chart has a title that states the question and data labels or a table next to it, so the value can be read without color (1.1.1, 1.4.1).
2. Text contrast >= 4.5:1, chart marks >= 3:1 against the white card (1.4.3, 1.4.11).
3. Reading order = visual order: KPI -> trend -> breakdown -> table -> Genie (1.3.2).
4. No gauge, pie with more than 4 slices, or 3D chart. Use bars and counters.
5. Page names and widget titles are unique and descriptive (2.4.6).
6. Filters have visible labels (3.3.2).
7. No red/green-only status; add text (Loss / Profit, Below floor / Above floor).
8. Zero real company names in titles, descriptions, text widgets, dataset names, or Genie copy.

## 9. Build handoff

* @data-analyst builds P3-DASHBOARD and P6-CHALLENGE-CARDS from this spec, on margin_ledger_mv first (page 1), then the suite views (page 2) when P2-MV-SUITE lands.
* Log the dashboard once in asset_ledger (dashboards are capped at ONE).
* @designer reviews under P3-DESIGN-REVIEW-DASH against sections 0 to 8 and files remediation to @data-analyst.

## Change log

* v1.0 2026-11-12 @designer: first release (DSN-DASHBOARD-SPEC).
