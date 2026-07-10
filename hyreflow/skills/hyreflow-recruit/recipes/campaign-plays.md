# Recipe — Campaign plays (sequence cadences) + the "confirm cadence first" rule

**Use when:** about to build an outreach sequence (Lemlist, etc.). The cadence shape is the **client's call**,
not an assumption — so **always prompt the user with a few example plays and confirm before building.**

## 🔒 Rule: confirm the cadence before building a sequence
1. **Never assume the channel.** Default to what the data + client supports: **no email on the leads → LinkedIn-only**;
   candidate acquisition → LinkedIn + personal email (never work email — see provider-precedence).
2. **Prompt the user** with 2–4 example **plays** (below) — let them pick or tweak (steps, delays, branching).
3. Only then build it (no sender, draft, no leads, not started). Sending (`start_campaign`) is separately approval-gated.

## Example plays (offer these)
**A — LinkedIn-only: connect → messages** (no email at all)
```
D0 linkedinVisit → D1 linkedinInvite (no note)
 └ IF linkedinInviteAccepted within 3d → linkedinSend ×3 (D0, +2, +3)
```
**B — LinkedIn-first + email fallback (multichannel)**  ← used for the Meta-RIF campaign
```
D0 linkedinVisit → D1 linkedinInvite (no note)
 └ accepted within 3d  → linkedinSend ×3 (if email on file: LinkedIn first, email only if no reply)
 └ fallback (not accepted in ~5d) → email-only sequence (fires only when a lead has an email)
```
**C — Email-only (BD / work email OK)**
```
D0 email → +3 email → +5 email   (work email; not for candidate acquisition)
```
**D — LinkedIn linear (no branching)** — simplest/most reliable
```
D0 linkedinVisit → D1 linkedinInvite → D4 linkedinSend → D7 linkedinSend
```

## How to build it in Lemlist (verified live 2026-06-02)
- `create_campaign(name, timezone=...)` → returns `_id` + `sequenceId` (auto-empty sequence, **no sender**).
- Linear steps: `add_sequence_step(seqId, type, subject?, message=<HTML/text>, delay=<days>)`.
  LinkedIn types: `linkedinVisit`, `linkedinInvite` (note via `message`, omit for no-note), `linkedinSend` (`message`).
- **Branching:** `add_conditional_step(seqId, "linkedinInviteAccepted", delay_type="within", delay=3)` →
  returns `conditions: [{sequenceId: <accepted branch>}, {sequenceId, fallback:true}]`. Add follow-ups into
  **those branch sequence ids**. `delete_sequence_step(seqId, stepId)` to remove (needs seqId in path).
- ⚠️ **SourceWhale has NO create-campaign API** (UI-only) — for SourceWhale, prompt the user to build the cadence in the app first (see `provider-playbooks/sourcewhale.md`). Lemlist is fully API-buildable.

## Live example (Meta-RIF, Play B)
campaign `cam_chQLJcAoSqHyE6jGK` · main `seq_uoqzMqirRwFi9Du42` (visit→invite→conditional) · accepted branch
`seq_i47bcdb9gJRieZAvT` (3 linkedinSend) · fallback `seq_GmMXi69vWvkSvJNRK` (empty — email branch, leads have no email).
