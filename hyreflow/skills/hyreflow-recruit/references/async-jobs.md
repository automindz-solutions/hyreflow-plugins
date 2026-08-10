# Async-job contract

> **You don't manage async polling.** Drive everything through the `hyreflow` CLI against the hosted
> engine — the waterfalls (`hyreflow enrich …`) and `hyreflow tools execute …` start + poll async jobs
> server-side and meter on the result. This doc is the engine's internal contract (system reference);
> the `cli.py`/local examples below describe the **server-side** implementation, not something you run.

Some providers are **async**: a `start_*` call returns a job id immediately; the result is ready later.
This doc defines how hyreflow handles them server-side (the same contract the hosted engine uses).

## The rule
**Adapters never block.** They expose two thin, synchronous-per-HTTP-call methods:
- `start_*(...)` → returns a job handle (id/trackId).
- `get_*` / `*_statistics(...)` → returns status + (when done) result.

ALL waiting happens in **`lib/_jobs.py:await_job`**, whose `sleeper` and `clock` are **injected**. Nothing
about waiting lives inside the adapter or inside a customer-facing request handler.

```
await_job(fetch, *, is_terminal=default_is_terminal, timeout=180, interval=6,
          sleeper=time.sleep, clock=time.monotonic) -> terminal response   # raises TimeoutError past timeout
extract_job_id(start_response) -> id            # handles id / trackId / data.id / request_id
TERMINAL[(tool, fetch_method)] -> predicate      # per-endpoint "is it done?"  (fallback: default_is_terminal)
```

## Three drivers, one seam
| Context | How it drives await_job | Notes |
|---|---|---|
| **Local test** | `cli.py <tool> <start> ... --await <fetch> [--poll-interval N --poll-timeout N]` | injects `time.sleep` (blocking loop). Proven on BetterContact. |
| **Server — background runner** | same `await_job`, inject an async sleeper (`asyncio.sleep`) or drive from a queue tick | **do NOT block a request worker** — return the job id to the orchestrator (the host agent) and resolve via a `get_status`/`get_result` tool, or run the poll in a background task. |
| **Server — push-only providers** | webhook receiver resolves the job; no poll | AI Ark email-finder is **webhook-mandatory** (no poll endpoint). Server hosts a receiver, stores results by id; the host agent reads the local store. Persistent server CAN do this (a stateless agent can't). |

## Async endpoints today (terminal states LIVE-confirmed where noted)
- **bettercontact** `start_enrichment` → `get_enrichment`; statuses `not_started` → `in progress` → **`terminated`** (✅ live). Only `terminated` is terminal — **every** pre-terminal state counts as not-done, `not_started` included.
- **aiark** `export_people`/`find_emails` → `export_statistics`/`email_finder_statistics`; terminal `state: DONE`. find_emails is **webhook-required** (push-only) — needs the server receiver.
- **apify** `run_actor` → `get_run`; terminal `data.status ∈ {SUCCEEDED, FAILED, ABORTED, TIMED-OUT}`. (`run_actor_sync` is the blocking convenience for short runs.)

## Adding a new async endpoint
1. Keep the adapter thin: a `start_*` and a `get_*`. Don't loop inside them.
2. Register a terminal predicate in `lib/_jobs.py:TERMINAL` for `(tool, fetch_method)`.
3. Test locally: `cli.py <tool> <start> <args> --await <fetch>`.
4. Server reuses all of the above unchanged — it only swaps the sleeper/driver (or wires the webhook).

## Why this is the portable design
The blocking-vs-async difference is pushed to the EDGE (the driver), not the core. Locally you block (fine);
on the server you inject a non-blocking sleeper or a webhook — but `await_job`, the terminal predicates, and the
id extraction are byte-identical. No adapter rewrite to go from laptop to production.
