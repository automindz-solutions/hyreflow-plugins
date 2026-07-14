---
name: hyreflow-recruit
description: "Hyreflow's recruitment-automation harness — the umbrella over every tool adapter (enrichment, data/sourcing, sequencers, recruiting CRMs, comms). Use to find the right tool for a GTM/recruiting step, to wire a cross-tool pipeline (source → enrich → verify → sequence → push to ATS), or whenever the user names one of the tools below. Each adapter is a thin Python client calling the vendor API directly; keys run on hyreflow's managed credit system or the client's own (BYOK)."
---

# hyreflow.ai — Integration Harness (Meta Skill)

Hyreflow is a recruitment-automation harness: a unified adapter + playbook layer
over every external recruiting/GTM tool. Each tool gets a thin Python **adapter** (`lib/<tool>.py`,
the "hands") paired with a **playbook** (`provider-playbooks/<tool>.md`, the "brain").

## Step 0 — connect + check for updates (once per session, before anything else)

**CLI installed?** If `hyreflow` returns "command not found" (common when the skills came from the plugin
marketplace, not the CLI installer), install it + sign in:

```bash
npm install -g hyreflow --prefix "$HOME/.local" --silent --no-fund --no-audit  # sandbox-safe; plain `npm install -g hyreflow` in a normal terminal
export PATH="$HOME/.local/bin:$PATH"
# blocked npmjs.com → add `--registry https://recruit.hyreflow.ai/api/v2/npm/`; no Node → `curl -fsSL https://recruit.hyreflow.ai/api/v2/cli/install | bash -s -- --no-skills`
hyreflow auth login              # prints a sign-in link (relay it to the user) and returns
hyreflow auth wait --timeout 120 # completes approval; if it says "still pending", relay the link & re-run this
hyreflow auth status             # confirm you're connected
hyreflow -h                      # see available commands
```

npm ships the CLI only (no duplicate skills copy — you already have them via the plugin). Once connected, continue.

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

## Speak the recruiter's language (always on)
Talk like a sourcer/recruiter, not an operator: use the trade's vocabulary (shortlist, slate, Boolean
string, MPC, passive vs active, response/positive-reply rate, time-to-slate) and — at each stage —
**proactively name the better next action** a good recruiter would take, then offer it. *Proactive =
recommend in conversation; never silently auto-run a different or paid path — the Credit & approval gate
still binds, and you still meet the user where they are.* When a user doubts a candidate's recruitability,
**reframe around recruitability signals** (open-to-work, tenure, job-change cadence, seniority band)
rather than stalling. Full vocabulary, the proactive bounds, and the funnel behaviour canon live in
[`recruiter-craft.md`](recruiter-craft.md) — read it at session start.

## Automating a pipeline → `/hyreflow-workflows`
If the user wants to **automate, schedule, or wire a repeatable multi-step pipeline** (cron/webhook,
"every Monday…", "when X happens…", a reusable workflow), route to **`/hyreflow-workflows`** — it builds
either a native Hyreflow cloud workflow or an n8n workflow in the user's own n8n. Use this skill to
pick the right tool/endpoint for each step inside that workflow.

## Documentation hierarchy
- **L1 — `SKILL.md`** (this file): router — decision model, guardrails, credit/approval gates, where to read next.
- **L2 — `recruiter-craft.md`**: always-on — recruiter voice/vocabulary + the full-funnel behaviour canon (what to do next, and why); recipes point back to it.
- **L2 — `references/*.md`**: cross-cutting *how* — `provider-precedence.md`, `async-jobs.md`, `architecture.md`, `cost-card.md`, `env-vars.md`, `recruiter-playbooks/` (Boolean/X-ray craft + corpus intake).
- **L2.5 — `recipes/*.md`**: step-by-step task playbooks — when one matches, **follow it as your plan**.
- **L3 — `provider-playbooks/<tool>.md`**: per-provider auth, methods, gotchas + the auto-generated **Callable surface**.
- **Lab log — `references/field-notes.md`**: raw live-test discoveries → curate into the canonical L3 playbook.

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
| A **CV / candidate** → fitting open jobs + hiring manager (spec-out / MPC) | [`recipes/cv-to-jobs.md`](recipes/cv-to-jobs.md) (parse CV → job search → match → hiring manager → BD) |
| Sourcing an **IT / engineering** role (devs) | [`recipes/it-sourcing.md`](recipes/it-sourcing.md) (GitHub ground-truth + people-DBs → qualify; free emails) |
| Qualify against a role / ICP | [`recipes/qualify-against-icp.md`](recipes/qualify-against-icp.md) (+ the client's `ICP.md`) |
| "Which companies are in my **TAM** / build a **target-account list**" | [`recipes/build-tam.md`](recipes/build-tam.md) (ICP → firmographic/people-first/lookalike sourcing → qualify → ICP-fit company list → opt. people) |
| Enrich for contact (email/phone/LinkedIn) | [`enriching-and-researching.md`](enriching-and-researching.md) + [`references/provider-precedence.md`](references/provider-precedence.md) |
| Push to an ATS/CRM, or sequence outreach | that tool's `provider-playbooks/<tool>.md` (auth + write methods + gates) |
| Build an outreach **sequence / campaign** (pick the cadence) | [`recipes/campaign-plays.md`](recipes/campaign-plays.md) (confirm cadence with the user → build idle → `start_campaign` is separately gated) |
| A **tradeshow / conference page** → BD on exhibitors (or speakers) | [`recipes/tradeshow-to-bd.md`](recipes/tradeshow-to-bd.md) (crawl exhibitors/speakers → ICP → hiring manager → pre-conference soft intro) |
| Signal-driven BD (funding / hiring / layoffs) | the signal tool's `provider-playbooks/<tool>.md` + [`recipes/funding-to-bd.md`](recipes/funding-to-bd.md) (funding→BD) / [`recipes/layoff-signal-to-poach.md`](recipes/layoff-signal-to-poach.md) (layoffs) |
| Any credit-consuming or write action | the **Credit & approval gate** section below |
| Not sure which tool fits the intent | **start here:** `hyreflow tools search <intent>` (ranked flat tools) → then `hyreflow tools get <tool> <method>` for the exact payload — never guess |

If nothing matches, grep the library: `Grep pattern="<keyword>" path="recipes/" glob="*.md"` (or `path="provider-playbooks/"`).

## Sub-agents — parallel orchestration (preferred for non-trivial work)
Two Claude Code sub-agents live in [`agents/`](agents/). Spawn them (via the Task tool) instead of
doing everything inline — they keep the main thread clean and run on a cheaper model:

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
```bash
# 1) Post the plan (JSON array of short step labels) + the user's original ask.
#    Include an "Approval gate" step ONLY when a paid full run follows (see the rule below).
hyreflow session start --steps '["Recon: company + sizing","Pilot contact search (rows 0:1)","Approval gate","Full pull","Qualify + enrich","Validate + deliver"]' --user-prompt "find all people at Acme"
# A fully-free / trivially-cheap task has NO approval gate — e.g. a count/sizing only:
hyreflow session start --steps '["Size audience (free count)","Pull a small page","Build CSV","Deliver"]' --user-prompt "how many SWEs at Meta in the US"
# 2) Mark steps as you go (0-indexed)
hyreflow session update --index 0 --status running
hyreflow session update --index 0 --status completed       # statuses: pending|running|completed|error|skipped
# 3) Live sub-step updates within a running step (emergent work)
hyreflow session status --message "aiark returned 0 — falling back to apollo" [--step-index 1]
# 4) Register any CSV you write (outside enrich)
hyreflow session output --csv hyreflow/data/<slug>/<slug>.csv --label "Acme employees"
# 5) ONLY when the next step spends credits: raise the Playground banner BEFORE you ask in the terminal,
#    then clear it. Free steps never do this. The message MUST name the estimated credits.
hyreflow session alert --message "Approval needed: enrich 101 rows (~20 credits)"
hyreflow session alert --clear                              # (advancing the gate step also auto-clears it)
# 6) Inspect this session's spend / cap at any time (the user may set a $ limit in the Playground)
hyreflow session usage                                      # add --json for the raw payload
```
Rules: post the plan **before** any tool/credit call; set step 0 to `running` right after; update as you go;
keep labels short (what, not how); don't re-post `--steps` just to finish (it replaces the plan) — finish
with `--update`. Re-post `--steps` only if the plan structure truly changes. Say the prose paragraph once,
up front — don't re-narrate it on every step update.

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
    field-notes.md      <- running log of LIVE-TEST discoveries (API gotchas, plan gates, working payloads)
    recruiter-playbooks/  <- Boolean/X-ray search craft + intake for contributed recruiter research
```
The adapters (`lib/`) and the machine-readable call contract (`reference/tool-registry.json`) live
**server-side** in the hosted engine — you reach them through the `hyreflow` CLI / API, not local files.

## Tool catalog (38 playbooks — 35 adapters + 2 Hyreflow Natives + 1 parked)

> **Two tool classes.** **Adapters** wrap a third-party vendor API (BYOK or hyreflow-managed key; obey
> the provider-precedence waterfall). **Hyreflow Natives** are first-party capabilities with no external
> vendor — **always credit-metered, no BYOK key**, the high-margin strategic core. `kind` is tagged per
> tool in `reference/tool-registry.json`.

**Prospecting databases** — net-new search + enrich + signals
`apollo` · `zoominfo` (OAuth; enrich/search/intent/scoops, lookalikes & recommendations)

**Enrichment** — emails/phones/contact + company data
`lusha` · `leadmagic` · `icypeas` · `prospeo` · `fullenrich` · `bettercontact` · `exa` · `enrichley` (email validation)

**Data / sourcing** — search, scrape, actors, signals
`apify` · `aiark` · `firecrawl` · `serper` · `theirstack` (hiring/intent signals) · `predictleads` (funding rounds incl. Series A + job openings + tech detections — funding/hiring discovery) · `shovels` (US building permits + contractors — construction/trades) · `github` (developer sourcing — IT recruiting) · `clinicaltrials` (pharma/biotech/CRO hiring signals; no key) · `builtwith` (technographics — source/qualify companies by tech stack)

**Sequencers** — outreach activation
`instantly` (email) · `lemlist` (email+LinkedIn) · `heyreach` (LinkedIn) · `smartlead` (email) · `sourcewhale` (recruiting outreach)

**Recruiting CRMs / ATS** — the write targets
`recruit-crm` · `loxo` · `vincere` · `recruiterflow` · `bullhorn` · `jobadder` (OAuth refresh-token; region base from token)

**Comms** — calls & meeting intelligence
`aircall` (phone) · `fathom` (meeting notetaker API) · `quil` (**parked — no public API**)

**Hyreflow Natives** — first-party, no external vendor, always credit-metered (no BYOK)
`layoffsignal` (layoff/RIF recruiting trigger — built on free public news RSS; poach displaced talent + BD signal) · `hyreflow-agent` (AI reasoning agent — OpenRouter model + adapter toolbelt; `infer` plain + `research` agentic; the metered reasoning layer for batch/headless — interactive reasoning stays free on the customer's Claude)

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
the engine walks the house provider order **aiark → prospeo → lemlist → apollo** (first source to fill the
limit wins, thin sources top up) and owns dedup/paging/count. See
[`finding-companies-and-contacts.md`](finding-companies-and-contacts.md).
```bash
hyreflow tools execute people_search --payload '{"company_domains":["meta.com"],"person_locations":["United States"],"limit":5}'
```
**Enrichment (add email/phone) = waterfall** — multi-provider, first-hit-wins, meters on hit:
```bash
hyreflow enrich --input <csv|ds_id> [--output out.csv] [--rows 0:1] --with '{"alias","tool","payload"}' # tool=e.g. email_enrichment
hyreflow qualify --job @jd.md --candidates @cands.json [--min-score N]
```
> **Flat single-provider tools are the ADVANCED path, not the default.** Drop to a provider's flat search
> (`hyreflow tools execute apollo_search_people --payload '{native filters}'`) only when you need
> provider-level control of the native filters, or the user names one provider — then YOU own
> dedup/count/top-up. Otherwise default to the `people_search` waterfall tool above.
>
> **No-result retries stay on the waterfall.** If `people_search` returns 0 rows for narrow titles, retry
> `people_search` with broader `titles[]`, `seniority`, or function keywords. Do not bypass the waterfall
> with `apollo_search_people` just because Apollo might have broader native coverage. Apollo flat tools are
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
deliverability) → `instantly`/`smartlead`/`heyreach`/`lemlist`/`sourcewhale` (activate) →
`recruit-crm`/`bullhorn`/`loxo`/`vincere`/`recruiterflow` (land the record).
`aircall` + `fathom` close the loop on the conversation side (call logs, transcripts → ATS activity).
The same arc as recruiter **behaviour** (source → shortlist → outreach → slate, + BD/MPC + passive-poach)
— the decision at each stage and *why* — is in [`recruiter-craft.md`](recruiter-craft.md) §B.

## Recipes (sequenced playbooks)
Multi-tool flows have a step-by-step recipe in `recipes/` — follow it as the execution plan.
- [`recipes/qualify-against-icp.md`](recipes/qualify-against-icp.md) — **the qualify gate.** Run after any
  sourcing step, before spending on enrichment/outreach: filter the company set against the client's ICP.
- [`recipes/layoff-signal-to-poach.md`](recipes/layoff-signal-to-poach.md) — **layoff/RIF trigger.** Sweep
  layoff news (`layoffsignal` native) → extract → source the displaced talent → enrich → outreach (+ BD).
- [`recipes/it-sourcing.md`](recipes/it-sourcing.md) — **IT / developer sourcing.** Two legs: GitHub (free,
  ground-truth — skill proof + personal email + website/socials, impact-tiered) **+** people-DBs (breadth) → merge
  (GitHub prioritised) → optional Firecrawl+AI personal-site context → qualify. Use for any engineering role.
- [`recipes/jd-to-shortlist.md`](recipes/jd-to-shortlist.md) — **JD → candidate shortlist.** Parse a job spec →
  filters → source (general **+ prioritized competitor profiles**) → qualify vs JD → enrich (personal email+LinkedIn).
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
- [`recipes/funding-to-bd.md`](recipes/funding-to-bd.md) — **funding → BD trigger.** Company raises →
  ICP check → find hiring managers (people_search wf) → work email (email_enrichment wf) → personalize →
  BD sequence → CRM. A pattern the agent composes from the capability waterfalls (not a hard-coded pipeline).
- [`recipes/build-tam.md`](recipes/build-tam.md) — **TAM / target-account mapping.** Resolve the ICP (ICP.md →
  derive from clients/Dream-100/CSV → NL) → source companies (firmographic filter **+** people-first reverse
  **+** lookalike-from-seeds) → count-first (TAM size) → **qualify** (hard filters → Model-A fuzzy-fit →
  ICP-driven web verification, industry-agnostic) → ICP-fit company list → **optional** people (HMs/candidates)
  → enrich → outreach/ATS. TAM membership = firmographic fit, **not** current hiring.
- [`recipes/cv-to-jobs.md`](recipes/cv-to-jobs.md) — **CV → fitting jobs → hiring manager (spec-out / MPC).**
  The inverse of jd-to-shortlist: parse a CV → search live open roles in the candidate's region (DACH job-board
  trio: LinkedIn + StepStone + Indeed via Apify) → match/score each job vs the CV → find the hiring manager
  (company-scoped people_search, **client-configured** size→title hierarchy + reporting-line-first) → work email →
  candidate-led BD. Channel = work email (pitching the candidate to the company).
- [`recipes/tradeshow-to-bd.md`](recipes/tradeshow-to-bd.md) — **event → BD.** Public exhibitor/speaker page →
  firecrawl extract companies (speakers: + person + talk topic) → resolve domains → qualify vs ICP → find the
  hiring decision-maker (company-scoped, size-adaptive) → work email → **pre-conference soft intro** ("coffee
  at `<event>`?"). Work-email/BD channel; run with lead time before the event date.
- [`recipes/campaign-plays.md`](recipes/campaign-plays.md) — **build a sequence/campaign.** The cadence is the
  client's call: prompt with 2-4 example plays (LinkedIn-only / multichannel / …) → confirm → build it idle
  (no sender/leads/start) → `start_campaign` is a separate, approval-gated send. Channel per the data
  (no email → LinkedIn-only; candidates → personal+LinkedIn, never work).

### The ICP qualify gate (Model A — runs on the customer's Claude)
- The client's **`ICP.md`** is built once by **`/icp`** at onboarding and lives in the client's working
  directory (per-client **data**, NOT in this skill).
- Qualification is **agent reasoning** — the customer's own Claude reads `ICP.md` and scores companies.
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
- Write outputs **UTF-8 (BOM for Excel)** so umlauts/accents survive.
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
  is filled from the row before the call. `alias` is the new column.
- **Tool classes:** a provider/flat tool (e.g. `apollo_search_people`), a **play** capability
  (`email_enrichment`, `personal_email`, `people_search`), `run_javascript` (deterministic row transforms —
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
- **Provider precedence (which key + which provider).** For substitutable capabilities (enrichment, people-search), walk the provider order — the client's `provider_order` override → else the house default — and for each provider use the **client's BYOK key first, else hyreflow's managed key, else skip**; fall to the next provider on a miss. **Apollo is the exception: BYOK-only, no managed fallback for user workspaces.** Single-source tools (the client's ATS/sequencer) skip the order — use their instance (BYOK). Full rule + house defaults + per-client config shape: [references/provider-precedence.md](references/provider-precedence.md).
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
The approval gate exists to authorize **spend**. Gate (raise `session alert` + ask via `AskUserQuestion`)
**only before an action that charges credits**. Do **not** gate — no banner, no question, no "Approval gate"
plan step — for free/zero-cost work:
- free count/sizing peeks (`size:1`/`page:1`/`Limit=0` to read a total without paying),
- cached or local reads, CSV/file ops, plan/registry lookups,
- BYOK reads the client owns,
- any method whose `cost.credits == 0` in `reference/tool-registry.json` (free providers, `*.fetch_credit`,
  list/iter/get reads — ~most read-only methods).

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
provider — we saw this live: enriching the bare Gera profiles returned nothing).
- **Do:** over-pull → run the full pipeline → deliver the best **N complete** rows → drop the incomplete ones.
- **Don't:** trim to exactly N before running; retry failed lookups across fallback providers; or run
  enrichment on everything just to patch a few gaps.

### Approval message (strict format — blocking)
Post these four sections before any full paid run. If any is missing, **stay in await-approval and run
nothing paid.** Use the **AskUserQuestion** tool for the gate.
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
```

### Checkpoint (mandatory)
- Run a real 1-record pilot on the **exact** target before asking; include its output verbatim.
- If the pilot fails, fix and re-run until clean **before** requesting approval.
- **Before** the `AskUserQuestion` gate, raise the Playground banner so a user watching the web UI knows to
  look at the terminal: `hyreflow session alert --message "Approval needed: <action> (~<N> credits)"`. The
  answer is given **in the terminal** — the banner is only a signal. Advancing the Approval-gate step (or
  `session alert --clear`) dismisses it.
- If the user set a **Session Spending Limit** in the Playground, enrichments pause at the cap (steps come
  back `session_limit`). Check with `hyreflow session usage` and report the pause rather than retrying.

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
  Summary: Use the AI reasoning Native for **batch/headless** classify, extract, qualify, or agentic research (model + web toolbelt) — when you don't want the customer's Claude looping per-row. Metered; powered by `prompts.json`.
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
  Summary: Use as the first-party layoff/RIF trigger — surface displaced talent to poach and companies to pitch (Hyreflow Native, credit-metered, no BYOK).
  Last reviewed: 2026-06-01
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
- [theirstack playbook](provider-playbooks/theirstack.md)
  Summary: Use for hiring-signal, technographic and buying-intent data on jobs and companies.
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
- **Telemetry is opt-in.** Prompt sharing with the Hyreflow team is controlled by `hyreflow telemetry`
  (stored as `prompt_sharing` in `~/.hyreflow/config.json`). Only attach the user's prompt to
  `session start --user-prompt` for telemetry when sharing is enabled; otherwise keep it local.
