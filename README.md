# Hyreflow plugins

Recruitment automation for your AI agent. Source → enrich → qualify → sequence → push to your
ATS, from Claude, ChatGPT, Codex, Cursor, Antigravity, Hermes and any other MCP-capable agent.

There are two ways in, and they work together:

- **MCP server** — a hosted, OAuth-protected server that gives any MCP client Hyreflow's tools
  directly. Nothing to install. Listed in the official MCP Registry as `ai.hyreflow/hyreflow`.
- **Plugin marketplace** (this repository) — Agent Skills and an approval hook that teach Claude Code,
  Claude Cowork, Codex and Cursor how to use Hyreflow well. The skills drive the `hyreflow` CLI.

---

## Connect via MCP

Endpoint: `https://recruit.hyreflow.ai/api/v2/mcp` · Transport: Streamable HTTP · Auth: OAuth 2.1

Add the URL to your client and it opens a browser sign-in; sign in with a Hyreflow account or
create one (new accounts start with free credits). Do not add an `Authorization` header — a static
token disables the browser sign-in.

| Client | How |
|---|---|
| Claude Desktop / claude.ai | Settings → Connectors → Add custom connector → paste the URL (free plan: one custom connector) |
| Claude Code | `claude mcp add --transport http hyreflow https://recruit.hyreflow.ai/api/v2/mcp` |
| ChatGPT web (developer mode) | Settings → Apps → Developer mode, then `+` → Connection → paste the URL, choose OAuth |
| ChatGPT desktop | Settings → Plugins → MCPs → Add → Connect to a custom MCP: name `Hyreflow`, type **Streamable HTTP**, paste the URL, leave the token and headers empty, Save. Restart the app; sign in when prompted. Allow a minute before the tools appear |
| Codex CLI | `codex mcp add hyreflow --url https://recruit.hyreflow.ai/api/v2/mcp` then `codex mcp login hyreflow` |
| Cursor | `~/.cursor/mcp.json`: `{"mcpServers":{"hyreflow":{"url":"https://recruit.hyreflow.ai/api/v2/mcp"}}}` |
| VS Code / Copilot | `.vscode/mcp.json`: `{"servers":{"hyreflow":{"type":"http","url":"https://recruit.hyreflow.ai/api/v2/mcp"}}}` |
| Cline | `{"mcpServers":{"hyreflow":{"type":"streamableHttp","url":"https://recruit.hyreflow.ai/api/v2/mcp"}}}` |
| Antigravity (desktop or IDE) | `~/.gemini/config/mcp_config.json`: `{"mcpServers":{"hyreflow":{"serverUrl":"https://recruit.hyreflow.ai/api/v2/mcp","oauth":{"clientId":"mcp_3c39d0bc0c1f435941f7962f"}}}}` then Ctrl+, → Customizations → Authenticate |
| Hermes Desktop | MCP settings: `{"mcpServers":{"hyreflow":{"url":"https://recruit.hyreflow.ai/api/v2/mcp","auth":"oauth"}}}` (CLI: same keys in `config.yaml`) |
| Grok Bot | In chat: "Add a custom MCP called Hyreflow at https://recruit.hyreflow.ai/api/v2/mcp" → **Add it** → **Authorize** on the connect card |
| OpenCode (desktop or CLI) | `~/.config/opencode/opencode.jsonc`: `{"mcp":{"hyreflow":{"type":"remote","url":"https://recruit.hyreflow.ai/api/v2/mcp","enabled":true}}}` — signs in on first use; allow a minute |
| DeepSeek Harness | Needs the community [`dsh-oauth-mcp-client`](https://github.com/springbrand-lab/dsh-oauth-mcp-client) plugin (clone, `pnpm install && pnpm build`, `dsh plugin --profile web add <dir>`), then in `~/.dsh/profiles/web/cordis.patch.yml` an `insert` entry with `name: '@dsh-external/dsh-oauth-mcp-client'` and `config: {serverName: hyreflow, url: https://recruit.hyreflow.ai/api/v2/mcp, credentialRef: HYREFLOW_OAUTH}` — signs in via browser on first start |

Not yet supported: the ChatGPT **desktop** app's custom-MCP option (bearer tokens only, no OAuth; use
the web app), the Gemini web app outside the US, and Meta's consumer Muse app (no MCP support).

Start with `hyreflow_tools_search` to find the right tool for a task and `hyreflow_billing_balance`
to check credits. See [`llms-install.md`](./llms-install.md) for a client-agnostic version of this
table, and the docs: [setup guide](https://recruit.hyreflow.ai/docs/mcp-setup) ·
[MCP reference](https://recruit.hyreflow.ai/docs/mcp-reference).

---

## Install the plugin

The plugin adds the skills below and the `hyreflow` CLI. If the CLI isn't installed yet, the skills
will offer to install it on first use, or install it yourself via **npm** (recommended):

```bash
npm install -g hyreflow
```

Behind a locked-down sandbox that can't reach npmjs.com? Install from the Hyreflow registry instead:

```bash
npm install -g hyreflow --registry https://recruit.hyreflow.ai/api/v2/npm/
```

No Node? Use the one-line installer (Python 3.9+ required):

```bash
curl -fsSL https://recruit.hyreflow.ai/api/v2/cli/install | bash
```

Then sign in: `hyreflow auth login`.

### Claude Code

```
/plugin marketplace add automindz-solutions/hyreflow-plugins
/plugin install hyreflow@hyreflow
/hyreflow:hyreflow-quickstart
```

`/plugin marketplace update hyreflow` pulls new versions later.

### Claude Cowork

1. **Settings → Plugins → Add → Add marketplace**
2. Paste the repo URL: `https://github.com/automindz-solutions/hyreflow-plugins`
3. Hyreflow appears under **More you can add**; click **Add**.
4. Start a session and run `/hyreflow:hyreflow-quickstart`.

Network access works out of the box. On Team and Enterprise plans an administrator may restrict it;
ask them to allow `recruit.hyreflow.ai` if sign-in fails.

### Codex  _(beta)_

```
codex plugin marketplace add automindz-solutions/hyreflow-plugins
```

Then install **hyreflow** from the Codex Plugins UI.

### Cursor  _(beta)_

The plugin ships a `.cursor-plugin` manifest. Add this repository as a marketplace in Cursor's plugin
settings, or clone it and add the `hyreflow` folder as a local plugin.

---

## What's inside

| Skill | Use it for |
|---|---|
| `hyreflow-recruit` | The umbrella: find the right tool for any sourcing/enrichment/sequencing step, wire a cross-tool pipeline. |
| `hyreflow-quickstart` | A guided demo of a search → enrich → results run. |
| `hyreflow-workflows` | Build and run recurring recruiting/GTM workflows. |
| `hyreflow-feedback` | Send feedback or a bug report to the Hyreflow team. |

## Permissions

The plugin ships an approval hook that auto-approves only **read-only, non-spending** `hyreflow`
commands (status, search, live-run progress). Anything that spends credits (`tools execute`,
`enrich`, `workflows run`) or changes your sign-in still asks first.

## License

[MIT](./LICENSE) © Automindz Solutions
