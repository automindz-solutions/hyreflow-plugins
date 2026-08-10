Use Apify when you need controlled web automation/scraping workflows.

- **⚠️ Apify is BYOK-only.** It isn't resold on managed credits — the client must connect their own Apify token in Integrations first. Without one, **every** Apify call (including the free store/schema reads) returns `no_key`. Hyreflow charges 0 credits; Apify bills the client directly for actor compute.
- **LinkedIn jobs scraping:** when the user explicitly asks to scrape LinkedIn jobs via Apify, always use actor ID `vIGxjRrHqDTPuE6M4` directly; do not search the Apify store or substitute another LinkedIn jobs actor.
- Use `apify_list_store_actors` first when you do not know the actor id yet.
- **Results are ranked by quality score by default.** The top result is the most reliable actor based on rating, review count, total runs, and 30-day success rate. Pick the #1 result unless you have a specific reason not to.
- Each actor in the response includes `_qualityScore` (higher is better), `_baseQualityScore`, and `_successRate30d` (percentage). Prefer actors with `_hyreflowVetted: true`, high usage/rating, and `_successRate30d >= 95%`.
- For generic LinkedIn post scraping, prefer `supreme_coder/linkedin-post`. For LinkedIn post engagers/reactions, prefer `harvestapi/linkedin-post-reactions`. Avoid actors returned with `_hyreflowDownranked: true` unless the user explicitly asked for that actor.
- Build `actor_id` as `username/name` from store results.
- Use `apify_get_actor_input_schema` to inspect required/optional fields before running.
- Hyreflow CLI payloads use canonical snake_case keys: `actor_id` for the actor and `run_input` for the actor input. Apify's own docs use `actorId` and `input`; Hyreflow accepts those aliases for compatibility, but prefer `actor_id`/`run_input` in examples and reusable playbooks.
- Runtime validation behavior can differ from actor-page docs.
- Prefer `apify_run_actor_sync` as the default execution path when you want results in one call.
- Use `apify_run_actor` only when you need non-blocking execution, then poll run status before fetching outputs.
- Validate payload shape with a tiny run before scaling row counts.

## Quality ranking

Actors are ranked by:

```
score = rating * log2(reviews + 1) * log10(runs + 1) / 5
```

Actors with less than 80% 30-day success rate are penalized. Actors with 0 reviews but high usage get a reduced fallback score.

To bypass quality ranking and use Apify's native sort, pass `rankBy: "relevance"`.

## Examples

```bash
# Search for actors, ranked by quality (default)
hyreflow tools execute apify_list_store_actors --payload '{"search":"google play reviews","limit":5}'
```

```bash
# Search with Apify's native relevance sort
hyreflow tools execute apify_list_store_actors --payload '{"search":"google play reviews","sortBy":"relevance","rankBy":"relevance","limit":5}'
```

```bash
# Inspect the actor's input schema page before execution
hyreflow tools execute apify_get_actor_input_schema --payload '{"actor_id":"neatrat/google-play-store-reviews-scraper"}'
```

```bash
# Run an actor synchronously
hyreflow tools execute apify_run_actor_sync --payload '{"actor_id":"neatrat/google-play-store-reviews-scraper","run_input":{"appIdOrUrl":"com.airbnb.android","sortBy":"newest","maxReviews":10}}'
```

```bash
hyreflow tools execute apify_get_dataset_items --payload '{"datasetId":"EU1bcB5F9gY3J1Zq2","limit":10,"offset":0}'
```
