# Recipe: Funding → Hiring Managers → BD

**Play #7.** A company raises → qualify it against the client's ICP → find the hiring managers/decision-makers
→ get work email → personalize off the funding hook → drop into a BD sequence → land in the CRM.

> **What's next + why:** this is the **signal → BD** branch of the funnel. See
> [`../recruiter-craft.md`](../recruiter-craft.md) §B for the branch and the work-email channel rule.

This is a **pattern the agent composes at runtime**, not a hard-coded pipeline. It chains the reusable
**capabilities/waterfalls** below; the agent decides scope, persona, and which client sequencer/ATS to use.
(If this exact path gets run constantly or needs to run headless on a schedule, *then* freeze it into a saved
cloud workflow — see "Graduating to a workflow" at the end.)

> **Side:** Business development (winning roles to fill). **Channel: WORK email** — this is BD, not candidate
> acquisition, so the candidate personal-email/LinkedIn rule does NOT apply here. See
> [references/provider-precedence.md](../references/provider-precedence.md).

## The capability chain (what the agent walks)
```
SIGNAL            QUALIFY            SOURCE                 ENRICH                  PERSONALIZE        ACTIVATE         LAND
funding raised →  ICP check    →     hiring managers   →    work email        →     BD first-line  →  BD sequence  →   CRM
(predictleads)    (free, Model A)    (people_search wf)     (email_enrichment wf)   (hyreflow-agent)  (client seq.)    (client ATS)
```

## Inputs the agent needs (ask if missing)
- **ICP** — the client's `ICP.md` (built once by `/icp`, lives in the client workspace), or quick firmographics.
- **Funding window + round types** — e.g. Series A+ in the last 90 days (default below).
- **BD persona** — which titles to reach (e.g. founder / VP Eng / Head of Talent / hiring manager). Not a hard
  filter list — the intent ("who signs off on using a recruiter").
- **Targets** — # companies, contacts per company (default 2–3), spend cap, which **sequencer** + **ATS** the client uses.

## Steps

**1 — SIGNAL: discover funded companies** *(metered; single-capability waterfall)*
- Primary event feed: `predictleads.discover_financing_events` (filter by round type + recency).
- Native account-filter path: use AI Ark `company_search` when the ask is firmographic account discovery
  around funding stage/window, revenue, language, or founded year. Raw shapes include
  `account.funding.type:["SEED"]`, `account.funding.duration:{start,end}` (epoch-ms strings),
  `account.revenue:{type:"RANGE",range:[{start,end}]}`, `account.language:{any:{include:["german"]}}`,
  and `account.foundedYear:{range:{start,end},type:"RANGE"}`. Peek `result.totalElements` with `size:1`
  before depth because unsupported fields are silently ignored (the count lives under the `{ _meta, result }` envelope, not the top level).
- Fallbacks (funding-discovery order): zoominfo scoops → `leadmagic` company_funding (enrich-only) → exa/serper news.
- **Count-before-pay:** peek how many companies match the window before pulling the full set.

**2 — QUALIFY: ICP gate** *(FREE — Model A, runs on the customer's own Claude; the strategic gate)*
- Hard firmographic filters on data you already have from the signal (industry/size/geo) — free.
- Then LLM fuzzy-fit of survivors vs `ICP.md` (the `company-qualifier` agent / inline reasoning). **No credits.**
- **Gate BEFORE enrichment** — never pay to find contacts at companies that don't fit. See
  [recipes/qualify-against-icp.md](qualify-against-icp.md).

**3 — SOURCE: find the hiring managers** *(metered; the `people_search` waterfall)*
- Run the **people-search waterfall** scoped per qualified company (`company_domains`/`company_names`) +
  the BD persona titles. Order `aiark → prospeo → lemlist → apollo` is handled *inside* the waterfall.
- **Single-source default / stop-at-target:** take the first source that yields enough contacts per company;
  don't fan out unless coverage is short (`--max`). Over-provision ~1.4× the contacts you actually want.

**4 — ENRICH: work email** *(metered; the `email_enrichment` waterfall)*
- Run the **email-enrichment waterfall** (`prospeo → bettercontact → fullenrich → lusha → wiza`), first-hit.
- **Optional verify:** `enrichley.validate_email` before sending — `catch_all_safe` is usable; drop undeliverable.

**5 — PERSONALIZE: BD first-line off the funding hook** *(metered AI — `hyreflow-agent`)*
- `hyreflow_agent.infer` with the `prompts.json` → **"BD first line from hiring signal"** template, feeding the
  funding event as the hook ("congrats on the $X round — you're likely scaling [team]…"). Structured output per row.

**6 — ACTIVATE: BD sequence** *(the client's sequencer, BYOK; activation only)*
- **Resolve the target campaign** — don't assume one exists:
  - use the client's **configured BD campaign** (from client config) if set; **else create one**
    (`lemlist.create_campaign` → `add_sequence_step` to author the steps/copy from a template) and record its id.
- **Enroll** the contacts (`add_lead_to_campaign`) with the personalized opener as a **custom variable**
  (e.g. `{{firstLine}}`) — so a standing sequence template stays fixed and only the opener varies per lead.
- **Enrolling ≠ sending.** create + enroll leaves the campaign **idle**; **`start_campaign` is the ONLY step
  that sends** — keep it a SEPARATE, explicitly-gated action (pilot-one → confirm → start). `pause_campaign` to stop.
- Which campaign (or the create-policy) is **per-client config**, like the ATS/sequencer choice.
- Activation only — never use the sequencer for enrichment.

**7 — LAND: CRM** *(the client's ATS/CRM, BYOK; optional but recommended)*
- Upsert company + contacts and log the **funding event as the opportunity/note** (e.g. `recruit_crm.create_company`
  + `create_contact`) so the "why now" is on the record. Approval-gated write.

## Gates (apply in order)
- **ICP gate** before step 4 (qualify before you pay to enrich).
- **Credit & approval gate** before any full paid run: pilot **one company end-to-end** (steps 1→5 on a single
  company), post the 4-section approval message, run the rest only on approval. See SKILL.md "Credit & approval gate".
- **Count-before-pay** at step 1 (companies) and step 3 (contacts).
- **Over-provision then filter** (~1.4×) — coverage is a property of the company.
- **Channel = work email** (BD).
- **Writes gated** — sequencer enroll (6) and CRM writes (7) pilot-first.

## Cost shape (where credits go)
| Step | Metered? |
|---|---|
| 1 signal (predictleads) | metered (per the funding source's cost) |
| 2 ICP qualify | **free** (Model A reasoning + free firmographic filters) |
| 3 people-search waterfall | metered (first source that hits; e.g. aiark ~3.0; current costs in cost-card.json) |
| 4 email waterfall (+verify) | metered (first hitting provider) |
| 5 personalization | metered (hyreflow-agent tokens) |
| 6 sequencer / 7 CRM | usually free (client BYOK) |
Free throughout: the ICP judgment, dedup, and any deterministic glue.

## Output
A set of **ICP-qualified, recently-funded companies** with named hiring managers, verified work emails,
funding-anchored opener lines, enrolled in a BD sequence and landed in the CRM with the signal attached.

## Graduating to a workflow (Model B)
If the client wants this **running automatically** (e.g. "every Monday, new Series A in DACH SaaS → BD"),
freeze this exact path into a saved **cloud workflow** with a cron trigger — the agent-composed pattern becomes
a pinned, headless pipeline. Until then, the agent composes it on demand from the capabilities above.
