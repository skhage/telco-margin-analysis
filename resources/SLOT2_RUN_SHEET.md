# Lakelink Fiber Margin Truth - Slot 2 run-sheet (DEC-120 slot, 2026-11-18 15:00-16:05 UTC)

Owner: @pm (DEC-129, answers COO-Q-20261117-81). Written 2026-11-17 ~22:1x UTC. Doc-only. Pinned refs (re-taken 2026-11-18 ~04:3x UTC by @designer, QA-F-RUNSHEET-L3-PINS-1118; CEO sheet pin re-taken 2026-11-18 ~08:3x UTC by @designer, DSN-REPIN-CEO-SHEET-0E77-1118, DEC-143(5)): CEO_ACTION_SHEET.md md5 5f6324b58e8e (130 newlines; S5 row l.88; re-pinned 2026-11-18 ~14:4x UTC by @devops, QA-F-SLOT2-PIN-D2655238-1118, after DSN-S7-APP-NO-WALL-LINE-1118), REHEARSAL_FALLBACKS.md md5 e3643042981e (362 newlines; re-pinned by @devops, DEVOPS-REPIN-FALLBACKS-512E-1118), scripts/margin_scene3_rule_change_revert.sql md5 45e14f198434. Minute plan rewritten to DEC-137(b) (DSN-SLOT2-RUNSHEET-DEC137-1118).

Pass-bar constants: CM (MV) = 2,375,095,705.09; Q3 2026 (ledger_quarter 2026-07-01) IP-VPN -6,715,475.88, Legacy Voice -249,532.74 (DEC-127); Margin Genie space 01f1df115a08164aab3ae5f6faac807c, benchmarks 13/13; hero ticket GROOM-1e655052ef; hero trace tr-2b088edfed85d22b2db662a6c0a7c68e (exp 1235449331932066).

## 0. Read to CEO first at 15:00Z - 8 CEO gates (DEC-134)

Owner: @designer (DSN-SLOT2-CEO-GATES-BLOCK-1118), written 2026-11-18 ~00:3x UTC. Doc-only. Read aloud as leg L0 (15:00-15:05Z, DEC-137(b)); L1 S5 starts as soon as it ends. There is no proven push path (margin_ceo_slack 404, Slack MCP is read-only), so this block is how the gates reach the CEO (DEC-134(b)). Any gate with no CEO answer by its cutoff takes its default with no further escalation. CEO_ACTION_SHEET.md is md5 5f6324b58e8e (130 newlines, see pins above); find sheet lines by grep, not by number.

| Gate | Task code | Exact CEO action | Cutoff (UTC) | Default if no answer | CEO_ACTION_SHEET ref |
| --- | --- | --- | --- | --- | --- |
| G1 | PM-CONFIRM-DEMO-START-UTC | Say the Nov 19 demo start time in UTC | 11-18 16:05Z | T0 = 2026-11-19 15:00Z (DEC-075) | none (this block) |
| G2 | PM-CEO-ACK-SIGNOFF-1117 | Say ACK (or name items to change) on the 9-item rehearsal sign-off list | 11-18 16:05Z | GO with fallbacks (DEC-124(c)) | none (this block) |
| G3 | PM-CEO-TEST-PRINCIPAL-1117 | Name one non-exempt test principal for the SOX parity check | 11-18 16:05Z | SOX parity stated as headless only; no live principal claim on stage | none (this block) |
| G4 | PM-SLACK-PUSH-CHANNEL | Enable a Slack send path for CEO escalations (CEO-owned connection margin_ceo_slack or a Slack send tool) | none | CEO_ACTION_SHEET stays the delivery channel | l.3, l.130 (grep 'Slack') |
| G5 | COO-EXEC-DELETE-PIPELINE-1117 | Confirm in an interactive chat, or delete in the Pipelines UI, pipeline ccea7e91-e657-4168-82fe-588f4e6437d5 (never 20960984) | 11-18 14:00Z | Hide-and-retire: ccea7e91 stays IDLE and is never shown (DEC-123/126) | gate 8 l.15, I3 l.54 (grep 'ccea7e91') |
| G6 | PM-CONFIRM-TAG-POLICY-1117 / COO-EXEC-TAG-FUNCTIONS-1117 | Confirm in chat: add margin_analysis to the telco_project tag policy allowed values, then tag the 4 margin_ UC functions | 11-18 14:00Z | TBLPROPERTIES ('telco_project'='margin_analysis') (directive 5) | none (this block) |
| G7 | DEVOPS-WC-RESET-RC4 | Confirm in chat: move the workspace clone to rc4 and clean the tree | 11-18 14:00Z | Workspace clone left unpushed; origin/main = rc5 1c59251 | none (this block) |
| G8 | PM-CEO-GENIE-ONE-INSTRUCTIONS | Approve or reject the Genie One workspace-instruction lines for Margin routing (resources/genie_one_instructions_proposal.md) | 11-18 14:00Z | Workspace instructions not edited; Margin Genie on stage (DEC-029b) | none (this block) |

Note: G5-G8 cutoffs (14:00Z) are before this slot opens, so at 15:00Z read them as "default already applied" unless the CEO acted earlier. G1-G3 can still be answered until 16:05Z. @pm records each answer or default at the 16:05Z go/no-go (DEC-124(c)).

## (a) Minute plan (DEC-137(b), 65 min; the timed S1-S7 run is DROPPED from the slot per DEC-129 drop rule; P6 go/no-go uses per-leg results)

| UTC | Step | Owner | Pass bar | Evidence artifact |
| --- | --- | --- | --- | --- |
| 14:45 | Read 4 preflights (DE, DevOps, RP, DA lines) | @pm | All PASS, md5s unchanged | status_updates rows |
| 14:52 | S1 warm-up: ask the verbatim S1 question once in Margin Genie (DEC-129(2)) | CEO (human) | Answer returns in <30 s | Genie conversation id |
| 15:00-15:05 | L0. Item 0: read the 8 CEO gates (section 0, DEC-134) | @pm reads; CEO answers | Each gate answered or default recorded | @pm go/no-go notes |
| 15:05-15:15 | L1. S5 approve of GROOM-1e655052ef in app lakelink-margin-truth (opened by name, DEC-119) + read-only verify | CEO; verify @app-developer | approval_audit row audit_id>12, action 'approved', actor_role Ops, for GROOM-1e655052ef | audit_id, actor, timestamp (APP-SLOT2-APPROVE-VERIFY-1118, cutoff 16:15Z) |
| 15:15-15:20 | L2. S6: open hero trace tr-2b088edf, read the identity on the trace | CEO; verify @ml-engineer | Identity line per DEC-129(3)(iv) delegated-identity wording, never an SP claim | trace id + recorded identity (QA-F-DEC091-S6-LINE-MISSING-1117) |
| 15:20-15:25 | L3. S1 in Genie One, BEFORE the rule change (DEC-120(2) amended by DEC-127) | CEO; verify @data-analyst | IP-VPN -6,715,475.88 and Legacy Voice -249,532.74, framed as legacy | Genie One conversation id (DA-SLOT2-GENIEONE-ID-1118) |
| 15:25-15:40 | L4. S3 live rule change (DEC-129(1), DEC-131): run scripts/margin_scene3_rule_change_revert.sql on rule_id MGN-ALR-customer_care-ticket_count-v1 ONLY, weight 0.70 -> 0.90 (never touch MGN-ALR-customer_care-circuit_count-v1; that rule gives 2,331,949,671.57). Right after the UPDATE: forced Refresh of dashboard 01f1df1950c5 (Refresh button or a filter change; shared cache, no schedule), then re-ask Margin Genie, dashboard, app. Revert to 0.70, then forced Refresh of 01f1df1950c5 again. Stop rule: 60 s per surface after the forced refresh, hard stop 15:40Z; on a miss, revert to 0.70 at once and use the DEC-018 clip / DEC-027(3) read-only sim on Nov 19 | CEO only (human executor) | 2,360,713,702.39 at 0.90 (delta -14,382,002.70); exactly 2,375,095,705.09 over 517,032 rows after revert | Script output + @qa p5_revert_verify (DEC-130(4)), not the editor |
| 15:40-15:50 | L5. S2 lineage render (DEC-128 click path margin_ledger_mv -> margin_ledger_allocated -> margin_ledger_v2 -> source PDF; click v2, not margin_ledger) + S4 Sales line (policy-only, DEC-136). No CM-dependent legs while @qa confirms the revert and re-runs benchmarks 13/13 (QA-S3-LIVE-REVERIFY-1118, cutoff 15:50Z) | CEO; verify @designer (S2) and @data-analyst (S4) | S2: rendered nodes match the API list; S4: DEC-136 line read, no Sales-scoped CM claim; @qa: CM exactly 2,375,095,705.09 + 13/13 | S2 screenshot (DSN-S2-LINEAGE-RENDER-CHECK-1118); COO-Q-20261116-14; @qa eval id |
| 15:50-16:00 | L6. Dashboard render ids for CM tile, ONLY after @qa revert confirm | CEO; verify @qa | Tile shows 2,375,095,705.09 | dataset statement ids (QA-S1-RENDER-IDS-1117) |
| 16:00-16:05 | L7. S7 $1B Wall challenge cards check inside dashboard 01f1df1950c51bd68e87ace31632c2bf | CEO; verify @data-analyst | Cards render as on 11-17 | COO-Q-20261117-61 |
| 16:05 | Go/no-go written to P6-DRESS-REHEARSAL from per-leg results (DEC-124, DEC-137) | @pm | - | status_updates rollup |

## (b) Priority order and drop rules

Run order = slot order above (DEC-137(b)): L0 gates > L1 S5 > L2 S6 > L3 Genie One S1 > L4 S3 > L5 S2 + S4 > L6 render ids > L7 S7.

* Overrun rule (DEC-137(b)): drop from the END - first L7 S7 (static card copy from the dashboard as rendered 11-17), then L6 render ids (dataset SQL statement ids fallback).
* Per-scene automatic defaults if a leg misses its cutoff are in DEC-137(a); unverified COO items are closed NOT VERIFIED by the @pm 17:00Z run (PM-SLOT2-NOTVERIFIED-SWEEP-1118).
* Any L4 (S3) failure (number off, a surface misses its 60 s after the forced refresh, or 15:40Z reached, or revert not exact): stop, revert MGN-ALR-customer_care-ticket_count-v1 to 0.70, force-refresh 01f1df1950c5, @qa re-verifies (p5_revert_verify); Nov 19 S3 uses the DEC-018 clip / DEC-027(3) read-only simulation (DEC-131(3)).

## (c) Fallback for each dropped item (NOT VERIFIED stated at go/no-go)

| Item | Fallback | Where written |
| --- | --- | --- |
| L1 S5 approve | Hero trace tr-2b088edf + stills pack | REHEARSAL_FALLBACKS l.344, l.347, l.354 |
| L2 S6 identity | Trace A / Trace B + audit query | REHEARSAL_FALLBACKS l.345 |
| L3 Genie One S1 | DEC-029b: Margin Genie on stage, no Genie One claim | REHEARSAL_FALLBACKS l.340, l.348; CEO_ACTION_SHEET l.11, l.35, l.59 |
| L6 Render ids | Dataset SQL statement ids + screenshot (CEO-only) | REHEARSAL_FALLBACKS l.349 |
| L4 S3 live change | Read-only simulation 0.70 -> 0.90 = 2,360,713,702.39 (DEC-027(3)) | REHEARSAL_FALLBACKS l.342 (CEO_ACTION_SHEET l.71, l.85, l.104) |
| Timed run (DROPPED, DEC-137(b)) | Live S1-S6 with the stills pack | REHEARSAL_FALLBACKS l.350, l.352 |

## (d) Recording results on the board (by 16:20 UTC)

* Each verifier above writes status_notes on its task with the evidence id within 15 min of 16:05Z.
* @pm writes the go/no-go (P6-DRESS-REHEARSAL) at the 16:05Z run and lists every NOT VERIFIED item with its fallback line.
* Never run the DEC-121(b) queue cleanup unattended; it stays at the 18:00Z cutoff.

## (e) Discover domain and glossary presenter lines (DSN-RUNSHEET-DOMAIN-GLOSSARY-LINES-1118, answers COO-Q-20261118-19)

Owner: @designer, written 2026-11-18 ~13:3x UTC. Doc-only, appended at the end so every existing l.N reference stays valid.

* Discover: open the domain 'Lakelink Fiber' (30075762) and its Margin sub-domains only. Never open the old domain lakelink_margin (2abc9194).
* $1B Wall: "The $1B Wall is tracked in the margin_onebillion_wall_mv metric view, which reads the same allocated ledger as contribution margin." (Checked 13:3xZ: cdm_tmforum._metrics.margin_onebillion_wall_mv is a METRIC_VIEW built on margin_ledger_mv, which reads margin_ledger_allocated.)
* Rate Variance, only if asked: "Rate variance is a stretch metric; Genie answers it from carrier invoices, and its page publishes with the rate metric view after the demo." (DEC-031, DEC-049: page 079d1b7a stays DRAFT.)
