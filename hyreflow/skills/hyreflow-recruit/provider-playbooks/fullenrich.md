# FullEnrich Agent Guidance

## Key patterns

- **Async submit + async fetch.** `fullenrich_start_bulk_enrichment` and `fullenrich_start_reverse_email` start background jobs and return an `enrichment_id`. Poll with `fullenrich_get_bulk_enrichment` or `fullenrich_get_reverse_email` for terminal data.
- **Use `enrich_fields`** to control what's enriched: `contact.emails`, `contact.phones`, `contact.personal_emails` — every revealed record bills the same flat 3 credits regardless of which field(s) matched.
- **LinkedIn URL** improves accuracy significantly (5-20% for emails, 10-60% for phones).
- **Email status hierarchy:** DELIVERABLE > HIGH_PROBABILITY > CATCH_ALL > INVALID. Use `most_probable_work_email` field for the best result.
- **Phone billing is the same flat 3 credits as email** -- no cost penalty, but still fine to gate behind explicit need since it's a slower/less-reliable match.
- **Search is synchronous** -- use `fullenrich_search_company` for company prospecting (there's no people-search method on this adapter — for person-level search use the `people_search` waterfall).
- Use `fullenrich_get_bulk_enrichment` / `fullenrich_get_reverse_email` after every async submit when you need terminal data.
- **`forceResults=true`** query param on get-result returns partial results if enrichment is still running.

## When to use

- Best for high-quality email/phone waterfall enrichment with extensive provider coverage (20+ sources).
- Company search API (`fullenrich_search_company`) is good for prospecting by company, industry, location — not a person-level search.
- Reverse email lookup useful for identifying contacts from email addresses.

## When NOT to use

- Don't use for email validation only -- use a dedicated validator (Enrichley, LeadMagic validation).
- Phone enrichment isn't more expensive than email here, but still gate it behind explicit need -- it's a slower/less-reliable match.
- For quick single-provider email lookups, LeadMagic or Prospeo are faster/cheaper.
