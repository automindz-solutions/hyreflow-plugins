---
name: hyreflow-workflows
description: 'Build, run, and oversee recruiting/GTM workflows with Hyreflow — cloud workflows that Hyreflow executes and meters, on an api, webhook, or cron trigger. Use when the user asks to automate, schedule, or wire a multi-step pipeline.'
---

# Hyreflow Workflows

> The skill root is `$HOME/.agents/skills/hyreflow-workflows/`; relative paths are relative to it — if a
> relative read fails, prefix it with the root.

A **workflow** is a persisted, trigger-bound pipeline that **Hyreflow runs for you**: steps execute on
Hyreflow's engine (metered), on an `api`, `webhook`, or `cron` trigger, with the full step DAG and run
history in the dashboard and in `hyreflow workflows …`. There is no second orchestrator to set up.

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

## Build it

Read `references/native-workflows.md`. Author with the Python SDK builder or a definition file, then
`hyreflow workflows apply --file wf.json --publish` and `hyreflow workflows call <name> --tail`.

Manage it from the dashboard list or the CLI: `hyreflow workflows list`,
`hyreflow workflows enable|disable|delete <id|name>`, `hyreflow workflows runs --workflow-id <id>`.

## Always

- Register a session so the live Playground shows progress (see `references/native-workflows.md`).
- Summarize what you built, its trigger, and any webhook URL at the end.
- Fallback to `hyreflow-recruit` for picking the right Hyreflow tool/endpoint to put inside a step — the
  `/hyreflow-recruit` slash command if your harness supports it, otherwise read and execute
  `~/.agents/skills/hyreflow-recruit/SKILL.md` directly.
