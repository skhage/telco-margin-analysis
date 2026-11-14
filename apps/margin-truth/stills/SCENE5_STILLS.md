# Scene 5 stills + evidence pack (DEC-025 fallback), 3-ticket build
Task DSN-F-STILLS-3TICKET-R1 (binding @designer finding), by @app-developer, regenerated 2026-11-14. Supersedes the 2026-11-13 2-ticket pack in /Volumes/cdm_tmforum/revenue_assurance/margin_documents/recordings/scene5/ (volume left untouched; workspace copy per DEC-044(3)). Use this pack only if the gate-1 app SP GRANTs miss Nov 15 12:00 CT. Otherwise record the live app with ../SCENE5_CLICK_SCRIPT.md.
Company: Lakelink Fiber (fictional). App: lakelink-margin-truth (the ONE app). Files only, no notebook or app.

## Contents
* frames/frame1_queue.html: Ops, Pending, 3 non-TEST tickets (DEC-037a, DEC-038), hero row 10211 outlined
* frames/frame2_ticket_detail.html: hero GROOM-1e655052ef / circuit 10211, comment typed, Approve highlighted
* frames/frame3_after_approval_evidence.html: PROJECTED post-approval state: announcement, 2 remaining pending, evidence panel (trace tr-2b088edf, label 'Agent identity'), audit record
* approval_tickets.json / approval_audit.json: real rows from Lakebase telco-margin-analysis-app public schema, TEST-* excluded (3 tickets, 3 audit rows)
* mv_tieout.json: ticket values compared with cdm_tmforum._metrics.margin_offnet_spend_mv

Frames link ../../client/tokens.css (the app's design tokens, unchanged). Open from a copy of the whole apps/margin-truth folder at 1440x900 to screenshot.

## Storyboard
| Frame | Screen | Annotation | On screen (2 dp, rehearsal build) |
| --- | --- | --- | --- |
| 1 | Approval queue, Ops, Pending | "Ops owns off-net grooming approvals." | GROOM-44c3612b69 circuit 45040, Partner Carrier 55, $2,880.05 / $879.34; GROOM-6d8f8ce31e circuit 98532, Partner Carrier 47, $2,469.86 / $469.00; GROOM-1e655052ef circuit 10211, Partner Carrier 28, $1,364.58 / $1,357.85 |
| 2 | Hero row 10211, comment typed | "Circuit 10211 runs 476 meters from our own fiber. We can save $1,357.85 a month." | Rationale from Margin Genie (score 99). Comment "Move on-net Q1", then Approve |
| 3 | Evidence panel after approval (projected) | "Agents act, people approve. Every action has an identity and a record." | Agent lakelink-margin-grooming-agent; Agent identity = user identity (fallback) stephen.hage@databricks.com; trace tr-2b088edfed85d22b2db662a6c0a7c68e; audit Created (real, audit_id 6) + Approved (projected); 2 tickets still pending |
| 4 | MLflow trace | Hand off to the @ml-engineer scene 6 pack: recordings/scene6/SCENE6_EVIDENCE.md | Spans, gateway usage, Genie audit |

Hero savings on screen: $1,357.85 a month (circuit 10211). Queue total, if asked: 1,357.85 + 879.34 + 469.00 = $2,706.19 a month. The old '$1,348 a month' 2-ticket total is retired.

## Number tie-out (verified 2026-11-14 by SQL, MEASURE on the MV vs app Lakebase rows)
| Ticket | Circuit | Ticket monthly cost | MV monthly cost | Ticket savings | MV savings | Diff |
| --- | --- | --- | --- | --- | --- | --- |
| GROOM-1e655052ef | 10211 | 1364.58 | 1364.58 | 1357.85 | 1357.85 | 0.00 |
| GROOM-44c3612b69 | 45040 | 2880.05 | 2880.05 | 879.34 | 879.34 | 0.00 |
| GROOM-6d8f8ce31e | 98532 | 2469.86 | 2469.86 | 469.00 | 469.00 | 0.00 |

Grooming candidates on the MV: 47; annual off-net cost (what we pay) 1,152,342.12; annual estimated savings 412,539.96 (savings, not spend, DEC-026).

## Caveats
* All 3 tickets are still pending. Frame 3 shows the expected post-approval state, so do not present it as a recorded approval.
* Only the hero ticket carries the live Margin Genie trace tr-2b088edfed85d22b2db662a6c0a7c68e (genie_basis margin_genie). The two older tickets carry tr-d9fef3bf (sql_fallback); they are not opened on stage.
* agent_sp_name / agent_sp_app_id are NULL, so the 'Agent identity' row shows the user fallback. Do not claim an agent service principal on screen.
* Dollar values are 2 dp to match the rehearsal build source (DEC-030). The live deployment 01f1df66 renders 0 dp until the CEO redeploy (REDEPLOY.md).
* TEST-GROOM-4d4c099b0e exists in Lakebase but is hidden (DEC-038) and excluded here.
