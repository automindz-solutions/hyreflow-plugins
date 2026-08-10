# Wiza — Agent Guidance

## When to use

Wiza for LinkedIn → email/phone enrichment. Key advantage over ContactOut: **accepts Sales Navigator and LinkedIn Recruiter URLs** in addition to standard LinkedIn profile URLs. Strong for outbound teams with Sales Nav lists.

## Provider characteristics

- **Input required**: LinkedIn URL (including Sales Nav), email, or name+company
- **Geographic coverage**: Global
- **Credit cost**: flat rate per revealed record, regardless of enrichment level (email, phone, or both) —
  check `hyreflow tools get wiza enrich_person` for the live rate
- **Enrichment levels**: `none` (profile only), `partial` (email), `phone`, `full` (email+phone) — the level only
  controls what's returned, not the price; every non-`none` reveal bills the same rate
- **Async**: reveals are queued and processed — the handler polls until finished

## Key operations

### wiza_start_individual_reveal

Starts an async enrichment job and polls until finished. Accepts any LinkedIn URL type.

```json
{
  "linkedin_url": "https://www.linkedin.com/in/johndoe",
  "enrichment_level": "partial"
}
```

For phones + emails:

```json
{
  "linkedin_url": "https://www.linkedin.com/in/johndoe",
  "enrichment_level": "full"
}
```

Name + company fallback:

```json
{
  "first_name": "John",
  "last_name": "Doe",
  "company_domain": "acme.com",
  "enrichment_level": "partial"
}
```

### wiza_prospect_search

Discover prospects by job title, level, company, industry, location. **Free** — returns masked profiles without contact info. Returns up to 30 results per search.

```json
{
  "filters": {
    "job_title": "VP of Sales",
    "job_level": "vp",
    "company_industry": "SaaS",
    "person_location": "United States"
  }
}
```

Typical flow: search → get LinkedIn URLs → feed into `wiza_start_individual_reveal` to enrich.

## Output shape

`wiza_start_individual_reveal` returns a flat object. Email at `email`, phones at `phone_number1`, `mobile_phone1`. Status at `status` ("finished" | "failed").

`wiza_prospect_search` returns `{ prospects: [...], total: N }`.

## Enrichment levels

| Level     | Returns             | Cost           |
| --------- | ------------------- | -------------- |
| `none`    | Profile data only   | same flat rate |
| `partial` | Emails only         | same flat rate |
| `phone`   | Phone numbers only  | same flat rate |
| `full`    | Emails + phones     | same flat rate |

Pricing is per call to `start_individual_reveal`, not per field returned — the `enrichment_level` you request
does not change the credit cost. Check `hyreflow tools get wiza enrich_person` for the live rate.

## Anti-patterns

- Don't over-request `enrichment_level: "full"` reflexively — it costs the same rate as `partial`, but a phone match takes longer/is less reliable, so only ask for it when the workflow actually needs a phone number
- Don't skip polling — reveals are async, status starts as "queued"
- Don't expect more than 30 results from search per call
