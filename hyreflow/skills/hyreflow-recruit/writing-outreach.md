# Writing Outreach — qualify, then sequence

The last legs of a GTM/recruiting pipeline: **qualify** the list against the role/ICP, then **sequence**
outreach on the right channel. Both have hard gates — do not skip them. In recruiter terms this is the
run to a **slate**, watching **response / positive-reply rate** — see [`recruiter-craft.md`](recruiter-craft.md)
§B (outreach → slate) for the behaviour + vocabulary.

## 1) Qualify before you reach out

Run the qualify gate after any search/enrich and before sequencing or pushing to an ATS. It scores each
record against the role/ICP and drops the misses, so you never spend credits sequencing unqualified leads.

→ Follow [`recipes/qualify-against-icp.md`](recipes/qualify-against-icp.md) as the plan (pair it with the
client's `ICP.md` when present).

## 2) Confirm the cadence before building a sequence

The cadence shape is the **client's call**, never an assumption. Always show a few example plays and
**confirm with the user before building** anything in a sequencer (Lemlist, Instantly, Smartlead, SendKit, …).

→ Follow [`recipes/campaign-plays.md`](recipes/campaign-plays.md) for the cadence templates and the
"confirm cadence first" rule.

## 3) Channel + source rules (safety gates)

Outreach channel follows the data and the candidate-vs-prospect distinction — see
[`references/provider-precedence.md`](references/provider-precedence.md):

- **No email on the leads → LinkedIn-only.** Don't invent or guess addresses.
- **Candidate acquisition → LinkedIn + personal email**, never the work email of someone at their current
  employer (candidate-channel rule).
- Verify before send; respect the provider-precedence waterfall for which source/channel wins.

## Handoff

Once qualified + cadence-confirmed, push to the sequencer or ATS/CRM via that tool's
`provider-playbooks/<tool>.md` (auth + write methods + send gates).
