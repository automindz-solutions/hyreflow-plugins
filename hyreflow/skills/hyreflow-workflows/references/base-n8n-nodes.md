# Base n8n nodes for Hyreflow workflows

Generated n8n workflows are plain n8n JSON: `{name, nodes[], connections{}, settings{}}`. Each node has
`{parameters, name, type, typeVersion, position:[x,y]}`. Node names must be unique. `connections` maps a
source node name → `{main: [[{node, type:"main", index:0}]]}`.

## The nodes you compose

| Purpose | `type` | Notes |
|---|---|---|
| HTTP trigger | `n8n-nodes-base.webhook` | `parameters.path` → production URL `{host}/webhook/{path}` |
| Schedule trigger | `n8n-nodes-base.scheduleTrigger` | cron-like recurring runs |
| **Call Hyreflow** | `n8n-nodes-base.httpRequest` | the workhorse — see below |
| Branch | `n8n-nodes-base.if` | conditional routing |
| Reshape | `n8n-nodes-base.set` | build/rename fields |
| Custom JS | `n8n-nodes-base.code` | transform between steps |
| Merge | `n8n-nodes-base.merge` | combine branches |

## Calling Hyreflow from an HTTP Request node

Hyreflow API base: `https://code.hyreflow.ai`. Auth: header `Authorization: Bearer <hf_live_ key>`.
Useful endpoints (POST, JSON body):

- `/tools/{tool}/{method}` — any provider tool, e.g. `/tools/apollo/search_people`
- `/search/people_search` — the sourcing waterfall
- `/enrich/email_enrichment` — the email waterfall
- `/qualify` — score candidates

HTTP Request node parameters (typeVersion 4):

```json
{
  "method": "POST",
  "url": "https://code.hyreflow.ai/search/people_search",
  "sendHeaders": true,
  "headerParameters": { "parameters": [
    { "name": "Authorization", "value": "Bearer ={{ $env.HYREFLOW_API_KEY }}" }
  ] },
  "sendBody": true,
  "specifyBody": "json",
  "jsonBody": "={{ JSON.stringify({ titles: $json.titles, limit: 25 }) }}"
}
```

Prefer referencing the key as `{{ $env.HYREFLOW_API_KEY }}` (set in n8n env) over hardcoding. If the user
has no env var, fall back to inlining the key value — but warn them it lives in the workflow JSON.

## Minimal example — webhook → people_search → respond

```json
{
  "name": "Hyreflow people search",
  "nodes": [
    { "name": "Webhook", "type": "n8n-nodes-base.webhook", "typeVersion": 1, "position": [240, 300],
      "parameters": { "httpMethod": "POST", "path": "hyreflow-people-search" } },
    { "name": "Hyreflow Search", "type": "n8n-nodes-base.httpRequest", "typeVersion": 4,
      "position": [520, 300],
      "parameters": { "method": "POST", "url": "https://code.hyreflow.ai/search/people_search",
        "sendHeaders": true, "headerParameters": { "parameters": [
          { "name": "Authorization", "value": "Bearer ={{ $env.HYREFLOW_API_KEY }}" } ] },
        "sendBody": true, "specifyBody": "json",
        "jsonBody": "={{ JSON.stringify({ titles: $json.body.titles, limit: 25 }) }}" } }
  ],
  "connections": {
    "Webhook": { "main": [[ { "node": "Hyreflow Search", "type": "main", "index": 0 } ]] }
  },
  "settings": {}
}
```

Gotchas: keep `position` values spread out (e.g. +280 x per node); match `typeVersion` to the node;
every referenced node name must exist; the webhook `path` is what forms the public URL.
