# Recruit CRM rate limits & bulk writes

## API rate limits

Recruit CRM enforces a **per-API-token** request limit:

- Accounts with **6 or fewer licenses**: **60 requests / minute**
- Accounts with **more than 6 licenses**: **10 requests / minute per license**
  (e.g. 10 licenses → 100 requests / minute)

The limit is returned in response headers for every call:

- `X-RateLimit-Limit` — total calls allowed per minute
- `X-RateLimit-Remaining` — calls left in the current window

If the limit is exceeded, the API returns `429 Too Many Requests`. The `lib.recruit_crm` adapter already retries 429s with exponential backoff, but for large jobs it proactively paces requests so 429s are rare.

## Pacing / batching

There is **no native bulk-create endpoint**. Creating 1,000 records means 1,000 separate `POST` calls. Use the batch helpers to stay inside the rate limit:

- `recruit_crm.create_candidates_batch(payloads)`
- `recruit_crm.create_contacts_batch(payloads)`
- `recruit_crm.create_companies_batch(payloads)`

Each helper loops single `POST` calls and respects `RECRUITCRM_RATE_LIMIT_RPM` (default `60`). It returns `created`, `failed`, `total`, `elapsed_ms` so you can resume from failures.

### Sizing a batch

| Licenses | rpm | 1,000 creates | Approx. time |
|----------|-----|---------------|--------------|
| ≤6 | 60 | 1,000 | ~17 min |
| 10 | 100 | 1,000 | ~10 min |
| 50 | 500 | 1,000 | ~2 min |

Use `RECRUITCRM_RATE_LIMIT_RPM` to override the default for accounts with more licenses:

```bash
# 10 licenses → 100 rpm
RECRUITCRM_RATE_LIMIT_RPM=100 hyreflow tools execute recruit-crm create_candidates_batch \
  --payload '{"payloads": [...]}'
```

### Resilience

- Always **pilot with 1–5 records** (`--rows 0:1` or a tiny `payloads` list) and inspect the response before scaling.
- The batch helper does **not** stop on the first error by default (`stop_on_error=false`). It collects every failure so you can retry the failed slice without reprocessing successes.
- Read `X-RateLimit-Remaining` when it is zero and back off before the next chunk; the adapter paces automatically but a manual pause is a safe fallback.

## Bulk push from an enriched CSV

Typical flow:

1. Enrich the records first (this is the credit-metered step). Get an estimate before the full run.
2. Inspect the output CSV / dataset.
3. Map columns to Recruit CRM fields (`first_name`, `email`, `company_slug`, etc.).
4. Resolve any account-specific IDs (`list_custom_fields`, `get_candidate_hiring_pipelines`).
5. Run `create_*_batch` in chunks (e.g. 50–200 records per call) so each call fits comfortably under the rate limit and inside HTTP timeouts.
6. Log the `slug` / `id` from each `created` item for rollback / audit.

See the main [recruit-crm playbook](recruit-crm.md) for field-level guidance and authentication.
