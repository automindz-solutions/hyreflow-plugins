# Connecting to Hyreflow

Hyreflow is a remote MCP server. There is nothing to download or run locally.

- **Endpoint:** `https://recruit.hyreflow.ai/api/v2/mcp`
- **Transport:** Streamable HTTP
- **Authentication:** OAuth 2.1 with dynamic client registration. Add the URL and the client
  opens a browser sign-in; sign in with a Hyreflow account or create one (new accounts start
  with free credits). Do not add an `Authorization` header: a static token disables the
  browser sign-in.

## Client configuration

Most MCP clients take the URL directly. Common shapes:

| Client | Where | Snippet |
|---|---|---|
| Claude Code | terminal | `claude mcp add --transport http hyreflow https://recruit.hyreflow.ai/api/v2/mcp` |
| Claude Desktop / claude.ai | Settings → Connectors → Add custom connector | paste the URL |
| Cursor | `~/.cursor/mcp.json` | `{"mcpServers":{"hyreflow":{"url":"https://recruit.hyreflow.ai/api/v2/mcp"}}}` |
| Cline | MCP settings (`cline_mcp_settings.json`) | `{"mcpServers":{"hyreflow":{"type":"streamableHttp","url":"https://recruit.hyreflow.ai/api/v2/mcp"}}}` |
| VS Code / Copilot | `.vscode/mcp.json` | `{"servers":{"hyreflow":{"type":"http","url":"https://recruit.hyreflow.ai/api/v2/mcp"}}}` |
| Codex CLI | terminal | `codex mcp add hyreflow --url https://recruit.hyreflow.ai/api/v2/mcp` then `codex mcp login hyreflow` |
| Antigravity | `~/.gemini/config/mcp_config.json` | `{"mcpServers":{"hyreflow":{"serverUrl":"https://recruit.hyreflow.ai/api/v2/mcp","oauth":{"clientId":"mcp_3c39d0bc0c1f435941f7962f"}}}}` |

## First steps

Start with `hyreflow_tools_search` to find the right tool for a task, and
`hyreflow_billing_balance` to check credits.

- Setup guide (per client): https://recruit.hyreflow.ai/docs/mcp-setup
- MCP reference (tools, auth, scopes): https://recruit.hyreflow.ai/docs/mcp-reference
