---
name: hyreflow-quickstart
description: 'Run a quick Hyreflow demo recipe to show the user how Hyreflow works.'
disable-model-invocation: false
---

# Hyreflow Quickstart

Run a high-confidence demo to show what Hyreflow can do. Default to Recipe 1 if no context is given.

**Prefer the hardcoded recipe below.** `/hyreflow-recruit` is the fallback only if (a) a command fails and
all fallbacks are exhausted, or (b) the user's ask doesn't match this recipe. Never invoke it preemptively.

## Execution flow

0. **Check for updates (once per session, before anything else).** Run `hyreflow update --check --json`.
   - **If `hyreflow` is not installed** ("command not found" — common when the skills came from the plugin
     marketplace rather than the CLI installer): offer to install it with
     `curl -fsSL https://recruit.hyreflow.ai/api/v2/cli/install | bash -s -- --no-skills` (installs the CLI
     and signs the user in; `--no-skills` avoids duplicating the skills you already have). Then continue.
   - On error (older CLI without `--check`), fall back to `hyreflow auth status` and read its
     "run `hyreflow update`" / skills "sync needed" lines.
   - If `cli_stale` or `skills_stale` (or the fallback shows either): tell the user in one line that a newer
     Hyreflow CLI/skills is available, then **ask** whether to run `hyreflow update` now or continue as-is.
     If they update → run `hyreflow update`, then proceed, and note: the new **CLI** is live on the next
     `hyreflow` command, but refreshed **skill guidance** applies from the next `/hyreflow*` invocation
     (re-invoke or restart for it now). If `below_min` is true, recommend updating strongly, then ask.
   - If up to date, unreachable, or offline (`reachable:false`): say nothing, continue. Check **once** —
     don't re-run on every later `hyreflow` call.

1. **Tell the user what you're about to do** — the goal + which data source(s), before running anything.
2. **Register a session start** so the live Playground can render progress:
   ```bash
   hyreflow session start --steps '["Search candidates", "Enrich emails", "Display results"]' \
     --user-prompt "Original user request"
   ```
3. **For each step**: send a status, run the command, mark it done.
   ```bash
   hyreflow session status --message "Searching…" --step-index 0
   hyreflow session update --index 0 --status completed
   ```
4. **Register output** after any CSV: `hyreflow session output --csv <path> --label "…"`.
5. **Summarize** results, where they came from, and what's next.

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
