# Boolean & X-ray search — building the string that defines who you want

> **Curation target.** Authored from well-established sourcing patterns. When a contributed Boolean
> guide arrives, distill and merge it here (see [`README.md`](README.md)).

A Boolean string is how a recruiter says *exactly* who they're looking for. You use it two ways in
Hyreflow: (1) to **think clearly** about the target before you search, and (2) to **map** that target
onto the `people_search` canonical query or a provider's native filters. You rarely paste a raw Boolean
string into a people-DB — you decompose it into structured fields. But writing it first keeps you honest
about titles, skills, and exclusions.

## Operators
- **`AND`** — all terms must appear. Narrows. (Most DBs AND your fields together by default.)
- **`OR`** — any term. Widens. **Group OR with parentheses:** `(devops OR "site reliability" OR sre)`.
- **`NOT`** / `-term` — exclude. Cuts noise: `NOT (recruiter OR "talent acquisition" OR staffing)`.
- **`"quotes"`** — exact phrase. `"machine learning"` ≠ `machine AND learning`.
- **`( )`** — grouping / precedence. Always parenthesize OR-blocks so they don't bind loosely.
- **`*`** — wildcard/stem (support varies): `engineer*` → engineer, engineering, engineers.

**Precedence:** evaluate `NOT` → `AND` → `OR`, but never rely on it — **parenthesize explicitly**.

## A clean string has four blocks
```
(title synonyms)  AND  (must-have skills)  AND  (seniority)  AND NOT (exclusions)
```
Example — a senior backend engineer:
```
("software engineer" OR "backend engineer" OR "platform engineer")
  AND (python OR golang) AND (fastapi OR django OR grpc)
  AND (senior OR staff OR lead OR principal)
  AND NOT (intern OR recruiter OR "talent acquisition")
```

### Title block — expand to functional equivalents
The single biggest miss is searching *one* literal title. Companies spell roles differently. Expand:
- VP Sales → `("vp sales" OR "vice president sales" OR cro OR "head of sales" OR "vp revenue")`
- Use EN **and** local-language variants when the market needs it (DACH, etc.).

### Skill block — the precision lever
Skills cut more noise than seniority words. Prefer concrete tools/methods/certs over soft skills.
In Hyreflow, push these into `skills[]` (prefiltered at the source) rather than title-only + client-side
filtering.

### Exclusion block — kill the predictable noise
Recruiters/agencies, students/interns (unless wanted), the company's own competitors-as-vendors,
unrelated homonym industries.

## X-ray search (`site:` — search a site from outside)
When a DB lacks a field, X-ray the public web with a search engine:
```
site:linkedin.com/in ("data engineer" OR "analytics engineer") (spark OR airflow) "San Francisco"
site:github.com (rust OR wasm) location ("Berlin" OR "remote")
```
- `site:linkedin.com/in` → public LinkedIn profiles. `site:github.com` → dev ground-truth (repos, bios).
- Combine with the four blocks above. X-ray is recall-heavy + noisy — treat hits as leads to verify,
  not a finished list. In Hyreflow, the engineering equivalent is the GitHub leg of
  [`../../recipes/it-sourcing.md`](../../recipes/it-sourcing.md).
- **Run the string with `serper search`** (payload key `query`, 0.1 cr per call, charged even when it finds
  nothing) — set `gl`/`hl` for non-US markets, since results default to US English:
  ```
  hyreflow tools execute serper search --payload '{"query":"site:linkedin.com/in (\"data engineer\" OR \"analytics engineer\") (spark OR airflow) \"San Francisco\"","num":10}'
  ```
  X-ray is the fallback for targets the people-DBs don't cover, not the default path — see
  [`../../finding-companies-and-contacts.md`](../../finding-companies-and-contacts.md) §No coverage.

## Mapping a Boolean string onto Hyreflow
Decompose, don't paste:

| Boolean block | `people_search` canonical field |
|---|---|
| title synonyms | `titles: [...]` (pass the variants — the waterfall ORs them) |
| must-have skills | `skills: [...]` (precision lever; prefilters at source) |
| seniority words | `seniority: [...]` (+ keep senior/staff/lead in `titles` if the DB lacks a seniority field) |
| location | `locations` / `person_locations` (resolve per provider — e.g. prospeo needs pre-resolved names) |
| company scope | `company_names` / `company_domains` (e.g. competitor-poach leg) |
| exclusions | usually **client-side** after the pull, or a provider's native `NOT` if it has one |

For native single-provider filters (the advanced path), read that provider's
[`../../provider-playbooks/`](../../provider-playbooks/) `<tool>.md` — filter shapes differ (aiark's
deeply-nested `contact`/`account`, etc.). Default to the `people_search` waterfall;
[`../../finding-companies-and-contacts.md`](../../finding-companies-and-contacts.md) covers the sourcing
mechanics.

## Recruiter discipline
- **Start broad-ish, then tighten.** Run the title+skill core, see the count, add exclusions to cut
  noise — don't over-constrain on the first pass and get zero.
- **Zero results = loosen, don't abandon.** Broaden titles or drop the rarest skill before changing
  market.
- **A Boolean string is a hypothesis.** The shortlist after qualification is the real answer.
