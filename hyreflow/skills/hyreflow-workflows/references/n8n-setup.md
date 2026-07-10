# n8n setup & validation

n8n workflows run in the **user's own n8n instance**. Hyreflow stores the n8n host + API key (encrypted),
proxies the n8n API, and surfaces the resulting workflows in the unified dashboard list.

## Prerequisites (one-time, done by the user)

1. **An n8n instance** — n8n Cloud (`https://<name>.app.n8n.cloud`) or self-hosted.
2. **An n8n API key** — in n8n: **Settings → n8n API → Create API key**. An **owner/admin** key is needed
   so Hyreflow can detect the Hyreflow credential (full access on n8n Cloud non-enterprise).
3. **Register it in Hyreflow** — dashboard → **Integrations → n8n** → paste host URL + API key → Connect.
   (Never ask for the key in chat; it belongs in the dashboard so it stays server-side.)

> Roadmap: install the `n8n-nodes-hyreflow` community node + create a "Hyreflow API" credential in n8n
> for first-class Hyreflow nodes. Until then, generated workflows call Hyreflow with HTTP Request nodes.

## Validate BEFORE building

```bash
hyreflow n8n validate
```

Interpret the result:

- `{"connected": false}` → not set up. Tell the user to connect n8n in the dashboard Integrations tab.
- `"reachable": false` → host/key wrong or instance down. Have them re-check host URL + API key.
- `"reachable": true` → good to build. (`hyreflow_credential` true/false only matters once the Hyreflow
  node ships — ignore for the HTTP-Request path.)

## After building

- `hyreflow n8n list` — the workflows in the user's n8n (id, name, active, editor + webhook URL).
- The created workflow also shows in `hyreflow workflows list` and the dashboard (source = n8n).
- Lifecycle via the **unified** commands (they proxy to n8n):
  `hyreflow workflows enable|disable|delete <hyreflow_id>`.
