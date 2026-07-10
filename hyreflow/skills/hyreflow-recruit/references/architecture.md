# hyreflow.ai — Architecture & how to add a tool

## The pairing rule
Every external tool = **two paired artifacts**:
- **Adapter** (`lib/<tool>.py`) — the *hands*. A thin `requests.Session` client: key from env, retry on
  429/5xx, typed methods for the core operations + a generic `request()` passthrough for the long tail.
- **Playbook** (`provider-playbooks/<tool>.md`) — the *brain*. Auth scheme, the operations, pagination contract,
  guardrails (approval gates), and the handoff (where this tool sits in the pipeline).

Every workflow follows the same split: pipeline (code) + recipe (markdown). Markdown-by-default for the
"brain"; Python only where something must execute.

## Why own the client code
Owning a thin client per tool (rather than routing through third-party middleware) means hyreflow
controls auth, retries, rate limits, and the exact request/response shape. Keys can run on hyreflow's
**managed credit system** or the client's **own keys (BYOK)** — either way each `lib/<tool>.py` reads
its key from env. The wrapped vendor API is an implementation detail behind the hyreflow product.

## Adapter template (mirror any existing `lib/<tool>.py`)
- `BASE_URL`, `<TOOL>_API_KEY` env constant, `DEFAULT_TIMEOUT`, `RETRY_STATUSES`.
- `<Tool>Error(status, message, body)` exception.
- `__init__` — key from env, `requests.Session` with the auth header set once.
- `request(method, path, *, params, json)` — generic call with retry on 429/5xx + error normalization;
  also the passthrough for un-wrapped endpoints.
- `_paginate(...)` / `iter_*` — matched to the provider's scheme (page/limit, cursor, or offset).
- Typed methods for the core recruiting/GTM operations.
- Secrets **only** from env; outreach/credit/write actions gated in the playbook.

## Field notes (production experience)
15 tools carry a **"## Field notes (production experience)"** section in their `provider-playbooks/<tool>.md` —
vendor-native operational knowledge accumulated over real runs: filter shapes, credit costs, async
flows, enum values, rate limits, gotchas. What's deliberately excluded: any third-party middleware's
normalized tool-id names or `{data, meta}` response envelope — our clients return **raw vendor JSON**,
so field shapes use the method names in this skill (no `result.data.` prefix). When adding a tool,
fold any production quirks you know into its Field notes (using our method names). This is also where
the **AI Ark base-URL** discrepancy was caught — see `provider-playbooks/aiark.md` and the `aiark.py` docstring.

Tools with Field notes: aiark, smartlead, lemlist, apollo, lusha, apify, leadmagic,
bettercontact, exa, fullenrich, serper, instantly, heyreach, icypeas, prospeo.

## Cheapest-doc-source hierarchy (use in order)
1. **OpenAPI/Swagger JSON** — fetch once, parse paths/schemas (e.g. Instantly, Apollo).
2. **llms.txt / static `.md`** (Mintlify/ReadMe) — plain HTTP discovery (most enrichment tools, Smartlead, Lemlist).
3. **JS-rendered SPA** — Firecrawl `/v2/map` to list URLs → `/v2/scrape` each as markdown (e.g. Recruit CRM/Stoplight).
4. **Hand-paste** — only if docs are gated/absent → flag and park (e.g. quil).

## Adding a new tool (checklist)
1. Find the cheapest doc source; cache raw docs to `reference/docs/<tool>/raw/` (idempotent, in-skill).
2. Build `lib/<tool>.py` from the template. `python -m py_compile` + import-check.
3. Write `provider-playbooks/<tool>.md` (auth, ops, pagination, guardrails, handoff).
4. Regenerate `lib/__init__.py` so the new client is re-exported (the generator introspects each module
   for its primary non-Exception class — see the build history / re-run the snippet in chat).
5. Add the tool's row to `references/env-vars.md` and a line to the SKILL.md catalog.
6. Deferred live check: once the key is set, run one read-only call (`list_*`/`search_*`) to confirm
   auth + pagination before any writes.

## Status notes carried from the build
- Paths/auth **inferred from doc slugs and flagged "verify on first pilot":** aiark, lemlist, heyreach,
  sourcewhale (auth scheme to confirm). prospeo is fully live-confirmed (enrich + search + suggestions).
- **Auth-heavy:** bullhorn (3-leg OAuth → BhRestToken+restUrl), vincere (x-api-key + ~30-min id_token).
- **Async (start→poll):** bettercontact, fullenrich.
- **Parked:** quil/CoRecruit (no public API) — use fathom for API-accessible meeting data.
