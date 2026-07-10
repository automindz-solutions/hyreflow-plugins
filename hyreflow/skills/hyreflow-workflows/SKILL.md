---
name: hyreflow-workflows
description: 'Build, run, and oversee recruiting/GTM workflows with Hyreflow — native cloud workflows (Hyreflow-executed, metered, cron/webhook) or n8n workflows (built in the user''s own n8n, linked out). Use when the user asks to automate, schedule, or wire a multi-step pipeline.'
disable-model-invocation: false
---

# Hyreflow Workflows

A **workflow** is a persisted, trigger-bound pipeline. Hyreflow supports two engines behind ONE unified
surface (the dashboard list + `hyreflow workflows …`):

| | **Native** | **n8n** |
|---|---|---|
| Runs on | Hyreflow's engine (metered) | the user's own n8n instance |
| Build with | SDK builder / `hyreflow workflows apply` | n8n workflow JSON via `hyreflow n8n create` |
| Best for | headless, metered, Hyreflow-only steps | visual editing, 400+ n8n nodes, mixing non-Hyreflow tools |
| Triggers | api · webhook · cron | webhook · schedule · any n8n trigger |
| Oversight | full DAG + run history in dashboard | listed in dashboard, links out to n8n |

**Decide which:** if the user wants a visual builder, to combine Hyreflow with other SaaS (Slack, Sheets,
their CRM), or already lives in n8n → **n8n**. If they want a headless, metered, Hyreflow-native pipeline
with run history in Hyreflow → **native**. When unsure, ask.

## Step 0 — check for updates (once per session, before anything else)
- **First, is the CLI installed?** If a `hyreflow` command returns "command not found", the CLI isn't
  installed yet (common when these skills came from the plugin marketplace rather than the CLI installer).
  Offer to install it: `curl -fsSL https://recruit.hyreflow.ai/api/v2/cli/install | bash -s -- --no-skills`
  — this installs the `hyreflow` CLI and signs the user in. `--no-skills` skips re-installing the skills
  (you already have them via the plugin), so there's no duplicate copy. Once it's installed, continue.

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

## Native path

Read `references/native-workflows.md`. Author with the Python SDK builder or a definition file, then
`hyreflow workflows apply --file wf.json --publish` and `hyreflow workflows call <name> --tail`.

## n8n path

1. **Check prerequisites FIRST** — `hyreflow n8n validate`. It must show the instance reachable. If not
   connected, tell the user to open **Hyreflow dashboard → Integrations → n8n** and paste their n8n host
   URL + API key (Settings → n8n API). Do not ask for the key in chat — it lives in the dashboard.
2. Read `references/n8n-setup.md` (prerequisites + validation) and `references/base-n8n-nodes.md` (the
   nodes you compose — Hyreflow is called via the **HTTP Request** node).
3. Spawn the **workflow-builder** sub-agent (`agents/workflow-builder.md`) to author the n8n workflow
   JSON, create it (`hyreflow n8n create --file flow.json`), and return the editor + webhook URLs.
4. The created workflow appears in the unified dashboard list (source = n8n) and via
   `hyreflow workflows list`. Manage it there: `hyreflow workflows enable|disable|delete <id>` proxy to
   n8n.

> **Tag scoping:** Hyreflow only pulls n8n workflows tagged **`hyreflow`** (`hyreflow n8n list` is filtered
> to that tag). Workflows created via `hyreflow n8n create` are tagged automatically. To adopt a
> workflow the user already built in n8n, tell them to add the `hyreflow` tag to it, then run
> `hyreflow n8n import` (or click **Import workflows** on the Integrations page). Connecting auto-imports.

> Hyreflow community node (`n8n-nodes-hyreflow`) is on the roadmap (see repo `TODO.md`). Until it ships,
> generated n8n workflows call the Hyreflow API with **HTTP Request** nodes (bearer header inline).

## Always

- Register a session so the live Playground shows progress (see `references/native-workflows.md`).
- Summarize what you built, where it runs, and the URLs (editor + webhook) at the end.
- Fallback to `/hyreflow-recruit` for picking the right Hyreflow tool/endpoint to put inside a step.
