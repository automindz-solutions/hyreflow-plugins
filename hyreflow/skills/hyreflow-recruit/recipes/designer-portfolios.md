# Recipe: Designer sourcing with portfolios (portfolio lookup as an add-on, or as a must-have)

Designers show their work on a portfolio, the way developers show theirs on GitHub. For a screen or
visual-communication design role, add each candidate's portfolio to the shortlist so the recruiter can look
at the work. A pattern the agent composes; not a hard-coded pipeline.

> **Engine-routed (SKILL.md → Execution model):** every method below runs as
> `hyreflow tools execute <provider>_<method>`. The engine holds the keys server-side.

## Scope: which roles get the portfolio lookup
**In scope (add-on by default):** screen and visual-communication roles: product designer (software), UX / UI,
interaction, UX research, visual, graphic, brand, web, motion, content / UX writer, design systems,
exhibition and packaging *graphics*.

**Physical-goods design** (industrial, furniture, fashion, interior, packaging engineering, hardware or
consumer-product design): **no add-on**. Source as usual with [`jd-to-shortlist.md`](jd-to-shortlist.md),
deliver without a portfolio column and don't mention portfolios. **Exception:** if the user requires a
portfolio, run mode B. These designers keep their work mostly on Behance and Coroflot, so accept tier 2.

**Decide before sourcing**, from the JD and the hiring company: "product designer" is ambiguous. Go by the
company's **main product**. A company that sells physical goods (Dyson, Bosch, Miele) means the physical role
even if it also has an app; assume the screen role only when software is the product. If it is still unclear,
ask one line before sourcing. After enrichment, use the candidates' employers only to drop people from the
wrong side.

## Pick the mode
| The user… | Mode | Effect |
|---|---|---|
| asks for designers and says nothing about portfolios | **A — add-on (default)** | source as usual, then look up portfolios near the cut. A relevant portfolio boosts a candidate; a missing one never drops or lowers anyone. |
| shows interest but no requirement ("I'd love to see their work", "a portfolio would be nice") | **A**, and offer B in one line **before sourcing** | B sources differently, so switching after an A run repeats the search. Same boost as plain A, no more. |
| says every candidate **must have** a portfolio ("only people with a portfolio", "must have own site") | **B — must-have** | source portfolio-first and drop candidates without one |

Never switch to B on your own: a portfolio requirement removes most of the market (on one product-designer run,
only about **30%** of otherwise qualified designers had an own site; it varies by discipline and country). If
the interest only shows up after delivery, offer B then and say how many of the N already had a portfolio.

**Search skills by discipline** (for `people_search` and the web queries): `Figma`, `UX Design`, `Design
Systems` for product / UX / UI · `Adobe Illustrator`, `InDesign`, `Branding` for graphic / brand ·
`User Research`, `Usability Testing` for UX research · `After Effects`, `Cinema 4D` for motion ·
`Rhino`, `SolidWorks`, `KeyShot` for industrial / furniture.

---

## Mode A — portfolio as an add-on (default)

```
JD → PARSE → people_search → enrich (linkedin_profile) → QUALIFY (portfolio not scored) → top ~1.5×N
           → portfolio lookup (profile text → name search) → verify → BOOST relevant portfolios → cut to N
```

**A1 — Source as usual.** Follow [`jd-to-shortlist.md`](jd-to-shortlist.md) (or plain `people_search`)
with `titles` + the discipline's `skills` + `locations`. See the **people_search gotchas** below.

**A2 — Enrich the work history** with the `linkedin_profile` waterfall. Qualify needs it anyway, and it brings
the `about` text the portfolio lookup reads first.

**A3 — QUALIFY vs the JD** (see **Qualify** below) with the portfolio left out of the score: no must-have, no
scoring category. This is the base score. Keep the top **~1.5×N**, so a boost in A5 can lift someone across
the cut.

**A4 — Look up portfolios for those ~1.5×N only.** Lookups and verification cost per candidate, so never run
them on the whole pool. Use the **portfolio lookup** steps below, then **verify** each hit.

**A5 — Boost, then cut to N.** A portfolio can only help:
- **Verified and relevant** (the work matches the JD's discipline or domain and is recent): **+0.5** on the
  0-10 score.
- **Probably theirs, stale, or off-discipline**: no boost.
- **None found**: no boost. The base score stands; nothing is subtracted.

Rank by the boosted score (capped at 10), cut to the N the user asked for, and show both numbers (e.g.
"7.1 (6.6 + 0.5 portfolio)") so the recruiter sees why someone moved.

**A6 — Deliver** the shortlist with a portfolio column: the URL and its status (verified / probably theirs /
none found). "None found" is a normal result, not a reason to drop anyone.

---

## Mode B — portfolio is a must-have

> **Why portfolio-first:** a people-DB row almost never says whether the person has a portfolio, so
> "people_search, then look for a portfolio" finds very few. On one validated run (Senior Product Designers in
> PL/ES/RS/GE/AM, rule "must have own portfolio site"), the people-DB-first search found **4 own-site
> designers out of 60**. Searching the web for the portfolios first found **47**, of which 22 passed the JD
> screen, for about 12 credits end to end. Everyone the web leg finds has a portfolio by definition.

```
JD → PARSE → ┌─ Portfolio leg (primary): exa personal-site search per geo ∥ serper X-ray on site builders
             │                           → drop non-portfolios → LinkedIn FROM the portfolio's own links
             └─ People-DB leg (backup):  people_search → enrich → portfolio lookup → drop rows without one
           → MERGE + dedup (portfolio row wins) → VERIFY → enrich work history
           → QUALIFY vs JD with the portfolio as a gate → shortlist
```

**B0 — Decide what counts as a portfolio** from the user's words, and report the tier per candidate. Ask only
when the wording is ambiguous.

| Tier | Counts as | Typical hosts |
|---|---|---|
| **1 — own site** | a personal domain or a site-builder site that is theirs | `name.com`, `*.framer.website`, `*.framer.ai`, `*.webflow.io`, `*.cargo.site`, `*.myportfolio.com`, `*.format.com`, Squarespace / Wix |
| **2 — platform profile** | real work, but on a shared platform | `behance.net`, `dribbble.com`, `coroflot.com`, Figma community profile; for UX research also case studies on Medium or Notion |

Use tier 1 only when the user says "own site"; otherwise accept both. Physical-goods roles: accept both.

**B1 — PARSE the JD.** Fetch the posting with `firecrawl_scrape`. Many job boards (Pinpoint and other
JS-rendered postings) return only a title to a plain fetch. Extract `titles`, design discipline, tools,
domain (e.g. fintech / BNPL), seniority and `locations`.

**B2 — Exa personal-site search** *(primary)*. One `exa_search` **per country or city**, with
`category: "personal site"` and the platforms and noise excluded, so the results are people's own sites. In a
non-English market run a second query in the local language (e.g. "Produktdesigner Portfolio Berlin").
```bash
hyreflow tools execute exa_search --payload '{
  "query":"senior product designer portfolio fintech, based in Warsaw Poland",
  "category":"personal site","type":"auto","numResults":15,
  "excludeDomains":["behance.net","dribbble.com","linkedin.com","medium.com","exa.ai","malt.com"]
}'
```
For tier 2, run a separate search with `includeDomains` instead of `excludeDomains`, and without
`category` (platform profiles are not personal sites, so that filter returns next to nothing): `["behance.net",
"dribbble.com"]` for screen and visual roles, `["behance.net","coroflot.com"]` for physical-goods roles (Dribbble
is screen work). For UX research, drop `medium.com` from the exclude list.

**B3 — Serper X-ray** *(adds recall Exa misses)*. One query per geo; set `gl`/`hl` for non-US markets. `num`
takes 10 or 20. Keep each query to **two `site:` terms at most**: five OR'd `site:` terms plus an OR'd title
returned nothing on a live run and was still charged.
- **Screen and visual roles:** the site builders.
  ```bash
  hyreflow tools execute serper_search --payload '{"query":"(site:framer.website OR site:webflow.io) \"product designer\" Warsaw","num":20,"gl":"pl","hl":"pl"}'
  ```
- **Physical-goods roles:** lead with Behance. Its page titles read "Name - Industrial Designer in Stuttgart,
  Germany", so `site:behance.net "industrial designer" "Stuttgart, Germany"` is very precise; on a Stuttgart
  run it was the best leg. The site-builder query found nothing there: these designers use their own domains.
  Coroflot profiles in Germany were mostly 10+ years old, so use Coroflot as a cross-link source (B5), not as
  a main leg.

**B4 — Drop what is not a person's portfolio:**
- marketplaces: Toptal, Malt, Contra, Twine, freelancermap
- Exa's own `exa.ai/library/person/…` pages
- agency and studio sites (a "we" homepage with a client list and several team members). A one-person studio
  name is ambiguous: keep it if the site shows one person's work.
- company careers pages built on Webflow or Framer (`…/careers/…`, job listings)
- CV PDFs: keep the root domain if it is a portfolio, drop the PDF URL

Dedup by domain, then group each person's pages (own site + Behance + Coroflot): B5 reads all of them.
**Flag studio owners and freelancers** (a one-person studio, "available for projects"): common among
industrial designers, and they may not be looking for a job. Keep them, but say so.

**B5 — LinkedIn from the portfolio first.** One `exa_contents` call over all the portfolio URLs, asking for the
links on each page plus a short slice of text:
```bash
hyreflow tools execute exa_contents --payload '{"urls":["https://janedoe.design","https://jd.framer.website"],"text":{"maxCharacters":1500},"extras":{"links":50}}'
```
- **Links** are at `results[i].extras.links`: a flat list in page order, with relative paths, duplicates and
  `mailto:` links mixed in. 50 is enough for own sites. Behance pages open with 25–30 navigation links, so
  send platform profiles in a separate call with `"links":80`.
- Normalize `linkedin.com/in/<handle>/…` (recommendations, recent-activity) to `linkedin.com/in/<handle>`;
  ignore `linkedin.com/company/…`. A `mailto:` link is the candidate's free contact email; it can come back
  percent-encoded (`info%40…`), so decode it. Ignore the `entities` field: it holds `exa.ai/library/…` pages.
- **Read every page the person has.** One designer's LinkedIn was linked only from her Coroflot profile, not
  from her own site.
- **The text** usually says "based in …" and the seniority, so it settles location without a scrape.
- **Failures:** `statuses[]` lists every URL; the failed ones have `status: "error"` and a reason in
  `error.tag` / `error.httpStatusCode`, and are missing from `results`. Retry them with `firecrawl_scrape`.
- Exa serves cached copies, and a JavaScript-heavy site can come back with 0–2 links. Scrape those with
  Firecrawl (`only_main_content: false`) before falling back to a name lookup.

Many sites simply do not link LinkedIn: on the validated run 13 of 31 did, on a Berlin test 9 of 17, and on a
Stuttgart test 6 of 15 pages. Only for the people with no link on any of their pages, fall back to a name
lookup, and treat that match as **unverified**: a name lookup returned the wrong person for 9 of 45.

**B6 — People-DB leg** *(backup; skip it when the user wants tier 1 only and the portfolio leg is large
enough)*. `people_search` → `linkedin_profile` → **portfolio lookup** below → drop rows with none.

**B7 — Verify, enrich, qualify.** Verify every portfolio (below), including the **current discipline**: on a
Stuttgart run several "industrial designers" had moved into automotive HMI, UX or process jobs. Drop or flag
them against what the user asked for. Run `linkedin_profile` on the rows that are
not enriched yet (don't pay twice for the same profile). Then qualify (below) with the portfolio as a gate,
e.g. `must_haves: ["Own portfolio website", "Based in <geo>"]`. If the user asked for **strong** or **good**
work, add a portfolio-quality must-have (depth of the case studies, relevance to the JD's domain) and say the
score is a judgment call. Deliver exactly the N asked for.

---

## Shared steps

### people_search gotchas (from live runs)
- **Location:** `"New York"` matches New York **State** (Rochester, Schenectady). Use
  `"New York City Metropolitan Area"`, `"Brooklyn"`, `"Manhattan"`. Same idea for any city that shares a
  name with a region.
- **Title:** a title-only search pulls people who merely list "UX" among their skills (communication
  specialists, illustrators). Add the discipline's `skills` and expect to drop about 3 in 10; pull `2×N`, so
  that after qualify there are still ~1.5×N left for the portfolio step.

### Portfolio lookup for a known candidate
Needs the `linkedin_profile` enrichment first: a `people_search` row has no About text.
1. **The profile's own text.** Read the enriched `about` (`linkedin_profile.matched_result.about`) and the
   experience descriptions (`.experience[].description`, missing on some rows) for a portfolio URL. Read the
   full rows from the dataset: the enrichment's sample view cuts `about` at about 200 characters, and the URL
   is often at the end. People maintain this text themselves, so it is the most reliable source. It found 2 of
   10 on one NYC test and 1 of 5 on another.
2. **A name web search**, only for candidates still without one: `"<full name>" <discipline> portfolio`
   via `serper_search` or `exa_search`. It found 3 more of the 10, but it is weak in two ways:
   - **Common names fail.** "Matt Gallo" returned only namesakes. Add the employer or city to the query; if
     the top results are still other people, stop and mark "none found". An uncommon name with no hits gets
     one query, not a retry.
   - **Hits are often stale or not theirs.** A 2010-era Behance whose own domain was dead, with a LinkedIn
     handle that differed from the profile's. Accept the hit only after verifying it.

   The two sources overlapped little: together they covered 5 of 10.

### Verify each portfolio
- **Same person** — mark **verified** when any holds:
  - the site's own LinkedIn link matches the candidate's `linkedin_url`, and the name matches; or
  - the candidate's own LinkedIn `about` names the site; or
  - the site has no LinkedIn link, but its work clearly matches the enriched profile (same employers or
    named projects, or a domain that equals the LinkedIn handle). Say "verified by content".

  Mark **probably theirs** when the site links a different handle or the match is only the name. Never drop
  or confirm on the name alone.
- **A portfolio**: case studies or project work, not a general blog or a CV page. For UX research, written
  case studies count.
- **Location** matches the search. Portfolio sites often say "based in …"; Exa's text slice or the page
  metadata (timezone) may show it. If nothing does, rely on the LinkedIn location and say the site did not
  confirm it. If the two disagree, go by LinkedIn, accept a commutable town near the city, and show both.
- **Live**: Exa serves cached copies, so `firecrawl_scrape` the site with `"maxAge": 0` (Firecrawl caches
  too), `links` + `summary` formats and `"only_main_content": false`, which returns header and footer links
  when the site has them. Firecrawl answers `success: true` even for a dead page: check
  `metadata.statusCode`, and drop the site on a 404. A dead domain can also redirect to a host's "missing"
  page (Adobe Portfolio does this).
- **Recent**: a dated project, or an employer or client the profile shows in the last 2 years. A site with
  nothing newer than ~5 years is a weak signal; say so.

The scrape is metered per page, so run it only on candidates you will deliver. Its summary also gives
discipline, clients and notable projects for the dossier.

### Enrichment runs async
`linkedin_profile` returns `status: running` even for a handful of rows. Poll it (free) until every row is
done before you qualify; its dry run lists the provider steps but does not quote a cost.

### Qualify
`/qualify` from the CLI. Over a connection without a shell there is no qualify tool: use
`hyreflow_shortlist` (see [`shortlist.md`](../shortlist.md)). Surface its errors as-is; never substitute your
own scores. The A5 portfolio boost is the one addition, always shown next to the engine's score.
- It needs a `job_spec`. With no JD, write a short one from the request (title, discipline, seniority,
  location, any must-haves the user named).
- **Mode A:** a JD that mentions portfolios can get a missing one counted against the candidate. Say in the
  job spec that a portfolio is not assessed (A5 adds the boost afterwards), then check it held:
  - `/qualify`: read each row's `gaps[]`. If a missing portfolio is listed, tell the user it is in that score.
  - `hyreflow_shortlist`: the first screen of a new job spec takes a couple of minutes while it writes its
    questions; poll the run. Check the categories in `_meta`; if a portfolio category is there, rerun once
    with `regenerate_questions: true`, and if it persists, tell the user it is in the score.

### Outreach handoff
LinkedIn first. Many portfolios list a contact email (the `mailto:` link): that is the candidate's own
published channel and costs nothing, so prefer it over a paid `personal_email` lookup. See
[`writing-outreach.md`](../writing-outreach.md).

## Gates
- **Mode A for screen and visual-communication roles unless the user makes the portfolio a must-have.** In
  mode A a relevant, verified portfolio adds +0.5; a missing one never drops or lowers a candidate.
- **Physical-goods design:** no add-on; mode B only when the user requires a portfolio.
- **LinkedIn from the portfolio's own link** before any name lookup; a name-matched LinkedIn is unverified
  until the site ties it to the candidate.
- **Never present an unverified portfolio as theirs.** Stale, dead or mismatched sites are reported as such.
- **Candidate channel:** LinkedIn + the portfolio's own email, never work email.
- **EEO:** never filter on age/gender/etc.; judge the work, not the photo on the site.

## Cost shape
| Step | Metered? |
|---|---|
| Exa search / contents (mode B) | per request (keep `numResults` tight; one `contents` call for all URLs) |
| Serper X-ray / name search | 0.1 credit per query, charged even with no hits |
| Firecrawl verify | per page, only for candidates you deliver |
| people_search | per result |
| `linkedin_profile`, qualify | metered |

Live tests: Berlin mode B (5 senior product designers, own site only) about 1.6 credits; Stuttgart mode B
(4 industrial designers, tier 1 + 2) about 1.9; the NYC mode A portfolio step for 8 candidates about 1.1 on
top of the search, enrichment and screen. Mode A
adds little on top of a normal search: the profile text is already paid for by the enrichment, and name
searches and scrapes run on the top ~1.5×N only.

## Output
A ranked designer shortlist, each with: **portfolio URL + status (verified / probably theirs / none found; tier
1/2 in mode B) · LinkedIn · discipline + notable projects/clients from the site · location · current role ·
portfolio contact email if published · 0-10 JD score.**
