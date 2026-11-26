# Second brain — read the fitting notes first, offer to save after

The skills hold the general how-to. The second brain holds what is specific to this agency: its candidate
personas, proof, angles, client ICPs. Read it at the start of a task so the run starts from the agency's own
words, and offer to add to it afterwards so the next run starts smarter. It needs the `hyreflow_knowledge_*`
tools (an MCP connection). On the CLI there is no brain: say so, and keep using `ICP.md`.

## When to read

At the start of any new task or chat that is a shortlist, sourcing, outreach, BD / TAM or qualify run, and
whenever the user names a client. The client's own `ICP.md` wins when it exists (see the ICP qualify gate in
`SKILL.md`); read the brain for what it does not cover.

## Which notes fit the task

Read only the notes that fit. Reading everything dilutes the run.

| The task is | Read these notes (folder) |
| --- | --- |
| Shortlist, sourcing | Candidate personas, and the persona's note in Search filters (it feeds the `people_search` payload), Pains |
| Outreach, messaging | Angles, Pains, Triggers, Proof |
| BD, TAM, qualify | Client ICP, Client personas, Offers, Desks (an in-house team has none of these: read Candidate personas) |

An `imported-*` note (folder Imported) is the user's own file: weigh it like `ICP.md`. The index gives each
note's `type` and `status`. A `draft` of a built type (not `note`, not `imported`) was built from their public
site and is a guess: confirm it with the user before relying on it. A note the user said yes to is `active`
and is their own words, so use it.

## How to read

1. `hyreflow_knowledge_index` once.
2. `hyreflow_knowledge_read` only the notes in the matching row that fit this role, client or persona (from the
   index titles), not every note in those folders; `hyreflow_knowledge_search` when the user names a topic the
   table does not cover.
3. Say in one line which notes you used ("Using your Candidate personas and Pains notes."), then carry on.

## Offer to save (propose only)

Offer after a run the user approved or liked (a good shortlist, a BD list they kept), or when they state
something durable about their agency ("we never place contractors", "our best proof is the 2-week fill").

- Make ONE short offer, "Save this to your second brain?", with the exact note text you would write.
- Wait for a clear yes. Never write on your own, and never write because the user said nothing. The one
  exception: the user themselves asked you to remember or save it ("remember that for next time"). Then save
  it and show them the text you saved.
- A note the build wrote (`company`, a persona, an angle) changes only when the user asks to change that note.
  A new rule or learning goes in a new note, in the folder that fits it.
- On yes, call `hyreflow_knowledge_write`. A new note is saved as `active` (the default): the user confirmed
  it, so there is no draft step. Pass no `type` (it defaults to `note`) and the `folder` from the table above
  that fits it (Candidate personas, Angles, Proof, Client ICP...), so the next run that reads that row finds
  it. A member may have renamed that folder: then use the folder its notes are in now
  (`hyreflow_knowledge_index`). For an existing note, read it first and merge: send the whole merged text,
  never overwrite what is there, and keep its folder. A built `draft` the user just confirmed becomes
  `active` (the ICP qualify gate in `SKILL.md` says the same).
- Folders have permanent ids. Renaming a folder is `hyreflow_knowledge_rename_folder` (current name, new name):
  the id and every note in it stay. Changing one note's `folder` with `hyreflow_knowledge_write` moves only
  that note into another folder, so never rename a folder by rewriting each note's folder.
- Never save one-off job details (a single role, a single deadline) or personal data about a candidate or
  contact. The brain holds patterns, not records.
- It is shared: every teammate's agent reads a saved note at once, and there is no undo. That is why the
  user sees the exact text first.

## Boundary

How to do something (a recipe, a payload shape, a rule of the tools) belongs in a skill, never in the brain.
The brain only holds facts about this agency and its clients.
