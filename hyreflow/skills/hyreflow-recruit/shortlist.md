# Screening and Shortlisting

**Opt-in.** The recipes score with `/qualify`, and that is the default — do not re-route them through
`/shortlist` on your own. Reach for the native screen when the USER asks for it, or when the pool is
large enough that a prose read per candidate is not worth it. This doc is how to run it well.

## `/shortlist` screens the pool. `/qualify` deep-dives the survivors.

| | `/shortlist` | `/qualify` |
|---|---|---|
| Call per row | one structured-decision call | one prose LLM read |
| Returns | `score, tier, categories{}, holistic, must_haves[]` | `score, summary, strengths[], gaps[]` |
| Reads like | numbers a filter can act on | a verdict a recruiter can act on |
| Run it on | the FULL enriched pool, up to 5000 rows a call | the survivors only |

When you do screen first, `/shortlist` is far cheaper and wider than a prose pass, so it is the right
tool for a big pool and the wrong one for a finalist. `/qualify` is the reverse: it writes the
evidence a human reads before picking up the phone, and it costs accordingly. For a pool small enough
to deep-dive outright, skip the screen — `/qualify` alone is fewer moving parts and better output.

**Ask before you qualify.** The screen has already ranked everyone. Qualifying means spending a
deeper read per finalist, so say what it buys in plain words and let the user pick the cut:

> "Screened all 340 — 28 came out tier_1. Qualifying writes a summary, strengths and gaps for each
> one, which is the bit you'd actually read before reaching out. Want that on the 28, or a smaller
> cut first?"

Both endpoints score on the history the row carries. **Enrich before you screen** — a sourcing row
has the current title, employer and location only, so run the `linkedin_profile` waterfall over the
pool first and screen on dated `experience[]`. A pasted resume in `profile.about` is also read in
full when no structured history is present. Each row reports its `basis`: `work_history`,
`resume_text`, or `title_only`. A batch where every row is `title_only` is refused (422
`no_work_history`); pass `allow_thin_profiles: true` for a pool that will never have richer evidence
(a referral list, for example) to rank it on the sourcing fields instead.

## The call

```
POST /shortlist {"job_spec": <JD text>,            # required
                 "candidates": [Person, …],        # required, or use "input": "ds_…"
                 "must_haves": ["…"],              # optional HARD GATES — ask the user first
                 "questions": {…},                 # optional: your own set, skips generation
                 "regenerate_questions": true,     # optional: replace this JD's stored set
                 "min_score": <0-10>}              # optional
```

Every screen runs in the background; there is no mode to pick. The call waits about 20 seconds for
it, then answers one of two ways:

- **Finished** — the ranking: `{run_id, status: "completed", candidates: [{row, full_name, title, …,
  shortlist: {score, tier, categories{}, holistic{}, must_haves[], basis}}], scored, count, _meta}`.
  Each ranked row carries who the candidate is, `row` (its position in `_meta.dataset_id`) and the
  verdict — not the profile you sent. The full rows are in the dataset.
- **Still running** — a handle: `{run_id, dataset_id, status, progress: {done, total},
  poll_after_s}`. Poll `GET /shortlist/runs/{run_id}` (over MCP: `hyreflow_shortlist` with just
  `run_id`) every `poll_after_s` seconds; it answers with the same ranking once the screen is done.
  The poll is free. **The first screen of a new job description always comes back this way**: it
  writes the question set first, which takes up to a couple of minutes.

Rows land in the dataset as they are scored, so nothing is lost if you disconnect — find the screen
again in the dataset list (`hyreflow_datasets_list`), named `shortlist: <first line of the JD>`.
Re-sending the identical call within 15 minutes returns the first screen (`_meta.replayed`, charged
0) rather than screening the pool again.

For a generated instrument, `_meta` carries `questions_source` (`generated`, `reused`, or
`regenerated_not_active` — a regeneration that graded worse than the stored set: it ranked this call,
and the stored set stays active), the `question_set` id, `instrument_unchecked` when the set was never
graded, `questions_asked`, `categories` and their weights, `generator_model`,
`instrument_check`, and `low_signal_questions` when any question barely varied. With `min_score`,
`_meta.filtered_out` counts the scored rows the filter removed.

## The question set is written for you

The decision model does not chat. It takes one `state` (the job spec + one candidate) and a set of
**typed questions**, evaluates each one independently against that state, and returns calibrated
numbers — no prose, nothing to parse. What you ask is what you get back, so the question set is the
whole instrument.

**You do not have to write it.** Post a `job_spec` with no `questions` and the engine generates the
instrument for that job: around 100 small yes/no questions grouped into ~8 weighted categories, plus
a job-shaped ladder. It is generated **once per job description**, validated, graded against two
anchors and stored; every later screen of the same JD reuses it (`questions_source: "reused"`), so
two pools screened for one role are ranked on the same questions and the second pays nothing to build
them. Reformatting the spec (whitespace, line breaks) keeps the set; editing its words writes a new one.

The set is the ruler, so a `min_score` threshold carries across screens that share a `question_set`
id and not across ones that do not. Pass `regenerate_questions: true` to replace a JD's set — when
`instrument_warning` flags it, or after the role itself changed — and re-set any threshold after.

**The instrument is graded before the pool is.** Along with the questions, the generator writes the
CV of an ideal candidate for the role. Two extra decision calls screen that CV and a deliberately
irrelevant profile through the new set. They come back in `_meta.instrument_check` as `ideal_mean`,
`null_mean` and `suspect_questions`.

That sweep exists for one failure nothing else can see: a question phrased backwards ("has **not**
shipped Python") returns a low probability for a strong candidate, and once it is averaged into a
category there is no way to tell it apart from a real weakness. A perfect-on-paper candidate should
not score low on a well-formed question, so anything they fail is listed. One or two misses on narrow
questions are normal; `instrument_warning` appears when the ideal candidate averages below 0.7 or fails
more than a tenth of the set. When it does, run the screen again with `regenerate_questions: true` or
pass your own questions before trusting the ranking.

**Write your own only when you need something the generator does not produce** — a `choice` question,
a second `score` ladder, an externally-agreed rubric you have to screen against verbatim. Pass
`questions: {<name>: {"type": …, "instructions": …, "criteria": …}}` and the engine sends it
untouched, skipping generation entirely. Three types:

### `score` — a graded ladder

`criteria` is 2–10 level descriptions, **worst first** (outside that range it is a 422
`bad_score_criteria`, refused before anything is charged). Write what each level looks like in this
job's terms. "Owns features end to end in a live system" is a level; "good" is not — and two rungs a
reader could not sort two real candidates between are one rung with extra words.

```json
"technical_depth": {
  "type": "score",
  "instructions": "Rate hands-on depth from the experience bullets: what they personally built, how complex, how much they owned. Ignore skills keyword lists, titles and company names. When torn between two levels, pick the lower.",
  "criteria": [
    "No roles where they wrote code — QA, IT support, PM or sales engineering only.",
    "Coding appears as coursework, bootcamp or tutorial projects. Nothing shipped to real users.",
    "Small scoped work inside someone else's design: bug fixes, minor features, CRUD screens. Also score here if you can't tell what they built.",
    "Owns features end to end in a live system, across two layers, with little supervision.",
    "Owns whole systems and makes architecture tradeoffs. Hard problems with numbers attached.",
    "Deep specialist with real breadth: OSS maintainer, systems internals, or org-wide architecture at scale."
  ]
}
```

Two things that lift accuracy a lot, both visible above: tell it **what to ignore** (titles, keyword
lists, company brand), and tell it **which way to round** when a profile sits between levels.

`instructions` may be an object when the question needs a fact to reason against — the model has no
clock, so a tenure question that doesn't carry the date will guess:

```json
"years_of_experience": {
  "type": "score",
  "instructions": {"question": "How many years of professional experience, as of today?",
                   "today": "<today's date>"},
  "criteria": ["None", "2 years", "4 years", "6 years", "8 years", "10+ years"]
}
```

### `noul` — a calibrated yes/no probability

Returns a probability, not a boolean, so you can act on how sure it is. `criteria` is optional
`{"true": …, "false": …}` and is worth writing whenever "yes" is ambiguous.

```json
"llm_experience": {
  "type": "noul",
  "instructions": "Does the candidate have experience developing LLM products?",
  "criteria": {"true": "Has built products or features powered by AI or LLMs",
               "false": "No evidence of building AI products"}
}
```

### `choice` — one bucket from a set

`criteria` is `{name: description, …}`. Describe each option well enough to pick between them; the
model returns the option plus its confidence.

```json
"career_progression": {
  "type": "choice",
  "instructions": "What type of career progression is shown?",
  "criteria": {"steady_growth": "Clear progression with increasing seniority",
               "lateral_moves": "Similar roles at different companies",
               "job_hopping": "Frequent changes with short tenure",
               "unclear": "Progression pattern is unclear"}
}
```

## What ranks, what gates, what just reports

1. **The CATEGORIES rank the pool.** Each category is the mean of its own questions; `score` is those
   category means, weighted, on a 0–10 scale. Rolling up per category first is deliberate: a flat
   average over all ~100 questions would make the score depend on how many questions the generator
   happened to write per dimension, and a set that spent 58 of 100 questions on one skill would rank
   a specialist in it about three points too high. Per-category numbers come back on every row under
   `shortlist.categories`, which is the part a recruiter actually reads.
2. **The ladder still runs, and reports.** The holistic `fit` question is still asked and comes back
   as `shortlist.holistic` — useful as a second opinion, and worth a look when it disagrees sharply
   with the composite. It does **not** decide the order. (When you supply your own `questions`, there
   are no categories, so your `score` question ranks exactly as before.)
3. **A `noul` named `must_have_1`, `must_have_2`, … is a HARD GATE.** Below 0.5 the row is `no_fit`
   whatever its score, and it comes back under `shortlist.must_haves` with its probability. Its
   `requirement` label is your `must_haves` entry when you passed one, otherwise the question's own
   `instructions`. **Generation never creates a gate** — a gate rejects people, so it stays something
   you asked for. With no `must_haves`, nothing is auto-rejected.
4. **Everything else reports without gating.** With a generated set the per-question probabilities are
   written to the output dataset and left out of the inline response — ~100 numbers a row is around
   900 tokens of context per candidate, and `categories` says the same thing in ten. Read the dataset
   when you want the question-by-question audit trail.

Tiers are code, not judgement, and any failed gate is `no_fit` whatever the score. On a generated
set they are drawn against the job's own ideal candidate: `tier_1` at ≥ 60% of the score the ideal
CV earns on this set, `tier_2` at ≥ 40% (`_meta.tier_thresholds` gives the numbers — about 5.5 and
3.7 for a typical set). A real pool rarely gets near the ideal: on 100 sourced engineers the best
scored 4.3, so expect a few `tier_2` and little `tier_1`, and read the ranking, not the label. A set
you wrote yourself keeps the fixed bars, `tier_1` ≥ 7.5 and `tier_2` ≥ 5. With `min_score`,
`candidates` holds every row at or above that score that passed every gate — the tier never filters;
a high score never overrides a failed must-have.
The poll applies the `min_score` the screen was sent with (`?min_score=` overrides it).

A row comes back `unscored`, and is reported in `_meta.not_scored` rather than ranked, when the batch
never reached it, when a gate came back **unanswered** (a blank is not a pass — it is not a rejection
either), or when too little of the instrument answered to rank on. None of those are silent.

## Reading the scores honestly

> **These figures were measured on the single-ladder scorer**, the one that ranked on one holistic
> `score` question — which is still exactly how a screen behaves when you supply your own `questions`.
> The generated multi-category composite has **not** been measured on a graded pool yet, so treat the
> shape of the advice below as sound and the specific numbers as not yet re-established for it.

Measured on a 52-candidate graded pool, screened live:

- **Ranking is the reliable part.** Rank correlation against a human ordering came out at ~0.93.
  Take the top N and you get close to the right N. That is what a screen is for.
- **The absolute number is not a grade.** Scores run generous — on that pool roughly 60% of a
  deliberately strong field landed `tier_1`. **`tier_1` is not your shortlist**; it is the pile you
  cut from. Set `min_score` from what the run actually returns, and re-set it whenever the
  instrument changes — a threshold does not carry across two different question sets.
- **It is deterministic.** The same profile screened repeatedly returns the same score.
- **One holistic question compresses the scale.** On that pool eight designed tiers collapsed onto
  about four distinguishable values, and a quarter of the field tied at exactly 10.0. That is the
  problem the generated composite exists to fix: ~100 fractional probabilities rolled up per category
  give a far finer scale than one ladder rung can.
- **Rungs need to describe distinguishable things, and more rungs is not automatically better.** The
  same pool on a 6-rung and a 10-rung ladder ranked equally well. What costs you resolution is two
  rungs a reader could not sort two candidates between, not the count. `_meta.score_levels` reports
  what the batch ranked on.
- **It answers what you asked, and nothing else.** No tenure question means job-hopping and a
  six-month stint cost a candidate nothing. On that pool the worst single miss was a strong engineer
  in the wrong stack scoring 9.7 — caught only by a gate, because nothing asked about the stack.
  Anything you want to count against someone has to be a question, which is most of the argument for
  letting the generator write a hundred of them.
- **Watch `_meta.low_signal_questions`.** A question nearly every candidate answers the same way
  costs tokens on every row and moves nobody in the ranking. They are reported, never silently
  reweighted: reweighting from the pool would make a candidate's score depend on who else happened
  to be in that request. Use it to improve a caller-supplied set or decide whether to run again.

**The two endpoints' scores do not mean the same thing.** They share the 0-10 range, and nothing
more. `/qualify` runs a fixed rubric that caps a candidate at 5 for any missing must-have and again
for a profile with no dated work history; a ladder you wrote measures whatever you described. On a
real pool, screening then qualifying the same 16 finalists ranked them at +0.05 Spearman — no
relationship. So: **rank on the screen, read `/qualify` for the evidence, and never re-sort your
shortlist by the qualify score or carry a `min_score` between the two.**

`/qualify` is also written for experienced hires. On a pool of students and interns it compresses
hard — every candidate loses points for having no dated work history, which is what being a student
means. The prose stays excellent and specific; the number stops discriminating. Read the `gaps`.

The failure mode worth internalising: a strong engineer in the **wrong stack** scored 9.7 on a
depth ladder — correctly, because depth was the question — and was only rejected by a
`must_have` gate at 0.02. **Put every disqualifying requirement in a gate.** A ladder ranks; only a
gate rejects.

**Draft the set, show it to the user before you spend on it, and screen on what they confirm.** A
pinned set makes the screen auditable: every number that comes back maps to a question someone
agreed to.

## `must_haves` — the gates, and only the gates

`must_haves: ["…"]` adds one hard gate per requirement, on top of whatever ranks. It is independent
of the question set: the generated instrument still does the ranking, and each must-have becomes a
`must_have_<n>` noul that can veto a row outright.

**Nothing is auto-gated.** Omit `must_haves` and no candidate is rejected on a requirement — they are
ranked, and you read the list. That is deliberate: a gate throws people away, so it should be
something a person asked for rather than something inferred from a job ad. **Ask the user whether
they want must-haves, and screen on what they confirm** — the JD usually implies several, and a
pinned list makes the screen auditable against something they agreed to.

Use gates only for requirements that genuinely disqualify. A hard gate on a nice-to-have silently
throws away good candidates: on a real 82-applicant pool, two gates eliminated 66 of them. At most 8
(a 9th is a 422 `too_many_must_haves`, not a silent truncation) — screen on the hard ones and judge
the rest in `/qualify`.

## Large pools

A large pool runs exactly like a small one, it just takes longer to finish — expect the handle and
poll it. Over MCP a pool over 1000 arrives as `input` (a `ds_` dataset: a CSV upload, or the output of
an earlier sourcing or enrich step), since a tool call carries at most 1000 inline rows; over the API
either form works:

```
POST /shortlist {…, "input": "ds_…"}   → {run_id, dataset_id, status, progress, poll_after_s}
GET  /shortlist/runs/{run_id}          → the same handle, then the ranking once status is "completed"
```

Rows carry their `shortlist` cell — including the `question_set` that ranked them — as they land,
checkpointed as the walk proceeds, so a crash resumes instead of re-charging. Up to 5000 candidates a
call (the next is a 422 `too_many_candidates`); above that, split the pool — the halves share the JD's
stored set, so their scores stay comparable.

## Cost and shape

Screening is one decision call per row and is cheap enough to run over the whole pool — that is the
entire point of the split. Asking ~100 questions instead of two costs very little more: the decision
model answers them in parallel, so they add tokens but almost no time.

Generating and grading the instrument is paid once per job description: the first screen of a JD
pays for one generation plus two anchor checks, every later screen of it pays for its rows only.

Check the exact number rather than quoting one from memory: `dry_run` (or `preview`) returns the call
count and the charge without spending anything.

Each row sends the job spec plus that candidate's profile text, both truncated to fit the model's
context. Very long profiles are cut, not rejected — another reason to screen on enriched history and
let `/qualify` read deeply.

## CLI

```bash
hyreflow shortlist --job @jd.md --candidates @pool.json [--must-haves '["…"]'] [--min-score N] [--dry-run]
hyreflow shortlist --job @jd.md --input ds_…                     # screen a dataset; results land in a
                                                                 # NEW ds_, the input is untouched
hyreflow shortlist --job @jd.md --input ds_… --questions @set.json    # screen on your own set
hyreflow shortlist --job @jd.md --input ds_… --regenerate-questions   # replace this JD's stored set
hyreflow shortlist --run enr_…                                   # follow an earlier screen to its ranking
hyreflow qualify   --job @jd.md --candidates @finalists.json [--async]
```

The CLI follows an unfinished screen to its ranking on its own (progress on stderr); `--no-wait`
prints the handle instead. `--job` and `--candidates` take inline text/JSON, `@FILE`, or `-` for stdin. **A leading `@` is what
makes it a path** — `--job jd.md` sends the literal string `jd.md` as the job spec. `--candidates`
is JSON, not CSV, and so is `--questions`.

## Over MCP

`hyreflow_shortlist` takes the same body as `POST /shortlist`.

**Sourced candidates — search, enrich, screen, by dataset id.** No candidate row passes through a tool
call, so this works the same for 10 people or 1000:

1. `hyreflow_tools_execute` `people_search` — the rows land in `_meta.dataset_id`.
2. `hyreflow_enrich_run` with `input` = that `ds_` id and `steps: [{"alias": "linkedin_profile",
   "tool": "linkedin_profile"}]` — it writes a NEW dataset (`_meta.dataset_id`) with each row's dated
   `experience[]`. The screen reads that enrich column directly; there is nothing to copy across.
3. Only when the user asks for a screen: `hyreflow_shortlist` with `input` = the enrich output's `ds_`
   id (steps 3-4 below). Enriching is its own step — never screen every enrich by default.

**Candidates from a CRM/ATS:**

1. Pull them with `hyreflow_tools_execute` (the CRM's `search_candidates` / `list_candidates` —
   see its provider playbook).
2. If the rows carry no work history, enrich them first — `hyreflow_enrich_run` with `input` when
   they are already in a dataset, else `hyreflow_tools_execute` `linkedin_profile` with `rows`; a
   pool with no history is refused.
3. `hyreflow_shortlist` with `dry_run: true` to quote, then the real call — `candidates` for the
   rows you hold, or `input` when an earlier step already put them in a `ds_` dataset.
4. If it comes back with `status: "running"` or `"queued"` (always, for a new job description), tell
   the user it is screening, wait `poll_after_s`, and call `hyreflow_shortlist` again with only
   `run_id` until it returns the ranking. The ranking carries the top 25 rows; all of them, full
   profiles included, are in `_meta.dataset_id` — read more with `hyreflow_dataset_read`, hand the
   file over with `hyreflow_dataset_export`. Never re-send the screen to "check on it" — poll the
   `run_id`.

A call over the spend threshold comes back `confirmation_required` with a quote; show the user the
cost, and repeat the identical call with the `confirm_token` once they approve.
