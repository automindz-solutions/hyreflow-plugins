# Recipe — Layoff signal → poach displaced talent (+ BD)

**Use when:** the trigger is *"a company is cutting staff."* Either a **broad sweep** ("who laid off in the
last 7 days?") or a **targeted employer** ("Microsoft just announced layoffs — get me the displaced
engineers"). A layoff = a pool of available candidates to poach **and** a BD opening with the survivors.

> **What's next + why:** this is the **passive-poach** branch (displacement trigger). See
> [`../recruiter-craft.md`](../recruiter-craft.md) §B + §A recruitability signals for who to approach first.

Powered by the **`layoffsignal`** Hyreflow Native (free public news RSS) → fan into the standard
sourcing pipeline. The native is **free (0 credits), no BYOK** (see `references/provider-precedence.md` — natives
are exempt from the waterfall).

## Where this runs (Model A)
The **extraction + dedupe + qualification is reasoning done by the host agent** — free, no
hosted AI model call. Credits are spent only on the downstream enrichment of *passes only* — the feed pull itself is free.

## Inputs
- Mode: `broad` (whole market) or `targeted` (one or more named employers).
- `when` window (default `7d`; `30d` for a named company).
- The client's `ICP.md` (for the qualify gate) — per-client data, not in this skill.

## Step 1 — Sweep the feeds (`layoffsignal`, native — free)
```bash
hyreflow tools execute layoffsignal layoff_news --payload '{"when":"7d"}'                 # broad sweep
# targeted:   hyreflow tools execute layoffsignal layoff_news --payload '{"company":"Microsoft","when":"30d"}'
# full stream: hyreflow tools execute layoffsignal iter_layoff_news --payload '{"when":"7d","companies":["Microsoft","Meta"]}'
# clean DIRECT links for curated outlets: hyreflow tools execute layoffsignal site_feeds --payload '{}'
```
Each item → `{title, link, source, published, summary}`. Links from `google_news`/`layoff_news` are Google
News **redirector** URLs; `site_feed()` links are clean/direct.

## Step 2 — Resolve + fetch article bodies (`firecrawl`)
For each item, get the real article text. `firecrawl` follows the redirector and returns the body
(more reliable than `resolve_link()` for the encoded Google News links). Skip paywalled fetches; keep the
headline+source as the minimal signal.

## Step 3 — Extract structured rows (host agent, free — Model A)
From each article, the agent extracts:
`{company, headcount, pct, date, location, function/dept (if stated), source_url, source_publisher}`.
Articles are often vague ("hundreds") — record the raw phrasing; don't fabricate a precise number.

## Step 4 — Dedupe + normalize (code, free)
Collapse multiple articles about the **same event**: key on `(normalized company, ~date)`. Keep the most
specific headcount and the best source. Output one row per layoff event.

## Step 5 — Resolve company → source affected roles
- Resolve company → domain (`builtwith.company_to_url`, or known domain).
- **Qualify the company vs `ICP.md`** if this is BD (`recipes/qualify-against-icp.md`).
- Source the displaced people by function:
  - **Engineering/IT →** `github` (search users by company/location/language; `find_user_emails`).
  - **Everyone else →** `apollo` / `aiark` people-search at that company (recently-departed if available),
    walking the `people_search` provider order.

## Step 6 — Enrich → verify → outreach

> 🎯 **Channel decision — ASK THE USER before enriching.** This is **candidate acquisition**, so the
> default is **LinkedIn + personal email ONLY — never work email** (you're recruiting them *away* from
> that employer; their work inbox is wrong and often dead post-layoff). Prompt: *"Personal email +
> LinkedIn only (recruiting default), or also include work email?"* The answer picks the waterfall:
> - **personal (default)** → **`leadmagic`** (`personal_email_finder`) → **`fullenrich`** (`contact.personal_emails`) → **`wiza`** (`start_individual_reveal`, `email_options.accept_personal`) — the personal-email providers + GitHub `find_user_emails` for engineers. ⚠️ do NOT use prospeo/aiark/bettercontact for personal (work email only).
> - work (only if user opts in, e.g. BD) → `email_enrichment` (work) order.
>
> **LinkedIn is the first/primary touchpoint** — we almost always already have it from people-search, so
> it needs no enrichment. Personal email is the second channel when found. SourceWhale is multichannel →
> one cadence fires a **LinkedIn touch + an email touch** on the same candidate (utilize both).

Standard tail: personal-email/phone **waterfall** (per the channel decision above) → validate (`enrichley`)
→ sequence (`sourcewhale` for recruiting / `lemlist` / `instantly`) → land in the client's ATS.
**Approval-gate** the first send + any bulk enrichment (one-record pilot first).

> ⚠️ **SourceWhale prerequisite — no create-campaign API.** Before pushing candidates, **tell the user they
> must create the campaign + message steps manually in the SourceWhale app, and wait for confirmation**;
> then resolve its id via `list_campaigns`. Never attempt to create a campaign via API. (See `provider-playbooks/sourcewhale.md`.)

## Pipeline
```
layoffsignal (native) → fetch (firecrawl) → extract (host agent) → dedupe
   → [qualify vs ICP, if BD] → source (github | apollo/aiark) → enrich → verify → sequence → ATS
```

## Guardrails
- **ToS / attribution.** The native surfaces *facts from public reporting* — attribute the originating
  publisher; never republish article text or resell a curated dataset. Signal/trigger use only.
- **Don't fabricate headcounts.** Keep the source's own wording when imprecise.
- **Recall caveat.** An automated sweep won't catch everything a manual tracker does — tune the query
  terms (`LAYOFF_TERMS`) and the curated `DEFAULT_SITES` over time; widen `when` for thoroughness.
- **Spend.** The native costs credits per pull; enrichment costs credits per record — pilot small.
