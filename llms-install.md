# Installing Hyreflow in Cline

Hyreflow is a remote MCP server. There is nothing to download or run locally.

1. Open Cline's MCP settings (the server icon in the Cline panel, or edit `cline_mcp_settings.json`).
2. Add a remote server:

```json
{
  "mcpServers": {
    "hyreflow": {
      "type": "streamableHttp",
      "url": "https://recruit.hyreflow.ai/api/v2/mcp",
      "disabled": false,
      "autoApprove": []
    }
  }
}
```

3. Cline will detect that the server requires sign-in and open your browser. Sign in with your Hyreflow account, or create one; new accounts start with free credits.
4. Back in Cline, the Hyreflow tools appear (search the tool catalogue, run a sourcing or enrichment step, check your credit balance, and so on). Start with `hyreflow_tools_search` to find the right tool for a task.

Do not add an `Authorization` header: Hyreflow uses OAuth, and a static header disables the browser sign-in.

Docs: https://hyreflow.ai/docs/mcp-setup
