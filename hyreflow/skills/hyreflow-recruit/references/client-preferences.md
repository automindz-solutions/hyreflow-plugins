# Client preferences (the Clients group in the second brain)

An agency works with many clients, each with its own taste ("prefers Mandarin speakers", "open to remote").
Keep one note per client in the second brain, read it before you build for that client, and grow it as the user
tells you more. The CLI has no second brain: there, keep a `clients.md` next to `ICP.md` in the project folder (not in a
`hyreflow/data/` task folder) with the same bullets and the same rules.

## The note

- Folder `Clients` (a member may have renamed it: then the folder the other `client`-tagged notes are in), tag
  `client`, title = the client's name, slug `clients-<name>`: the name lowercased,
  apostrophes dropped, every other run of characters that is not ASCII `a-z` or `0-9` turned into one hyphen
  (`Acme's Partners` -> `clients-acmes-partners`, `Acmé Grüp` -> `clients-acm-gr-p`), no hyphen at either
  end, the whole slug (prefix included) at most 100 characters. If nothing is left (a name in another
  script), use a short Latin transliteration and say which. The `clients-` prefix keeps a client called
  "Company" or "Persona X" from colliding with the build's own `company` and `client-persona-*` notes.
- Only a note tagged `client` whose title is this client's name is this client's note (ignore case and a
  legal suffix such as Inc. or GmbH: "ACME" and "Acme Inc." are Acme). Two names can give one slug (`Acmé`
  and `Acmè`): if the tag or title does not match, it is not this client's, so never edit it; search the
  client name instead, ask the user when unsure, and for a new client add a short suffix to the slug.
- Body = a short `Preferences` bullet list: language, remote or onsite, seniority, must-haves, exclusions, the
  kinds of profile they turned down before (never a named person), fees or terms only if the user states them.
- Preferences about the client's hiring only. Never personal data about a candidate or a contact.

## Read it first

When the user names a client, or says "for <client>", at the start of a shortlist, sourcing, outreach or BD task,
`hyreflow_knowledge_read` `clients-<name>` with `view: full` (the default view hides `folder` and `status`;
`hyreflow_knowledge_search` the client name if the slug is unknown).
Apply the preferences to the `people_search` payload, the qualify must-haves and the outreach copy, and say in
one line which ones you applied. These notes are the user's own words, so use them.
Here "client" means the agency's customer; the ICP.md that SKILL.md calls "the client's own" is the agency's.
The user's words in this chat win over the note. The note narrows the agency's ICP.md for this client's
searches; if the two clash outright, ask the user which holds.

## Save it, propose only

When the user states a durable client preference, offer ONE short "Save this to <client>'s note?" and show the
exact bullet you would add. Wait for a clear yes; never write unprompted.

- Only what holds for the client's hiring in general. A one-off job detail ("this role needs 5 years") is not a
  preference.
- Existing note: read it again right before writing (a teammate may have changed it), add the bullet, keep
  every existing bullet, and send the FULL body back with `hyreflow_knowledge_write` (`body` replaces the whole
  text, it does not append; the last write wins).
- New client: propose creating the note; once the user says yes, write it. It is saved as `active` (the
  default), because the user confirmed it. There is no draft step.

## Seeding (only when asked)

Only when the user asks ("add my clients from the CRM"): list the client names found in the connected CRM or ATS,
let them drop items, create nothing before they confirm, then one note per confirmed client holding only
hiring preferences the user said or the CRM shows (never a contact's name, email or phone). The brain holds at most 500 notes in all: check
`hyreflow_knowledge_index` first and, if the list would not fit, say so and let the user pick. Never crawl on
your own.
