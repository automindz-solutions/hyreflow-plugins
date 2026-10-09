# Recipe: People from a webpage → roster → LinkedIn → enriched profiles

**Trigger**: the user hands you a URL that *already lists the people* and asks you to pull them off it —
a team / about / leadership / "our people" page (e.g. `https://acme.example.com/meet-the-team/`), a
speaker or committee list, a member directory, an award or "40 under 40" list. The roster is *on the
page*; you are not searching for it.

**The rule: do not open with `people_search`.** The waterfall answers "find people matching criteria
across the databases" — a different question from "read the people printed on this page". **The page is
the source of truth for who is on it**; the databases are stale or thin for exactly the small/owner-led
firms whose team pages people paste.

```
page URL → SCRAPE / EXTRACT the roster (firecrawl) → FILL what the page omits (exa_agent: LinkedIn URL)
→ ENRICH for work history / sector experience (linkedin_profile waterfall) → dataset
```

Provider details: [`../provider-playbooks/firecrawl.md`](../provider-playbooks/firecrawl.md) ·
[`../provider-playbooks/exa.md`](../provider-playbooks/exa.md).

## Step 1 — firecrawl owns the page
`firecrawl_scrape` for a single page (returns markdown, 0.1 credit per page). `firecrawl_extract` with a
JSON schema when you want the roster back as structured rows, or when the roster spans several URLs
(departmental/paginated team pages — `firecrawl_map` to enumerate them first, 0.1 credit per call).
`firecrawl_extract` is LLM extraction billed on usage, not a fixed per-request fee — check the
`_meta.credits_charged` on the result before running it across many pages. Take name + job title **as printed** —
the page's own title is more current than a database's.

```bash
hyreflow tools execute firecrawl_scrape --payload '{"url":"https://acme.example.com/meet-the-team/","formats":["markdown"],"only_main_content":true}'
```

```bash
hyreflow tools execute firecrawl_extract --payload '{
  "urls":["https://acme.example.com/meet-the-team/"],
  "schema":{"type":"object","properties":{"people":{"type":"array","items":{"type":"object","properties":{"name":{"type":"string"},"job_title":{"type":"string"}},"required":["name","job_title"]}}},"required":["people"]}
}'
```

## Step 2 — exa owns what the page omits
Most team pages print name + title and nothing linkable. For the LinkedIn URL (or any field the page
lacks), run **one** `exa_agent` over the Step-1 rows — pass them through `input.data`, bound the output
with an `outputSchema`, and poll with `exa_agent_get`. Do not fire one search per person.

```bash
hyreflow tools execute exa_agent --payload '{
  "query":"Find the LinkedIn profile URL for each person provided.",
  "input":{"data":[{"name":"Jane Smith","job_title":"Head of Operations"}]},
  "effort":"low",
  "outputSchema":{"type":"object","properties":{"people":{"type":"array","maxItems":25,"items":{"type":"object","properties":{"name":{"type":"string"},"linkedin_url":{"type":"string","format":"uri"}},"required":["name","linkedin_url"]}}},"required":["people"]}
}'
hyreflow tools execute exa_agent_get --payload '{"run_id":"agent_run_01j..."}'
```

## Step 3 — what the page cannot tell you
Job title comes off the page; **core sector / domain experience does NOT** — a team-page bio is
marketing copy, not a work history. Get it from the enriched profile (the `linkedin_profile` waterfall /
enrichment) once you have the LinkedIn URL — see
[`../enriching-and-researching.md`](../enriching-and-researching.md). Never infer a person's sector
experience from a team-page blurb.

## Scope guard
This recipe is about which path you *enter* when a URL is already in hand. It does **not** change the
`people_search` waterfall's own retry rules, and `people_search` remains the default for every
query-shaped sourcing ask ([`../finding-companies-and-contacts.md`](../finding-companies-and-contacts.md)).
If the page turns out to list nobody (a stock-photo or "contact us" page), fall back to a company-scoped
`people_search` on that domain.

A page that lists **companies** rather than people (exhibitor list, portfolio page) is a different play —
[`tradeshow-to-bd.md`](tradeshow-to-bd.md).
