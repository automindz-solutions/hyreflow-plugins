# Hyreflow plugins

Recruitment automation for your coding agent. Source → enrich → qualify →
sequence → push to your ATS, driven from Claude Code, Claude Cowork, Codex, or
Cursor. This repository is a **plugin marketplace**: add it once, install the
`hyreflow` plugin, and your agent gains the Hyreflow skills.

The skills drive the **Hyreflow CLI** (`hyreflow`). If it isn't installed yet,
the skills will offer to install it on first use, or install it yourself — via
**npm** (recommended):

```bash
npm install -g hyreflow
```

Behind a locked-down sandbox that can't reach npmjs.com? Install from the
Hyreflow registry instead:

```bash
npm install -g hyreflow --registry https://recruit.hyreflow.ai/api/v2/npm/
```

No Node? Use the one-line installer (Python 3.9+ required):

```bash
curl -fsSL https://recruit.hyreflow.ai/api/v2/cli/install | bash
```

Then sign in: `hyreflow auth login`.

---

## Claude Code

```
/plugin marketplace add automindz-solutions/hyreflow-plugins
/plugin install hyreflow@hyreflow
/hyreflow:hyreflow-quickstart
```

`/plugin marketplace update hyreflow` pulls new versions later.

## Claude Cowork

Cowork installs the same marketplace through its UI:

1. **Customize → Plugins → Add marketplace**
2. Paste the repo URL: `https://github.com/automindz-solutions/hyreflow-plugins`
3. Install the **hyreflow** plugin.
4. **Settings → Capabilities →** enable **network egress** (the CLI needs to
   reach the Hyreflow API). If prompted for a domain allowlist, allow
   `recruit.hyreflow.ai`.
5. Start a session and run `/hyreflow:hyreflow-quickstart`.

## Codex  _(beta)_

```
codex plugin marketplace add automindz-solutions/hyreflow-plugins
```

Then install **hyreflow** from the Codex Plugins UI. Codex support is new —
please open an issue if something misbehaves.

## Cursor  _(beta)_

Cursor has no one-line marketplace install yet. Clone the repo and point Cursor
at the plugin, or copy the skills into your project's agent directory:

```bash
git clone https://github.com/automindz-solutions/hyreflow-plugins /tmp/hyreflow-plugins
# then add /tmp/hyreflow-plugins/hyreflow as a local plugin in Cursor
```

---

## What's inside

| Skill | Use it for |
|---|---|
| `hyreflow-recruit` | The umbrella: find the right tool for any sourcing/enrichment/sequencing step, wire a cross-tool pipeline. |
| `hyreflow-quickstart` | A guided demo of a search → enrich → results run. |
| `hyreflow-workflows` | Build and run recurring recruiting/GTM workflows. |
| `hyreflow-feedback` | Send feedback or a bug report to the Hyreflow team. |

## Permissions

The plugin ships an approval hook that auto-approves only **read-only,
non-spending** `hyreflow` commands (status, search, live-run progress). Anything
that spends credits (`tools execute`, `enrich`, `workflows run`) or changes your
sign-in still asks first.

## License

[MIT](./LICENSE) © Automindz Solutions
