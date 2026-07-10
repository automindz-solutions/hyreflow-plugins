Use Exa for web-grounded retrieval, then synthesis.

**`type` vs `category`:** `type` controls the search strategy (auto/fast/neural/deep). `category` filters result type (company/people/news/financial report). These are independent params. `"type":"news"` is a 422 error — use `"category":"news"` for news results.

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

**Cost.** Agent runs are usage-metered on your own Exa account — Agent Compute Units plus per-search,
and optional per-email / per-phone when you request contacts. A fixed `effort` sets a per-request price;
`auto` varies with the work done. The completed run reports its own `costDollars`.

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
