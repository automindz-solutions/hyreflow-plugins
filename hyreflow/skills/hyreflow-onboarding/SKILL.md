---
name: hyreflow-onboarding
description: 'First run with Hyreflow. Use when the user says "Run hyreflow onboarding for me", asks to be onboarded ("onboard me"), or wants to get started with Hyreflow.'
---

# Hyreflow Onboarding

Over the MCP connection (most people), use the `hyreflow_*` tools your client lists. The user has just
connected Hyreflow and pasted their first prompt, and their Hyreflow setup page is open in a browser tab,
following each step. Get them to a real result quickly, on something about their own work. The whole
thing should take a couple of minutes.

## Steps

0. **Start onboarding.** If this text did not arrive from `hyreflow_onboarding`, call it now with no
   arguments: that call is what moves the setup page on. Then say hello in two lines: Hyreflow finds
   candidates, hiring companies and contact details for recruiters, straight from this chat, and you'll
   run one small search together to show how it works.

1. **Check for a second brain.** The `start` call may have returned `brain` (Hyreflow reading their
   company's website: the one they gave on the setup page, else their work email's domain). Then:
   - **`status: "done"`:** call `hyreflow_knowledge_index`, open the top candidate persona with
     `hyreflow_knowledge_read`, and say it back in one line, for example "Hyreflow read acme.example.com and
     the person you hire for most looks like <persona>: right?". If they confirm, run step 3's people
     search with a payload built from the persona's Search filter note, and skip the question below.
     If that persona was a `draft`, also set it `status: "active"` with `hyreflow_knowledge_write`: they
     just confirmed it. If not, ask the question below.
   - **`status: "running"`:** say in one line that Hyreflow is still reading their website, then ask the
     question below.
   - **`status: "failed"`, or no `brain`:** ask the question below.

   **Ask one question:** what role and location are they recruiting for right now (for example "senior
   backend engineers in Berlin")? If they'd rather not say, use that example.

2. **Tell the setup page you're searching.** Call `hyreflow_onboarding` with `step: "progress"` and
   `note: "Running your first search"`. When its answer carries `brain` with `status: "done"` and you have
   not searched yet, the build finished while you talked: use it as in step 1.

3. **Run ONE small, real search, 5 people.** Use `hyreflow_tools_execute` with `tool: "people_search"`
   and a payload of `titles`, `locations` and `"limit": 5`, passing the user's own words as
   `user_prompt`. Do not use `dry_run` here: it returns no people to show.
   - If the call returns `confirmation_required`, tell the user the quoted cost in one line and repeat
     the call with `approved_credits` set to that cost once they say yes.
   - If it comes back empty, widen once (drop the seniority words, or use the country instead of the
     city) and run it again. Don't loop more than that: say what you tried and move on.

4. **Show the results** as a short table: name, title, company, location, LinkedIn. One line on where
   they came from.

5. **Finish onboarding.** Call `hyreflow_onboarding` with `step: "completed"`. Then end with one short
   message:
   - **If they came from the Hyreflow setup page** (`hyreflow_onboarding` returned `setup_page: true`),
     send them back to that tab: it has finished setting up, and from there they can join
     the community and open their dashboard, which shows what else to ask for and where to connect their
     CRM or sequencer. If the `completed` answer carries `closing` (their second brain landed), say it
     word for word: "Head back to your setup tab, your second brain (N notes) is waiting there." Do not
     offer follow-up searches or ready-made prompts here: the next step is the setup tab, not more chat.
   - **Otherwise** (no setup page, for example with the CLI), offer two or three next things, each as a
     sentence they can just say back to you: "Get work emails for these 5." / "Which companies in <their
     location> are hiring <their role> right now?" / "Build me a shortlist from this job description:
     <paste it>." When a second brain is ready and you have the `hyreflow_knowledge_*` tools, lead with
     "Show me what Hyreflow learned about my business."

## Don't

- Don't run more than the one search before step 4. This is a first impression, not a full campaign.
- Don't ask a questionnaire. One question, then show them something.
- For anything beyond these steps, use the `hyreflow-recruit` skill.

**With the CLI instead:** the same search runs through `hyreflow tools execute` (see `hyreflow-quickstart`
for the command shapes). The setup page follows the MCP connection, so connect over MCP to see it move.
The CLI has no second-brain tools: skip step 1's check and ask the question, and do not offer "Show me
what Hyreflow learned about my business.", which only an MCP connection can answer.
