# BetterContact Agent Guidance

## Key patterns

- **Enrichment is async.** `bettercontact_start_enrichment` launches a BetterContact job (one method — it always accepts a list, so single and bulk both go through it) and returns a request id immediately. Use `bettercontact_get_enrichment` to fetch terminal results.
- **Email status hierarchy:** deliverable > catch_all_safe > catch_all_not_safe > undeliverable. Only trust deliverable and catch_all_safe for outreach.
- **Batch up to 100 contacts** per `bettercontact_start_enrichment` request.
- Use the launcher response `id` as the `request_id` for `bettercontact_get_enrichment`.
- **Rate limit:** 60 requests per minute per API key, shared across all endpoints.

## Pricing

- Hyreflow bills a flat rate per revealed record — email or mobile phone, no surcharge either way. Check
  `hyreflow tools get bettercontact start_enrichment` for the live rate.
- `bettercontact_get_enrichment` returns the vendor's own `credits_consumed` field, but that's BetterContact's internal accounting and does not change what Hyreflow bills.
- Enabling `enrich_phone_number: true` does not cost more than email-only enrichment.

## When to use

- Use BetterContact when you need waterfall email enrichment with multi-provider verification.
- Good fallback when single-provider finders (LeadMagic, Prospeo) miss.
- Includes triple email verification, phone verification, contact & company enrichment.

## When NOT to use

- Don't use for email validation only — use a dedicated validator.
- Don't use for company/org enrichment — BetterContact is contact-focused.
