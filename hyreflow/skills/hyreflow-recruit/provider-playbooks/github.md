---
name: github
description: "Developer sourcing via the GitHub API — search users/repos/code, read profiles + repos (languages, stars, activity), list repo contributors, and run GraphQL for rich candidate dossiers. Use when the user wants to source engineers/developers for IT roles, find contributors to specific tech/projects, or assess a developer's skills from their GitHub. Keys: hyreflow-managed credits or BYOK."
---

# GitHub — Integration Meta Skill

Implemented in `lib/github.py`. Sourcing-relevant subset only; index: `reference/docs/github/raw/endpoints.md`.

> **Output rule (always):** when GitHub is the source, ALWAYS include each person's **GitHub profile URL**
> (`https://github.com/<login>`) — the primary handle. Pair it with their **website + ALL socials** (not just
> LinkedIn), and an **impact tier** from their top repo's stars.
>
> **Use ONE GraphQL dossier call per dev** (richest, captures everything REST misses):
> ```graphql
> user(login:$login){ name websiteUrl followers{totalCount}
>   socialAccounts(first:10){nodes{provider url}}          # LinkedIn + X/Bluesky/Mastodon/YouTube/personal…
>   repositories(first:5, ownerAffiliations:[OWNER,ORGANIZATION_MEMBER,COLLABORATOR],
>                orderBy:{field:STARGAZERS,direction:DESC}){nodes{nameWithOwner stargazerCount}} } }
> ```
> - **`ownerAffiliations` MUST include `ORGANIZATION_MEMBER`/`COLLABORATOR`** — else you undercount the best people,
>   whose flagship is **org-owned** (FastAPI under `fastapi/`, Netty under `netty/`). `list_user_repos` (REST) returns
>   user-account repos ONLY → it showed tiangolo 3k vs the real FastAPI 99k.
> - **Impact tier** (proxy for the un-exposed achievement badges): top-repo stars **≥5,000 = viral · ≥1,000 = strong · ≥100 = notable**.
>   Context-adjust: stars in a niche language/recent repo weigh more than in JS; true "going viral" = star *velocity* (trending), readable from `starred_at`.
> - **`lib/github.py` `graphql()` returns the UNWRAPPED data** → top-level key is `user` (not `data.user`).
> - **Website + socials:** `websiteUrl` is the personal site (often the richest contact hub); `socialAccounts` lists every linked profile — capture all, surface LinkedIn first.
> - **Email (`find_user_emails`, harvests commit author emails — works even when the profile email is hidden):**
>   it returns **both personal AND employer emails**. These are **candidates**, so **use the PERSONAL email only**
>   (gmail/personal-domain) and **DISCARD employer-domain addresses** (`@google.com`, `@apple.com`, …) — never recruit
>   via someone's current-employer inbox (candidate-channel rule). Filter out `*noreply*`/`users.noreply.github.com`.
>   ⚠️ Commit-harvested personal email is unconsented + often EU/GDPR-relevant → **LinkedIn-first**, personal email as follow-up.

## Auth & config
- **REST:** `https://api.github.com` · **GraphQL:** `https://api.github.com/graphql`.
- **Auth:** PAT (fine-grained or classic) → `Authorization: Bearer <token>` (env `GITHUB_TOKEN`; never hardcode) + `X-GitHub-Api-Version: 2022-11-28`.
  - **Scope = public data only (by design).** Candidate sourcing reads only **public** GitHub — profiles, public repos, commit emails — never private-repo contents. Don't build sourcing paths that assume private access.
- **Rate limits:** REST 5,000/hr · **Search 30 req/min, 1,000-result cap** · GraphQL ~5,000 points/hr. Search pagination: `page`/`per_page` (≤100); `iter_search_users` respects the cap. Adapter auto-sleeps on 403/429 rate-limit + transient 5xx.

## Operations
Discovery: `search_users`/`iter_search_users`, `search_repositories`, `search_code`. Profile + skill signal: `get_user`, `list_user_repos`, `get_repo_contributors`, `list_user_followers`. Ops: `get_rate_limit`. **`graphql(query, variables)`** — generic passthrough (one endpoint; you specify the fields) for rich single-call dossiers: profile + `socialAccounts` (linked LinkedIn/Twitter) + top languages + pinned repos + `contributionsCollection`.

**First-class IT-sourcing helpers** (engine-routed; the batch-friendly replacement for agent-authored local match/dossier scripts):
- `search_profile_match(full_name, …)` — name + company/location/linkedin_url → **ranked GitHub matches** with confidence + reasons (drops bots; conservative — review low-confidence hits).
- `user_dossier(username, …)` — one user → recruiter-ready dossier (profile, socials, top repos/languages, impact tier, commit-email harvest, JD-keyword scores).
- `candidate_dossier(full_name|github_url, …)` — end-to-end: identity match → dossier → JD scoring, in one call writable into an enrich column.
- ⚠️ **Owned-repo impact:** these read `list_user_repos` (REST, user-account repos only) → `impact_tier`/`flagship_repo` **undercount org-owned flagships** (tiangolo 3k, not FastAPI 99k). For an accurate impact read use the **GraphQL dossier** above with `ownerAffiliations:[OWNER,ORGANIZATION_MEMBER,COLLABORATOR]`.
- **`jd_score` = JD-keyword coverage (0-10):** fraction of the supplied `jd_keywords` the candidate demonstrates across their repos × 10 — comparable across candidates, stable as the JD grows. It is **pure relevance**; `impact_tier` carries fame separately, so rank on both. Run the helpers at batch scale through `hyreflow enrich --with '{"tool":"github_user_dossier",…,"extract_js":…}'` (always the flat `<tool>_<method>` name, never dotted) — no local scripts.

## Skill/tool verification via code search

Use `search_code` as a **per-candidate verification/enrichment pass** after you already have a geo-sourced candidate
pool. It proves whether a candidate has public code matching the JD's exact tools/frameworks, which is stronger than
self-reported CV/LinkedIn skills.

Run via the flat tool name:
```bash
hyreflow tools execute github_search_code --payload '{"q":"\"[tool.ruff]\" user:<login>","per_page":1}'
```
Read `result.total_count`; counts are usually enough for ranking/tagging.

Query cookbook:
- Quality tooling: `"[tool.ruff]" user:<login>`, `"[tool.mypy]" user:<login>`
- Testing: `pytest user:<login>`, `filename:conftest.py user:<login>`, `filename:pytest.ini user:<login>`
- Framework import fingerprints: `"from fastapi" user:<login>`, `"from django" user:<login>`, `"from flask" user:<login>`
- CI quality gates: `filename:*.yml "ruff check" user:<login>`
- Discovery experiments: the same fingerprints **without** `user:<login>` can find public repos/users using a tech, but
  do not treat that as geo-qualified sourcing.

Constraints / interpretation:
1. **Code search is 10 queries/min** (stricter than the 30/min user/repo search bucket). Batch in rate-windowed passes
   and inspect `get_rate_limit().resources.code_search` / `github_get_rate_limit` before large runs.
2. **No `location:` qualifier on code search.** Use `search_users` or people-DBs for geo sourcing first, then
   `search_code user:<login>` for verification.
3. **Presence = strong evidence; absence = weak evidence.** GitHub indexes public, default-branch files only. Private
   employer repos, private side projects, non-default branches, and unindexed files under-show. Never hard-reject a
   candidate solely on zeros.
4. **Read zeros in context.** A candidate can score low on `"from fastapi"`/`"from django"`/`"from flask"` because they
   author an adjacent framework (for example Litestar), not because they lack backend depth.

For IT shortlists, add verified-tooling fields when the JD calls out specific tools/frameworks, e.g.
`verified_ruff`, `verified_mypy`, `verified_pytest`, `verified_frameworks`, and `verified_ci_quality_gates` with short
count/evidence notes.

## Pulling contact details when they ARE listed/derivable
GitHub does expose contact info three ways — try these before falling back to the waterfall:
1. **Public profile email + site + twitter:** `get_user(username)` → `email` (if the dev set one public), `blog`, `twitter_username`, `bio`.
2. **LinkedIn / social links** (the icons under the avatar): `get_user_social_accounts(username)` → `[{provider, url}]` (linkedin, mastodon, …). Also in GraphQL `user.socialAccounts`.
3. **Commit-email harvest** (when the profile email is private): `find_user_emails(username)` walks their recent owned repos' commits and returns real emails, dropping `*@users.noreply.github.com` proxies. (Primitives: `list_repo_commits(author=…)`, `list_user_events`.)

## ⚠️ The recruiter reality
- Even with the above, **many devs have no usable email on GitHub** (private email + noreply commits). So GitHub is still primarily **discovery + skill signal** → if 1–3 come up empty, hand `name + company + GitHub/LinkedIn` to the **enrichment waterfall**. GitHub slots in *before* enrichment.
- Run **narrow** search queries (rate cap; `find_user_emails` is bounded by `max_repos`). Keep outreach human-paced (ToS).

## Handoff (IT candidate sourcing)
`search_users`/`get_repo_contributors` by language+location → `get_user`+`list_user_repos` (skill signal) → **score vs the JD** (agent, free) → **enrich email** (waterfall) → validate → ATS (Vincere/Bullhorn) → sequencer (SourceWhale/Lemlist/HeyReach). The engineer-sourcing front-end for the "source & shortlist" recipe.

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface
Call via the CLI: `hyreflow tools execute github <method> --payload '{...}'` (preview with `--dry-run`; `hyreflow tools get github <method>` returns the live contract + cost). Base: `https://api.github.com`. Any endpoint without a typed method is reachable through the tool's generic `request` passthrough.

- `candidate_dossier(full_name: str | None = None, *, github_url: str | None = None, company_name: str | None = None, location: str | None = None, linkedin_url: str | None = None, jd_keywords: list[str] | str | None = None, max_candidates: int = 5, max_repos: int = 12, include_emails: bool = True) -> dict[str, Any]` — End-to-end IT-sourcing GitHub leg: match identity → build dossier → score repos vs JD.
- `find_user_emails(username: str, *, max_repos: int = 10) -> list[str]` — Harvest candidate emails from a user's public commits (when the profile email is private).
- `get_rate_limit() -> Any` — GET /rate_limit — remaining REST/Search/GraphQL budget (safe read-only pilot).
- `get_repo_contributors(owner: str, repo: str, **params) -> Any` — GET /repos/{owner}/{repo}/contributors — source the people who build a given project.
- `get_repo_tree(owner: str, repo: str, *, ref: str = 'HEAD', recursive: bool = True) -> Any` — GET /repos/{owner}/{repo}/git/trees/{ref} — list every path in the repo in one call.
- `get_user(username: str) -> Any` — GET /users/{username} — profile: name, company, location, blog, email (if public), hireable, counts.
- `get_user_social_accounts(username: str) -> Any` — GET /users/{username}/social_accounts — the linked social accounts shown on the profile (e.g. LinkedIn, Mastodon, Twitter): list of {provider, url}. This is where a profile's LinkedIn lives.
- `graphql(query: str, variables: dict | None = None) -> Any` — POST /graphql — run any GraphQL query/mutation. Best for rich single-call candidate dossiers (profile + socialAccounts + top languages + pinned repos + contributions in one round-trip).
- `iter_search_users(q: str, *, per_page: int = 100, max_results: int = 1000, **params) -> Iterator[dict]` — Paginate /search/users up to GitHub's 1,000-result cap.
- `list_repo_commits(owner: str, repo: str, *, author: str | None = None, per_page: int = 100, **params) -> Any` — GET /repos/{owner}/{repo}/commits — commits (filter by `author`=username). Each carries commit.author.email / commit.committer.email — the basis for commit-email harvesting.
- `list_user_events(username: str, **params) -> Any` — GET /users/{username}/events/public — public activity (PushEvents carry commit author emails).
- `list_user_followers(username: str, **params) -> Any` — GET /users/{username}/followers — network expansion.
- `list_user_repos(username: str, *, sort: str = 'pushed', per_page: int = 100, **params) -> Any` — GET /users/{username}/repos — skill signal: languages, stars, recency. sort: pushed|updated|created|full_name.
- `read_file(owner: str, repo: str, path: str, *, ref: str | None = None) -> Any` — GET /repos/{owner}/{repo}/contents/{path} — read one file, authenticated + decoded.
- `search_code(q: str, *, per_page: int = 30, page: int = 1, **params) -> Any` — GET /search/code — find code (derive authors using a specific tech). Stricter rate limit.
- `search_profile_match(full_name: str, *, company_name: str | None = None, location: str | None = None, linkedin_url: str | None = None, max_candidates: int = 5) -> dict[str, Any]` — Name → likely GitHub identity matches with confidence scoring.
- `search_repositories(q: str, *, sort: str | None = None, order: str | None = None, per_page: int = 30, page: int = 1) -> Any` — GET /search/repositories — q e.g. 'language:rust stars:>500 topic:cli'. sort: stars|forks|updated.
- `search_users(q: str, *, sort: str | None = None, order: str | None = None, per_page: int = 30, page: int = 1) -> Any` — GET /search/users — find developers. q e.g. 'location:Berlin language:Go followers:>50 repos:>10'.
- `user_dossier(username: str, *, jd_keywords: list[str] | str | None = None, max_repos: int = 12, include_emails: bool = True) -> dict[str, Any]` — Return a recruiter-ready GitHub dossier for one user.

<!-- API-SURFACE:END -->
