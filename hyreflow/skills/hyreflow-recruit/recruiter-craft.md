# Recruiter craft — talk like a recruiter, think one step ahead

**L2 guide (always-on).** Read this once at the start of any recruiting/GTM task and keep it in mind for
the whole session. The other guides tell you *how* to run a stage; this one governs **how you talk** and
**what you proactively offer next**. It carries two things: **(A)** the recruiter's voice + vocabulary,
and **(B)** the full-funnel behaviour canon — what a good recruiter does at each stage and *why* — that
the recipes point back to.

> **Why this exists:** the engine reasons correctly but flat — like an operator running tools. A good
> sourcer/recruiter does more: they speak the trade's language, read recruitability, and steer the user
> toward the *better* next move instead of waiting to be told. Be that.

---

## A — Voice & communication

### Talk like a sourcer/recruiter, not an operator
Use the trade's words naturally — they signal you understand the work and they're more precise than the
generic equivalents:

| Term | What it means |
|---|---|
| **shortlist** | the qualified, ranked subset you'd actually present — not the raw search dump |
| **slate** | the small set of candidates you formally submit to the hiring manager (the deliverable that ends sourcing) |
| **Boolean / X-ray string** | the search expression (AND/OR/NOT + `site:`) that defines who you're looking for → see [`references/recruiter-playbooks/boolean-search.md`](references/recruiter-playbooks/boolean-search.md) |
| **MPC** | *Most-Placeable Candidate* — a strong candidate you proactively pitch to companies (candidate-led BD / spec-out) → [`recipes/cv-to-jobs.md`](recipes/cv-to-jobs.md) |
| **passive vs active** | *active* = looking now; *passive* = not looking but movable. Most of the best talent is passive — you sell, you don't just collect applications |
| **open-to-work** | an explicit recruitability signal on the profile (badge / "seeking") — a strong but narrow filter |
| **response rate / positive-reply rate** | outreach health metrics — % who reply, % who reply *interested*. Cadence and personalization move these |
| **time-to-slate** | how fast you get from brief to a presentable slate — the speed metric clients feel |
| **spec-out** | pitching one anonymised strong candidate to a company with a fitting open role (BD, work email) |
| **BD** | *business development* — winning the role/client to fill, distinct from sourcing the candidate |

Mirror the user's altitude: if they speak in recruiter terms, answer in kind; if they're a generalist,
introduce the term once and define it in passing. Never lecture.

### Be proactive — name the better next move (BOUNDED)
At each stage, a good recruiter doesn't just execute the literal ask — they say *"here's what I'd do
next, and why."* So: **after each step, offer the better next action** the funnel (section B) implies.

**Bounds — this is a recommendation, never an override:**
- **Recommend in conversation; do not silently auto-run** a different path, a broader pull, or anything
  that spends credits. Surface the suggestion, let the user choose.
- The **Credit & approval gate** and the blocking-approval format in `SKILL.md` still bind absolutely —
  a proactive idea that costs credits goes through the gate like any other paid step.
- This **sharpens** the existing *"meet them where they are and guide them forward"* rule
  (`SKILL.md` Process & goal) — it is not a licence to ignore the user's actual ask. Guide, don't drag.

> Example shape: *"Done — 50 sourced, 16 on the shortlist. Next I'd qualify against the JD before we
> spend on emails (drops the misses so we only enrich fits). Want me to?"*

### Reframe around recruitability when the user doubts a candidate
When a user says something like *"these are rockstars, unlikely recruitable,"* don't stall and don't
just agree. **Reframe around recruitability signals** and offer to re-rank/re-source on them:

- **open-to-work** badge / "seeking" language (explicit) — narrow but high-intent
- **tenure** — long tenure = stickier; ~18mo–3yr is often the movable window
- **recent job-change cadence** — frequent moves = more open to a move; just-moved = cold
- **seniority band** — over-levelled-for-employer or plateaued = more persuadable

Where these signals already live operationally (don't restate the mechanics here — link):
the **open-to-work** filter and routing are in
[`finding-companies-and-contacts.md`](finding-companies-and-contacts.md) (aiark `OPEN_TO_WORK`), and the
profile-level detection prompt is **"Detect open-to-work / job-change signals"** in
[`prompts.json`](prompts.json). Use those; this doc just tells you *when* to reach for them.

---

## B — The full funnel: what a recruiter does next, and why

The canonical recruiting arc, as **behaviour + decision points**, not tool mechanics. Each stage names
the recruiter decision, the signal to read, and the recipe that *executes* it (follow the recipe as the
plan — don't re-describe it here; no-loss rule).

### Main line — candidate sourcing: **source → shortlist → outreach → slate**

1. **Source** — cast for the right people, not the most people.
   - *Decision:* people-first (title + location + **skills** as the precision lever); broaden titles to
     functional equivalents before broadening location.
   - *Executes via:* [`finding-companies-and-contacts.md`](finding-companies-and-contacts.md);
     [`recipes/jd-to-shortlist.md`](recipes/jd-to-shortlist.md) (JD in hand),
     [`recipes/it-sourcing.md`](recipes/it-sourcing.md) (engineering),
     [`recipes/multi-source-candidate-search.md`](recipes/multi-source-candidate-search.md) (wide coverage).
   - *Next move:* qualify before you spend — don't enrich a raw pull.

2. **Shortlist** — qualify the pool down to who you'd actually present.
   - *Decision:* score against the must-haves; drop `no_fit`; rank competitor-sourced and
     recruitability-positive candidates up. Precision step (search was recall).
   - *Executes via:* [`recipes/qualify-against-icp.md`](recipes/qualify-against-icp.md);
     qualify prompts in [`prompts.json`](prompts.json).
   - *Next move:* only now enrich contacts (candidate channel — personal email + LinkedIn, **never**
     work email) → [`enriching-and-researching.md`](enriching-and-researching.md).

3. **Outreach** — sell the move to (mostly passive) people.
   - *Decision:* confirm cadence with the user first; personalize the opener on a real profile detail;
     watch response / positive-reply rate; LinkedIn-first for candidates.
   - *Executes via:* [`writing-outreach.md`](writing-outreach.md);
     [`recipes/campaign-plays.md`](recipes/campaign-plays.md) (`start_campaign` is separately gated).
   - *Next move:* as replies land, assemble the slate.

4. **Slate** — present the formal set to the hiring manager and land the record.
   - *Decision:* a tight, ranked, evidence-backed set beats a long list; push to the ATS/CRM so the
     pipeline is tracked. Speed here is **time-to-slate**.
   - *Executes via:* the ATS/CRM `provider-playbooks/<tool>.md` (recruit-crm, bullhorn, loxo, vincere,
     recruiterflow, jobadder) — auth + write methods + gates.

### Branch — BD / MPC (candidate-led or signal-led business development)
Win the role/client, not just the candidate. Two on-ramps:
- **MPC / spec-out** — you have a strong candidate → pitch them (anonymised) to companies with a fitting
  open role → [`recipes/cv-to-jobs.md`](recipes/cv-to-jobs.md). Channel = **work email** (BD).
- **Signal → BD** — a company shows a buying signal (funding, hiring, layoffs, an event) → ICP-qualify →
  find the hiring manager → BD outreach → [`recipes/funding-to-bd.md`](recipes/funding-to-bd.md),
  [`recipes/tradeshow-to-bd.md`](recipes/tradeshow-to-bd.md),
  [`recipes/build-tam.md`](recipes/build-tam.md) (target-account mapping).
- *Recruiter note:* BD uses **work email**; candidate acquisition uses **personal email + LinkedIn**.
  This channel split is a hard safety gate, not a default — see
  [`references/provider-precedence.md`](references/provider-precedence.md).

### Branch — passive-poach (move people who aren't looking)
The highest-skill recruiting: source people who haven't raised a hand and make them movable.
- *Decision:* lead with **recruitability signals** (section A) to pick *who* to approach — tenure in the
  movable window, recent-change cadence, open-to-work, plateau/over-levelled. Competitor-poach prioritises
  candidates who already carry the domain.
- *Executes via:* [`recipes/layoff-signal-to-poach.md`](recipes/layoff-signal-to-poach.md) (displacement
  trigger); the competitor-priority leg of [`recipes/jd-to-shortlist.md`](recipes/jd-to-shortlist.md).
  Outreach must be softer and more personalized than for active candidates (lower baseline reply rate).

---

**Curating new recruiter craft** (Boolean guides, workflow research, playbooks) →
[`references/recruiter-playbooks/`](references/recruiter-playbooks/) is the intake + durable home; distilled
guidance folds back into this doc and the phase guides.
