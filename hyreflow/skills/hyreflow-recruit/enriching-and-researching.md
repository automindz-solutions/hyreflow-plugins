# Enriching (contact + research stage)

**L2 phase doc.** How to run the *enrichment* stage well — turn a list of people into rows with usable
**email / phone / LinkedIn / context**. Sits between [`references/provider-precedence.md`](references/provider-precedence.md)
and the `recipes/`. Read before any enrichment.

> Already have the contact data a provider would return? **Don't re-enrich it** — wasted credits.

## The one mental model
Everything is **one canonical `Person` → a per-capability waterfall → the best value, first-hit**. You never
hand-shape each provider's payload; the waterfall maps the canonical record to each provider and stops at the
first real result.

```
Person = { linkedin_url, first_name, last_name, full_name, company_name, company_domain, email, phone }
```
Run it: `POST /enrich/email_enrichment` (engine) — body `{rows:[Person, …]}`. On this capability the
output row also carries `company_match` (whether the returned address checked out against the employer)
and `company_match_basis` (`company_domain` or `company_name` — which one it was judged on).

**Many people ⇒ ONE call, not a loop.** Hand the whole list over at once:
```bash
hyreflow tools execute personal_email --rows @candidates.json      # up to 100 rows; JSON, @file or -
```
On MCP, call `hyreflow_tools_execute` once with the whole array:
```json
{"tool":"email_enrichment","rows":[{"first_name":"Jane","last_name":"Doe","company_domain":"acme.example.com"}]}
```
Use `email_enrichment` for BD work emails and `personal_email` for candidates.
The engine walks the chain **stage-major** (every row through provider 1, the leftovers through provider 2,
…) and batches at the provider where it can — FullEnrich takes all still-pending rows as **one job with one
poll loop** instead of one ~50s job per row, so 12 or 100 candidates finish in roughly the time a single
row takes.
First hit still wins per row; billing is still per row (hits only). Looping `tools execute … --payload`
over rows one at a time throws that away. A row that comes back `still_enriching` carries `job_id` +
`resume` and **ends its chain there** — no further provider is tried. The job is persisted and settles
server-side on its own; run the printed resume command any time to check it sooner (polling is free; a
finished job bills each revealed row once); never resend the row (that starts a second, billed job). It
usually settles within 1–2 minutes — check it every 20–30 seconds rather than waiting minutes between
checks. If it settles with no result, the later providers in the chain were never tried for that row;
continue the chain yourself with the next provider (see
[`references/provider-precedence.md`](references/provider-precedence.md)).

**Identifier rule:** `linkedin_url` alone works, OR `first_name + last_name + company_domain` (no
LinkedIn needed). Common aliases are folded in automatically — `domain`→`company_domain`,
`company`→`company_name`, `name`→`full_name` — so a `{first_name, last_name, domain}` row enriches fine.
If a row truly lacks a usable identifier the step returns `no_identifier` with a `needs` hint naming the
missing fields.

## Pick the channel FIRST (this decides the waterfall)
- **Candidate acquisition → `personal_email` + LinkedIn. NEVER work email.**
- **BD / selling to companies → work email → `email_enrichment`.**
- **Employment history — past employers, "has worked at a startup", anything you're about to SCORE on →
  `linkedin_profile`.**
  `POST /enrich/linkedin_profile` / `hyreflow tools execute linkedin_profile --payload '{"linkedin_url":"…"}'` —
  one row per profile, answer lands in `profile` (`experience[]` = company/title/start/end/is_current, plus
  `duration_months`/`description` and `headline`/`about`/`skills`/`certifications`/`education` from the
  providers that carry them, newest first) instead of `email`. **This is the step that runs BEFORE
  qualification/scoring**, not after: a sourcing row carries only the current title, employer and location, and
  `/qualify` refuses a batch in which no row has work history. A provider answer with no employment history
  counts as a miss — it costs nothing and the waterfall moves on. **Enrich each profile once and carry it on the
  row:** a step that also serves the work-email chain charges its per-result rate on both capabilities, so
  re-running `linkedin_profile` over rows that already hold a `profile` pays for it twice.
  ⚠️ Never hand-pick a raw scraper actor for this: Apify is BYOK-only
  and its spend is invisible to your credits, the spend cap and the approval gate.
- ⚠️ prospeo / aiark / lusha / **bettercontact** are **work-email only** — never use them for candidate/personal
  *email* flows, and never as a "fallback" when the `personal_email` waterfall comes up short (a
  `spending_cap_reached` shortfall, or a `still_enriching` job that is still running, is *retry later*, not
  *find another provider*). A `still_enriching` job that has since **settled empty** is different — pick up
  with the next provider in the `personal_email` chain itself, never a work-email one.
  (prospeo/aiark/lusha/hyreflow_native *profile* answers carry no contact detail, so `linkedin_profile` is safe for candidates.)
- House order for every waterfall lives in `reference/waterfalls.json` — never restate it here.

## Per-provider input is auto-mapped (the canonicalization)
Each provider wants the identifier in a different field/shape — the waterfall translates one `Person` to all of them:
| Provider | Wants | Sync/async |
|---|---|---|
| prospeo | `data:{linkedin_url}` | sync |
| lusha | `linkedin_url=` (kwarg) | sync |
| wiza | **`profile_url`** (not linkedin_url) | async (start→poll) |
| fullenrich | `datas:[{…}]` (batch) | async |
→ You just provide whatever `Person` fields you have; pass **linkedin_url** when you can (highest hit-rate).

## Run discipline
- **First-hit wins.** Walk the order; the first provider that returns a real email stops the chain. On a miss,
  fall through to the next **for that row** (a single `UNAVAILABLE` is a miss, not a stop).
- **Charge only on result.** A miss / empty / "no result" charges **0** — only a real hit bills. (Soft misses like
  HTTP-200-with-empty-body are treated as 0, not billed.)
- **Skip on no key / error** — a provider without a key (or erroring) is skipped, chain continues.
- **A cap is not a miss.** When the workspace spending cap stops a provider mid-batch, the affected rows
  record `outcome: "skip", detail: "spending_cap_reached"` AND the response carries a
  `_meta.warnings[]` entry with `code: "spending_cap_reached"` (rows affected + providers skipped). Read
  that as "retry after the cap is raised/rolls over" — the rows were never asked, so a lower hit count
  says nothing about coverage and is NOT a reason to reach for a different (work-email) provider.
- **Count-before-pay + over-provision ~1.4×.** Coverage is a property of the person — a bare profile / tiny-co
  contact has near-zero coverage everywhere. Deliver the best **N complete** rows; drop the incomplete.

## Verify deliverability (before any send)
- `enrichley.validate_email` → **`catch_all_safe` is usable** (send it); only `undeliverable` / `catch_all_not_safe`
  are unusable. Drop those; keep verified + catch_all_safe.

## Provider quirks (rest in each `provider-playbooks/<tool>.md`)
- **BetterContact** — **BD / work-email flows only.** Not part of any waterfall; on an `email_enrichment`
  (work-email) run you may call it directly (`bettercontact_start_enrichment`) when single-provider
  finders miss. It returns **work** addresses (`data[].contact_email_address`) — never use it on a
  candidate / `personal_email` pipeline, whatever the waterfall's hit rate was. Batch + async; ~30–40s to
  terminate; `_status:"deliverable"` marks a usable hit. The engine stamps `_meta.channel: "work_email"`
  + a `work_email_only` warning on its responses as a reminder.
- **Prospeo** — sync, fast; returns `person.email.{email,status}`; status `UNAVAILABLE` = real miss → fall through.
- **Wiza** — async (`data.status` finished/failed); consumes **api_credits** (separate from email_credits — keep topped up).
- **FullEnrich** — async batch; needs `FULLENRICH_API_KEY`. **Personal-email** channel.
- **Lusha** — sync; can return HTTP-200 with an error body on no-match (counts as a miss, charges 0).

## Research / context (beyond contact)
For company/person *context* (not just contact): use the AI step `hyreflow_agent.infer` (structured output via
a `prompts.json` template) or `exa`/`firecrawl` for grounded web data. Deterministic facts you already have →
never spend an AI/enrich call on them.

## Gates
- **Channel rule** (candidate=personal+LinkedIn, BD=work) — non-negotiable.
- **Credit & approval gate** for the full run (pilot one row end-to-end → approval → full). See SKILL.md.

## Hand-off
Enriched + verified rows → qualify (ICP) → **[`writing-outreach.md`](writing-outreach.md)** (personalize + sequence).
