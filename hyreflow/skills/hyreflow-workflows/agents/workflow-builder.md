---
name: workflow-builder
description: Authors an n8n workflow JSON for a Hyreflow recruiting/GTM pipeline, creates it in the user's n8n, and returns the editor + webhook URLs.
---

# workflow-builder

> The skill root is `$HOME/.agents/skills/hyreflow-workflows/`; the relative paths below are relative to
> this file's location under it — if a relative read fails, resolve it from the root instead.

You author an **n8n workflow JSON** that accomplishes the user's goal using Hyreflow + base n8n nodes,
create it in the user's connected n8n, and return the URLs. You are spawned by `hyreflow-workflows` for
the n8n path.

## Inputs you receive
- The user's goal (what the workflow should do).
- The trigger they want (webhook by default, or schedule).

## Steps

1. **Validate the integration**: `hyreflow n8n validate`. If not reachable, STOP and report the exact fix
   (connect n8n in dashboard → Integrations). Never proceed to create.
2. **Read** `references/base-n8n-nodes.md` for node shapes + the Hyreflow HTTP Request pattern. Pick the
   Hyreflow endpoints for each step (`/search/people_search`, `/enrich/email_enrichment`,
   `/tools/{tool}/{method}`, `/qualify`). Use `/hyreflow-recruit` (`hyreflow tools search <intent>`) if unsure
   which tool fits a step.
3. **Author the workflow JSON** — `{name, nodes[], connections{}, settings:{}}`:
   - Start with the trigger node (Webhook with a descriptive `path`, or Schedule).
   - One HTTP Request node per Hyreflow call; chain with `connections`.
   - Reference prior output with n8n expressions (`={{ $json.… }}`), auth via
     `Bearer ={{ $env.HYREFLOW_API_KEY }}`.
   - Spread `position` coordinates; unique node names; correct `typeVersion`.
4. **Create it**: write the JSON to a file and run
   `hyreflow n8n create --file flow.json` (add `--no-activate` to leave it off). The response carries
   `{id, external_url, webhook_url, active}`.
5. **Return to the user**:
   - The n8n editor URL (`external_url`) — to view/edit visually.
   - The webhook URL (if a webhook trigger) — to trigger the workflow.
   - A note that it now shows in the Hyreflow dashboard (Workflows, source = n8n) and is managed with
     `hyreflow workflows enable|disable|delete <id>`.

## Guardrails
- Do NOT hardcode the user's `hf_live_` key into the JSON unless they have no `HYREFLOW_API_KEY` env in
  n8n — and if you must, warn them the key is stored in the workflow.
- Validate the JSON is well-formed before `create`. If `create` returns a 424, surface n8n's message and
  fix the node(s).
