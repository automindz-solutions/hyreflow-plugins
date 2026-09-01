# Recipe — Network ICP Qualification (LinkedIn network → scored prospect DB → weekly Dream 100 sweep)

**Use when:** the client wants to turn their **own LinkedIn connection graph** into a scored, queryable
prospect database, then run a **weekly engine** on a curated **Dream 100** that surfaces 10 researched
targets a week with personalised invite drafts. Two coupled pipelines share one config doc and one client
state store: a one-shot **batch qualifier** and a **weekly sweep**.

> **Key rule — the human send is a hard gate, by design.** No LinkedIn send automation, ever — that is the
> account-safety guarantee this recipe sells. Everything up to a staged draft is headless; clicking
> "Connect"/"Send" is always a human, capped at 20-25/day. Already-connected contacts never get an invite
> draft — they branch into a warm-DM route instead (see Part 3).

## The two pipelines (capability chain)
```
Batch:  Connections.csv → PREFILTER (title/function, free) → ENRICH (email_enrichment wf: linkedin_url
        or name+company) → DEEP SCREEN (network-ICP, binary in/out — never a score) → LOAD → Airtable
        "LinkedIn Network" (client BYOK REST)

Build:  network-ICP sub-segments → people_search waterfall (layered, one pass per segment) → dedupe on
        profile_url across layers → Airtable "Dream 100" ← warm-flag: cross-ref connection_status
        against the "LinkedIn Network" table from Batch

Sweep (weekly, scheduled): SUPPRESS (90-day join, runs FIRST) → REFRESH (7-day activity) → SCORE
        (engagement) → rank → TOP-10 → RESEARCH (exa, news/funding) → DRAFT (invite, client voice)
        → stage in Airtable → HUMAN SEND (cap 20-25/day, hard gate) → SUPPRESS (on send, 90-day hold)
```

## Config primitive — the network-ICP doc
One file drives all three pipelines: `<client-slug>-network-icp.md`, client-local data (like the
company-level `ICP.md` used by [`build-tam.md`](build-tam.md) / [`qualify-against-icp.md`](qualify-against-icp.md)
— but this one screens **people**, not companies, so keep it a **separate file**; a client may have both).
Built once at onboarding, versioned per-client. If it's missing, tell the user to build it first — don't
silently skip the gate, same discipline as the company `ICP.md`. It must supply:
1. **Title/function match rules** for the pre-filter (decision-maker titles, functions to keep).
2. **Full screening criteria + exclusions** for the deep screen (the binary bar).
3. **Sub-segment definitions** for the Dream 100 layering (e.g. a PE / CEO-or-hiring-manager /
   podcast-guest split — whatever the client's Dream 100 actually looks like).
4. **Message archetypes + voice** for the invite drafts (so drafts sound like the client, not a template).

## Inputs
- **`Connections.csv`** — the client's LinkedIn export ("Settings & Privacy → Data privacy → Get a copy of
  your data → Download larger data archive"). Surface these gotchas before running:
  - emails are only present for connections who allow their connections to see/download them;
  - the CSV/vCard drop extended charsets (Chinese/Japanese/Hebrew names may come through mangled);
  - the export is **1st-degree connections only**.
- **`<client-slug>-network-icp.md`** — see above.
- **Airtable base** (client BYOK) with (at least) a "LinkedIn Network" table and a "Dream 100" table, and
  somewhere to hold suppression state (`last_contacted` on the row is enough — a separate table isn't
  required).
- **Send cap** — default 20-25/day (per client policy) — and who owns the **warm-DM route** for
  already-connected contacts (typically the connected consultant on the account).

## Part 1 — Batch qualifier (file-drop, one-shot; re-run on a periodic refresh e.g. bi-weekly)
Triggered by dropping a fresh `Connections.csv`. Fans out pre-filter + enrich + deep-screen, writes Airtable.

**0 — Ingest.** Read the CSV — LinkedIn's own export already carries `First Name`, `Last Name`, `Company`,
`Position`, `Connected On`, and (where allowed) `Email Address`. No enrichment call needed to get this far.

**1 — PREFILTER: title/function match** *(free — no LLM call needed for the obvious cases)*
Apply the network-ICP doc's title/function rules to the `Position`/`Company` columns you already have.
Drop clear non-fits (e.g. wrong function entirely) before spending anything downstream. For ambiguous
titles, either judge inline (small N, interactive) or dispatch `hyreflow_agent.infer` at scale (thousands
of rows, headless) — same free-vs-metered split as [`qualify-against-icp.md`](qualify-against-icp.md) Step 2.

**2 — ENRICH: candidate → full profile** *(metered; the `email_enrichment` waterfall)*
Run the **email-enrichment waterfall** (order in `reference/waterfalls.json`) scoped by
whatever identifier the row carries — `linkedin_url` if the export includes it (preferred: Lusha/Prospeo
both accept it directly), else `first_name`+`last_name`+`company_name` (Lusha's documented fallback shape).
This fills in the fields the raw CSV lacks (current title/company if stale, LinkedIn URL, verified
email/phone) that the deep screen and the Dream 100 dedupe both need.

**3 — DEEP SCREEN: binary verdict vs the network-ICP doc** *(metered AI at scale — `hyreflow-agent`)*
`hyreflow_agent.infer` with `prompts.json` → **"Deep screen contact against Network ICP (binary)"**, feeding
the enriched profile + the network-ICP doc's full screening criteria and exclusions. **The verdict is
binary (`in`/`out`) with a `reasoning` string — never a numeric score.** This is a deliberate constraint
from the brief: a scored network invites gaming/drift ("everyone's a 72"); binary keeps the bar honest.

**4 — LOAD: Airtable "LinkedIn Network"** *(client BYOK REST — no dedicated Hyreflow adapter yet)*
Upsert one row per screened contact: `profile_url`, enriched profile fields, `icp_verdict` (`in`/`out`) +
`reasoning`, `connection_status` (`already_connected` for everyone from this export — that's the whole
point of Part 1; new candidates surfaced later by Part 2 may be `not_connected`). There's no dedicated
Airtable adapter in this stack today — write via Airtable's own REST API using the client's base/table id
and API key (BYOK). If a client wants a first-class adapter, note the gap; don't fabricate one.

## Part 2 — Dream 100 build (one-shot + idempotent refresh)
A **`people_search` waterfall** run, layered by the network-ICP doc's sub-segment definitions (e.g. run one
pass per segment: PE operators, CEO/hiring-manager, podcast guests — whatever the doc defines), same
provider order the waterfall already walks (`reference/waterfalls.json`). **Cross-layer dedupe on
`profile_url`** so a contact matching two segments doesn't get two rows. For every target, **cross-reference
`connection_status` against the "LinkedIn Network" table from Part 1** — a target who's already a
1st-degree connection gets `connection_status = already_connected` (and, per Part 3, routes to the warm-DM
path, never the cold-invite path). Write/refresh the Airtable "Dream 100" table: `company`/`person`,
`sub_segment_layer`, `connection_status`, `engagement_score` (seeded blank, Part 3 fills it),
`last_contacted` (blank until first contact).

## Part 3 — Weekly sweep (scheduled agent skill; headless up to the draft)
Reads the Dream 100 table, refreshes activity, scores, researches the top 10, drafts invites. **Nothing
sends** — this stage's output is staged drafts, full stop.

**0 — SUPPRESS, first, always.** Before anything else, join the Dream 100 against `last_contacted`: exclude
any row contacted within the last 90 days. **This must run at the START of every sweep, not as a later
filter** — a sweep that scores/ranks before suppressing will re-surface someone you just DM'd, which burns
trust fast. Suppressed contacts become re-eligible automatically once 90 days elapse (no action needed,
just don't exclude them past that window).

**1 — REFRESH: 7-day activity.** For the surviving Dream 100 rows, pull a lightweight refresh via the same
enrichment path as Part 1 Step 2 (`email_enrichment` waterfall scoped by `profile_url`) to catch a recent
title/company change — and **verify the returned name matches the target** before trusting the row (a dead
or reassigned handle can return a stranger's data with no error).

**2 — SCORE: engagement.** Combine recency signals (7-day activity, `last_contacted` recency, sub-segment
priority from the ICP doc) into an `engagement_score` per row — deterministic scoring/ranking, no LLM
needed here (this is glue, not judgment; keep it free).

**3 — TOP-10 shortlist.** Rank by `engagement_score`, take the top 10.

**4 — RESEARCH: news/funding on the shortlist** *(paid — Exa, per request)*
For each of the 10, run [`provider-playbooks/exa.md`](../provider-playbooks/exa.md)'s research agent for
recent news/funding/company-signal context — the hook the invite draft will reference.

**5 — DRAFT: personalised invite, client voice** *(metered AI — `hyreflow-agent`)*
`hyreflow_agent.infer` with `prompts.json` → **"Personalised LinkedIn invite draft (client voice)"**,
feeding the profile, the Exa research hook, and the network-ICP doc's message archetypes/voice. LinkedIn
connection notes cap at 300 characters — enforce that in the schema, not just the prompt wording.
**Already-connected targets skip this step entirely** — see the warm-DM branch below.

**6 — STAGE in Airtable.** Write the 10 drafts back (one per Dream 100 row) with `status = staged`,
ready for human review — never auto-queued to send.

**7 — HUMAN SEND — the hard gate.** A human reviews and sends each invite manually; **no LinkedIn send
automation, ever.** Enforce the 20-25/day cap **at this staging step**, not merely as guidance: count
today's already-sent rows (`status = sent` with today's `last_contacted`) and cap how many of the 10 you
hand to the human today at `send_cap − already_sent_today` — don't stage more than the day's remaining
budget, even though the click itself is always manual.

**8 — SUPPRESS on send.** The moment a human marks a row sent, set `last_contacted = today` — that's what
Step 0 of next week's sweep reads.

**Already-connected branch (warm-DM route, not the invite path):** a Dream 100 row with
`connection_status = already_connected` never gets an invite draft (you're already connected — there's no
connection to send). Instead it routes to a **warm DM through the connected consultant** — same research
(step 4) feeds a DM opener instead of an invite note, staged the same way, sent by the same human gate.

## Gates (apply in order)
- **ICP gate before enrich** (Part 1: pre-filter before Step 2's paid enrichment call) — never pay to
  enrich a contact the title/function filter would have dropped for free.
- **Deep screen is binary, never numeric** (Part 1 Step 3) — `in`/`out` + reasoning, full stop.
- **Suppression runs FIRST in every sweep** (Part 3 Step 0) — before scoring, before ranking, before
  anything else touches the Dream 100 rows.
- **Send cap enforced at the staging step** (Part 3 Step 7), not just documented as a policy — count
  today's sends before deciding how many drafts to hand the human.
- **Already-connected → warm-DM, never the invite path.**
- **Human send is the hard gate** — this recipe automates research and draft generation, never the send.
- **Credit & approval gate** before any full paid run: pilot Part 1 on a handful of rows end-to-end, post
  the 4-section approval message, run the rest only on approval. See SKILL.md "Credit & approval gate".

## Cost shape (where credits go)
| Step | Metered? |
|---|---|
| Part 1.1 prefilter | free (small N) or AI tokens at scale |
| Part 1.2 enrich (email_enrichment wf) | metered (first hitting provider) |
| Part 1.3 deep screen | metered (hyreflow-agent tokens, per row) |
| Part 1.4 load | free (client's own Airtable) |
| Part 2 Dream 100 build | metered (people_search waterfall, per layer) |
| Part 3.0 suppress / 3.2 score / 3.3 rank | free (deterministic glue) |
| Part 3.1 refresh | metered (email_enrichment waterfall) |
| Part 3.4 research | paid (Exa, per request — a broader ask costs more) |
| Part 3.5 draft | metered (hyreflow-agent tokens) |
| Part 3.6-8 stage/send/suppress | free (Airtable + human action) |

## Failure modes & health checks
| Watchpoint | Fails how | Health check |
|---|---|---|
| Dead/reassigned LinkedIn handle | the enrich step returns a stranger's data, no error | verify the returned name matches the target before trusting the row (Part 3 Step 1) |
| Enrichment/AI credit drain | the batch stalls mid-run silently | check balance before each run; alert if it drops below a threshold mid-batch |
| Network-ICP too loose | deep-screen filter-out rate drops below ~70%, the resulting list looks like a pass but is junk | flag any batch under 70% filtered as an **ICP problem**, not a clean run |
| Suppression not applied | the weekly sweep re-surfaces someone just contacted, burns trust | assert the suppression join runs at the **start** of every sweep (never later) |
| Connect-cap breach | more than 20-25/day sent, puts the account at risk | enforce the cap at the human-send staging step, not just in written guidance |

## Output
A scored **LinkedIn Network** table in Airtable (every screened connection, binary verdict + reasoning),
a maintained **Dream 100** table (layered by sub-segment, warm-flagged), and — every week — a pack of 10
targets each with fresh research and a personalised invite (or warm-DM) draft staged for human send.

## Graduating to a workflow (Model B)
The weekly sweep is the natural candidate for a saved **cloud workflow** with a **cron trigger** (e.g.
`{"type":"cron","cron":"0 7 * * 1"}` for Monday 7am, matching the brief's schedule) — freeze Part 3 into a
pinned, headless pipeline once the client is happy with it running unattended. The batch qualifier
(Part 1) and Dream 100 build (Part 2) stay agent-composed, file-drop/on-demand runs — they're not the
recurring piece.

## Notes
- **No dedicated Airtable adapter in this stack today** — Parts 1/2/3 write via Airtable's own REST API
  under the client's own key (BYOK), same convention as any other client-owned destination this skill
  doesn't have a first-party adapter for. Don't invent `airtable.*` method calls; note the gap if a client
  wants it formalized into a real adapter.
- **No LinkedIn send automation, ever** — the sold guarantee is draft generation, not sending. Every
  headless step in this recipe stops at a staged draft.
- The network-ICP doc and the company-level `ICP.md` are **separate files** even for the same client —
  one screens companies (firmographic fit), this one screens **people** (LinkedIn network fit). Don't
  collapse them; a client may run both recipes at once.
