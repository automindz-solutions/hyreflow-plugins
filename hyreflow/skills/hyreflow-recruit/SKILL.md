---
name: hyreflow-recruit
description: "Hyreflow's recruitment-automation harness — the umbrella over every tool adapter (enrichment, data/sourcing, sequencers, recruiting CRMs, comms). Use to find the right tool for a GTM/recruiting step, to wire a cross-tool pipeline (source → enrich → verify → sequence → push to ATS), or whenever the user names one of the tools below. Each adapter is a thin Python client calling the vendor API directly; keys run on hyreflow's managed credit system or the client's own (BYOK)."
---

# hyreflow.ai — Integration Harness (Meta Skill)

> The skill root is `$HOME/.agents/skills/hyreflow-recruit/`; every relative path in this doc (and its
> recipes/playbooks/references) is relative to it — if a relative read fails, prefix it with the root.

Hyreflow is a recruitment-automation harness: a unified adapter + playbook layer
over every external recruiting/GTM tool. Each tool gets a thin Python **adapter** (`lib/<tool>.py`,
the "hands") paired with a **playbook** (`provider-playbooks/<tool>.md`, the "brain").

## Step 0 — connect + check for updates (once per session, before anything else)

**Already connected?** Check that first — this skill needs a signed-in CLI:

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

Then run `hyreflow update --check --json`.
- On error (older CLI without `--check`), fall back to `hyreflow auth status` and read its
  "run `hyreflow update`" / skills "sync needed" lines.
- If `cli_stale` or `skills_stale` (or the fallback shows either): tell the user in one line that a newer
  Hyreflow CLI/skills is available, then **ask** whether to run `hyreflow update` now or continue as-is.
  If they update → run `hyreflow update`, then proceed, and note: the new **CLI** is live on the next
  `hyreflow` command, but refreshed **skill guidance** applies from the next `/hyreflow*` invocation
  (re-invoke or restart for it now). If `below_min` is true, recommend updating strongly, then ask.
- If up to date, unreachable, or offline (`reachable:false`): say nothing, continue. Check **once** — don't
  re-run on every later `hyreflow` call.

## Execution model — engine-routed; you hold NO provider keys (read this first)
**Every vendor call goes through the hosted Hyreflow engine via the `hyreflow` CLI.** The engine resolves
the provider key **server-side** (hyreflow's managed credit system, or the client's BYOK keys configured
on the server) and runs the adapter. **Your machine has no provider keys — that is by design.**

- ✅ DO: `hyreflow tools execute <provider>_<method> --payload '{…}'` · `hyreflow tools execute people_search --payload '{…}'`
  (waterfalls are first-class tools) · `hyreflow enrich --input … --with …`. The CLI turns these into authenticated
  HTTPS calls; auth, retries, metering are handled.
- ❌ NEVER: grep/echo the environment for keys (`GITHUB_TOKEN`, `APOLLO_API_KEY`, …), call a vendor API
  directly (curl/requests), or write a local "ingestion"/transform script that hits a provider. Those keys
  live on the server, not here — looking for them locally is always wrong.
- A `no_key` / skipped step means the **SERVER** isn't configured for that provider (a hyreflow/ops config
  issue) — **not** your machine. Report it; don't try to supply a key yourself.
- `references/env-vars.md` lists the keys the **engine operator** sets on the server — it is NOT a list
  of things you set locally.

When the recipes below name a method (`search_users`, `people_search`, `enrich_person`, …), that means
`hyreflow tools execute <provider>_<method>` (or the relevant `search`/`enrich` waterfall) — never a
direct vendor call.

## Process & goal
The customer goes from an **open role** (or a BD target) → a **qualified shortlist with reachable contacts**
(candidates: personal email + LinkedIn, **never** work email; BD: work email) → **outreach or the ATS**.
They may enter anywhere along that arc — meet them where they are and guide them forward.
**Discovery order depends on the job:** candidate sourcing is **people-first** (title + location across the
people-DBs); BD / signal work is **company-first** (find the accounts/signals, *then* the contacts). Don't
open a broad people search when the task is really "find the right companies first."
**A connected CRM/ATS is a recognized branch, not an edge case:** as soon as a CRM is connected and the
user wants to match candidates to a job from their **own existing candidate base**, route into
[`recipes/crm-matching.md`](recipes/crm-matching.md) alongside (never instead of) pure net-new sourcing —
the two are combinable.

## Speak the recruiter's language (always on)
Talk like a sourcer/recruiter, not an operator: use the trade's vocabulary (shortlist, slate, Boolean
string, MPC, passive vs active, response/positive-reply rate, time-to-slate) and — at each stage —
**proactively name the better next action** a good recruiter would take, then offer it. *Proactive =
recommend in conversation; never silently auto-run a different or paid path — the Credit & approval gate
still binds, and you still meet the user where they are.* When a user doubts a candidate's recruitability,
**reframe around recruitability signals** (open-to-work, tenure, job-change cadence, seniority band)
rather than stalling. **Mirror the user's language in everything you author** (plan steps, progress
notes, the approval message, the run summary) — infer it from their message and follow them if they
switch (outreach copy is the one exception, following the target market instead).
Proper nouns, job titles, and place names are never translated: a place name the user wrote
themselves keeps their spelling; else the local form you know for that market; else a provider's
anglicised location gets its casing repaired only, and nothing more. The CSV/dataset column is a separate
matter — the engine always writes it as the provider's raw value, regardless of what you say. Spend is
quoted in **credits**; a money figure is stated as an explicit **USD** amount, never converted into
another currency. Full vocabulary, the proactive bounds, the user-language canon, and the funnel
behaviour canon live in [`recruiter-craft.md`](recruiter-craft.md) — read it at session start.

## Automating a pipeline → `/hyreflow-workflows`
If the user wants to **automate, schedule, or wire a repeatable multi-step pipeline** (cron/webhook,
"every Monday…", "when X happens…", a reusable workflow), route to **`/hyreflow-workflows`** — it builds
a Hyreflow cloud workflow that Hyreflow runs and meters. Use this skill to pick the right
tool/endpoint for each step inside that workflow.

## Documentation hierarchy
- **L1 — `SKILL.md`** (this file): router — decision model, guardrails, credit/approval gates, where to read next.
- **L2 — `recruiter-craft.md`**: always-on — recruiter voice/vocabulary + the full-funnel behaviour canon (what to do next, and why); recipes point back to it.
- **L2 — `references/*.md`**: cross-cutting *how* — `provider-precedence.md`, `async-jobs.md`, `architecture.md`, `cost-card.md`, `env-vars.md`, `recruiter-playbooks/` (Boolean/X-ray craft + corpus intake).
- **L2.5 — `recipes/*.md`**: step-by-step task playbooks — when one matches, **follow it as your plan**.
- **L3 — `provider-playbooks/<tool>.md`**: per-provider auth, methods, gotchas + the auto-generated **Callable surface**.
- **Field notes — `references/field-notes.md`**: live-verified provider behaviour per provider (filter shapes, billing units, coverage limits) — the specifics vendor docs get wrong or omit.

**No-loss rule:** when guidance moves, it stays fully documented at its canonical layer and is linked from here — don't duplicate, link.

## Read the right doc BEFORE executing
SKILL.md routes; it does **not** hold the *how*. Before you call a paid tool, write a search payload, or push
to an ATS, **open the matching doc** — the recipes/playbooks encode validated filter shapes, costs, and
pitfalls from real runs. Skipping this re-discovers failures already solved (e.g. mis-nesting a provider
filter and pulling the entire DB). Reading more than one is normal and encouraged.

| When the task is… | Read first |
|---|---|
| Talk like a recruiter / what's the better next move / reframe recruitability | [`recruiter-craft.md`](recruiter-craft.md) (voice + vocabulary + full-funnel behaviour canon) |
| Construct a **Boolean / X-ray** search string | [`references/recruiter-playbooks/boolean-search.md`](references/recruiter-playbooks/boolean-search.md) (operators, `site:` X-ray, mapping onto `people_search`) |
| Source candidates / find people / build a shortlist | [`finding-companies-and-contacts.md`](finding-companies-and-contacts.md) (the sourcing stage: query shapes, company-scoping, single-source-default) |
| A **job description / spec** → candidate shortlist | [`recipes/jd-to-shortlist.md`](recipes/jd-to-shortlist.md) (parse → search + competitor-poach → qualify → enrich) |
| **Max coverage / talent map / "find the passive ones"** (source from every angle) | [`recipes/multi-strategy-sourcing.md`](recipes/multi-strategy-sourcing.md) (5 angles: structured ∥ semantic + tiered competitor map + lookalike + open-to-work intent → qualify → signal/enrich survivors) |
| **Cross-DB structured merge** (one title set across AI Ark · Lemlist · Prospeo) | [`recipes/multi-source-candidate-search.md`](recipes/multi-source-candidate-search.md) (gendered-title + location-superset gotchas → dedup by LinkedIn → qualify) |
| Match candidates to a job from the client's **OWN connected CRM/ATS candidate base** (a CRM is connected, or the user wants to draw on existing candidates) | [`recipes/crm-matching.md`](recipes/crm-matching.md) (prefilter on CRM taxonomy/custom fields → longlist broad → enrich w/ CRM notes/activities/interviews → AI score; combinable with net-new sourcing) |
| A **CV / candidate** → fitting open jobs + hiring manager (spec-out / MPC) | [`recipes/cv-to-jobs.md`](recipes/cv-to-jobs.md) (parse CV → job search → match → hiring manager → BD) |
| A **CV / candidate** → a full sequenced BD **campaign** across many companies (MPC Shot / candidate-led BD) | [`recipes/candidate-led-bd-campaign.md`](recipes/candidate-led-bd-campaign.md) (evergreen-candidate gate → scrape+lookalike fan-out → fit-match → CRM-first routing → poaching guard → approval gate → frontsheet + send) |
| Sourcing an **IT / engineering** role (devs) | [`recipes/it-sourcing.md`](recipes/it-sourcing.md) (GitHub ground-truth + people-DBs → qualify; free emails) |
| Qualify against a role / ICP | [`recipes/qualify-against-icp.md`](recipes/qualify-against-icp.md) (+ the client's `ICP.md`) |
| "Which companies are in my **TAM** / build a **target-account list**" | [`recipes/build-tam.md`](recipes/build-tam.md) (ICP → firmographic/people-first/lookalike sourcing → qualify → ICP-fit company list → opt. people) |
| Enrich for contact (email/phone/LinkedIn) | [`enriching-and-researching.md`](enriching-and-researching.md) + [`references/provider-precedence.md`](references/provider-precedence.md) |
| Push to an ATS/CRM, or sequence outreach | that tool's `provider-playbooks/<tool>.md` (auth + write methods + gates) |
| Build an outreach **sequence / campaign** (pick the cadence) | [`recipes/campaign-plays.md`](recipes/campaign-plays.md) (confirm cadence with the user → build idle → `start_campaign` is separately gated) |
| A **tradeshow / conference page** → BD on exhibitors (or speakers) | [`recipes/tradeshow-to-bd.md`](recipes/tradeshow-to-bd.md) (crawl exhibitors/speakers → ICP → hiring manager → pre-conference soft intro) |
| **Which companies are hiring for X** / find open roles (a hiring signal, often geo-scoped) | [`provider-playbooks/hyreflow_native.md`](provider-playbooks/hyreflow_native.md) — the first-party job scrapes are the default source: `linkedin_jobs` / `indeed_jobs` (title + location across companies), `career_pages` (one named company), and **`arbeitsagentur_jobs` FIRST for a Germany-scoped query** (German employers post there who never list on the global boards). Germany is the one geo with its own board — run it as a leg alongside the global ones, not as a fallback; elsewhere LinkedIn/Indeed/career pages are the full set. `theirstack` only when the query needs *its* filters (tech-stack / keyword-slug) rather than raw postings |
| Signal-driven BD (funding / hiring / layoffs) | the signal tool's `provider-playbooks/<tool>.md` + [`recipes/funding-to-bd.md`](recipes/funding-to-bd.md) (funding→BD) / [`recipes/layoff-signal-to-poach.md`](recipes/layoff-signal-to-poach.md) (layoffs) |
| A client's **LinkedIn connections export** → scored prospect DB + a weekly Dream 100 sweep | [`recipes/network-icp-qualification.md`](recipes/network-icp-qualification.md) (batch qualifier + Dream 100 build + weekly sweep, headless up to the human send) |
| Any credit-consuming or write action | the **Credit & approval gate** section below |
| Not sure which tool fits the intent | **start here:** `hyreflow tools search <intent>` (ranked flat tools) → then `hyreflow tools get <tool> <method>` for the exact payload — never guess |

If nothing matches, search the library: `grep -rl "<keyword>" recipes/ provider-playbooks/`.

## Sub-agents — parallel orchestration (preferred for non-trivial work)
Two sub-agent briefs live in [`agents/`](agents/). Delegate to them with your harness's subagent tool
instead of doing everything inline — they keep the main thread clean and run on a cheaper model. A
subagent starts with **no** conversation history, so pass the absolute path of the brief AND the
concrete task inputs when you spawn one:

- **`execution-plan-creator`** — turns a recruiting request into a concrete, session-step plan with an
  approval gate, before any paid run. Spawn it first for any multi-step task.
- **`list-builder`** — builds a candidate/company seed list via the **flat-tools** discovery path
  (pick provider → `tools execute <provider>_<search>` → dedup), stopping at the enrichment hand-off.
  Spawn it for the sourcing stage; for wide coverage, spawn several in parallel over disjoint
  provider/segment slices, then merge + dedup.

Trivial one-shot lookups (a single search, a single enrich) → just do it inline. Plan + source +
enrich at scale → orchestrate the sub-agents.

## Session plan — narrate every task (MANDATORY)
**Step zero of every task: publish your plan** so the user can watch progress live in the Playground.
Not optional — without it the UI shows nothing. **Before (or right after) `session start`, also say the
plan in prose, in the conversation** — one short paragraph in plain language naming which tools you'll
use, why, and what gets qualified against what, e.g. "I'll size the DACH pool with Prospeo (people-first,
free count), verify build artifacts on GitHub for free, qualify against the role must-haves, then only pay
to enrich personal emails for the finalists." Then execute. The step list is for the Playground; the prose
paragraph is for the user watching the conversation — post both, never the steps alone. This is what lets
the user sanity-check the approach before any tool runs or credits spend, instead of watching terse step
labels with no reasoning behind them.

**`session status --message` is client narration, not an engineering log.** Every message the user sees in
the Playground must read like a recruiter explaining what's happening and why, in one short plain-language
sentence — what you're searching, why, and what you found. **Never surface raw mechanics** — provider/tool
names, payload shapes, filter-probe internals, or credit math belong in your own reasoning and in the
terminal, not in a `session status`/`session update` message.
| Don't write (engineering log) | Write instead (plain language) |
|---|---|
| `"aiark returned 0 — falling back to apollo"` | `"That source had no matches — trying another to fill the gap."` |
| `"filter probe: employee_size 51-200 AND industry=saas → 0 rows"` | `"Narrowing to mid-size SaaS companies didn't return results — loosening the size range."` |
| `"charged 0.07cr × 42 rows via people_search"` | `"Found 42 growth-stage DACH peers of your seed accounts."` |
```bash
# 1) Post the plan (JSON array of short step labels) + the user's original ask.
#    Include an "Approval gate" step ONLY when a paid full run follows (see the rule below).
hyreflow session start --steps '["Recon: company + sizing","Pilot contact search (rows 0:1)","Approval gate","Full pull","Qualify + enrich","Validate + deliver"]' --user-prompt "find all people at Acme"
# A fully-free / trivially-cheap task has NO approval gate — e.g. a count/sizing only:
hyreflow session start --steps '["Size audience (free count)","Pull a small page","Build CSV","Deliver"]' --user-prompt "how many SWEs at Meta in the US"
# 2) Mark steps as you go (0-indexed)
hyreflow session update --index 0 --status running
hyreflow session update --index 0 --status completed       # statuses: pending|running|completed|error|skipped
# 3) Live sub-step updates within a running step (emergent work) — plain language, see table above
hyreflow session status --message "That source had no matches — trying another to fill the gap." [--step-index 1]
# 4) Register any CSV you write (outside enrich)
hyreflow session output --csv hyreflow/data/<slug>/<slug>.csv --label "Acme employees"
# 5) ONLY when the next step spends credits: raise the Playground banner BEFORE you ask in the terminal,
#    then clear it. Free steps never do this. The message MUST name the estimated credits.
hyreflow session alert --message "Approval needed: enrich 101 rows (~60 credits)"
hyreflow session alert --clear                              # (advancing the gate step also auto-clears it)
# 6) Inspect this session's spend / cap at any time (the user may set a $ limit in the Playground)
hyreflow session usage                                      # add --json for the raw payload
```
**On Windows, pass the plan as a file — don't fight the shell.** PowerShell strips the single quotes the
examples above use, so the JSON arrives unquoted and fails to parse, and the escaped-double-quote form
breaks again on ordinary parentheses inside a label (`"Size the pool (free)"`). Write the array to a file
and hand it over with `@`, which every JSON flag accepts (`--steps`, `--payload`, `--candidates`, `--arg`):

```powershell
Set-Content -Path steps.json -Encoding utf8 -Value '["Size the pool (free)","Pull a small page","Build CSV","Deliver"]'
hyreflow session start --steps "@steps.json" --user-prompt "how many SWEs at Meta in the US"
```

Keep the quotes around `"@steps.json"` in PowerShell — a bare `@name` there is the splatting operator and
fails to parse before the CLI ever runs. On POSIX shells `--steps @steps.json` is fine either way. Every
JSON flag also reads stdin when the value is `-` (`... | hyreflow tools execute people_search --payload -`),
which is the same quoting-proof path without a temp file; one value per command can read stdin.

Rules: post the plan **before** any tool/credit call; set step 0 to `running` right after; update as you go;
keep labels short (what, not how); keep `session status` messages plain-language (see the table above); don't
re-post `--steps` just to finish (it replaces the plan) — finish with `--update`. Re-post `--steps` only if
the plan structure truly changes. Say the prose paragraph once, up front — don't re-narrate it on every step
update.

`session start` opens the **local** Playground (`http://127.0.0.1:4173/?session_id=…`, no sign-in — the CLI
serves it and proxies to the engine with your stored key). Manage it with `hyreflow playground {open,stop,
status}`; use `session start --cloud` (or `HYREFLOW_PLAYGROUND=cloud`) for the hosted view instead.

## Structure
```
hyreflow-recruit/                    <- this skill package (installed to ~/.agents/skills/hyreflow-recruit)
  SKILL.md                       <- this router
  skill-metadata.json            <- doc kinds/tags map for the skill loader
  recruiter-craft.md             <- always-on: recruiter voice/vocab + full-funnel behaviour canon
  finding-companies-and-contacts.md
  enriching-and-researching.md
  writing-outreach.md
  prompts.json
  provider-playbooks/<tool>.md   <- per-tool playbook (auth, ops, guardrails, handoff)
  recipes/<task>.md              <- step-by-step task playbooks
  references/
    env-vars.md         <- every env var each adapter needs
    architecture.md     <- the pairing rule, adapter template, how to add a new tool
    provider-precedence.md  <- the channel/source waterfall + safety gates
    cost-card.md        <- per-operation credit costs
    field-notes.md      <- live-verified provider behaviour (API gotchas, plan gates, working payloads)
    recruiter-playbooks/  <- Boolean/X-ray search craft + intake for contributed recruiter research
```
The adapters (`lib/`) and the machine-readable call contract (`reference/tool-registry.json`) live
**server-side** in the hosted engine — you reach them through the `hyreflow` CLI / API, not local files.

## Tool catalog (42 playbooks — 38 adapters + 3 Hyreflow Natives + 1 parked)

> **Two tool classes.** **Adapters** wrap a third-party vendor API (BYOK or hyreflow-managed key; obey
> the provider-precedence waterfall). **Hyreflow Natives** are first-party capabilities with no external
> vendor — **always credit-metered, no BYOK key**, the high-margin strategic core. `kind` is tagged per
> tool in `reference/tool-registry.json`.

**Prospecting databases** — net-new search + enrich + signals
`apollo` · `zoominfo` (OAuth; enrich/search/intent/scoops, lookalikes & recommendations)

**Enrichment** — emails/phones/contact + company data
`lusha` · `leadmagic` · `icypeas` · `prospeo` · `fullenrich` · `bettercontact` · `wiza` · `exa` · `enrichley` (email validation)

**Data / sourcing** — search, scrape, actors, signals
`apify` (**BYOK-only** — needs the client's own Apify key; 0 credits, Apify bills them) · `aiark` · `firecrawl` · `serper` · `theirstack` (tech-stack / keyword-filtered job & company search, technographics, buying intent) · `predictleads` (funding rounds incl. Series A + job openings + tech detections — funding/hiring discovery) · `shovels` (US building permits + contractors — construction/trades) · `github` (developer sourcing — IT recruiting) · `clinicaltrials` (pharma/biotech/CRO hiring signals; no key) · `builtwith` (technographics — source/qualify companies by tech stack)

**Sequencers** — outreach activation
`instantly` (email) · `lemlist` (email+LinkedIn) · `heyreach` (LinkedIn) · `smartlead` (email) · `sendkit` (email, dedicated-IP deliverability) · `sourcewhale` (recruiting outreach)

**Recruiting CRMs / ATS** — the write targets
`recruit-crm` · `loxo` · `vincere` · `recruiterflow` · `atlas` · `bullhorn` · `spott` · `jobadder` (OAuth refresh-token; region base from token)

**Comms** — calls & meeting intelligence
`aircall` (phone) · `fathom` (meeting notetaker API) · `granola` (meeting notes) · `quil` (**parked — no public API**)

**Hyreflow Natives** — first-party, no external vendor, always credit-metered (no BYOK)
`layoffsignal` (layoff/RIF recruiting trigger — built on free public news RSS; poach displaced talent + BD signal) · `hyreflow_native` (first-party scrapers — (a) job scrapers for career pages, LinkedIn, Indeed, Arbeitsagentur; async launch→poll, pay-on-match per job, and (b) **LinkedIn post feeds** for a person or a company via `profile_posts`/`company_posts`; one call, per request, 50 posts a page — reach for these on "what has X been posting" or any launch/hiring/funding/exec-commentary signal) · `hyreflow-agent` (AI reasoning agent — OpenRouter model + adapter toolbelt; `infer` plain + `research` agentic; the metered reasoning layer for batch/headless — interactive reasoning stays free on the host agent)

> Read the matching `provider-playbooks/<tool>.md` before executing against any tool — it has the auth scheme,
> the typed methods, the pagination contract, and the approval gates. Don't guess params.

## Calling a tool — via the hosted engine (the `hyreflow` CLI)
You drive the **hosted engine** with the installed **`hyreflow` CLI**. **There is no local `lib/`,
`cli.py`, or `reference/` in this skill package** — the adapters + registry live server-side. **Do not
look for or run local Python**; if `hyreflow --version` works, you're ready.

Each `provider-playbooks/<tool>.md` ends with a **`## Callable surface`** block (the exact method names +
params + one-line behaviour). Read the method + args there, then run it through the CLI:
```bash
hyreflow tools list                                       # all tools
hyreflow tools get <tool> <method>                        # a method's inputs + cost (the call contract)
hyreflow tools execute <tool> <method> --payload '{...}'  # run it (auth + retries + metering handled)
hyreflow tools execute <tool> <method> --payload '{...}' --dry-run   # preview — no call, no charge
```
**Sourcing (find people) = the `people_search` waterfall tool (DEFAULT).** Call it like any tool —
one **canonical query** (`titles`, `locations`, `company_names`, `company_domains`, `seniority`, `limit`);
the engine walks the house provider order (see `reference/waterfalls.json`; first source to fill the
limit wins, thin sources top up) and owns dedup/paging/count. See
[`finding-companies-and-contacts.md`](finding-companies-and-contacts.md).
```bash
hyreflow tools execute people_search --payload '{"company_domains":["acme.com"],"person_locations":["United States"],"limit":5}'
```
**Enrichment (add email/phone) = waterfall** — multi-provider, first-hit-wins, meters on hit:
```bash
hyreflow enrich --input <csv|ds_id> [--output out.csv] [--rows 0:1] --with '{"alias","tool","payload"}' # tool=e.g. email_enrichment
hyreflow qualify --job @jd.md --candidates @cands.json [--min-score N]
```
> **Enrich the work history BEFORE you qualify.** A sourcing row carries the current title, employer and
> location only — run the `linkedin_profile` waterfall on the pool first and score on the dated
> `experience[]`. `qualify` refuses a batch in which no row carries work history (`no_work_history`) and
> reports `qualify.basis` (`work_history` | `title_only`) per candidate.

> **Flat single-provider tools are the ADVANCED path, not the default.** Drop to a provider's flat search
> (`hyreflow tools execute apollo_search_people --payload '{native filters}'`) only when you need
> provider-level control of the native filters, or the user names one provider — then YOU own
> dedup/count/top-up. Otherwise default to the `people_search` waterfall tool above.
>
> **No-result retries stay on the waterfall — and KEEP a title filter on.** If `people_search` returns too
> few rows for narrow titles, retry `people_search` by **expanding `titles[]` with more role variants**
> (see the canonical title lists in [`finding-companies-and-contacts.md`](finding-companies-and-contacts.md)
> §Title handling), and/or adding `seniority` or `skills` — **never by dropping `titles[]` entirely** to
> "filter client-side" instead. On a company-scoped search, removing `titles` pulls the ENTIRE roster
> (every function, plus self-declared-employer noise from people who merely list the company on LinkedIn)
> — expensive and imprecise versus a server-side title filter. Do not bypass the waterfall with
> `apollo_search_people` just because Apollo might have broader native coverage. Apollo flat tools are
> BYOK-only; use them only when the user intentionally asks for Apollo/provider-native control and Apollo
> BYOK is configured.

### Do not guess fields
Method names, paths, and params come from the contract — never invent them:
- Read the method's **`## Callable surface`** block in its `provider-playbooks/<tool>.md`, **or**
- query the live contract: **`hyreflow tools get <tool> <method>`** (inputs + cost).

Preview spend first with `--dry-run`; the CLI adds bearer auth, 429/5xx retries, and credit metering.

## The canonical pipeline
**source → qualify (ICP) → enrich → verify → sequence → push to ATS**, e.g.
`apollo`/`aiark`/`apify`/`theirstack` (find companies/people) → **qualify against the client's `ICP.md`
(see below)** → `leadmagic`/`prospeo`/`fullenrich` (waterfall email+phone) → `enrichley` (validate
deliverability) → `instantly`/`smartlead`/`sendkit`/`heyreach`/`lemlist`/`sourcewhale` (activate) →
`recruit-crm`/`bullhorn`/`loxo`/`vincere`/`recruiterflow`/`atlas` (land the record).
`aircall` + `fathom` close the loop on the conversation side (call logs, transcripts → ATS activity).
The same arc as recruiter **behaviour** (source → shortlist → outreach → slate, + BD/MPC + passive-poach)
— the decision at each stage and *why* — is in [`recruiter-craft.md`](recruiter-craft.md) §B.

## Recipes (sequenced playbooks)
Multi-tool flows have a step-by-step recipe in `recipes/` — follow it as the execution plan.
- [`recipes/qualify-against-icp.md`](recipes/qualify-against-icp.md) — **the qualify gate.** Run after any
  sourcing step, before spending on enrichment/outreach: filter the company set against the client's ICP.
- [`recipes/layoff-signal-to-poach.md`](recipes/layoff-signal-to-poach.md) — **layoff/RIF trigger.** Sweep
  layoff news (`layoffsignal` native) → extract → source the displaced talent → enrich → outreach (+ BD).
- [`recipes/it-sourcing.md`](recipes/it-sourcing.md) — **IT / developer sourcing.** Two legs, both carrying real
  volume: GitHub (free, ground-truth — skill proof + personal email + website/socials, impact-tiered) **+**
  people-DBs (breadth, to a `1.5×N` row target) → merge (GitHub wins a dedup tie) → optional Firecrawl+AI
  personal-site context → qualify. Role type picks the primary leg — infra/sysadmin roles are people-DB-only.
- [`recipes/jd-to-shortlist.md`](recipes/jd-to-shortlist.md) — **JD → candidate shortlist.** Parse a job spec →
  filters → source (general **+ prioritized competitor profiles**) → enrich the work history → qualify vs JD →
  enrich contact (personal email+LinkedIn).
  The most-requested recruiter flow; competitor-poach is a priority add-on, not exclusive.
- [`recipes/multi-strategy-sourcing.md`](recipes/multi-strategy-sourcing.md) — **max-coverage sourcing (5 angles).**
  The superset of jd-to-shortlist: structured ∥ **semantic (Exa)** + **tiered competitor talent map** (bench-
  concentration / raid-targets) + **lookalike** expansion + **open-to-work intent** → merge/dedup → **qualify (free)**
  → then spend signal scans + enrich on survivors only. Use for "leave no stone unturned", a talent/market map, or
  to catch the passive profiles structured filters miss.
- [`recipes/multi-source-candidate-search.md`](recipes/multi-source-candidate-search.md) — **cross-DB structured merge.**
  One title set across AI Ark · Lemlist · Prospeo with the gendered-title + location-superset gotchas → dedup by
  LinkedIn slug → qualify on profile text. The plain coverage-completion play (no semantic/competitor/intent angles —
  reach for `multi-strategy-sourcing` when you want those).
- [`recipes/crm-matching.md`](recipes/crm-matching.md) — **CRM Matching: match the client's OWN candidate base
  to a job.** A recognized branch alongside net-new sourcing, combinable with it. Prefilter on the CRM's own
  taxonomy/custom fields → longlist broad (location, title variations) → enrich with rich CRM context (CV, notes,
  activities, past interviews/applications, past jobs shortlisted for) → AI-score using that history, not just the
  profile. Route in whenever a CRM is connected and the user wants their existing candidates included.
- [`recipes/funding-to-bd.md`](recipes/funding-to-bd.md) — **funding → BD trigger.** Company raises →
  ICP check → find hiring managers (people_search wf) → work email (email_enrichment wf) → personalize →
  BD sequence → CRM. A pattern the agent composes from the capability waterfalls (not a hard-coded pipeline).
- [`recipes/build-tam.md`](recipes/build-tam.md) — **TAM / target-account mapping.** Resolve the ICP (ICP.md →
  derive from clients/Dream-100/CSV → NL) → source companies (firmographic filter **+** people-first reverse
  **+** lookalike-from-seeds) → count-first (TAM size) → **qualify** (hard filters → Model-A fuzzy-fit →
  ICP-driven web verification, industry-agnostic) → ICP-fit company list → **optional** people (HMs/candidates)
  → enrich → outreach/ATS. TAM membership = firmographic fit, **not** current hiring.
- [`recipes/cv-to-jobs.md`](recipes/cv-to-jobs.md) — **CV → fitting jobs → hiring manager (spec-out / MPC).**
  The inverse of jd-to-shortlist: parse a CV → search live open roles in the candidate's region (native
  LinkedIn + Indeed + Arbeitsagentur scrapes, no key required; StepStone via Apify is an optional additive
  DACH leg — needs the client's own Apify key) → match/score
  each job vs the CV → find the hiring manager
  (company-scoped people_search, **client-configured** size→title hierarchy + reporting-line-first) → work email →
  candidate-led BD. Channel = work email (pitching the candidate to the company).
- [`recipes/candidate-led-bd-campaign.md`](recipes/candidate-led-bd-campaign.md) — **MPC Shot: candidate → full
  BD campaign.** The multi-company, sequenced sibling of `cv-to-jobs.md`: an evergreen/one-paragraph-pitchable
  candidate gate → scraped roles **+** lookalike-company fan-out → fit-match (>75) → **CRM-first split**
  (existing clients route direct, enrich only net-new) → poaching/exclusion guard → mandatory human approval
  gate → anonymised frontsheet + teaser → sequencer send → reply classify (positive-rate, not reply-rate) →
  human spec-CV call. Candidate-triggered mirror of the signal→BD plays (`funding-to-bd.md`/`tradeshow-to-bd.md`).
- [`recipes/tradeshow-to-bd.md`](recipes/tradeshow-to-bd.md) — **event → BD.** Public exhibitor/speaker page →
  firecrawl extract companies (speakers: + person + talk topic) → resolve domains → qualify vs ICP → find the
  hiring decision-maker (company-scoped, size-adaptive) → work email → **pre-conference soft intro** ("coffee
  at `<event>`?"). Work-email/BD channel; run with lead time before the event date.
- [`recipes/campaign-plays.md`](recipes/campaign-plays.md) — **build a sequence/campaign.** The cadence is the
  client's call: prompt with 2-4 example plays (LinkedIn-only / multichannel / …) → confirm → build it idle
  (no sender/leads/start) → `start_campaign` is a separate, approval-gated send. Channel per the data
  (no email → LinkedIn-only; candidates → personal+LinkedIn, never work).
- [`recipes/network-icp-qualification.md`](recipes/network-icp-qualification.md) — **LinkedIn network →
  scored prospect DB → weekly Dream 100 sweep.** A client's Connections.csv export → pre-filter → enrich
  → deep screen (binary in/out vs a person-level `<client-slug>-network-icp.md`, never a score) → Airtable. Separately,
  a layered `people_search` build feeds a Dream 100 table; a weekly scheduled sweep suppresses (90-day),
  scores engagement, researches the top 10, and drafts invites in the client's voice — the human send is
  a hard gate (cap 20-25/day, no LinkedIn send automation, ever); already-connected targets warm-DM instead.

### The ICP qualify gate (Model A — runs on the host agent)
- The client's **`ICP.md`** is built once by **`/icp`** at onboarding and lives in the client's working
  directory (per-client **data**, NOT in this skill).
- Qualification is **agent reasoning** — the host agent reads `ICP.md` and scores companies.
  **No hyreflow server call, no OpenRouter, no credits for the judgment itself.** Hard firmographic
  filters run on data you already have (free); the LLM fuzzy-fit (via the `company-qualifier` agent or
  inline) runs only on survivors; enrichment runs only on the passes.
- Always gate **before** enrichment/sequencing so you never pay to process non-fit companies.

## Working directory & outputs — set up BEFORE any file write
**Never write run outputs (candidate CSVs, qualified lists, enriched data, research) to `%TEMP%`/`/tmp`,
or inside this skill package.**
- **Temp** is cleaned on reboot/cache-clear → the customer permanently loses paid enrichment output (real data-loss risk).
- **Inside `hyreflow.ai/`** is the shared product → outputs pollute it and leak between clients.

Your **first action** before any file write — create a descriptive, persistent working dir under
**`<cwd>/hyreflow/data/<task-slug>/`** (relative to the user's current project folder), and write the
CSV(s) there as `<task-slug>.csv`:

```bash
WORKDIR="hyreflow/data/<task-slug>" && mkdir -p "$WORKDIR"   # e.g. hyreflow/data/acme-employees
# PowerShell: $WORKDIR = "hyreflow/data/<task-slug>"; New-Item -ItemType Directory -Force $WORKDIR
# → outputs: hyreflow/data/acme-employees/acme_employees.csv
```

- The slug must **describe the task** (`acme-employees`, `munich-steuerfachwirt`, `gera-steuerfach-50km`)
  — no `mktemp`/random names; the customer has to find these later.
- Per-client work may nest under the client: `<cwd>/hyreflow/data/<client-slug>/<task-slug>/`.
- **Scratch files go here too**, never inside the skill package. Drive tools with the `hyreflow` CLI (above), not local scripts.
- State the output path back to the user so it's findable.

### Data / large files
- **Never `Read` a large candidate CSV into context** — it burns the window for zero output. Inspect shape
  first (row count, columns, a 2-row sample), then process row-by-row / in code.
- **Count-before-pay:** every people-DB exposes a total (AI Ark `totalElements`, Lemlist `total`,
  Prospeo `pagination.total_count`, JobAdder `Limit=0`) — peek it cheaply, estimate credits, decide depth.
  Never blind-paginate a paid source. **The count (and all vendor data) lives under `result`:** every
  `tools execute` response is the envelope `{ "_meta": {…}, "result": <vendor payload> }`, so read
  `result.totalElements` / `result.total` / `result.pagination.total_count`, not the top level — a
  top-level read returns `None` and the peek looks empty.
- Write outputs **plain UTF-8** (no BOM) so umlauts/accents survive and headers match the
  `{{token}}` names used in an `enrich` payload.
- **Never edit a source / user-provided file in place.** Write a new file in your workdir; only iterate on your *own* outputs.
- **Preserve lineage columns** (`sources`, profile URLs, tier) when merging/deduping across providers — that's how the user audits where each row came from.
- **Report, don't paste.** In chat send the output **path + a short summary** (counts, tiers), not pasted CSV rows, unless asked.

## Enrich engine & datasets — the scale path (run this, not row-by-row loops)
For any list work over ~5 rows, use `hyreflow enrich` — a **server-side, per-column** executor. Rows live
in a **dataset** (the CSV-equivalent, stored server-side); you work on **handles + samples** and never pull
all rows into context. This is how a 10k-row job stays out of the window.

```bash
# Pilot FIRST (rows 0:1) on the real file, check the shape, then scale.
hyreflow enrich --input hyreflow/data/<slug>/leads.csv --output hyreflow/data/<slug>/out.csv --rows 0:1 \
  --with '{"alias":"email","tool":"name_and_domain_to_email_waterfall","payload":{"first_name":"{{first_name}}","last_name":"{{last_name}}","domain":"{{domain}}"}}'
# Scale once the pilot looks right (drop --rows, or widen the range).
hyreflow enrich --input hyreflow/data/<slug>/leads.csv --output hyreflow/data/<slug>/out.csv \
  --with '{"alias":"email","tool":"name_and_domain_to_email_waterfall","payload":{...}}'
```

- **Step shape** (`--with`): `{"alias","tool","payload","extract_js?"}`. `{{column}}` in any payload string
  is filled from the row before the call. `alias` is the new column, plus four sibling columns per row
  (a miss leaves `alias` empty and `_status` says why):
  - `<alias>_source` — which provider step or tool supplied the value
  - `<alias>_status` — `hit`/`miss`/`skip`/`error`, or a more specific reason such as `no_identifier`
  - `<alias>_verified` — whether the value was verified, for capabilities that verify
  - `<alias>_charged` — credits charged for that alias on that row
- **Tool classes:** a provider/flat tool (e.g. `apollo_search_people`), a **play** capability
  (`email_enrichment`, `personal_email`, `people_search`, `linkedin_profile`), `run_javascript` (deterministic row transforms —
  `row` is in scope, e.g. `{"tool":"run_javascript","payload":{"code":"return row.email.split('@')[1]"}}`),
  or `hyreflow_agent` (AI: `payload.{model,prompt,jsonSchema}` — use only when JS/providers can't do it).
- **Waterfalls:** `--with-waterfall <column> … --end-waterfall` tries the steps in order, first non-null
  wins, only the hitting step is billed.
- **Chaining:** pass a dataset id back in — `--input ds_…` (or `--in-place`) — so search→enrich→enrich runs
  server-side without rows ever touching chat. `--input` also takes a local CSV (auto-uploaded to a dataset).
- **`--dry-run`/`--preview`:** show the interpolated payloads per step, no calls, no spend.
- **Inspect / deliver via handles, never by inlining:** `hyreflow dataset head <ds_id> -n 5` to peek;
  `hyreflow dataset download <ds_id> --out hyreflow/data/<slug>/<slug>.csv` to write the final CSV; then
  report the path + counts. Any result over ~50 rows from `search`/`tools execute` is auto-stored and
  returns a `dataset_id` + 5-row sample — treat the handle as the source of truth, do **not** ask the
  engine to re-emit all rows.

## Guardrails (apply to every tool)
- **Provider precedence (which key + which provider).** For substitutable capabilities (enrichment, people-search), walk the provider order — the client's `provider_order` override → else the house default — and for each provider use the **client's BYOK key first, else hyreflow's managed key, else skip**; fall to the next provider on a miss. **Apollo, Shovels, BuiltWith, ZoomInfo, and Apify are the exception: BYOK-only, no managed fallback for user workspaces.** Single-source tools (the client's ATS/sequencer) skip the order — use their instance (BYOK). Full rule + house defaults + per-client config shape: [references/provider-precedence.md](references/provider-precedence.md).
- **Keys: env only.** Never hardcode; never write a key to a file or commit. See env-vars.md.
- **Approval-gate writes & spend.** Any credit-consuming call or ATS/CRM/outreach write follows the
  **Credit & approval gate** protocol below (pilot one → approval message → full run). Prefer cheaper
  providers first; BYOK is free. Per-op credit costs live in each method's `cost` field in
  `reference/tool-registry.json` (see [references/cost-card.md](references/cost-card.md)).
- **No fabricated endpoints.** Adapters built from each vendor's real docs (cached under `reference/docs/<tool>/raw`).
  Where a path/auth was inferred from doc slugs, the tool's playbook flags "verify on first pilot".
- **Stack rules** (per Hyreflow defaults): Python-only; OpenRouter for LLM; InboxKit for mailboxes;
  the Hyreflow-built product is the strategic layer — the wrapped vendor API is an implementation detail.

## Credit & approval gate (paid actions)
Applies to **any credit-consuming call** (enrichment, paid search/reveal, signal pulls) and **any
ATS/CRM/outreach write**. BYOK reads the client owns are exempt from the spend gate, but writes still pilot-first.

### When NOT to gate (gate only on cost)
The approval gate exists to authorize **spend**. Gate (raise `session alert` + ask with your harness's
structured-question tool) **only before an action that charges credits**. Do **not** gate — no banner, no question, no "Approval gate"
plan step — for free/zero-cost work:
- free count/sizing peeks (`size:1`/`page:1`/`Limit=0` to read a total without paying),
- cached or local reads, CSV/file ops, plan/registry lookups,
- BYOK reads the client owns,
- any method whose cost block says **`unit: "free"`** in `reference/tool-registry.json` (`*.fetch_credit`,
  list/iter/get reads, masked search previews, async polls — ~most read-only methods).

**`credits: 0` alone does NOT mean free.** Read `unit` too, and gate unless it is `"free"`:
- `byok` — 0 hyreflow credits: the call runs on the client's own vendor account. Two different reasons to
  gate, so read which kind it is:
  - **Metered data** (Apollo, ZoomInfo, BuiltWith, Shovels) — each call burns their vendor credits. Real
    money → gate the spend.
  - **Their sequencer / ATS / CRM / meeting tool** (Instantly, Lemlist, HeyReach, Smartlead, SendKit,
    Recruit CRM, Recruiterflow, Loxo, Atlas, Fathom, Granola) — a flat plan, so a call costs no per-call
    money. Reads
    are free to make; gate the **write**, because it lands in their live account in front of candidates.
- `metered` / `runtime` / `token` — priced by usage (Apify, the LLM Native): no fixed per-call
  number, so quote an estimate and gate.
- `cost_path` present ⇒ the method is **request-priced** (Exa): the provider prices the request from what
  it asked for and reports that on the response, so `credits` is the base request and a bigger ask (more
  results, more content types, more pages) bills proportionally more. Quote the base, gate the bulk run.
- `variable` present ⇒ the method is **argument-priced**: an option raises the price (e.g.
  `prospeo_enrich_person(enrich_mobile=True)` bills 3.4 cr instead of 0.4). Budget with **`credits_max`**,
  never `credits`.

A provider being cheap or free *to hyreflow* is never a reason to skip the gate — the customer is billed
the price in the cost block regardless.

The `session alert` / approval **message must name the estimated credits** (e.g. "…(~3 credits)") — that
number is the whole reason the gate exists. If the estimate rounds to ~0, there is nothing to approve, so
skip the gate entirely. The pilot itself may cost a little, but the gate guards the **full run** after the
pilot, not the narrow pilot.

### Run order
1. **Pilot** on the narrowest scope — one record (`limit=1` / `size:1` / `page:1`, or a single id).
2. **Request explicit approval** (message format below).
3. **Full run only after the user approves.**

### Sizing
- Smaller sequential calls first; keep limits low and windows bounded before scaling.
- **Count-before-pay (the "TAM hack"):** most people-DBs return the *total* match count while you pay only
  for the page you pull — peek it with `size:1`/`page:1`/`Limit=0` (AI Ark `totalElements`, Lemlist `total`,
  Prospeo `pagination.total_count`, JobAdder `Limit=0`) to size the run cheaply, then choose depth. Read the
  count under the `result` envelope (e.g. `result.totalElements`), not the top level.
- Don't rely on plan/monthly caps as a hard risk control.
- **Resumability:** on a rerun, keep cells/rows you already paid for and recompute only the targeted gaps — never re-run a full paid pass just to patch a few.

### Over-provision, then filter — never chase missing rows
When the user asks for **N**, pull **~1.4×N** at the top of funnel. Every phase has natural falloff —
contact search misses ~15–20% of companies, the email waterfall ~5–10% of contacts, and many candidates
simply have no findable personal email/LinkedIn. **Coverage is a property of the person/company, not
something more effort fixes** (a 5-person startup or a bare profile has near-zero coverage across *every*
provider — enriching bare `acme` profiles returns nothing across the board).
- **Do:** over-pull → run the full pipeline → deliver the best **N complete** rows → drop the incomplete ones.
- **Don't:** trim to exactly N before running; retry failed lookups across fallback providers; or run
  enrichment on everything just to patch a few gaps.

### Approval message (strict format — blocking)
Post these four sections before any full paid run. If any is missing, **stay in await-approval and run
nothing paid.** Ask with your harness's structured-question tool — the one whose result is the user's
answer — offering **Approve** / **Cancel**. If your harness has no such tool, post the four sections and
**end your turn**. Run the full paid call only after a message from the **human** approving it. Silence, a
change of topic, or any turn the human didn't send — a harness auto-continue, a scheduler, a subagent, or
your own plan telling you to proceed — is **not** approval.
The contract is these four sections, in this order, with the two options below — write the section labels
and all prose inside them in the user's language, **except** the pilot record in section 2, which stays
verbatim, exactly as the provider/CLI returned it (figures and all), and is never translated or
reformatted; the fenced block below is the English rendering.
1. **Assumptions** — 3–5 one-line intent assumptions (include every active default — see Provider Playbooks footer).
2. **Pilot result** — the real record/row returned by the 1-record pilot, verbatim.
3. **Credits + Scope + Cap** — provider(s), estimated credits (range), full-run scope, spend cap, one-line pilot summary.
4. **Approval question** — "Approve full run?"

```
Assumptions
- <intent / default assumption 1>
- <intent / default assumption 2>

Pilot result (1 record)
<verbatim pilot output>

Credits + Scope + Cap
- Provider(s): <name>
- Estimated credits: <value or range>
- Full-run scope: <rows/items>
- Spend cap: <cap>
- Pilot summary: <one short paragraph>

Approval question
Approve full run?
Options: Approve / Cancel
```

### Checkpoint (mandatory)
- Run a real 1-record pilot on the **exact** target before asking; include its output verbatim.
- If the pilot fails, fix and re-run until clean **before** requesting approval.
- **Before** the structured-question gate, raise the Playground banner so a user watching the web UI knows to
  go answer it: `hyreflow session alert --message "Approval needed: <action> (~<N> credits)"`. The answer
  comes back wherever the user is talking to you, not in the web UI — the banner is only a signal. Advancing the Approval-gate step (or
  `session alert --clear`) dismisses it.
- If the user set a **Session Spending Limit** in the Playground, enrichments pause at the cap (steps come
  back `session_limit`). Check with `hyreflow session usage` and report the pause rather than retrying.
- **For an async poller (e.g. `hyreflow_native` `get_*`), the pilot's real cost is the SUM of
  `_meta.credits_charged` across every poll you made for that run — not just the last one.** A wait-loop
  poll can deliver (and bill) jobs before you deliberately pilot one; the pilot's own poll can then dedupe
  to `credits_charged: 0` while still reporting `_meta.already_billed > 0`. Check `hyreflow session usage`
  (or sum the polls yourself) so the approval message's "Estimated credits" and pilot summary reflect what
  was actually spent, not what the single most-recent call reported.

### Balances
Check the provider's own balance before a big run where one's exposed — e.g. `prospeo.account_information()`,
`theirstack.credit_balance()`, `wiza.get_credits()`, `lusha.get_usage()`. Estimate in **credits**, not dollars
— the credit→$ conversion depends on the hyreflow plan (pricing TBD). On the hosted engine, balance + top-up
live at the `code.hyreflow.ai` dashboard.

## Adding a new tool
See [references/architecture.md](references/architecture.md): find cheapest doc source → cache to
`reference/docs/<tool>/raw` → build `lib/<tool>.py` from the template → compile/import-check → write
`provider-playbooks/<tool>.md` → re-run `lib/__init__.py` generation so it's re-exported → **add an entry to the
Provider Playbooks index below.**

## Provider Playbooks
Open the matching playbook before executing against a tool — it has the auth scheme, typed methods,
pagination contract, cost notes, **and the gotchas**. The summaries here say only *what each tool is
for / when to reach for it*; the quirks live in the playbook. (Keep this list current when you add/verify a tool.)

- [aiark playbook](provider-playbooks/aiark.md)
  Summary: Use company & people search for prospecting, reverse-lookup to resolve a person from an email/phone, the mobile-phone finder for strong matches, and the async export / email-finder flows when you need verified emails.
  Last reviewed: 2026-06-02
- [aircall playbook](provider-playbooks/aircall.md)
  Summary: Use to sync phone activity into the ATS — list/search calls, pull transcription & summary, tag/comment calls, click-to-dial and send SMS.
  Last reviewed: 2026-06-01
- [apify playbook](provider-playbooks/apify.md)
  Summary: Use to run Apify Store actors (scrapers/automation) when a source-specific actor exists; prefer the sync run, and reach for it before generic web search when the source is already known (LinkedIn profiles/jobs, sites).
  Last reviewed: 2026-06-02
- [apollo playbook](provider-playbooks/apollo.md)
  Summary: Use search for free net-new previewing, then people/company enrichment when you need resolved emails/phones, plus CRM and sequence actions.
  Last reviewed: 2026-06-02
- [atlas playbook](provider-playbooks/atlas.md)
  Summary: Use as the Atlas ATS/CRM — push sourced/enriched candidates & leads, dedup companies/contacts, read projects (jobs) and opportunities (deals) as sourcing starting points.
  Last reviewed: 2026-07-14
- [bettercontact playbook](provider-playbooks/bettercontact.md)
  Summary: Use as a waterfall when you want email and/or phone across many providers in a single async job.
  Last reviewed: 2026-06-02
- [builtwith playbook](provider-playbooks/builtwith.md)
  Summary: Use to source companies by the technology they run (who-uses-tech-X), or to qualify/enrich one company's tech stack.
  Last reviewed: 2026-06-01
- [bullhorn playbook](provider-playbooks/bullhorn.md)
  Summary: Use as the Bullhorn ATS read/write target — search & query entities, and get/create/update candidates, jobs, companies and contacts.
  Last reviewed: 2026-06-01
- [clinicaltrials playbook](provider-playbooks/clinicaltrials.md)
  Summary: Use as a pharma/biotech/CRO hiring-signal source — find recruiting trials by sponsor/condition/phase and track changes that precede hiring (free, no key).
  Last reviewed: 2026-06-01
- [enrichley playbook](provider-playbooks/enrichley.md)
  Summary: Use to validate email deliverability (especially catch-all/risky addresses) before sequencing.
  Last reviewed: 2026-06-01
- [exa playbook](provider-playbooks/exa.md)
  Summary: Use for neural/semantic web search, fetching page text, finding lookalike pages/companies, and grounded cited answers for research — plus Exa Agent for async multi-hop research, list-building, and enrichment runs that return schema-validated structured JSON with citations.
  Last reviewed: 2026-07-05
- [fathom playbook](provider-playbooks/fathom.md)
  Summary: Use to pull meeting/call notes, transcripts, summaries and action items into the ATS/CRM.
  Last reviewed: 2026-06-01
- [firecrawl playbook](provider-playbooks/firecrawl.md)
  Summary: Use to scrape/crawl/map JS-rendered sites and extract structured data when a plain fetch can't see the content.
  Last reviewed: 2026-06-01
- [fullenrich playbook](provider-playbooks/fullenrich.md)
  Summary: Use as a waterfall when you need personal email + phone for a contact (the candidate channel); bulk, async.
  Last reviewed: 2026-06-01
- [github playbook](provider-playbooks/github.md)
  Summary: Use to source and skill-signal developers for IT recruiting (search users/repos/code, build GraphQL dossiers); pair with the enrichment waterfall for contact details.
  Last reviewed: 2026-06-01
- [granola playbook](provider-playbooks/granola.md)
  Summary: Use to read Granola meeting notes, transcripts and folders.
  Last reviewed: 2026-06-02
- [heyreach playbook](provider-playbooks/heyreach.md)
  Summary: Use to enroll LinkedIn leads into an existing campaign and manage LinkedIn outreach and inbox.
  Last reviewed: 2026-06-01
- [hyreflow-agent playbook](provider-playbooks/hyreflow-agent.md)
  Summary: Use the AI reasoning Native for **batch/headless** classify, extract, qualify, or agentic research (model + web toolbelt) — when you don't want the host agent looping per-row. Metered; powered by `prompts.json`.
  Last reviewed: 2026-06-02
- [icypeas playbook](provider-playbooks/icypeas.md)
  Summary: Use to find and verify emails (and run domain search) at scale, async.
  Last reviewed: 2026-06-01
- [instantly playbook](provider-playbooks/instantly.md)
  Summary: Use to push leads into cold-email campaigns and manage sending accounts, activation and analytics.
  Last reviewed: 2026-06-01
- [jobadder playbook](provider-playbooks/jobadder.md)
  Summary: Use as the JobAdder ATS read/write target — find/create/update candidates, jobs, companies and contacts, and attach candidates to jobs.
  Last reviewed: 2026-06-02
- [layoffsignal playbook](provider-playbooks/layoffsignal.md)
  Summary: Use as the first-party layoff/RIF trigger — surface displaced talent to poach and companies to pitch (Hyreflow Native, free, no BYOK).
  Last reviewed: 2026-06-01
- [hyreflow_native playbook](provider-playbooks/hyreflow_native.md)
  Summary: First-party job scrapers (career pages, LinkedIn, Indeed, Arbeitsagentur) — async launch→poll, pay-on-match per job (Hyreflow Native, credit-metered, no BYOK).
  Last reviewed: 2026-07-16
- [leadmagic playbook](provider-playbooks/leadmagic.md)
  Summary: Use to find/validate work & personal email, find mobiles, resolve email↔LinkedIn, and enrich companies.
  Last reviewed: 2026-06-01
- [lemlist playbook](provider-playbooks/lemlist.md)
  Summary: Use to activate email + LinkedIn outreach — build campaigns/sequences and add leads (activation only; not for enrichment).
  Last reviewed: 2026-06-02
- [loxo playbook](provider-playbooks/loxo.md)
  Summary: Use as the Loxo ATS — read/create jobs and people, and apply candidates to jobs.
  Last reviewed: 2026-06-01
- [lusha playbook](provider-playbooks/lusha.md)
  Summary: Use to enrich a known person/company, or to prospect (search → enrich) when you need verified emails and direct dials.
  Last reviewed: 2026-06-02
- [predictleads playbook](provider-playbooks/predictleads.md)
  Summary: Use to discover funding rounds (incl. Series A), job openings and tech adoption as funding/hiring signals.
  Last reviewed: 2026-06-02
- [prospeo playbook](provider-playbooks/prospeo.md)
  Summary: Use to find work emails & phones and to search people/companies for BD/work-email workflows (not for candidate channels — use fullenrich/leadmagic there).
  Last reviewed: 2026-06-02
- [quil playbook](provider-playbooks/quil.md)
  Summary: Parked — no public REST API; use its native ATS integrations or Fathom instead.
  Last reviewed: 2026-06-01
- [recruit-crm playbook](provider-playbooks/recruit-crm.md)
  Summary: Use as the Recruit CRM ATS — sync candidates, companies, contacts and jobs, and move candidates through the hiring pipeline.
  Last reviewed: 2026-06-01
- [recruiterflow playbook](provider-playbooks/recruiterflow.md)
  Summary: Use as the Recruiterflow ATS — list/get/add/update candidates and read jobs and contacts.
  Last reviewed: 2026-06-01
- [sendkit playbook](provider-playbooks/sendkit.md)
  Summary: Use to push leads into cold-email campaigns and check mailbox health/warmup/deliverability before sending.
  Last reviewed: 2026-08-28
- [serper playbook](provider-playbooks/serper.md)
  Summary: Use for Google search results (web/news/places/maps/scholar) and quick single-page scrapes before deeper extraction.
  Last reviewed: 2026-06-01
- [shovels playbook](provider-playbooks/shovels.md)
  Summary: Use to find active contractors via US building permits (construction/trades) — resolve a place, then pull its permits and contractors.
  Last reviewed: 2026-06-02
- [smartlead playbook](provider-playbooks/smartlead.md)
  Summary: Use to push leads into cold-email campaigns, build sequences, and manage sending accounts and analytics.
  Last reviewed: 2026-06-01
- [sourcewhale playbook](provider-playbooks/sourcewhale.md)
  Summary: Use to push candidates into recruiting outreach campaigns and to search/report on them.
  Last reviewed: 2026-06-01
- [spott playbook](provider-playbooks/spott.md)
  Summary: Use as the Spott ATS — sync candidates, clients, contacts and jobs, and move applications through the hiring pipeline.
  Last reviewed: 2026-06-01
- [theirstack playbook](provider-playbooks/theirstack.md)
  Summary: Use for tech-stack / keyword-filtered job and company search, technographic and buying-intent data — plain open-roles queries go to the Hyreflow native job scrapes instead.
  Last reviewed: 2026-06-01
- [vincere playbook](provider-playbooks/vincere.md)
  Summary: Use as the Vincere ATS — search/get/create/update candidates and search jobs, companies and contacts.
  Last reviewed: 2026-06-01
- [wiza playbook](provider-playbooks/wiza.md)
  Summary: Use to reveal emails & phones and run prospect searches (includes the personal-email candidate channel).
  Last reviewed: 2026-06-02
- [zoominfo playbook](provider-playbooks/zoominfo.md)
  Summary: Use for GTM data — enrich/search contacts & companies, pull intent/scoops, and find lookalikes & recommendations.
  Last reviewed: 2026-06-01

### Defaults
- Apply a tool's documented defaults when the user gives no value.
- User-specified values always override defaults.
- In approval messages, list every active default as an assumption (so the user can correct it before spend).

## Feedback & session sharing
- **Proactive issue reporting.** If a tool/playbook is wrong, a payload shape fails, or the docs misled
  you, report it via the **`/hyreflow-feedback`** skill (include the command + error). This is how the
  playbooks improve.
- **Always pass the user's ask to `session start --user-prompt`** — verbatim, as they phrased it, not a
  paraphrase. It's what makes a run's trace readable to the Hyreflow team when the user reports a problem:
  the ask, then the tools it drove.
- **Run traces are on by default** (`hyreflow telemetry on|off|status`) — one setting, covering both the
  tool calls a run makes and the ask that started it. If the user asks to stop being tracked, run
  `hyreflow telemetry off`; don't turn it back on for them. That setting covers this install; a workspace
  can also have recording pinned on or off for the whole workspace (a support arrangement), which outranks
  the local setting and which `telemetry status` doesn't read — so if the user needs it truly off
  everywhere, tell them to ask the Hyreflow team to clear the workspace pin.
