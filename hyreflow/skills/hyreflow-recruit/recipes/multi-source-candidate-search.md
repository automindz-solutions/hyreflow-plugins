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
   - **Prospeo location MUST be canonical** from `search_suggestions({location_search})` (free); a **ZONE**
     suggestion (e.g. "Greater Munich Metropolitan Area, Germany") covers a metro radius in ONE value — Prospeo
     needs no town enumeration. (For AI Ark/Lemlist, the geo-radius Native — [[planned]] — will expand city→list.)
3. **Count-peek BEFORE paying.** All 3 return a total, nested under the `result` envelope every
   `tools execute` returns (`{ _meta, result }`): AI Ark `result.totalElements`, Lemlist `result.total`,
   Prospeo `result.pagination.total_count` (a top-level read returns `None`). Do a `size:1`/`page:1` call to read it cheaply, then decide depth.
   Billing: **Prospeo 1 cr/page(≤25), 30-day dedup → re-runs `free:true`**; **AI Ark ~0.5/result (size-capped)**;
   **Lemlist credit-metered per search**. Surface "N total ≈ X credits to pull all — proceed?".
4. **Paginate** only as deep as needed (cap pages; log if you stop early).
5. **Dedupe across sources** — by **LinkedIn slug** (`/in/<slug>`) where present: AI Ark `link.linkedin`,
   Lemlist `lead_linkedin_url`, Prospeo `person.linkedin_url`. **Xing/external have NO LinkedIn → dedupe by
   normalized name** (strip umlauts/case). Expect ~40–50% cross-source overlap.
6. **Qualify on profile text** (skills + headline/summary + experience descriptions) — keyword match per required skill.
   - **Merge evidence ACROSS sources**: skill A in one DB + skill B in another → candidate has both. Multi-source raises confidence.
   - Keyword qualification is **conservative (high precision, low recall)** — absence of a keyword ≠ candidate lacks it
     (many empty-skill profiles are real fits). Tier: **must-have key skill** vs **key skill + nice-to-have**.
   - Domain note: some skills are near-universal for a role (e.g. Datev for German tax pros) — treat "key-skill-only" as likely-qualified, confirm in screening. Watch **software substitutes** (Addison ≠ Datev).
7. **EEO / compliance:** never filter candidates on protected attributes (gender/age/marital/children/etc.) even when a source exposes them. Role/skill/location only.

## Per-provider quick ref
| Provider | Title filter | Location filter | Total field | Bill |
|---|---|---|---|---|
| **AI Ark** | `experience.current.title` mode SMART (full words) | `contact.location` str[] superset (geoLocation=ACCOUNT only) | `result.totalElements` | ~0.5/result |
| **Lemlist** | `currentTitle` in[] (full words; each filter needs `in`+`out`) | `location` in[] superset | `total` | per-search credits |
| **Prospeo** | `person_job_title` include[]+`match_mode:CONTAINS` (stem ok) | `person_location_search` include[] = canonical from `search_suggestions` (ZONE=radius) | `pagination.total_count` | 1cr/page, 30d dedup free |

## Field shapes for qualification text
- AI Ark: `profile.headline`/`.summary`, `skills[]`, `position_groups[].profile_positions[].title/description`.
- Lemlist: `headline`, `skills[]`, `inferred_skills[]`, `experiences[].title/description/company_name`.
- Prospeo: `person.headline`, `person.skills[]`, `person.job_history[].title/description`.
- Xing (external scrape): `scraped_tags[]`, `scraped_occupation`, `scraped_timeline[].companyNotes`. No LinkedIn URL.
