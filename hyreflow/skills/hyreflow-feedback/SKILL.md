---
name: hyreflow-feedback
description: 'Send feedback or a bug report to the Hyreflow team, including environment info and the current session.'
disable-model-invocation: false
---

# Hyreflow Feedback

Send feedback or a bug report to the Hyreflow team. It files a **Linear issue** (via the engine) with
everything needed to reproduce — so debugging is smooth.

## Steps

> **CLI required.** This skill files the report through the `hyreflow` CLI. If a `hyreflow` command returns
> "command not found" (common when the skills came from the plugin marketplace rather than the CLI
> installer), install it first — **prefer npm** (in an agent sandbox use the no-sudo, quiet form so a
> global EACCES / verbose output doesn't trip the tool's output limit):
> `npm install -g hyreflow --prefix "$HOME/.local" --silent --no-fund --no-audit` (add `$HOME/.local/bin`
> to PATH). Plain `npm install -g hyreflow` works in a normal terminal; no Node?
> `curl -fsSL https://recruit.hyreflow.ai/api/v2/cli/install | bash -s -- --no-skills`. Then
> `hyreflow auth login`.

1. **Get feedback text + the repro command.**
   - Use the argument if provided (e.g. `/hyreflow-feedback the waterfall broke`). Otherwise ask the
     user what they'd like to report.
   - Also capture the **originating command** that triggered the report — the `/hyreflow-recruit <query>`
     (or other CLI call) the user ran. If the issue surfaced in this session you already have it in
     scope; otherwise ask "What did you run when it broke?". Pass it as `--repro-query`.
   - **Images (up to 5).** If the user attached screenshots/images (the prompt shows them as `[Image #N]`,
     each with a real file path on disk), collect those paths — a screenshot of the bug is the fastest
     repro signal. Pass each as a separate `--image <path>` (extras beyond 5 are dropped). Don't invent
     paths; only attach files the user actually provided.

2. **Pin down a vague report (triage).** Reports are often vague — _"prospeo doesn't work"_, _"the
   CLI is broken"_, _"enrichment is bad"_. A vague report makes a useless issue. If you can't already
   answer **all three** of these from the message + session context, ask the user — via **AskUserQuestion**,
   **at most 3 questions, one round** — to fill the gaps:
   - **Which exactly?** the specific tool / provider / CLI command / waterfall (e.g. `prospeo`,
     `people_search`, `hyreflow enrich`) — not the general area.
   - **What went wrong?** the concrete symptom: the exact error text, an empty/wrong result, a bad
     count, a hang/crash — with numbers if any ("0 of 50 rows got emails").
   - **How to reproduce?** the exact input/query/payload and roughly when it happened.

   Skip a question you can already answer (don't re-ask what's in scope). Skip the whole step if the
   report is already specific. **Don't file the user's vague words verbatim** — synthesize their answers
   into a clear, specific report in the next step.

3. **Write the report — structured, with bold inline labels** so the issue renders cleanly (the engine
   passes the message through as Markdown). Keep the FIRST line a short one-sentence summary (it becomes
   the issue title — the engine drops it from the body so it isn't repeated), then a blank line, then a
   **bulleted** list of bold-labelled points with a **blank line between each bullet** (so they render
   spaced out, not packed). For a bug:

   ```
   <one-line summary>

   - **Expected:** <what should happen>

   - **Actual:** <what happened, with numbers if you have them>

   - **Impact:** <why it matters / what it blocks>

   - **Suggestion:** <optional fix or workaround idea>
   ```

   For plain feedback, `- **What's good:**` / `- **What's rough:**` / `- **Idea:**` work well. Skip any
   label you have nothing for — don't pad.

4. **Collect environment + session** (auto):
   ```bash
   hyreflow --version
   hyreflow config show
   hyreflow billing balance
   hyreflow update --check --json    # freshness — falls back to `hyreflow auth status` on older CLIs
   ```
   If the check reports `cli_stale`/`skills_stale` (a stale CLI is a common root cause), say so in one line
   and fold it into the report's environment notes — then continue filing (don't block the report to update).
   If a live session is active, note its id (`hyreflow session show`) and pass it as `--session <id>` —
   the engine pulls the full session snapshot (steps, events, outputs, last alert) into the issue
   itself. Account details (workspace, balance, user email) are added server-side from your login.

5. **Confirm.** Use AskUserQuestion:

   > This report will file a Linear issue including:
   > - Your feedback: {feedback text}
   > - Reproduction: `/hyreflow-recruit {repro query}` (if any)
   > - Environment (CLI version, api_url)
   > - Account (workspace + balance + your email)
   > - Current session snapshot (if any)
   > - Attached images (if any): {filenames}
   >
   > Send this feedback?

   Options: "Send it" / "Cancel".

6. **If confirmed**, file it:
   ```bash
   hyreflow feedback --message "{feedback text}" [--bug] [--session {id}] [--repro-query "/hyreflow-recruit {query}"] [--image {path} …]
   ```
   Add `--bug` for a bug report (it also gets the `Bug` label; otherwise just `feedback`). The CLI
   prints the filed Linear issue URL — share it with the user. If cancelled, do nothing.
