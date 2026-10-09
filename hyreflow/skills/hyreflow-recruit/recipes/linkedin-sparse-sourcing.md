# Recipe: LinkedIn-sparse roles → employer pages → Impressum → enriched contacts

**Trigger**: the role is one where the person rarely keeps (or is findable through) a LinkedIn profile —
blue-collar / trades, chefs and cooks, car mechanics, senior care workers, nurses, doctors, mechanical
engineers, and similar — **or** a `people_search` for the title + region comes back thin/empty. These
people still show up on the employer's own site: a "team" / "about us" / "Über uns" / "Unser Team" page for
a care home, clinic, garage or restaurant. German and other local-registry markets add a second page worth
mining: the mandatory **Impressum**, which names the owner or managing director (Geschäftsführer /
Inhaber).

**How this differs from the other page-first recipe**: in
[`people-from-webpage.md`](people-from-webpage.md) the user already handed you the roster URL. Here you
don't have a URL yet — you have to **find the employer, then find its team/about page**, before you can
scrape anything.

**US construction/trades**: `search_contractors` → `get_contractor_employees` in
[`../provider-playbooks/shovels.md`](../provider-playbooks/shovels.md) stays the **primary** candidate DB
for that vertical — it returns named staff with personal email + LinkedIn directly, no page-hunting
needed. Use this recipe as the **fallback for construction/trades outside the US**, and as the **primary**
path for the non-construction niche roles above everywhere.

```
people_search (run first, don't abandon it) ∥
find local employers in the region (exa_search / openmart / company_search)
  → resolve domains
  → find each employer's team/about/Impressum pages (firecrawl_map or exa_search)
  → firecrawl_extract names + titles as printed
  → qualify vs role
  → contact: candidate rows → personal_email waterfall; Impressum owner → hiring-manager work email
```

Provider details: [`../provider-playbooks/exa.md`](../provider-playbooks/exa.md) ·
[`../provider-playbooks/firecrawl.md`](../provider-playbooks/firecrawl.md) ·
[`../provider-playbooks/openmart.md`](../provider-playbooks/openmart.md) (local-business search, BYOK).
Identifier and channel rules: [`../enriching-and-researching.md`](../enriching-and-researching.md).

## Step 0 — don't drop `people_search`
Run the normal `people_search` waterfall for the title + region in parallel with (or just before) the
steps below — some of these roles do have a thin footprint in the databases, and it costs nothing to ask
first. This recipe covers what the waterfall structurally can't reach: people who are never in a
people-DB at all.

## Step 1 — find the local employers
Resolve **which** care homes / clinics / garages / restaurants sit in the target region before you can look
at their pages:
- `exa_search` for employer pages in the city/region (e.g. "care homes in Leverkusen", "Autowerkstatt
  München").
- `openmart` `search_businesses` / `search_brands` for local businesses, when the workspace has connected
  its own Openmart key (BYOK) — see the openmart playbook.
- The `company_search` waterfall for a firmographic cut of the same segment (industry + geo).

```bash
hyreflow tools execute exa_search --payload '{"query":"Seniorenpflege Pflegeheim Leverkusen Team","numResults":10,"type":"auto"}'
```

Keep only rows with a resolvable root domain — you need the employer's own site for Step 2.

## Step 2 — find each employer's team / about / Impressum pages
`firecrawl_map` enumerates a site's URLs so you can pick out the ones worth scraping without guessing a
path — filter for team/about/Impressum keywords. `exa_search` scoped to the domain is the alternative when
map turns up nothing useful.

German-language keywords worth matching, alongside the English ones: **Impressum, Geschäftsführer,
Inhaber, Über uns, Unser Team, Team, Mitarbeiter**.

```bash
hyreflow tools execute firecrawl_map --payload '{"url":"https://pflegeheim-example.de","search":"team OR über uns OR unser team OR impressum","limit":20}'
```

## Step 3 — extract names + titles as printed
`firecrawl_extract` across the URLs you kept, one schema, one call per employer (not one call per person).
It's usage-priced — check `_meta.credits_charged` before running it across many employers.

```bash
hyreflow tools execute firecrawl_extract --payload '{
  "urls":["https://pflegeheim-example.de/unser-team","https://pflegeheim-example.de/impressum"],
  "schema":{"type":"object","properties":{"people":{"type":"array","items":{"type":"object","properties":{"name":{"type":"string"},"job_title":{"type":"string"},"page_type":{"type":"string"}},"required":["name","job_title"]}}},"required":["people"]}
}'
```

## Step 4 — qualify before you spend on contact
Title and location come **off the page** — the same rule as `people-from-webpage.md`: don't infer years of
experience or seniority from a bio blurb, it's marketing copy. Keep only rows whose printed title matches
the role you're sourcing for (nurse, cook, mechanic, …) and whose page places them in the target region.

## Step 5 — contact: candidates vs the Impressum owner (different channel)
Once a row carries `first_name + last_name`, the **employer domain** is the lookup identifier for
enrichment — no LinkedIn URL required (see the identifier rule in
[`../enriching-and-researching.md`](../enriching-and-researching.md)).

- **Candidates found on a team/about page** (the nurse, cook, mechanic, care worker themselves) →
  candidate channel: `personal_email` waterfall, plus a LinkedIn search where one exists. Never work email
  for these rows.
- **The Impressum's Geschäftsführer / Inhaber / managing director** → treat as the **hiring manager / BD
  decision-maker**, not a candidate, even when that name also functions as CEO. Small local businesses
  often have the owner as the *only* hiring decision-maker, so this name is frequently your best (and only)
  contact at the employer. Use `email_enrichment` (work email) with name + domain.

```bash
hyreflow tools execute personal_email --rows '[{"first_name":"Anna","last_name":"Schmidt","company_domain":"pflegeheim-example.de"}]'
```

```bash
hyreflow tools execute email_enrichment --rows '[{"first_name":"Markus","last_name":"Weber","company_domain":"pflegeheim-example.de"}]'
```

## Cost notes
- **Count employers before you fan out.** Run one employer end-to-end (find → map/search → extract →
  qualify → enrich) before repeating the play across the rest of the region.
- `firecrawl_extract` is usage-priced, not a flat per-request fee — check `_meta.credits_charged` on the
  result rather than assuming it costs the same as `firecrawl_scrape`.
- Bound `exa_search` with a tight `numResults` — every search is charged, including one that matches
  nothing.
- Public pages only. **Never guess a name off a photo or a PDF** you haven't actually read the text of —
  extract from the rendered page content.

## EEO / privacy
Never filter or screen candidates on protected attributes (age, gender, marital/parental status, and the
like) inferred from a photo or bio blurb — the same hard rule as everywhere else in this skill. Qualify on
job title, location and role fit only.

## Scope guard
If the region turns out to have plenty of `people_search` coverage for the role (a city with strong
LinkedIn presence, an urban clinical role), fall back to the normal waterfall — this recipe is for the gap,
not a replacement for it. A page that lists **companies** rather than people is a different play —
[`tradeshow-to-bd.md`](tradeshow-to-bd.md). A page the user already handed you →
[`people-from-webpage.md`](people-from-webpage.md).
