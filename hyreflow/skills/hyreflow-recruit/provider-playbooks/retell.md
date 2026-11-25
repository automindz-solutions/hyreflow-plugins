---
name: retell
description: "Retell AI (voice-AI phone agents) via its API — read calls with their transcript, recording link, summary and extracted fields, list agents and phone numbers, and add links or texts to a Retell knowledge base (e.g. a second-brain folder link the agent answers from). Use when the user mentions Retell, AI screening calls, voice-agent call notes, saving candidate call notes to the ATS, or feeding their Retell agent from Hyreflow. Keys: connect your own Retell AI account on the Integrations page (API key)."
---

# Retell AI — Integration Meta Skill

HOW in `lib/retell.py`. Docs: docs.retellai.com/api-references.

## Auth & config
- **Base URL:** `https://api.retellai.com` · **Auth:** header `Authorization: Bearer <api_key>`. The key comes from the Retell dashboard > **Settings > API Keys**. A scoped key needs Read on calls (Monitor > History), agents (Build > Agent) and phone numbers (Deploy > Phone). Adding knowledge base sources needs **Edit** on Build > Agent, the group Retell puts knowledge bases in; a key with only Read gets a permission error there.
- **What it can change:** only the knowledge base (create one, add links or texts). It cannot delete anything, place calls or change agents or numbers.
- **Pagination:** call, agent and number lists return `{items, has_more, pagination_key}`. While `has_more` is true, send `pagination_key` back. `limit` is at most 1000 (default 50); a larger one is rejected, not trimmed. `list_calls` takes `skip` or `pagination_key`, never both. `list_knowledge_bases` returns everything at once. A call's transcript is never paged: `get_call` returns it whole.
- **Unknown ids** come back as a 404 "Not Found": the id is wrong or belongs to another Retell workspace.

## Operations
- **`list_calls`** — newest first. Filter with `filter_criteria`; every filter is a typed object and all filters must match:
  - by agent: `{"agent": [{"agent_id": "agent_abc"}]}`
  - by time (epoch milliseconds): `{"start_timestamp": {"type": "range", "op": "bt", "value": [<from_ms>, <to_ms>]}}`
  - finished calls only: `{"call_status": {"type": "enum", "op": "in", "value": ["ended"]}}`
  - by number: `{"to_number": {"type": "string", "op": "eq", "value": "+14155550123"}}`
  - by a value you passed when the call started: `{"metadata": [{"key": "candidate_id", "type": "string", "op": "eq", "value": "c_123"}]}` (same shape for `dynamic_variables` and `custom_analysis_data`).
  List items carry the post-call analysis but **not the transcript or recording**.
- **`get_call(call_id)`** — the full call: `transcript` (`Agent:` / `User:` lines), `transcript_object`, `recording_url`, `start_timestamp` / `end_timestamp` / `duration_ms`, `from_number` / `to_number` / `direction`, `metadata`, `retell_llm_dynamic_variables`, `collected_dynamic_variables`, `disconnection_reason`, and `call_analysis`: `call_summary`, `user_sentiment`, `call_successful`, `in_voicemail` and `custom_analysis_data` (the fields the agent was set up to extract, e.g. notice period or salary expectation). Analysis is empty for calls that never connected. An agent set to `everything_except_pii` or `basic_attributes_only` has its transcript and recording deleted shortly after the call, so they can be missing: use `call_analysis` then, and don't read a missing transcript as a silent call.
- **`list_agents`** / **`get_agent(agent_id)`** — find the screening agent; `get_agent` shows `post_call_analysis_data`, i.e. which `custom_analysis_data` fields to expect.
- **`list_phone_numbers`** — the account's numbers and the agents bound to them.
- **`list_knowledge_bases`** / **`get_knowledge_base(knowledge_base_id)`** — knowledge bases with their sources (each has a `source_id`, a `type` of `url`, `text` or `document`, and its `url` or `title`), `enable_auto_refresh` and `status` (`in_progress`, `complete`, `error`, `refreshing_in_progress`). Failed sources show in `error_messages`.
- **`create_knowledge_base(knowledge_base_name, urls=[...], texts=[{title, text}], enable_auto_refresh=true)`** — name under 40 characters. **Auto refresh** re-reads every link daily and **can only be set here**: the API can't turn it on later, so leave it on for any link whose content changes.
- **`add_knowledge_base_sources(knowledge_base_id, urls=[...], texts=[...])`** — add to an existing knowledge base. A link must start with `http://` or `https://`. Each knowledge base has a rolling 30-day budget (by default 200 links, 50 texts); `remaining_ingestion_quota` in the reply shows what's left, and deleting a source doesn't give it back.

## Feed a Retell agent from the second brain
Each second-brain folder can have a private link that shows only that folder's active notes. Retell reads it as a web page.
1. Get the folder link(s) the user means. Never add a link to a folder the user didn't name: a candidate-facing agent must not see folders like Business Development.
2. `list_knowledge_bases` and ask which one to use. If there is none, or the one they pick has `enable_auto_refresh: false`, offer `create_knowledge_base` with auto refresh on; without it, Retell never re-reads the link.
3. Show the user the knowledge base name and the exact links, then `add_knowledge_base_sources` on a yes.
4. Check with `get_knowledge_base` after a minute: the `status` should be `complete` and the link listed with no `error_messages`.
5. Tell the user to attach the knowledge base to the agent in Retell (the agent's **Knowledge Base** setting) if it isn't already. This connector doesn't change agents.

When a folder link is reset, the old one stops working: add the new link, then ask the user to remove the old source in Retell (the knowledge base's page in the dashboard). Hyreflow doesn't delete anything in Retell.

## Candidate call notes
1. Find the calls: `list_calls` filtered by the screening agent and a time window (or by `to_number` for one candidate). Keep `call_status` `ended`.
2. For each call, `get_call` for the transcript, summary and extracted fields. Match the candidate by phone number or by the `metadata` / dynamic variables the call was started with.
3. Write the note: a heading with the candidate's name, the date and the duration, then the summary, the extracted fields as a short list, then the transcript. Include the `recording_url` only if the user asks; it may be a link that expires.
4. Save it where the user wants it:
   - **ATS/CRM:** as a note or activity on the candidate, with that system's playbook.
   - **Google Drive or another document store:** with your assistant's own connector for it, if it has one (Hyreflow returns the note text; the assistant saves the file).

Saving is a write to the customer's own ATS or Drive: show the user the first note and where it goes, and save the rest only on a yes.

## Handoff
Read source for screening outcomes: transcript and summary → note in the ATS; `custom_analysis_data` → candidate fields; `call_successful` / `user_sentiment` → shortlist triage. Write target for what the agent should know: second-brain folder links → knowledge base.

<!-- API-SURFACE:START (auto-generated by reference/_gen_api_surface.py — do not hand-edit) -->
## Callable surface
Call via the CLI: `hyreflow tools execute retell <method> --payload '{...}'` (preview with `--dry-run`; `hyreflow tools get retell <method>` returns the live contract + cost). Base: `https://api.retellai.com`. Only the methods listed below are callable.

- `add_knowledge_base_sources(knowledge_base_id: str, *, urls: list[str] | None = None, texts: list[dict] | None = None) -> Any` — POST /add-knowledge-base-sources/{knowledge_base_id} — add links and/or texts to an existing knowledge base.
- `create_knowledge_base(knowledge_base_name: str, *, urls: list[str] | None = None, texts: list[dict] | None = None, enable_auto_refresh: bool = True) -> Any` — POST /create-knowledge-base — a new knowledge base from links and/or texts; auto refresh re-reads links daily.
- `get_agent(agent_id: str, *, version: str | int | None = None) -> Any` — GET /get-agent/{agent_id} — an agent's config, incl. the post-call analysis fields it extracts.
- `get_call(call_id: str) -> Any` — GET /v2/get-call/{call_id} — one call with transcript, recording URL, summary and custom analysis.
- `get_knowledge_base(knowledge_base_id: str) -> Any` — GET /get-knowledge-base/{knowledge_base_id} — one knowledge base: sources with their ids, status, auto refresh.
- `list_agents(*, filter_criteria: dict | None = None, limit: int | None = None, sort_order: str | None = None, pagination_key: str | None = None) -> Any` — POST /v2/list-agents — the account's voice and chat agents (limit max 1000).
- `list_calls(*, filter_criteria: dict | None = None, sort_order: str | None = None, limit: int | None = None, skip: int | None = None, pagination_key: str | None = None, include_total: bool | None = None) -> Any` — POST /v3/list-calls — calls with their post-call analysis, newest first (limit max 1000; no transcript).
- `list_knowledge_bases() -> Any` — GET /list-knowledge-bases — every knowledge base with its sources, auto refresh and status (no paging).
- `list_phone_numbers(*, filter_criteria: dict | None = None, limit: int | None = None, sort_order: str | None = None, pagination_key: str | None = None) -> Any` — POST /v2/list-phone-numbers — the account's numbers and the agents bound to them (limit max 1000).

<!-- API-SURFACE:END -->
