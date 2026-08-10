# Icypeas Workflow Guidance

The adapter exposes 6 methods: `icypeas_email_search`, `icypeas_domain_search`, `icypeas_email_verification`,
`icypeas_read_results`, `icypeas_subscription_information`, `icypeas_ping`. There is no count-first,
bulk-search, or LinkedIn-profile-scraping workflow for this provider today — routes like
`find_people`/`find_companies`/`scrape_profile`/`scrape_company` don't exist on this engine.

- **Email search is async.** `icypeas_email_search` returns a `SCHEDULED` status immediately (billed per
  result). Poll `icypeas_read_results` (free) with the returned `_id` to get the final email.
- **Domain search** (`icypeas_domain_search`, billed per request) is the closest thing to a company-level
  lookup this provider offers.
- **Verify before sending.** Run `icypeas_email_verification` on discovered emails before outbound. Treat
  `NOT_FOUND` and `DEBITED_NOT_FOUND` as non-deliverable. Check `hyreflow tools get icypeas <method>` for
  the live rate on each.
- **Free operations:** `icypeas_read_results`, `icypeas_subscription_information`, and `icypeas_ping` cost zero
  credits. Use `icypeas_subscription_information` to check account status before large operations.
