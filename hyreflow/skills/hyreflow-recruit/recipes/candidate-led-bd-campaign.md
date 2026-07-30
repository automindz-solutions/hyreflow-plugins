# Recipe: Candidate-led BD campaign (MPC Shot)

**The full-campaign sibling of [`cv-to-jobs.md`](cv-to-jobs.md).** That recipe ends at a single spec-out
*message* per target company (no sequencer, no frontsheet, no CRM write). This recipe is the "MPC Shot":
take that same strong, unplaced candidate and run a properly **sequenced, multi-company BD campaign** —
fan out to a target list (scraped live open roles **or** a lookalike-company list), route existing CRM
contacts direct and enrich only net-new, apply a poaching/exclusion guard, draft an anonymised frontsheet,
and send a one-candidate/one-role teaser. A human gates the send; a human takes the warm reply. It is the
**candidate-triggered mirror of the company-triggered signal→BD plays** ([`funding-to-bd.md`](funding-to-bd.md),
[`tradeshow-to-bd.md`](tradeshow-to-bd.md)) and shares their enrich/exclusion/reply-routing spine.

> **Naming:** "MPC" (Most-Placeable-Candidate) is UK/EU recruiter jargon a US hiring manager won't
> recognize. On the product surface, call this **candidate-led BD** (recruiters may still say "MPC" or
> "spec-in" to you — route either name here; see the vocabulary table in
> [`../recruiter-craft.md`](../recruiter-craft.md)).

> **What's next + why:** this is the **MPC / spec-out** branch of the funnel, run as a full campaign
> instead of a one-off message. See [`../recruiter-craft.md`](../recruiter-craft.md) §B "Branch — BD / MPC".

## Candidate selection is the gate, not a preference
Before running anything, the candidate must clear both bars (per the source brief — this is load-bearing,
not a nice-to-have):
- **Evergreen / high-demand** function (sales, engineers, accountants, nurses, …) — never a C-level
  one-off or an admin/generalist profile. The wrong candidate class kills reply rates regardless of
  downstream execution quality.
- **One-paragraph-pitchable** — one role, one quantified achievement, one availability line. If you can't
  say it in a paragraph, the candidate isn't ready for this play.

If the candidate doesn't clear this bar, use [`cv-to-jobs.md`](cv-to-jobs.md)'s lighter single-message
path instead (it has no such gate), or don't run a campaign at all.

## Capability chain
```
CV/MPC-flag → PARSE (candidate profile, + selection gate)
   ├─ (a) SEARCH live open roles (job-board trio, region-scoped, cv-to-jobs Step 3) ────┐
   └─ (b) LOOKALIKE companies (seed waterfall; AI-generate only as last resort) ────────┤
                                                                                        ▼
                                                DEDUP (company-level) + radius filter
                                                                                        │
                                                    FIT-MATCH (AI, keep > threshold)
                                                                                        │
                       CRM-FIRST SPLIT: existing contact → route direct | net-new → ENRICH (work email)
                                                                                        │
                                POACHING + EXCLUSION GUARD ──▶ human APPROVAL GATE
                                                                                        │
                      FRONTSHEET content + teaser copy ──▶ sequencer send (attach gap — see Step 10)
                                                                                        │
                                REPLY ──classify (positive-rate)──▶ human spec-CV call
```

## Inputs
- Candidate: CV file or ATS/CRM candidate slug (same as [`cv-to-jobs.md`](cv-to-jobs.md) Step 1) — plus the
  evergreen/pitchable gate above.
- `target_titles` / location + radius (from the CV, same as `cv-to-jobs.md` Step 2).
- `fit_score_threshold` — default 75 (client-configurable; the brief's "keep > 75").
- The client's **`poaching_exclusion_source`** — its own current-staff + current-client roster (per-client
  config; if not supplied, say so and run Step 7 without it rather than fabricating a source).
- The connected CRM/ATS (for the CRM-first split, Step 5) and whichever sequencer the client sends through
  (Step 10 — see the attach-capability gap there before assuming Recruit CRM/Loxo/Bullhorn can send).

## Steps

**1 — Parse the candidate + gate.** Identical to `cv-to-jobs.md` Step 1
(`prompts.json → "Parse CV to candidate profile"`), then apply the evergreen/pitchable gate above before
continuing. → `cv-analysis.json`.

**2a — Search live open roles** *(metered; Apify)* — the same job-board-trio approach as
`cv-to-jobs.md` Step 3 (swap in the client's market boards), title × geo × radius, default a **14-day**
recency window (vs. `cv-to-jobs.md`'s 7-day default — this play tolerates slightly older postings since
it's fanning wider).

**2b — Lookalike company fallback** *(metered)* — when board coverage is thin (or the market has weak
board coverage generally), build the target list from the candidate's most recent employer(s) as seeds
through the existing **lookalike waterfall**: `prospeo search_company company_lookalike` →
`lusha company_lookalikes` → `zoominfo company_lookalikes` → `predictleads similar_companies` →
`exa find_similar` (see [`build-tam.md`](build-tam.md) step 1C for the full waterfall + tiering). Use
**T1/T2** tier for a tight, high-relevance ~15-20 company list, matching the brief's target size.
**AI-generate only as a last resort** (no seed resolves, or zero board coverage at all):
`hyreflow_agent.infer` — "generate 15-20 lookalike companies for this candidate's function/industry/geo."
Tag these rows `_source: ai_generated`; they get an extra domain-verification pass before any spend
(an invented company name/domain is a real risk with a pure-LLM list, unlike the resolved-seed waterfall).

**3 — Dedup + radius filter** *(free, code)* — company-level key (one company can post the same role
across boards, or appear from both 2a and 2b); re-apply the candidate's location/radius filter.

**4 — Fit-match** *(free — Model A / metered at scale)* — for a **real open role**:
`prompts.json → "Score job against CV (0-10)"` (as `cv-to-jobs.md` Step 5), ×10 to match the brief's
0-100 framing. For a **lookalike company with no live posting**: the speculative sibling,
`prompts.json → "Fit-match candidate against company (speculative)"` — same grounding discipline, output
carries `speculative_fit_rationale` instead of a job-posting match. Keep only survivors above
`fit_score_threshold`.

**5 — CRM-first split** *(free CRM read, before any paid enrichment)* — for each matched company, check
the client's connected CRM/ATS **first**: `search_companies` / `search_contacts` (or the ATS's equivalent)
by domain. **Existing client** (a decision-maker contact already on file) → route direct, no enrichment
spend. **Net-new** → falls through to Step 6. Same "never pay before checking your own base" discipline as
[`crm-matching.md`](crm-matching.md) Step 1, applied to companies instead of candidates — this is the
credit-saving reason CRM-first sits ahead of enrichment in the brief.

**6 — Enrich net-new only** *(metered; the standard hierarchy + waterfall)* — company-scoped
`people_search` for the decision-maker (reuse `cv-to-jobs.md` Step 6's size-adaptive title hierarchy) →
**work-email waterfall** (`email_enrichment`; BD channel — see
[`references/provider-precedence.md`](../references/provider-precedence.md)).

**7 — Poaching + exclusion guard** *(free, code + CRM read, before the gate)* — drop or flag:
- companies that ARE (or are a subsidiary of) the client's **own current client roster** — don't pitch a
  candidate into an account the client already serves without a heads-up.
- **poaching exposure** — cross-reference the target company's decision-maker/domain against the client's
  `poaching_exclusion_source` (their own current-staff list) so a send never solicits into a company that
  employs the client's own current placements in a way that could breach a non-solicit. Best-effort and
  per-client config — if the client hasn't supplied a source, say so explicitly and proceed without the
  guard rather than fabricating one.

**8 — Human approval gate** *(mandatory — sold as control, not just a spend gate)* — show the full
matched-company list (company · role/rationale · fit score · CRM-existing flag · guard flags) before any
copy is drafted or anything is sent. This sits **in addition to** the normal credit/approval gate on
Step 6's enrichment (SKILL.md "Credit & approval gate") — the brief explicitly sells "run one CV through,
approve before anything goes out" as the product's control feature.

**9 — Frontsheet + teaser copy** *(AI tokens)* — draft the anonymised one-pager content with
`prompts.json → "Frontsheet content (anonymised one-pager)"` (headline, one quantified achievement,
availability — no name, no employer) and the teaser email with the same
`"Spec-out sequence (anonymised candidate to hiring manager)"` prompt `cv-to-jobs.md` uses.
**⚠️ Rendering that content to an actual PDF is not a capability this skill has today** — there is no
PDF-generation adapter in the toolbelt. Hand the drafted content to the user for their own document
tooling until a frontsheet module ships (see "Open gaps" below); don't claim a PDF was produced.

**10 — Send** *(the client's sequencer; approval-gated)* — **this is the step with the real capability
gap**, so read it before assuming it works end to end. The brief calls for the frontsheet PDF to ride
along, which means an attach-capable send. Checked against every sequencer's callable surface: **none of
the cold-outreach sequencers (`instantly`, `lemlist`, `smartlead`, `heyreach`, `sourcewhale`) support a
file attachment on a send.** The recruiting CRMs the brief names as the alternative
(`recruit-crm` / `loxo` / `bullhorn`) don't fill the gap either — their callable surfaces are read/write
**data** methods (candidates/companies/contacts/jobs), not an outbound-email-with-attachment endpoint.
**Until one of those documents (or hyreflow builds) an attach-capable send, treat this as a known
product gap**, not a working step — see "Open gaps". Practical fallback today: send the teaser through
the normal sequencer waterfall **without** the attachment, and share the frontsheet content as a
follow-up once the reply is warm.

**11 — Reply routing** *(new — no existing plumbing; describes the target behaviour)* — classify inbound
replies with `prompts.json → "Classify reply (positive/neutral/negative)"` and log the result to the CRM.
**Monitor positive-rate, not reply-rate** — a fast "not interested" counts as engagement noise, not a lead
(per the brief). A **positive** hands to the human for the spec-CV call; multi-thread the buying-committee
contacts on live interest (5-8 members per the brief), the same multi-thread instinct as
[`tradeshow-to-bd.md`](tradeshow-to-bd.md) uses for a warm conference lead. There is **no inbound-webhook
→ CRM-write plumbing in this skill layer today** — this step is the target behaviour once that lands, not
a currently callable tool; route replies to the human manually until it does.

## Gates
- **Candidate-selection gate** (Step 1) — evergreen/high-demand + one-paragraph-pitchable, before anything runs.
- **CRM-first, before enrichment** (Step 5) — never spend on a company already on the client's own CRM.
- **Credit & approval gate** before Step 6's paid enrichment (pilot one company, standard 4-section message).
- **Content approval gate** before Step 9 (Step 8) — the human reviews the matched-company list before any
  copy is drafted or a send goes out.
- **Poaching/exclusion guard** (Step 7) before the gate — best-effort; explicitly skipped (and said so) when
  the client hasn't supplied a `poaching_exclusion_source`.

## Cost shape
| Step | Metered? |
|---|---|
| 1 parse + gate | AI tokens (free, Model A interactive) |
| 2a job-board search | metered (Apify, per result) |
| 2b lookalike / AI-generate fallback | metered (waterfall) / AI tokens |
| 3 dedup | free |
| 4 fit-match | free (Model A) / metered at scale |
| 5 CRM-first check | free (CRM read) |
| 6 enrich net-new | metered (people-search + email waterfalls) |
| 7 poaching/exclusion guard | free (CRM read + code) |
| 8 human approval gate | free (no additional call) |
| 9 frontsheet + teaser copy | AI tokens |
| 10 send | client sequencer, usually free (BYOK) — attachment itself is a gap, see Step 10 |
| 11 reply classify | AI tokens (once the webhook plumbing exists) |

## Output
A ranked, CRM-deduped, exclusion-checked list of target companies for one candidate, each with a fit
score/rationale, a drafted anonymised frontsheet + teaser copy, sent through the client's sequencer
(without the attachment until Step 10's gap closes), with replies classified by positive-rate for the
human spec-CV handoff. The candidate itself persists as a reusable BD asset — re-run this recipe against
new signals once a registry exists (see "Open gaps").

## Open gaps (flagged in the source brief — do not build ahead of a product decision)
- **Candidate registry / spec-in vault** — where a client's evergreen candidates persist so a future job
  signal can query "do we already have someone for this" before falling through to generic outreach (the
  mirror of a `job-signal-bd`-style signal entry). Not built; per-client data, product call on where it lives.
- **Frontsheet module** — anonymised PDF (and a named-microsite variant) as a reusable service, including
  asset storage. Today this recipe drafts the *content* only (Step 9).
- **Attach-capable sequencer** — mandate a CRM sequencer for these sends, or build an attach layer over the
  existing cold-email sequencers? Unresolved; Step 10 above is the honest current-state workaround.
- **Multi-profile bundling** (3-4 candidates per send) — not modeled here; this recipe is
  one-candidate/one-role, per the brief's initial scope.
- **US naming** — this file uses "candidate-led BD" as the product-facing name; "MPC" stays valid
  recruiter-side vocabulary (see `recruiter-craft.md`).

## New prompts added (`prompts.json`)
- `Fit-match candidate against company (speculative)` — the no-live-posting sibling of "Score job against
  CV (0-10)", for lookalike companies without a scraped role.
- `Frontsheet content (anonymised one-pager)` — headline/achievement/availability blurb, no name/employer.
- `Classify reply (positive/neutral/negative)` — inbound reply → positive-rate classification, reusable
  beyond this recipe for any BD/candidate sequence reply.
