Use Exa for web-grounded retrieval, then synthesis.

**`type` vs `category`:** `type` controls the search strategy (auto/fast/neural/deep). `category` filters result type (company/people/news/financial report). These are independent params. `"type":"news"` is a 422 error — use `"category":"news"` for news results.

**Cost.** Every `exa_search` / `exa_contents` / `exa_answer` / `exa_find_similar` call is charged, including one that
matches nothing — Exa prices the request it accepted. The card price covers the base request, and the request
itself moves it: results beyond the first 10, a per-result `summary`, extra content types, more URLs, and a
`deep` / `deep-reasoning` `type` each cost more. So keep `numResults` tight, ask only for the content types you
will read, and prefer one `search` with `contents` over a `search` plus a separate `get_contents`.

- In AI-column workflows, instruct the model prompt to use Exa retrieval explicitly for website-derived tech stack and on-site signals.
- Use direct Exa tool calls when you need tighter provider controls or auditable step-by-step retrieval outside AI-column orchestration.
- For auditable outputs, run `exa_search`/`exa_contents` first and synthesize after inspecting citations.
- Use focused queries and small `numResults` during pilots, then widen only if coverage is low.
- Treat `exa_answer` as the summarization layer, not the first retrieval step, when precision matters.

```bash
hyreflow tools execute exa_search --payload '{"query":"series b devtools companies united states","numResults":5,"type":"fast"}'
```

```bash
hyreflow tools execute exa_contents --payload '{"urls":["https://example.com"],"text":true}'
```

```bash
hyreflow tools execute exa_answer --payload '{"query":"Summarize the top GTM signals from these results","text":true}'
```

## Exa Agent — async research / list-building / enrichment

**Async submit + poll.** `exa_agent` starts a long-running, high-compute run (deep research, list
building, or row enrichment) and returns a run **id** immediately. Poll `exa_agent_get` with that id
until `status` is `completed` (terminal states: `completed` / `failed` / `cancelled`). Locally you can
let the CLI drive the loop with `--await get_agent_run`.

**When to use vs plain search.** Reach for `exa_agent` when one call must do more than a single
retrieval — multi-hop tasks ("find companies, *then* their decision-makers"), open-ended list building,
or research across many structured fields with citations. For a single low-latency lookup, stay with
`exa_search` / `exa_answer`.

**Key knobs (all optional):**
- `outputSchema` — a JSON Schema; the run returns validated JSON in `output.structured`. Bound arrays
  with `maxItems` so the maximum enrichment cost is predictable.
- `effort` — `minimal` · `low` · `medium` · `high` · `xhigh` · `auto` (default `auto`). Use `auto` for
  list-building where the number of results is unknown; step up to `high`/`xhigh` for large schemas or
  fields that need verification, down to `low`/`minimal` for narrow factual lookups.
- `input.data` — existing rows to enrich (add fields, surface more entities, or both).
- `input.exclusion` — entries to skip (things you already have).
- `previousRunId` — continue a prior run's context for a follow-up ("find 10 more", "narrow to SF").
  Each follow-up starts a **new** run id.
- `dataSources` — attach premium data partners (e.g. `[{"provider":"similarweb"}]`); reference the
  source in a schema field ("from Similarweb") and the run calls that partner instead of a web search.

**Cost.** An agent run is charged **when it completes**, for what the completed run came to — starting one costs
nothing, polling it costs nothing however often you poll, and a run that ends `failed` or `cancelled` is not
charged at all. A fixed `effort` caps what a run can reach (`minimal` is the cheapest, `xhigh` the most
expensive); the default `auto` has no cap and spends whatever the work takes, so the charge is only known when
the run finishes. Bound it deliberately: set an explicit `effort` and `maxItems` on the output schema for
predictable spend, and keep `auto` for list-building where the size genuinely isn't known up front.

```bash
hyreflow tools execute exa_agent --payload '{
  "query":"Find engineering leaders at AI infrastructure companies that raised a Series A or B in the last 6 months.",
  "effort":"auto",
  "outputSchema":{"type":"object","properties":{"people":{"type":"array","maxItems":10,"items":{"type":"object","properties":{"name":{"type":"string"},"job_title":{"type":"string"},"linkedin_url":{"type":"string","format":"uri"}},"required":["name","job_title","linkedin_url"]}}},"required":["people"]}
}'
```

```bash
hyreflow tools execute exa_agent_get --payload '{"run_id":"agent_run_01j..."}'
```

## Field notes

- **Agent runs are async** — `exa_agent` hands back a run id; the answer/structured JSON arrives only
  once `exa_agent_get` reports `status: completed`. `failed` and `cancelled` are the other terminals.
- **Cost is self-reported per run** — a completed run carries its own `costDollars` breakdown (ACUs +
  search + any contact enrichment), so runs are easy to meter after the fact.
- **Concurrency is limited** — Exa caps active Agent runs at roughly one-fifth of the account's QPS
  (about two concurrent runs on a default pay-as-you-go account). Queue large batches rather than firing
  them all at once.
- **`type` vs `category` still applies** to the underlying searches — see the note at the top.

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface
Call via the CLI: `hyreflow tools execute exa <method> --payload '{...}'` (preview with `--dry-run`; `hyreflow tools get exa <method>` returns the live contract + cost). Base: `https://api.exa.ai`. Any endpoint without a typed method is reachable through the tool's generic `request` passthrough.

- `answer(query: str, *, text: bool = False, **opts) -> dict` — POST /answer — LLM answer grounded in Exa search results, with citations.
- `budget_remaining() -> dict` — Remaining Exa balance — NOT callable by a workspace. It reads a Hyreflow-side Exa balance rather than the caller's own account, so connecting your own Exa key does not unlock it; the engine refuses it on the workspace path regardless of BYOK.
- `find_similar(url: str, *, num_results: int = 10, **opts) -> dict` — POST /findSimilar — find pages semantically similar to a seed URL.
- `get_agent_run(run_id: str) -> dict` — GET /agent/runs/{run_id} — fetch an Exa Agent run's status and result.
- `get_contents(urls: list[str], *, text: bool = True, **opts) -> dict` — POST /contents — fetch cleaned page content for URLs (text/highlights/summary).
- `list_agent_runs(*, limit: int = 10, **opts) -> dict` — GET /agent/runs — list recent Exa Agent runs (id/status/createdAt/request).
- `ping() -> dict` — BYOK key-verification probe. Exa's usage endpoint needs an api-key id in the path, so this fires the cheapest real search (1 result) to confirm the key authenticates — NOT free, ~1 search charge on the caller's own Exa account.
- `search(query: str, *, num_results: int = 10, type: str | None = None, category: str | None = None, contents: dict | None = None, **opts) -> dict` — POST /search — neural/auto web search. `type`: auto|neural|keyword|fast|deep.
- `start_agent_run(query: str, *, output_schema: dict | None = None, effort: str | None = None, input: dict | None = None, data_sources: list | None = None, previous_run_id: str | None = None, **opts) -> dict` — POST /agent/runs — start an async Exa Agent research/list-build run; returns a run id to poll.

<!-- API-SURFACE:END -->
