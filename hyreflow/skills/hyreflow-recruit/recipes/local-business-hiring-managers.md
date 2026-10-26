# Recipe: Openmart local businesses → Impressum decision-makers → verified work email + LinkedIn

**Trigger**: niche local businesses (Kanzleien, Steuerberater, Praxen, Handwerksbetriebe, Pflegedienste,
and similar small firms) in **Germany, Austria or Switzerland** — or any other market where naming the
business owner in a legal notice is mandatory — and the goal is the **decision-makers / hiring managers**
at those businesses, not candidates. Candidates found on the same employer pages stay on the
[`linkedin-sparse-sourcing.md`](linkedin-sparse-sourcing.md) play; finding the businesses themselves in a
market without a mandatory owner-naming notice stays on [`../provider-playbooks/openmart.md`](../provider-playbooks/openmart.md).

**The gap this closes**: the Impressum names the owner/partner reliably, but the page almost always prints
only a **generic shared inbox** (`info@`, `kanzlei@`, `kontakt@`, …) next to that name — never the person's
own mailbox. Putting that shared inbox straight into the person's email field is the single most common
mistake here. This recipe adds the two steps that turn a printed name into a **real, verified work email**:
full name + domain through the enrichment waterfall, and — since the business and the person are both
known — the person's actual **LinkedIn profile**, which is both a deliverable in its own right and the
highest-hit-rate enrichment key once you have it.

```
openmart search_businesses / search_brands (country set) → keep rows with root domain + tracking_id
  → firecrawl_map → firecrawl_extract Impressum + team page (name, title, page_type, printed email/phone)
  → prioritise Geschäftsführer/Inhaber/Partner/Gesellschafter/Praxisinhaber/Kanzleiinhaber
  → generic-inbox rule: shared mailbox → company_email, NOT the person's email
  → work email: lookup_people (domain + name) and/or email_enrichment (first_name + last_name + company_domain)
  → LinkedIn profile resolution: exa_search / serper (name + company + city) → accept only a verified match
  → re-enrich rows still missing an email using the linkedin_url
  → verify every email found OUTSIDE email_enrichment with verify_emails (email_enrichment already verifies its own)
```

Provider details: [`../provider-playbooks/openmart.md`](../provider-playbooks/openmart.md) (search/people/
email field names, async batch lifecycle) · [`../provider-playbooks/firecrawl.md`](../provider-playbooks/firecrawl.md) ·
[`../provider-playbooks/exa.md`](../provider-playbooks/exa.md) · [`../provider-playbooks/serper.md`](../provider-playbooks/serper.md) ·
[`../provider-playbooks/hyreflow_native.md`](../provider-playbooks/hyreflow_native.md) (email verification).
Identifier and channel rules: [`../enriching-and-researching.md`](../enriching-and-researching.md).

## Step 1 — search local businesses in the target market

Openmart's business/brand search is the primary business-finding leg for DACH SMBs. Set `country` and keep
`limit` small until the rows look right (a typo'd location field searches the whole state/country silently
— see the openmart playbook).

```bash
hyreflow tools execute openmart search_businesses --payload '{"query":"Steuerberater","location":[{"country":"DE","state":"Niedersachsen","city":"Oldenburg"}],"has_valid_website":true,"limit":10}'
```

Keep only rows with a resolvable **root domain**, and preserve each business's `tracking_id` so every
later result (Impressum extract, email lookup, LinkedIn match) joins back to the right source row.

## Step 2 — Impressum + team page: name, title, page type, and the printed contact SEPARATELY

`firecrawl_map` enumerates the site so you can pick Impressum/team/about URLs without guessing a path,
then `firecrawl_extract` the pages — one call per business, not one call per person.

```bash
hyreflow tools execute firecrawl_map --payload '{"url":"https://kanzlei-example.de","search":"impressum OR team OR kanzlei","limit":20}'
```

```bash
hyreflow tools execute firecrawl_extract --payload '{
  "urls":["https://kanzlei-example.de/impressum","https://kanzlei-example.de/team"],
  "schema":{"type":"object","properties":{
    "people":{"type":"array","items":{"type":"object","properties":{
      "name":{"type":"string"},
      "job_title":{"type":"string"},
      "page_type":{"type":"string"}
    },"required":["name","job_title"]}},
    "company_email":{"type":"string"},
    "company_phone":{"type":"string"}
  },"required":["people"]}
}'
```

Extract the printed email/phone as **company-level** fields (`company_email`, `company_phone`), separate
from each person's row — never copy the Impressum's printed inbox into a person's `email` field at
extraction time, even before you've classified it (Step 4 does that classification, but the shape has to
keep the two apart from the start).

## Step 3 — prioritise by title

High priority (enrich these first): **Geschäftsführer, Inhaber, Partner, Gesellschafter, Praxisinhaber,
Kanzleiinhaber** — these are the people with hiring authority at a small local firm, often the *only*
decision-maker on staff. Lower-priority titles (associates, Prokuristen without ownership, admin staff) can
wait for a second pass.

## Step 4 — the generic-inbox rule (don't let a shared mailbox become a person's email)

A role/shared mailbox is **not** a person's work email: `info@`, `kontakt@`, `office@`, `kanzlei@`,
`praxis@`, `mail@`, `post@`, `empfang@`, `verwaltung@`, `service@`, `team@`, `buero@`/`büro@`, or any local
part that isn't derived from the person's own name. Treat any of these — and anything you can't tie to a
specific name — as `company_email` only; leave the person's `work_email` empty and run Step 5.

A printed address that **does** contain the person's name (`m.weber@kanzlei-example.de`,
`markus.weber@kanzlei-example.de`) is a personal work email — keep it, but still run it through Step 8
validation before presenting it as found.

## Step 5 — work email from full name + domain

Two routes, either or both:

```bash
hyreflow tools execute openmart lookup_people --payload '{"tasks":[{"domain":"kanzlei-example.de","people":[{"first_name":"Markus","last_name":"Weber"}],"info_access":["EMAIL"]}]}'
```

```bash
hyreflow tools execute email_enrichment --rows '[{"first_name":"Markus","last_name":"Weber","company_domain":"kanzlei-example.de"}]'
```

Before enriching, normalize the name:
- **Umlauts/ß**: ü→ue, ö→oe, ä→ae, ß→ss (a domain's mailbox convention is almost always built off the
  ASCII-folded spelling, even when the printed Impressum name keeps the umlaut).
- **Strip titles/prefixes**: Dr., Prof., RA, StB, von, van, and similar academic/professional/noble
  prefixes don't belong in `first_name`/`last_name` — enrich on the bare given/family name.

`lookup_people` is async like every other openmart batch task (`get_batch_status` → `get_batch_task_ids`
→ `get_task_result`); a name Openmart can't match still completes, with `data: null` — that's a miss, not
an error, so fall through to `email_enrichment`.

## Step 6 — LinkedIn profile resolution

Search for the person's actual LinkedIn profile using full name + company name + city — this is a
deliverable column in its own right, and it's also the single highest-hit-rate identifier for re-enrichment
(Step 7).

```bash
hyreflow tools execute exa_search --payload '{"query":"Markus Weber Kanzlei-Example Oldenburg linkedin","numResults":5,"type":"auto"}'
```

```bash
hyreflow tools execute serper search --payload '{"query":"\"Markus Weber\" \"Kanzlei Example\" Oldenburg site:linkedin.com/in","num":5}'
```

Accept a `linkedin_url` **only** when the profile's name matches AND the profile's company or city/region
matches what the Impressum printed. Never attach a different person's profile just because the name is
common — a mismatch here poisons both the LinkedIn column and the re-enrichment step that follows.
Optionally confirm with `linkedin_profile` (`hyreflow tools execute linkedin_profile --payload
'{"linkedin_url":"…"}'`) before relying on it.

## Step 7 — re-enrich with the LinkedIn profile

For rows still without a personal work email after Step 5, re-run the waterfall with the now-known
`linkedin_url` — it has the best hit rate of any identifier:

```bash
hyreflow tools execute email_enrichment --rows '[{"first_name":"Markus","last_name":"Weber","linkedin_url":"https://www.linkedin.com/in/markus-weber-example","company_domain":"kanzlei-example.de"}]'
```

## Step 8 — verify before you present a found email

An address from `email_enrichment` is already verified — it only comes back if it's safe to send to, so
don't pay to check it again. Every other candidate (an Openmart `lookup_people` email, an address printed in
the Impressum, a pattern guess) goes through the email verifier before you call it "found". Send them all
in one call, then poll:

```bash
hyreflow tools execute verify_emails --payload '{"emails":["markus.weber@kanzlei-example.de","info@kanzlei-example.de"]}'
hyreflow tools execute hyreflow_native_get_verified_emails --payload '{"request_id":"ev_..."}'
```

Only the addresses in `result.emails` are usable. An address listed in `result.catch_all` (the domain
accepts any mailbox) or `result.unknown` (no verdict) can get a second opinion from
`enrichley validate_email` — keep it only if that says it's valid. Every other address is dropped: the row
goes back to "no verified email" rather than presenting an unverified guess. If you ever reason your way to a
pattern guess (`vorname.nachname@domain`) instead of a provider hit, it is acceptable **only** once the
verifier confirms it, and the output must label that row's `email_source` as a pattern guess, not a
provider hit.

## Output columns

`business, domain, city, company_email, full_name, title, priority, linkedin_url, work_email,
email_source, email_status`

## Cost notes

- **Run one business end-to-end first** (search → Impressum extract → prioritise → email → LinkedIn →
  re-enrich → verify) before fanning the play out across a region.
- `firecrawl_extract` is usage-priced — check `_meta.credits_charged`, don't assume it costs the same as a
  single scrape.
- Openmart is **BYOK-only**; `lookup_people` and `lookup_business_email` are async batches — poll, don't
  resubmit while a batch is still processing.
- `exa_search` and `serper search` are each charged per call, including a call that matches nothing — keep
  `numResults`/`num` tight.

## Channel guardrail

Everything here is the **BD / hiring-manager channel** — work email, never personal email. The
Geschäftsführer/Inhaber found through the Impressum is a decision-maker to sell or recruit *into*, not a
candidate, even when the same person also happens to be the firm's most senior practitioner.

## GDPR note (not legal advice)

These are business contacts published in a mandatory public legal notice (the Impressum), processed for
B2B outreach to the business — generally supported under a legitimate-interest basis for this kind of
contact. This is a brief operational note, not legal advice; route a genuine compliance question to the
client's own counsel.

## Scope guard

- The person is a **candidate**, not a decision-maker (a nurse, mechanic, cook on the same team page) →
  [`linkedin-sparse-sourcing.md`](linkedin-sparse-sourcing.md) — personal email + LinkedIn, never work
  email.
- The market has **no** mandatory owner-naming legal notice (outside DE/AT/CH, and the site has no such
  notice) → plain [`../provider-playbooks/openmart.md`](../provider-playbooks/openmart.md) company → owner
  workflow, without the Impressum-specific generic-inbox handling here.
- Plenty of `people_search` coverage already exists for the role/region → that waterfall is cheaper; this
  recipe is for the gap it can't reach.
