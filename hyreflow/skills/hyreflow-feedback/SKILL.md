---
name: hyreflow-feedback
description: 'Send feedback or a bug report to the Hyreflow team, including environment info and the current session.'
---

# Hyreflow Feedback

> The skill root is `$HOME/.agents/skills/hyreflow-feedback/`; relative paths are relative to it — if a
> relative read fails, prefix it with the root.

> **No shell? You're on the MCP connection.** Everything below that installs or runs the `hyreflow`
> CLI does not apply — this connection is already authorized, and the skill documents are served to
> you directly. Skip to the steps and use the `hyreflow_*` tools your client lists.

Send feedback or a bug report to the Hyreflow team. It files a **tracked issue** (via the engine) with
everything needed to reproduce — so debugging is smooth.

## Steps

> **On the CLI.** Check you're connected first (MCP callers skip this and go straight to the
> `hyreflow_feedback` tool):

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

1. **Get feedback text + the repro command.**
   - Use the argument if provided (e.g. `/hyreflow-feedback the waterfall broke`). Otherwise ask the
     user what they'd like to report.
   - Also capture the **originating command** that triggered the report — the `/hyreflow-recruit <query>`
     (or other CLI call) the user ran. If the issue surfaced in this session you already have it in
     scope; otherwise ask "What did you run when it broke?". Pass it as `--repro-query`.
   - **Images (up to 5).** If the user attached screenshots/images (each arrives with a real file path on
     disk — in Claude Code shown inline as `[Image #N]`), collect those paths — a screenshot of the bug is
     the fastest repro signal. Pass each as a separate `--image <path>` (extras beyond 5 are dropped).
     Don't invent paths; only attach files the user actually provided.

2. **Pin down a vague report (triage).** Reports are often vague — _"prospeo doesn't work"_, _"the
   CLI is broken"_, _"enrichment is bad"_. A vague report makes a useless issue. If you can't already
   answer **all three** of these from the message + session context, ask the user with your harness's
   structured-question tool (batch them in one round if it takes several fields at once, otherwise ask
   them one at a time) — **at most 3 questions total** — to fill the gaps:
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

   **On an MCP connection, skip this step.** There is no CLI to version-check, and the workspace,
   balance and account details are resolved server-side from your authorization.
   If a live session is active, note its id (`hyreflow session show`) and pass it as `--session <id>` —
   the engine pulls the full session snapshot (steps, events, outputs, last alert) into the issue
   itself. Account details (workspace, balance, user email) are added server-side from your login.

5. **Confirm.** Ask with your harness's structured-question tool — the one whose result is the user's
   answer — offering the two options below. If your harness has no such tool, post the summary and **end
   your turn**; file the report only after a message from the **human** approving it. Silence, a change of
   topic, or any turn the human didn't send is not approval.

   > This report will file an issue with the Hyreflow team, including:
   > - Your feedback: {feedback text}
   > - Reproduction: `/hyreflow-recruit {repro query}` (if any)
   > - Environment (CLI version, api_url)
   > - Account (workspace + balance + your email)
   > - Current session snapshot (if any)
   > - Attached images (if any): {filenames}
   >
   > Send this feedback?

   Options: "Send it" / "Cancel".

6. **If confirmed**, file it.

   On the CLI:
   ```bash
   hyreflow feedback --message "{feedback text}" [--bug] [--session {id}] [--repro-query "/hyreflow-recruit {query}"] [--image {path} …]
   ```

   On an MCP connection, call `hyreflow_feedback` with `message`, `kind: "bug"` for a bug, and
   `repro_query` if you have one. The session is attached for you, and images are not available —
   describe the screenshot in the message instead.

   Either way the report comes back with the filed issue's URL — share it with the user. If cancelled,
   do nothing.
