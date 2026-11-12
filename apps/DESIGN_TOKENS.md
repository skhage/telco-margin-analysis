# Lakelink Fiber Design Tokens v1.2 (Margin Truth)

Owner: @designer. Task: P3-DESIGN-SYSTEM (2026-11-12). These rules are binding. They cover the ONE app (`apps/margin-truth`), the ONE AI/BI dashboard, and the Margin Genie experience.
Company name in every UI string: **Lakelink Fiber**. Product name: **Margin Truth**. Never use a real company name.

All contrast ratios below were computed with the WCAG 2.1 relative-luminance formula.
Required: 4.5:1 for normal text, 3:1 for large text (>=24px, or >=18.66px bold), 3:1 for UI boundaries and graphics (SC 1.4.11).

## 1. Color tokens

| Token | Hex | Use | Contrast (measured) | Rule |
| --- | --- | --- | --- | --- |
| `--llf-primary` | #FF3621 | Brand mark, active-tab underline, viz series 2 | 3.62 on #FFF, 3.39 on surface | Never use for body text. White text on it only at large/bold size |
| `--llf-primary-ink` | #B8200F | Links, red text, white-on-red buttons | 6.46 on #FFF, 6.04 on surface | Use for every red text |
| `--llf-secondary` | #1B3139 | Header, primary text, focus ring | 13.59 on #FFF, 12.71 on surface | Default text color |
| `--llf-accent` | #00A972 | Decorative green, viz series 3 | 3.04 on #FFF, 2.84 on surface | Never use as text or as a focus ring |
| `--llf-accent-ink` | #007A52 | Approve button fill, positive text | 5.38 vs white | White text on it passes AA |
| `--llf-surface` | #F9F7F4 | Page background | - | - |
| `--llf-card` | #FFFFFF | Cards, tables | - | - |
| `--llf-text` | #1B3139 | Body text | 12.71 to 13.59 | - |
| `--llf-muted` | #5A6B72 | Secondary text, table headers | 5.55 on #FFF, 5.19 on surface | OK for text >=13px |
| `--llf-border` | #D9D4CC | Decorative dividers only | 1.47 on #FFF | Not allowed as the only boundary of an input or button |
| `--llf-border-strong` (NEW) | #8A8378 | Input, select, and outline-button boundaries | 3.75 on #FFF | Required for form controls |
| `--llf-negative` | #B8200F | Losses, errors | 6.46 on #FFF | Always add text such as "(loss)" or a minus sign. Never rely on color alone |
| `--llf-positive` (NEW) | #007A52 | Gains, approved state | 5.38 on #FFF | Pair with text |
| `--llf-focus` (NEW) | #1B3139 | Focus outline, 3px solid, 2px offset | 12.71 vs surface, 13.59 vs card | Replaces the accent focus ring. Accent was 2.84 on surface and 1.77 against the approve button, which fails 3:1 |

## 2. Data-viz palette (dashboard + app charts)

Ordered series. Each value must reach 3:1 against the white card (SC 1.4.11).

| Order | Token | Hex | vs #FFF | Status |
| --- | --- | --- | --- | --- |
| 1 | `--llf-viz-1` | #1B3139 | 13.59 | Pass. Use first for the main measure (Contribution Margin) |
| 2 | `--llf-viz-2` | #FF3621 | 3.62 | Pass |
| 3 | `--llf-viz-3` | #00A972 | 3.04 | Pass (marginal). Use for fills, not thin lines |
| 4 | `--llf-viz-4` | #5F7A8A | 4.53 | Pass. Replaces #6E8898 (3.72) so thin lines get more contrast |
| 5 | `--llf-viz-5` | #D9603B | 3.69 | Pass. **Replaces #FF8C69, which measured 2.28 and fails** |

Semantic chart colors: loss or negative margin = #B8200F, profit = #007A52, neutral or benchmark = #5A6B72.
Series 2 and 5 are both warm hues, so charts with 4 or more series must use direct data labels or a legend with patterns (color-blind safety). Show at most 5 series. Group the rest as "Other".

## 3. Typography

* Family: `Inter, system-ui, -apple-system, "Segoe UI", sans-serif`. Inter is not bundled yet, so the system fallback is acceptable for the demo.
* Scale (px): 12 caption (non-essential only), 13 table header, 14 table body, 16 body, 20 H2/app title, 24 H1/KPI label, 32 KPI value.
* Numbers: `font-variant-numeric: tabular-nums`, right-aligned. Currency is USD with no decimals in tables and compact ($1.2M) in KPI tiles. Percentages have 1 decimal.
* Weights: 400 body, 600 headings, labels, and active tab.

## 4. Spacing, shape, icons

* 8px grid: `--llf-space-1..4` = 8 / 16 / 24 / 32. Card padding is 16. Page gutter is 24 (16 at 720px or less).
* Radius 8px on cards and buttons, 2px on the brand mark.
* Icons: Lucide with a 1.5px stroke, 20px in-line and 24px in the header. Decorative icons get `aria-hidden`.
* Touch or click targets are at least 44x44px for tabs and at least 40px tall for buttons (keep 8px between targets).

## 5. Layout and responsiveness

* Breakpoints: 720px (mobile), 1024px (tablet), 1280px max content width.
* Wide tables are wrapped in `overflow-x: auto` with a visible caption. The first column stays sticky at 720px or less.
* An embedded Genie iframe uses `height: min(640px, 75vh)`.
* Layout must reflow at 320px CSS width (400% zoom) without horizontal page scroll, except inside table wrappers (SC 1.4.10).

## 6. Interaction and accessibility rules (WCAG 2.1 AA)

1. Tabs follow the ARIA tabs pattern: `id` and `aria-controls` on each tab, `aria-labelledby` on the panel, roving `tabIndex`, and Left/Right/Home/End keys. Keep `<main>` as the landmark and put `role=tabpanel` on an inner element.
2. Focus is always visible (`--llf-focus`). After an approval, move focus to the evidence panel heading (`tabIndex=-1`).
3. Irreversible actions (Approve/Reject) disable the buttons and show "Saving..." while the request runs, then confirm the result in an `aria-live=polite` region.
4. Status is shown as a text badge (Pending / Approved / Rejected), not by color alone.
5. Empty, loading, and error states are required on every data view. Error copy says what happened and what to do next. Do not show raw stack text.
6. A missing value is shown as an em dash with `aria-label="not available"`.

## 7. Voice and copy

* Short, plain, and active. Use sentence case for headings and tabs ("Approval queue", "Margin explorer").
* Use the governed display names from `margin_ledger_mv`: Revenue, Network Expense, Cost to Serve, Contribution Margin, Contribution Margin %. "CM %" is allowed only as a short label where space is tight (KPI tile subtitles, chart axes), never as a page or widget title.
* Show category values in title case: "Legacy" / "Strategic", "On-net" / "Off-net". Do not show raw TRUE/FALSE or lowercase codes in any UI, chart legend, or Genie answer table.
* Say "Lakelink Fiber network" or "our own fiber", never a real carrier name. Translate plan wording such as "approved list" to "Lakelink Fiber approved model list".

## 8. AI/BI dashboard rules (P3-DASHBOARD)

* Title: "Lakelink Fiber Margin Truth" (same as the bundle display_name). Page names: "CFO margin scorecard", "$1B Wall tracker", "Challenge cards".
* The full widget-by-widget layout is in `resources/dashboard_layout_spec.md` (binding, DSN-DASHBOARD-SPEC).
* Loss red #B8200F and profit green #007A52 are only 1.20:1 against each other. Every loss/profit chart needs signed data labels.
* Each page puts its KPI row first (at most 4 tiles), then a trend, then a breakdown, then a detail table. Each widget has a title stating the question it answers and a description that names the metric view.
* Colors come from section 2, in order. Loss bars are #B8200F.
* The embedded Genie on the dashboard is the ONE Margin Genie.

## 9. Margin Genie experience

* Title: "Lakelink Fiber Margin Genie". The description names the four personas and says that margin always means contribution margin from the governed metric view.
* Sample questions: the four persona starters from the plan, with any carrier name in the plan wording replaced by "our own fiber" or "the Lakelink Fiber network".
* Approved description (paste into the space): "Ask Lakelink Fiber margin questions in plain English. One space for Finance, Ops, Sales, and Marketing. Margin always means contribution margin (revenue minus network expense minus cost to serve) from the governed metric view margin_ledger_mv, so every team gets the same number."
* Approved sample questions, in this order: (1) Finance: "Which product families lost money after cost to serve last quarter?" (2) Ops: "Which off-net circuits run next to our own fiber, and what do we pay for them?" (3) Sales: "Which renewals in the next 90 days are below the margin floor?" (4) Marketing: "Which segments have the highest margin and the most room to grow?"
* Answers show money in USD with no decimals and percentages with 1 decimal, matching the metric view formats.
* Copy reviewed under DA-GENIE-COPY-REVIEW (2026-11-12, PASS with changes); remediation in DSN-GENIE-COPY-R1.

## Change log

* v1.2 2026-11-12 @designer: section 8 dashboard title aligned to "Lakelink Fiber Margin Truth" (bundle yml) and page 2 renamed "$1B Wall tracker"; adds the red/green 1.20:1 rule and a link to resources/dashboard_layout_spec.md.
* v1.1 2026-11-12 @designer: section 7 adds the Contribution Margin % naming rule and the title-case category value rule; section 9 adds the approved Genie description and the ordered sample questions (DA-GENIE-COPY-REVIEW).
* v1.0 2026-11-12 @designer: first release. Supersedes the provisional values in `apps/margin-truth/client/tokens.css`. Changes: focus ring moved from accent to #1B3139, border-strong added, viz-5 changed from #FF8C69 to #D9603B, viz-4 changed from #6E8898 to #5F7A8A, viz order now leads with #1B3139.
