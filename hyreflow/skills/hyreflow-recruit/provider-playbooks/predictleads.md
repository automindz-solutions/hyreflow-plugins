# PredictLeads Guidance

Use PredictLeads for company-level signals: hiring, technology detections, news events, financing events, connections, products, GitHub repositories, and similar companies.

Prefer direct company endpoints when you already have a domain. They can return up to 1,000 records on list endpoints, but there's no flat per-request discount — direct endpoints bill per returned result exactly like the discovery endpoints (3 credits for `company`/`job_openings`/`connections`/`technology_detections`, 5 for `financing_events`, 0.5 for `news_events`/`products`/`website_evolution`). Use discovery endpoints when you need broad search across companies rather than a single known domain.

Avoid follow/unfollow workflows for now. PredictLeads followed-company APIs are designed for webhook delivery and recurring monthly billing, not one-shot agent execution.
