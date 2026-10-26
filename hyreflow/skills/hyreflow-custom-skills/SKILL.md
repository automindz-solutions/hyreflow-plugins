---
name: hyreflow-custom-skills
description: 'Save, update or share a way of working as a Hyreflow custom skill for this workspace or team. Use when the user asks to save, remember or share how they work in Hyreflow as a skill, or to change one.'
---

# Hyreflow custom skills

A **custom skill** is a set of instructions the people in a Hyreflow workspace write for their agents:
how the team sources, the tone of its outreach, the checks before a shortlist goes out. The user
describes how they work; you write the skill for them. Most users aren't technical, so never ask them
to write the file themselves, and don't talk about YAML or frontmatter.

## 1. Check you can save one

Saving needs the `hyreflow_custom_skill_*` tools, which come with the Hyreflow MCP connection. The
dashboard can't create or edit a skill; it only shows them for reading and approval. If your client
doesn't list the tools, you can't save a skill from here: tell the user to connect Hyreflow over MCP
(the docs page "MCP setup") and ask again. Offer to write the draft now (steps 3 and 4) so it's ready.

When the user gives you a skill's name from the dashboard's **Copy name** button, find it in
`hyreflow_custom_skills_list` and change that skill (step 2).

## 2. Look for an existing skill first

Call `hyreflow_custom_skills_list`. If a skill already covers this topic, read it with
`hyreflow_custom_skill_read` and save a new version of it (pass its `skill_id`) instead of creating a
second one that says nearly the same thing. If that skill shows `draft_by_other: true`, another
member's update is already waiting for the owner, and a new version will be refused until the owner
decides. Tell the user before you draft anything.

## 3. Ask, in plain words, at most three questions

1. What should the agent do, or do differently?
2. When does it apply? (Which tasks, roles, clients.)
3. Is it just for you, or for the whole team?

Skip any question the conversation has already answered. A **personal** skill is the user's alone. A
**team** skill is shared with everyone in the workspace.

## 4. Write it

The package is a `SKILL.md` and, if needed, more text files beside it.

- **`name`**: lowercase letters, digits and single hyphens, up to 64 characters, and it can't start
  with `hyreflow`. It can't be changed later, so make it say what the skill is (`acme-outreach-tone`).
- **`description`**: one line, with no angle-bracket tags, that says what the skill does **and when to
  use it**. The agent decides
  whether to read the skill from this line alone, so name the tasks it applies to.
- **Body**: short. The steps or rules to follow, then one example of good output. Write instructions
  the agent can act on ("Keep emails under 120 words"), not background. Use the user's own rules and
  details; don't invent facts about their company, clients or roles. Where you need one you don't have,
  write a placeholder such as `[booking link]`.
- **Longer material** (a full template, a list of target companies) goes in its own file, such as
  `references/templates.md`, with a line in the body saying when to read it.
- Keep the top block to the two flat lines `name:` and `description:`. Nothing nested.
- Text files only (`.md`, `.txt`, `.json`, `.yaml`, `.yml`, `.csv`). No scripts, no commands that pipe
  a download into a shell, and nothing that needs admin rights. Those are refused.

A complete small skill:

```md
---
name: acme-outreach-tone
description: House tone for every first message Acme sends to a candidate. Use when drafting or reviewing candidate outreach.
---

# Acme outreach tone

- Open with the role and why this person fits, in one sentence.
- Keep it under 120 words.
- Never mention salary in the first message.
- End with one question they can answer in a line.

Example: "Hi Sam, we're hiring a ward manager at St Mary's and your five years running a surgical
ward stood out. Would a ten-minute call this week work?"
```

## 5. Show the draft, then save

Show the user what the skill will tell the agent to do, in plain words, and ask if it's right. Then call
`hyreflow_custom_skill_save` with `files` as `{"SKILL.md": "...", "references/...": "..."}`, and either
`scope` for a new skill (`personal`, or `org` for a team skill), or `skill_id` for a new version of an
existing one.

## 6. Say what happened, accurately

Go by what the save returns, not by who you think the user is. Check `changed` first.

- **`changed: false`:** nothing new was saved, because it matches the latest version. Say so.
- **`status: approved`:** live now. For a team skill, that means for everyone (the user is the workspace
  owner).
- **`status: pending`:** **waiting for the workspace owner's approval** on the dashboard; Hyreflow lets
  the owner know by email. Don't tell the user it's live. Until the owner approves, the team keeps the
  last approved version, or has nothing yet if this skill has never been approved.
- **Refused because another member's update is waiting:** you can't save a new version until the owner
  approves or rejects that one. Tell the user, and offer to keep the draft until then.

## If a save is refused

The error message says what to fix: the name, the description line, a file type, a path, the size, or
a line the checks don't allow. Fix that one thing, tell the user what you changed if it changes the
meaning, and save again.
