---
name: hyreflow-quickstart
description: 'Run a quick Hyreflow demo recipe to show the user how Hyreflow works.'
---

# Hyreflow Quickstart

> The skill root is `$HOME/.agents/skills/hyreflow-quickstart/`; relative paths are relative to it — if a
> relative read fails, prefix it with the root.

## Quick Start

```bash
# Install the CLI (sandbox-safe: user-local prefix + quiet). In a normal terminal, plain `npm install -g hyreflow` is fine.
npm install -g hyreflow --prefix "$HOME/.local" --silent --no-fund --no-audit
export PATH="$HOME/.local/bin:$PATH"
# Fallbacks: blocked npmjs.com → add `--registry https://recruit.hyreflow.ai/api/v2/npm/`; no Node → https://hyreflow.ai/docs/quickstart
hyreflow setup                   # installs skills + signs in; relay the link it prints, then re-run
                                 # this to resume (it continues the same sign-in, so the link stays valid)
hyreflow auth status             # confirm you're connected
hyreflow -h                      # see available commands
```

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
# Pilot FIRST on row 0, check the shape, then scale (drop --rows or widen the range).
hyreflow enrich --input <csv_from_step_1> --output enriched.csv --rows 0:1 \
  --with '{"alias":"email","tool":"email_enrichment","payload":{"first_name":"{{first_name}}","last_name":"{{last_name}}","company_domain":"{{company_domain}}","linkedin_url":"{{linkedin_url}}"}}'
```

`--input` takes the CSV (or a `ds_…` dataset id); `--rows` is a row RANGE (`0:1`), not a file.
The waterfall only charges credits when a usable email comes back (soft misses are free).

### Step 3 — Display results

Show a table: name, company, email, LinkedIn. Note emails were filled via the dedicated waterfall.
Mention they can go deeper — phones, firmographics, hiring signals — with `/hyreflow-recruit`.

### Fallback (if Step 1 errors)

Tell the user, then try a specific provider directly:

```bash
hyreflow tools execute apollo search_people_with_match --payload '{
  "person_titles": ["Software Engineer"],
  "person_locations": ["San Francisco, California, United States"],
  "organization_num_employees_ranges": ["1-200"],
  "per_page": 5, "page": 1
}'
```

### Last resort

If all commands fail, tell the user, then invoke `/hyreflow-recruit`:

> Find 5 software engineers at Bay Area startups with verified emails and LinkedIn profiles.
