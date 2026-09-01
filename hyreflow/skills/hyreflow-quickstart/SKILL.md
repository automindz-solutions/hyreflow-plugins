---
name: hyreflow-quickstart
description: 'Run a quick Hyreflow demo recipe to show the user how Hyreflow works.'
---

# Hyreflow Quickstart

> The skill root is `$HOME/.agents/skills/hyreflow-quickstart/`; relative paths are relative to it — if a
> relative read fails, prefix it with the root.

> **No shell? You're on the MCP connection.** Everything below that installs or runs the `hyreflow`
> CLI does not apply — this connection is already authorized, and the skill documents are served to
> you directly. Skip to the steps and use the `hyreflow_*` tools your client lists.
>
> Two things below read differently there: results come back in the response rather than as a CSV on
> disk, so show the rows themselves instead of a file path; and `/hyreflow-recruit` is a command for a
> client with a shell — offer to go deeper with the tools instead.

## Quick Start

```bash
hyreflow auth status                   # connected? continue below
hyreflow -h                            # see available commands
```

**Not connected, or `hyreflow` not found?**

```bash
npm install -g hyreflow
# Fallback for secure sandboxes: npm install -g hyreflow --prefix "$HOME/.local" --registry https://recruit.hyreflow.ai/api/v2/npm/ && export PATH="$HOME/.local/bin:$PATH"
hyreflow auth login --wait auto
hyreflow auth wait --timeout 120       # completes the browser approval; no-op if already connected
hyreflow auth status
```

**CLI resolution.** Run `hyreflow` when available. If the shell reports the command is missing, use
`<workspace-root>/.hyreflow/runtime/bin/hyreflow` or the npm-created `.cmd` shim on Windows. If neither
exists, follow `https://recruit.hyreflow.ai/SKILL.md` to set up Hyreflow.

Run a high-confidence demo to show what Hyreflow can do. Pick the recipe below, or default to Recipe 1.

**Prefer the hardcoded recipe below.** `/hyreflow-recruit` is the fallback only if (a) a command fails and
all fallbacks are exhausted, or (b) the user's ask doesn't match this recipe. Never invoke it preemptively.

## Execution flow

Follow this pattern for the recipe:

1. **Tell the user what you're about to do** — the goal + which data source(s), before running anything.
2. **Run the recipe directly.** Keep it fast: do NOT run `hyreflow session …` progress commands or
   `hyreflow --version` / `auth status` on this path — they don't improve the demo. (Session/Playground
   progress is for real runs — see `/hyreflow-recruit` or `/hyreflow-workflows`.)
3. **Tell the user the results** — what came back, where it came from, and the exact CSV path to inspect
   next. Mention they can go deeper (phones, firmographics, hiring signals) with `/hyreflow-recruit`.

---

## Recipe 1 — Find engineers with verified emails

**Goal:** Find 5 software engineers at startups with verified personal emails + LinkedIn.
**Data sources:** people search (Apollo/AI Ark) + the `email_enrichment` waterfall.

### Step 1 — Search

```bash
hyreflow tools execute people_search --payload '{
  "titles": ["Software Engineer", "Senior Software Engineer"],
  "locations": ["San Francisco Bay Area"],
  "skills": ["Python", "Go"],
  "limit": 5
}'
```

Note the output CSV path from the result.

### Step 2 — Enrich emails (waterfall)

```bash
hyreflow enrich --input <csv_from_step_1> --output enriched.csv \
  --with '{"alias":"email","tool":"email_enrichment","payload":{"first_name":"{{first_name}}","last_name":"{{last_name}}","company_domain":"{{company_domain}}","linkedin_url":"{{linkedin_url}}"}}'
```

Before you run it, tell the user this step walks a provider waterfall per row and takes roughly a minute,
so the wait is expected. The command prints the provider chain it will walk (`email_enrichment: prospeo →
…`) and an elapsed-seconds heartbeat while it runs; the run summary ends with a per-provider hit/miss tally
(`summary.provider_stats`) — report which provider filled the emails.

`--input` takes the CSV (or a `ds_…` dataset id). Rows are enriched in parallel, so a 5-row demo takes
about as long as one row. On a bigger file, `--rows 0:1` (a row RANGE, not a file) enriches just the first
row to check the shape before spending on the rest.
The waterfall only charges credits when a usable email comes back (soft misses are free).

### Step 3 — Display results

Show a table: name, company, email, LinkedIn. Note emails were filled via the dedicated waterfall.
Mention they can go deeper — phones, firmographics, hiring signals — with `/hyreflow-recruit`.

### Fallback (if Step 1 errors)

Tell the user, then try a specific provider directly:

```bash
hyreflow tools execute apollo search_people --payload '{
  "person_titles": ["Software Engineer"],
  "person_locations": ["San Francisco, California, United States"],
  "organization_num_employees_ranges": ["1-200"],
  "per_page": 5, "page": 1
}'
```

### Last resort

If all commands fail, tell the user, then invoke `hyreflow-recruit` — as the `/hyreflow-recruit` slash
command if your harness supports it, otherwise by reading and executing
`~/.agents/skills/hyreflow-recruit/SKILL.md` directly:

> Find 5 software engineers at Bay Area startups with verified emails and LinkedIn profiles.
