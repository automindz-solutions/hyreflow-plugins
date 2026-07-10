# Recipe: Tradeshow exhibitors/speakers → company map → ICP → hiring manager → pre-conference soft intro

**A BD play** (selling your recruiting services), triggered by a shared event. The client gives a
**public event page** (no login); the agent maps the **exhibitor** list and/or the **speaker** list,
qualifies the companies against the client's ICP, finds the hiring decision-maker at each, and drafts a
**soft pre-conference intro** ("we'll be at `<event>` — coffee at your booth?") to be top-of-mind before
the show.

> Scope: **exhibitors and speakers** (two routes; attendee lists are usually login-gated → out for now).
> Same shape as [`funding-to-bd.md`](funding-to-bd.md), with the event as the signal instead of funding.
> - **Exhibitor route:** a company → find the decision-maker at it.
> - **Speaker route:** a named, usually senior person (with a talk topic) → often the decision-maker
>   *themselves*; the talk is a strong, specific outreach hook.

## Channel (hard rule)
BD → **work email** end to end (`email_enrichment` waterfall). Not a candidate flow.

## Output dir (set up first)
`clients/<client-slug>/runs/tradeshow-<event-slug>/` (or `<cwd>/hyreflow-runs/tradeshow-<event-slug>/`).
Never write to `%TEMP%` or inside the skill. Outputs UTF-8 (BOM for Excel).

## Capability chain
```
event URL (+ name + date) → CRAWL + EXTRACT exhibitors &/or speakers (firecrawl) → RESOLVE domains
  → QUALIFY vs ICP → FIND decision-maker (speaker may BE the contact; else company-scoped people_search,
    size-adaptive) → ENRICH work email (waterfall) → PRE-CONFERENCE soft-intro sequence (talk hook for
    speakers) → output: qualified company map + contact + outreach message
```

---

## STEP 1 — Ingest + locate the list(s)
Take the **event URL**, **event name**, **event date** (drives outreach timing), and which **route(s)** the
client wants: **exhibitors**, **speakers**, or both. `firecrawl.map` the site to find the directories —
exhibitors (`/exhibitors`, `/aussteller`, `/exhibitor-list`) and/or speakers (`/speakers`, `/agenda`,
`/programme`, `/referenten`), often paginated. If the client gives exact list URLs, skip the map.

## STEP 2 — Crawl + extract
`firecrawl.scrape` (single page) or `firecrawl.crawl` (paginated directory) with a structured extract.
Firecrawl renders JS and follows pagination. **Public pages only** (the client's constraint) — respect the
event's robots.txt / ToS; if a list forbids scraping or isn't machine-readable (image-only/PDF), **flag it,
don't guess**. Extraction schemas:
```json
{ "exhibitors": [ { "company_name": "", "profile_url": "", "website": "", "booth": "", "blurb": "" } ] }
{ "speakers":   [ { "name": "", "title": "", "company": "", "talk_title": "", "profile_url": "" } ] }
```
For speakers, capture the **talk title/topic** — it's the outreach hook in Step 7.

## STEP 3 — Resolve domains + dedup
For exhibitors listed by name only (no website), resolve the official domain via `serper`/`exa`
(company name → primary domain; lowercase, no www/path). **Dedup** — exhibitors are often listed multiple
times (by hall, category, sponsor tier). Keep one row per company with its best domain.

## STEP 4 — Qualify vs ICP  (the gate — free, runs first)
Follow [`recipes/qualify-against-icp.md`](qualify-against-icp.md): hard firmographic filters on the data
you already scraped (free) → LLM fuzzy-fit against the client's `ICP.md`. **Model A — runs on the
customer's Claude, no credits.** Gate **before** any paid enrichment — exhibitor lists are large and noisy,
so this is where most of the list falls away and where you avoid paying to process non-fit companies.

## STEP 5 — Find the decision-maker  (company-scoped, size-adaptive)
**Speaker route shortcut:** a speaker is usually a named, senior person — if their title is itself a
relevant decision-maker / hiring owner for the client's specialty (e.g. VP Engineering, CFO, Head of
People, founder), **target them directly** (skip the search; go straight to Step 6 to enrich their work
email). Only fall back to a company search if the speaker is too junior/irrelevant. Either way you keep
their **talk** as the Step-7 hook.

For each **qualified** company (exhibitor route, or speaker fallback), company-scoped `people_search` (pass name + domain + company_linkedin so
each provider scopes correctly; `finding-companies-and-contacts.md`). Target = whoever owns hiring / buys recruiting:
- **Head of Talent Acquisition / HR Director / Head of People** (the universal buyer), **plus**
- the **hiring department head derived from the client's specialty** (client recruits engineers → + VP
  Engineering / CTO; finance → + CFO / Head of Finance; sales → + VP Sales), **plus**
- **Founder / GF / CEO** at small companies.
- **Size-adaptive** by the **client's configured size buckets** (same table as cv-to-jobs Step 6 — small →
  GF/founder + function head; mid → HR head + function head + GF fallback; large → HR head + function head;
  thresholds are per-client config, not hardcoded). Reporting-line-first if a public org signal names the owner.

## STEP 6 — Enrich work email  (BD channel)
`email_enrichment` waterfall for the decision-maker's work email. **Over-provision → filter** (contact
search misses ~15–20%, the email waterfall ~5–10%): pull ~1.4× the target, deliver the complete rows, drop
the rest — don't chase missing contacts. Verify with `enrichley` if needed (`catch_all_safe` is usable).

## STEP 7 — Output: pre-conference soft-intro sequence
Generate with `prompts.json → "Pre-conference soft-intro sequence (exhibitor/speaker BD)"` — a 2-touch
sequence returned as `{subject, email1, email2}`, **context-tied** to the shared event:
- **Hook** — speaker route: reference their **talk/topic** specifically ("saw you're speaking on `<talk>`
  at `<event>`…"); exhibitor route: reference that they're exhibiting.
- **Email 1 (now):** the hook + one line on why relevant to the client's specialty + a soft ask (coffee /
  drop by / catch you after your session). No hard pitch.
- **Email 2 (day before / at the event):** short nudge — booth `<booth>` (exhibitor) or "catch you after
  your session" (speaker); omit cleanly if unknown.

Deliverable per row: **qualified company → domain → contact (name · title · LinkedIn · work email) →
booth/talk → the soft-intro message.** No CRM write unless asked.

---

## Tools (all exist) & new bits
| Step | Tool | Status |
|---|---|---|
| Map/crawl/extract | `firecrawl` (map · scrape · crawl · extract) | ✅ |
| Domain resolve | `serper` / `exa` | ✅ |
| Qualify | ICP gate (agent reasoning, Model A) | ✅ |
| Decision-maker | company-scoped `people_search` | ✅ |
| Work email | `email_enrichment` waterfall (+ `enrichley` verify) | ✅ |
| Outreach | `prompts.json` soft-intro prompt + `hyreflow_agent` | **new prompt** |

→ Net-new = the extraction schema (above) + the soft-intro prompt. Everything else is recomposition.

## Gates & caveats (honest)
- **Public exhibitor pages only**; respect robots/ToS — some events forbid scraping. Login-gated attendee
  lists are out of scope for this recipe.
- **Extraction varies** (JS, pagination, PDFs, iframes, image-only lists) → firecrawl handles most; flag and
  stop if a list isn't machine-readable rather than fabricating exhibitors.
- **Domain resolution** is imperfect (name→domain ambiguity) → verify before enrichment.
- **Timing** — run with enough lead time before the event date; the soft intro is worthless after the show.
- **Company-scoping** is weak for tiny/obscure exhibitors (the cv-to-jobs caveat) → verify those manually.
- **Spend** — qualify gate first; pilot one exhibitor through Steps 5–6 before the full run.
- **BD/GDPR** — B2B work email, legitimate-interest context, pilot-first per the Credit & approval gate.
