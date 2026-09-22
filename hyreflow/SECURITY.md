# Security

## Reporting a vulnerability

Please report security issues privately to **security@hyreflow.ai**, or through the
[Hyreflow support page](https://hyreflow.ai/docs/support). Do not open a public issue for
anything that could be exploited before it is fixed.

Include what you found, how to reproduce it, and the version (`hyreflow/.codex-plugin/plugin.json`
→ `version`, or `hyreflow skills --version`). We acknowledge reports within 3 business days and aim
to ship a fix, or a documented mitigation, within 30 days for confirmed issues.

## Supported versions

Only the latest released version of the plugin is supported. The skills are refreshed on every
`hyreflow skills install` and every plugin update, so upgrading is the fix for anything already
patched.

## Scope

This repository ships Agent Skills (Markdown), plugin manifests, and one approval hook
(`hyreflow/hooks/approve-cli.sh`). The hook auto-approves only read-only, non-spending `hyreflow`
CLI commands; anything that spends credits or changes sign-in still prompts. The hosted MCP server
at `https://recruit.hyreflow.ai/api/v2/mcp` is operated separately; issues there are in scope for
the same contact.
