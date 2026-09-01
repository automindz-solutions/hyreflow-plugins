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
- ⚠️ prospeo / aiark / lusha are **work-email only** — never use them for candidate/personal *email* flows.
  (Their *profile* answers carry no contact detail, so `linkedin_profile` is safe for candidates.)
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
- **Count-before-pay + over-provision ~1.4×.** Coverage is a property of the person — a bare profile / tiny-co
  contact has near-zero coverage everywhere. Deliver the best **N complete** rows; drop the incomplete.

## Verify deliverability (before any send)
- `enrichley.validate_email` → **`catch_all_safe` is usable** (send it); only `undeliverable` / `catch_all_not_safe`
  are unusable. Drop those; keep verified + catch_all_safe.

## Provider quirks (rest in each `provider-playbooks/<tool>.md`)
- **BetterContact** — not part of the `email_enrichment`/`personal_email` waterfalls; call it directly
  (`bettercontact_start_enrichment`) when single-provider finders miss. Batch + async; ~30–40s to
  terminate; email at `data[].contact_email_address` (+ `_status:"deliverable"`).
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
