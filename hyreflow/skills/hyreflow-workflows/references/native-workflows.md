# Native workflows (Hyreflow-executed)

Native workflows run on Hyreflow's own engine: metered per step, queued + executed server-side, with full
run history and a DAG view in the dashboard. Model: **Workflow → Revision (publish bumps version) → Run →
per-step records**.

## Definition shape

```json
{
  "name": "weekly_sourcing",
  "publish": true,
  "specification": "## Goals\n…\n## Inputs\n- titles\n## Expected Outputs\n- enriched people",
  "config": { "version": 1, "commands": [
    { "alias": "find", "tool": "people_search",
      "payload": { "titles": ["{{input.title}}"], "locations": ["{{input.location}}"], "limit": 25 } },
    { "alias": "emails", "tool": "email_enrichment",
      "payload": { "rows": "{{find.data}}" } }
  ] },
  "trigger": { "type": "cron", "cron": "0 9 * * 1" }
}
```

- **Placeholders**: `{{input.field}}` and `{{alias.data.field}}` resolve in payloads.
- **Triggers**: `api` (call on demand), `webhook` (public URL secret), `cron` (5-field).
- **`run_javascript`** steps run sandboxed JS for glue/transform.

## Build it

Python SDK:

```python
from hyreflow_sdk import Hyreflow, Workflow
hf = Hyreflow.connect()
wf = (Workflow("weekly_sourcing")
      .step("find", tool="people_search", payload={"titles": ["{{input.title}}"], "limit": 25})
      .step("emails", tool="email_enrichment", payload={"rows": "{{find.data}}"})
      .cron("0 9 * * 1").build())
hf.workflows.apply(wf, publish=True)
```

Or a definition file:

```bash
hyreflow workflows lint --file wf.json      # validate before applying
hyreflow workflows apply --file wf.json --publish
hyreflow workflows call weekly_sourcing --payload '{"title":"Recruiter"}' --tail
```

## Run + inspect

```bash
hyreflow workflows list
hyreflow workflows runs --workflow-id <id>
hyreflow workflows enable|disable|delete <id|name>
```

## Session (live Playground)

```bash
hyreflow session start --steps '["Design","Apply","Run","Validate"]' --user-prompt "<request>"
hyreflow session update --index 0 --status completed
```

Pick the right tool for a step with `/hyreflow-recruit` (`hyreflow tools search <intent>`).
