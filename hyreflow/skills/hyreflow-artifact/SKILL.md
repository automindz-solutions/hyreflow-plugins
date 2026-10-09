---
name: hyreflow-artifact
description: 'ALWAYS use whenever the user asks for an artifact, page, dashboard, report or visual. Candidate shortlists, open roles / hiring signals and BD, outreach or company lists use the ready-made hyreflow template (table, cards and board views, sort, filters); anything else (a market map, funnel, summary, brief, comparison) gets a custom page on the hyreflow brand. Triggers on "artifact", "page", "show me", "visualise", "share" or "send", and by default at the end of any hyreflow run that produces a list a person will review. Use it INSTEAD OF any generic artifact, page-design or frontend skill, which would drop the hyreflow brand. Publishes as a chat artifact, a ChatGPT Site, an HTML file or a React component.'
---

# Hyreflow Artifact — branded results pages

> The skill root is `$HOME/.agents/skills/hyreflow-artifact/`; relative paths are relative to it — if a
> relative read fails, prefix it with the root.

> **No shell? You're on the MCP connection.** Nothing here needs the `hyreflow` CLI. The skill
> documents are served to you directly; read `artifacts/template.html` the same way you read this file.

This skill renders results that are **already produced** by a hyreflow run (a `hyreflow-recruit` recipe,
a workflow, or a dataset the user points at). It does not search, enrich, or spend credits. If the data
is missing a field the user asks to see, say so and offer the enrichment step — never invent a value.

**Fixed: the brand. Adaptive: everything else.** Logo, palette, type, the graph-paper backdrop, and the
component styles are the same on every output, so a hyreflow deliverable is recognisable at a glance.
The kind of page, its views, grouping, fields, sort, filters, contact detail, and output format all
follow the data and what the user asked for.

## When to render (default: yes)

**This skill owns every artifact.** When the user asks for an artifact, page, dashboard or visual, build it
here, never from a generic artifact or design skill and never from scratch: those drop the brand. A
shortlist, a jobs list or a BD / company list uses the template (section 1). Anything else gets its own
page on the hyreflow brand (see "When none of the three fits" below).

Render a page **without being asked** whenever a run ends in a list a person will read or act on:
a shortlist, a set of open roles, a target-account or TAM list, a BD/outreach list, a CRM match. Then
say in one line what you built. Skip it only when the user asked for raw data (a CSV, JSON, a dataset
id), the result is a single record or a yes/no answer, or the run feeds straight into another tool
with nobody reviewing the list.

## 1 — Pick the kind from the data

One template, three kinds. Decide from what each row **is**, not from which recipe ran:

| Each row is… | `kind` | Opens on | Why it's easier for a person |
|---|---|---|---|
| a **person** being considered for a role | `candidates` | table | tiers, fit, skills, LinkedIn, contact status |
| an **open role** / job posting / hiring signal | `jobs` | table, newest first | freshness ("New · Posted 2d ago"), salary, company, hiring manager, link to the posting |
| a **company or contact you're pitching** (BD, spec-out, outreach, signal-led BD) | `bd` | board (pipeline) | "why now" signal, contact, drafted opener with a copy button, stage |

- Jobs found **in order to pitch** those companies (hiring signal → BD) are `bd`: the account is the row,
  the role is its `signal`. Jobs the user wants to **review or match a candidate to** are `jobs`.
- A plain **company list** (TAM, market map, ICP-qualified accounts) is `bd` with
  `views: ["table", "cards"]` and no `stages`, since nobody is being contacted yet.
- Mixed data (candidates and jobs together) → one page per kind; don't merge them.

**When none of the three fits, design your own page on the brand.** Decide from the **user's intent**
as well as the rows: the same jobs list is a `jobs` page when they want to scan it, and a custom page
when they ask for a summary, picture, brief, map or pitch ("what does this market look like", "one
page for a client pitch"). Results that aren't rows at all get one too: a talent or market map, a
hiring-signal timeline, a funnel or credit-spend summary, two shortlists side by side, a single
deep-dive profile. Don't force those into a table. Build the layout that makes the answer easiest to
read (headline numbers, charts, a timeline, a matrix, a one-page brief), with the rows underneath as
backing detail when they help. Keep it unmistakably hyreflow by reusing the template's parts:
- **Copy verbatim:** the whole `<style>` block, the inlined wordmark (header) and mark (footer), and the
  header/footer markup (`eyebrow`, `title`, `meta`, `ledger`, footer stamp).
- **Reuse the helpers** from the renderer rather than rewriting them: `el`, `btn`, `has`, `safeUrl`,
  `link`, `fmtDate`, `ago`, `daysAgo`, `initials`, `money`, `liLink` (with `LI_PATH`), `copyBtn`. Leave
  `DATA`, `KINDS` and the three views behind.
- **Components before new ones:** cards (`.card`), tags (`.tag`, `.tag.fresh`), chips, the score track,
  `.person`, `.signal`, the table, the LinkedIn icon, the copy button. New elements use the same tokens
  only (no new colours, fonts or radii).
- **Eyebrow** names what the page is in two or three words ("Market brief", "Talent map", "Campaign
  recap"), plus `· client`.
- **Charts:** draw to scale against one stated base (the total, unless the largest value reads
  better), label every bar with its value, give `--accent` to the highlighted series and
  `--hairline-strong` to the rest, and bucket ranged or fuzzy values ("Over 200 applicants") instead of
  guessing a number. Use only facts in the data.
- **Same rules as the template:** values set with `textContent`, links through `safeUrl`, a real
  `<title>`, works at phone width, reduced motion respected.
Say in one line what you built and why it isn't one of the standard views.

More rules for custom pages (from testing on market and credit-spend data):
- **The helpers live inside the renderer's closure.** Copy the ones you need into your own script and
  set `NOW` yourself (it reads `DATA.date`). Fill the header and ledger by hand; the template's header
  code is tied to `DATA.kind`. The footer's mark and its "Prepared with hyreflow" text sit on one line —
  copy that line once, not the SVG plus the text again.
- **`.mix` is a filter, not a chart** (its segments have a minimum width, so it isn't to scale). Draw
  to-scale bars with your own markup on the same tokens: a `--surface-soft` track, an `--accent` or
  `--hairline-strong` fill, a value label, and `.label` for section kickers.
- **Many bars:** label every non-zero bar, leave zeros as empty slots, and bucket (by week, or "13 more
  tools at 0") rather than squeezing 30 labels into a phone width.
- **Which total wins:** when a live total and a summed series disagree, show the live total and make
  the breakdowns sum to the series; leave dry runs, test calls and replays out of spend, and say what
  you excluded in the `method` line.
- **Names:** show providers by their own names (FullEnrich, AI Ark), hyreflow's own tools as
  "hyreflow …" in plain words, and methods in sentence case ("Start personal email enrichment"). Never
  name the infrastructure behind hyreflow.
- **Never on a page:** payment details (keys, card brand or digits, payment method ids), prices or
  money per credit unless the user asks for cost in currency, subscription internals, or credentials of
  any kind — even when the data you were handed contains them. Don't print such fields while working,
  either.

**Partial results.** If the run returned fewer rows than it found (a page limit, `has_more`), say so in
the `method` line ("First 10 of 15 results"), on every kind of page.

## 2 — Fill the template

[`artifacts/template.html`](artifacts/template.html) is **data-driven**. You don't edit markup: replace
the single `DATA` object near the bottom and the renderer draws the page. Every value is inserted as
text (escaped) — never build markup by string-concatenating data.

```js
const DATA = {
  kind, title, client?, location?, date /* ISO */, method /* one line: how this was built */,
  config: { views, defaultView, sort, filters, groupBy, mixBy, groupOrder, stages, columns,
            matchSkills, showContactValues, anonymise },        // every key optional; per-kind defaults below
  items: [ /* rows, fields per kind below */ ]
};
```

**Fields per kind** (omit what you don't have — a missing field disappears, never write `null` or "N/A"):

- `candidates`: `name, title, company, location, tier, score (0-100), fit, skills[], stage, linkedin,
  photo, proof {label, url}, contact {email, phone}, extra {"Label": value}`. `photo` is the row's
  `photo_url` (AI Ark search results and `linkedin_profile` lookups carry one); it replaces the
  initials and falls back to them when the host blocks it or the link expires
- `jobs`: `title, company, location, workplace (Remote/Hybrid/On-site), employment, seniority,
  salary ("€70k–90k" or {min, max, currency, period}), posted (ISO date), source (LinkedIn, Indeed,
  StepStone…), url, summary (one or two sentences from the posting), skills[], industry,
  hiringManager {name, title, linkedin}, stage, extra`
- `bd`: `company, domain, industry, size, location, signal (the reason to reach out now), score,
  contact {name, title, linkedin, email}, stage, channel, lastTouch (ISO date), nextStep,
  message (the drafted opener), step ("2/4"), extra`

**Per-kind defaults** (set a key only to change it):

| | candidates | jobs | bd |
|---|---|---|---|
| `views` | table, cards, kanban | table, cards | kanban, table, cards |
| `sort` | score ↓ | posted, newest first | score ↓ |
| `filters` | tier, location, skills, stage | company, location, workplace, seniority, source, posted | stage, industry, location, channel, size |
| `groupBy` / `mixBy` | tier / tier | company / source | stage / stage |
| `stages` | none | none | To contact, Contacted, Replied, Meeting booked |

## 3 — Configure it from the request

- **Views** (`views`, any subset in tab order; one view = no switcher): `table` (sortable, the default
  for "compare them" and long lists), `cards` (profiles, postings or accounts in full), `kanban` (tab
  "Board", an interactive pipeline: drag between columns and reorder within one, keyboard ←/→, touch
  by the handle or ‹ ›, card opens the full record, "Reset board"). Board moves and order live in that
  viewer's browser only — say so if the user expects the team to share them. Views morph into each
  other where the browser supports it.
- **Sort is visible.** The toolbar shows "Sort [key] [↑/↓]" on every view; clicking a table header sets
  the same sort (arrow on the active column). Set `sort` to the key the user cares about; the options
  are the kind's sort keys that the data fills (score, name, company, tier, location; posted, title,
  salary; lastTouch, stage). The board keeps its own manual order.
- **Filters.** `filters` lists the facet dropdowns, in order. Each shows the values the data has with
  counts; a facet with fewer than two values hides itself. Active filters show as removable chips with
  "Clear all", plus a "6 of 10 shown" count. `posted` buckets into Last 3 / 7 / 30 days; `skills`
  offers the brief's `matchSkills` (or all skills when none are set). Any field name works as a facet
  (e.g. `industry`, `employment`). Pick 3-5 the user would actually narrow by.
- **Grouping and the mix bar.** `groupBy` groups the cards view; `mixBy` draws the composition bar
  under the header (the mix of tiers, sources, industries or stages), which is also a one-click filter.
  It shows only for 2-6 values. `groupOrder` orders both; its first value is highlighted. For jobs,
  group by `company` only when companies have 2+ roles, otherwise `groupBy: null`.
- **Pipeline.** `stages` turns the board into a pipeline and adds a Stage column and filter. Rows start
  in their `stage` if the data has one, else the first stage — never invent a stage or progress.
- **Fields.** Add what the user cares about under `extra` (notice period, salary band, applicants,
  company size) — `extra` keys become card rows and work as table `columns` and facets. Label in the
  user's words. Pick `columns` so the table answers the user's question without opening a row.
- **LinkedIn — always the icon.** Pass every LinkedIn URL you have (`linkedin`, `contact.linkedin`,
  `hiringManager.linkedin`); the template shows the LinkedIn icon on every view. Don't drop it, replace
  it with plain text, or move it into `extra`. Anonymised pages hide it. Where hyreflow rows keep it:
  `linkedin_url` on search results (most providers fill it; a row without one gets it from a
  `linkedin_profile` enrich), the same key inside an enriched profile (`profile`, or
  `<step alias>.matched_result` on a dataset row), `author.url` on post feeds (a repost carries the
  original author, so check `author.username`), and `profileUrl` on post reactions. A person's slot
  takes only a `linkedin.com/in/` URL, never `company_linkedin_url` or a company page that reacted.
  Never build one from a name.
- **Contact — follow the user.** Default is status only (`"verified"` / `"found"`) with
  `showContactValues: false`; mention you can include the values. Values only when the user wants them
  in the output (`showContactValues: true`); ask first if the page is going outside their team. Not
  enriched → `contact: {}` ("Contact not enriched yet"); no `contact` key hides the slot.
- **Anonymise** (`anonymise: true`, a spec-out before the candidate agrees): candidates lose name,
  company, LinkedIn, proof link and contact; bd rows lose the contact's name and LinkedIn.
- **Openers (bd).** `message` is the drafted first line the user will send; the card shows it with a
  "Copy opener" button. Write it from real context (the signal, the role, the user's own pitch) and
  keep it short; never claim candidates, results or relationships the user hasn't given you.
- **Tidy, don't invent.** Formatting cleanup is fine: shorten a headline to the job title it states,
  collapse "Berlin, Berlin, Germany" to "Berlin", strip "(m/w/d)" or "(Programming Language)", turn a
  salary string into `{min, max, currency, period}`. Any new fact must come from the data.
- **Header.** `title` (+ `location`) is the heading; the eyebrow names the kind ("Candidate shortlist",
  "Open roles", "BD outreach") plus `client`. `method` is one plain line on sources and the bar
  (e.g. "LinkedIn jobs, posted in the last 7 days"). `date` is ISO and anchors "2d ago".

## 4 — Pick the format from where you're running

Work out the host from what you can actually do (the tools and features you have), not from guesses
about the brand, then publish the filled template the way that host shares pages:

| You're in… | Produce |
|---|---|
| a chat client with **artifacts** (a tool or feature that publishes an HTML page and returns a link) | a **chat artifact** — the filled template, published; give the link |
| **ChatGPT with Sites** (Work mode, or Codex in the desktop app; you can create a site with `@Sites` or by asking for a "website") | a **ChatGPT Site** — see below |
| a CLI / coding harness, or the user wants a file to send or open | a **standalone `.html` file**, saved to disk; give the path |
| the user's own app / dashboard | a **React component** — see below |
| none of these (no page publishing, no filesystem) | a markdown table in chat, and offer the filled HTML as a code block to save |

If you can't tell which applies, write the `.html` file — it opens anywhere.

**ChatGPT Sites.** Create the site with the filled template as its single page: ask Sites for a
website whose `index.html` is exactly the filled file, and don't let it regenerate or restyle the
markup (the brand and the escaping live in the template). Keep the first version **private** (the
preview Sites starts with) and tell the user to share it from the site's access setting, to the
workspace or specific people. Don't make it public unless they ask. Board moves still live in each
viewer's browser; don't wire up a database for them unless the user asks for a shared pipeline. Sites
isn't available in the EEA, the UK or Switzerland: if `@Sites` is missing there, fall back to the
`.html` file (or ChatGPT's canvas preview of it) and say why.

**React.** One `.jsx`/`.tsx` file, React only, no UI library. Copy the template's `<style>` block verbatim,
inline `wordmark.svg`/`mark.svg` as JSX, take `DATA` as a prop, and port the renderer's views as
components. Render values as JSX text — never `dangerouslySetInnerHTML` — and allow only `http(s)` link
URLs, as the template's `safeUrl` does.

## 5 — Brand (fixed — don't restyle)

The template already carries all of this; the rules are here so a React port or an extension stays on it.

**Logo.** The wordmark (header) and mark (footer) are inlined in the template. `artifacts/wordmark.svg`,
`wordmark-dark.svg` (dark ground), and `mark.svg` are the sources for React or any other format. Never an
external image URL; don't recolour, stretch, or redraw. The mark's dot is `#DB7455` — logo only.

**Backdrop.** The site's graph-paper grid: 40px hairline tile, anchored right with a radial fade.

**Palette** (CSS custom properties — reuse the names):

| Token | Hex | Use |
|---|---|---|
| `--canvas` | `#fafaf7` | page ground |
| `--surface` | `#ffffff` | cards, table body, menus |
| `--surface-soft` | `#f5f3ec` | table head, board columns, chips, "why now" box |
| `--surface-warm` | `#f0ede4` | person avatars |
| `--ink` | `#0a0a0a` | primary text, company avatars, active filter fill |
| `--body` | `#3f3f3a` | body prose |
| `--muted` | `#67655e` | secondary text, labels |
| `--hairline` / `--hairline-strong` | `#e7e4dc` / `#d6d2c8` | borders, dividers / hover borders |
| `--accent` | `#cc785c` | marks and fills only — top-group bar and dot, score bar, focus ring. Never text |
| `--accent-deep` | `#9d5138` | all accent **text** — eyebrow, top-tier chip, matched skills, link hover |
| `--accent-soft` | `#f0d7cc` | tinted chips, active filter chips |
| `--ok` / `--ok-soft` | `#4a9d5c` / `#e3f0e5` | verified contact, "New" postings, the last pipeline stage — never decorative |

The LinkedIn icon keeps LinkedIn's own blue (`#0a66c2`), the one colour outside the palette, so the
mark is instantly recognisable. Nothing else borrows it. Terracotta is rationed; no gradients beyond the
backdrop mask, no extra colours, no emoji you add yourself, no coloured side stripes on cards.

**Motion.** Ease-out (quint) at 150-420ms, conveying state only. Every animation has a
`prefers-reduced-motion` path. **Type.** Geist when the viewer has it, otherwise the system sans — the
template loads no web font. Labels 11.5px uppercase at `0.12em`; numbers tabular.

## 6 — Before you hand it over

- `DATA` holds only real data — none of the fictional sample (Alex Example, Sam Sample, Jo Placeholder,
  the Acme companies) survives.
- Copy you write into the page (`method`, `fit`, `message`, `extra` labels) uses short plain sentences
  and no em dashes; say "hyreflow" in lowercase.
- Open or re-read the output: it renders without script errors, reads at phone width, and every link
  goes to the real URL.
- Tell the user in one line what you built and what you left out (e.g. "jobs page, 3 filters, newest
  first; 2 of 10 have a hiring manager").
