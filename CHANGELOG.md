# Changelog

All notable changes to the Hyreflow plugin are documented here. Versions track
the plugin, kept in lockstep across the marketplace manifests and the plugin's
own `plugin.json` files.

## 0.1.3 — 2026-07-14

- CLI install is now sandbox-safe: the npm step uses a no-sudo user prefix and
  quiet flags (`--prefix "$HOME/.local" --silent --no-fund --no-audit`) so it
  doesn't hit a global-install EACCES or flood an agent's tool output.

## 0.1.2 — 2026-07-14

- CLI install now prefers **`npm install -g hyreflow`** (public npm) across all
  skills, with the curl installer as a no-Node fallback.

## 0.1.1 — 2026-07-13

- Skills re-synced to the current engine (provider-playbook + reference doc
  updates: leadmagic, field notes, n8n node reference).

## 0.1.0 — 2026-07-10

Initial release. Single `hyreflow` plugin bundling the recruitment-automation
skills: `hyreflow-recruit`, `hyreflow-quickstart`, `hyreflow-workflows`,
`hyreflow-feedback`.

- Claude Code + Claude Cowork: install as a marketplace plugin.
- Codex + Cursor: manifests shipped (beta — please report issues).
- `PreToolUse` approval hook auto-approves read-only, non-spending `hyreflow`
  CLI calls; anything that spends credits or changes auth still prompts.

_Reserved for a future release: serving the Hyreflow CLI binary directly from
this repo's GitHub Releases (`bin/` shim + versioned release assets)._
