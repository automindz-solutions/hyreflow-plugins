---
name: quil
description: "Quil (now CoRecruit) — AI notetaker for recruiting firms. PARKED: no public REST API documented. Use when the user mentions Quil/CoRecruit so you can explain there's no BYOK adapter yet and route to its native ATS integrations or to Fathom instead."
---

# Quil / CoRecruit — PARKED (no public API)

**Status: parked — Tier-4 (gated/undocumented).** No adapter built.

Quil (rebranded **CoRecruit**) is an AI notetaker for recruiting firms: it auto-summarizes
video/phone/in-person interviews, generates submittals/scorecards/reformatted résumés, and writes
results straight into the ATS. Its value is delivered through **native ATS integrations**
(Bullhorn, Loxo, Crelate, JobAdder, Top Echelon, Zoho Recruit…), not a public developer REST API.

## Why no `lib/quil.py`
A web/docs scan found **no public API reference, base URL, or auth scheme** — only a paste-your-API-key
flow for connecting Quil *to* an ATS (e.g. Loxo: Integrations > Loxo). That is Quil consuming the
ATS's key, not exposing one of its own. Building an adapter would mean guessing endpoints → skipped
per the cheapest-source-first rule (don't fabricate auth/paths).

## What to do instead
- **Meeting/transcript data via API:** use **[[fathom]]** (documented `X-Api-Key` REST API) — the
  API-accessible notetaker in this estate.
- **Quil data into our ATS:** rely on Quil's native ATS integration; we read the notes back out of
  the ATS (Bullhorn/Loxo/Recruit CRM adapters).
- **To revisit:** if Hyreflow gets Quil/CoRecruit API docs or a partner key, drop the spec in
  `reference/docs/quil/raw/` and build the adapter from it — same pattern as the rest.
