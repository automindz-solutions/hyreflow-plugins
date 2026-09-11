# Recipe — Multi-source candidate search + qualify (AI Ark · Lemlist · Prospeo [+ external])

Find candidates for a role across several people-DBs, dedupe, and qualify on required skills — using
profile data only (no contact info until the shortlist). Hard-won gotchas from the Munich/Steuerfachwirt run.

## Flow
1. **Define titles — include GENDERED + watch stem-vs-substring (critical).**
   - German (and many) titles are gendered: include BOTH, e.g. `Steuerfachwirt` **and** `Steuerfachwirtin`,
     `Steuerfachangestellte` **and** `Steuerfachangestellter` (+`…angestellten`).
   - **A bare STEM only works as a true CONTAINS substring.** `"Steuerfachangestellt"` (no ending) →
     **Prospeo `match_mode:"CONTAINS"` matches it (336); AI Ark `SMART` and Lemlist `currentTitle` returned 0**
     until given the full gendered words. ⇒ For AI Ark/Lemlist pass the **full forms**; for Prospeo a stem+CONTAINS is fine.
2. **Define location — exact-string providers need a SUPERSET; Prospeo uses canonical/ZONE.**
   - **AI Ark `contact.location` & Lemlist `location` are exact-string** (no radius). Pass a **superset**:
     metro labels (`Munich`, `München`, `Greater Munich Metropolitan Area`) **+ EN *and* DE variants** + the ~50km town list.
   - ⚠️ **Most people list the METRO, not their suburb** — a narrow town-only list UNDER-matches badly
     (live: Lemlist 42→12, Prospeo 66→19 when narrowed; dropping the English "Munich" lost the bulk). Superset > narrow.
   - **AI Ark `geoLocation` is an ACCOUNT (company-HQ) filter, NOT contact** — under `contact` it's silently ignored.
   - **Prospeo location MUST be canonical** from `search_suggestions({location_search})` (free inside the
     waterfall; 0.1 credits on a direct call); a **ZONE**
     suggestion (e.g. "Greater Munich Metropolitan Area, Germany") covers a metro radius in ONE value — Prospeo
     needs no town enumeration. (For AI Ark/Lemlist, the geo-radius Native — [[planned]] — will expand city→list.)
3. **Count-peek BEFORE paying.** All 3 return a total, nested under the `result` envelope every
   `tools execute` returns (`{ _meta, result }`): AI Ark `result.totalElements`, Lemlist `result.total`,
   Prospeo `result.pagination.total_count` (a top-level read returns `None`). Do a `size:1`/`page:1` call to read it cheaply, then decide depth.
   Billing: **Prospeo `search_person` bills 0.4 credits per request** (masked preview; 30-day dedup on
   repeat calls); **AI Ark
   bills per result (size-capped)**; **Lemlist is credit-metered per search**. Check
   `hyreflow tools get <tool> <method>` for the live rate on each. Surface "N total ≈ X credits to pull
   all — proceed?".
4. **Paginate** only as deep as needed (cap pages; log if you stop early).
5. **Dedupe across sources** — by **LinkedIn slug** (`/in/<slug>`) where present: AI Ark `link.linkedin`,
   Lemlist `lead_linkedin_url`, Prospeo `person.linkedin_url`. **Xing/external have NO LinkedIn → dedupe by
   normalized name** (strip umlauts/case). Expect ~40–50% cross-source overlap.
6. **ENRICH the profile before you qualify — search output is a snapshot.** A `search_person`/`people_search`
   row carries the CURRENT title, employer and location; it cannot tell a 20-year specialist from a 14-month
   career changer, and it hides relevant experience sitting behind an unrelated current title. Run the
   `linkedin_profile` waterfall on the deduped pool first —
   `hyreflow tools execute linkedin_profile --payload '{"linkedin_url":"…"}'` (bulk:
   `POST /enrich/linkedin_profile {"rows":[…]}`) → a normalized `profile` with
   `experience[{company, title, start, end, is_current, duration_months?, description?}]`, newest first;
   a row with no employment history is a miss and costs nothing. Skip rows whose source already carried a
   dated history (the field-shape table below) — the point is that SOMETHING dated reaches the scorer.
7. **Qualify on the enriched profile** (dated work history first, then skills + headline/summary + role
   descriptions) — count relevant years from the role dates, and keyword-match per required skill.
   - **Merge evidence ACROSS sources**: skill A in one DB + skill B in another → candidate has both. Multi-source raises confidence.
   - Keyword qualification is **conservative (high precision, low recall)** — absence of a keyword ≠ candidate lacks it
     (many empty-skill profiles are real fits). Tier: **must-have key skill** vs **key skill + nice-to-have**.
   - Domain note: some skills are near-universal for a role (e.g. Datev for German tax pros) — treat "key-skill-only" as likely-qualified, confirm in screening. Watch **software substitutes** (Addison ≠ Datev).
   - `/qualify` (`hyreflow qualify`) reports `qualify.basis` (`work_history` | `title_only`) per candidate and
     **refuses a batch in which no row carries work history** (422 `no_work_history`) — enrich first, or pass
     `allow_thin_profiles: true` to accept a title-only ranking knowingly.
8. **EEO / compliance:** never filter candidates on protected attributes (gender/age/marital/children/etc.) even when a source exposes them. Role/skill/location only.

## Per-provider quick ref
| Provider | Title filter | Location filter | Total field | Bill |
|---|---|---|---|---|
| **AI Ark** | `experience.current.title` mode SMART (full words) | `contact.location` str[] superset (geoLocation=ACCOUNT only) | `result.totalElements` | per result — check live rate |
| **Lemlist** | `currentTitle` in[] (full words; each filter needs `in`+`out`) | `location` in[] superset | `total` | per-search credits |
| **Prospeo** | `person_job_title` include[]+`match_mode:CONTAINS` (stem ok) | `person_location_search` include[] = canonical from `search_suggestions` (ZONE=radius) | `pagination.total_count` | 0.4 cr/request (30d dedup on repeat calls) |

## Field shapes for qualification text
- AI Ark: `profile.headline`/`.summary`, `skills[]`, `position_groups[].profile_positions[].title/description`.
- Lemlist: `headline`, `skills[]`, `inferred_skills[]`, `experiences[].title/description/company_name`.
- Prospeo: `person.headline`, `person.skills[]`, `person.job_history[].title/description`.
- Xing (external scrape): `scraped_tags[]`, `scraped_occupation`, `scraped_timeline[].companyNotes`. No LinkedIn URL.
