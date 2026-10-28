---
name: hyreflow-second-brain
description: 'Import the user''s own ICP and company-knowledge files into their Hyreflow second brain. Use when the user asks to "import my ICP", "add my company docs to Hyreflow", or "teach Hyreflow about my business from my files".'
---

# Hyreflow Second Brain Import

Hyreflow keeps notes about the user's business (its second brain) and reads them before every search. This
skill adds the user's own documents to it. The Hyreflow server cannot see the user's computer: you read the
files with your own file tools and send their text with `hyreflow_knowledge_import`. This needs an MCP
connection: with the CLI only, there is no second brain to write to, so keep `ICP.md` up to date instead.

## Steps

1. **Ask permission first.** Ask one question: may you look through this computer for files about their ideal
   customer and company, such as `ICP.md`, personas, positioning, pricing, case studies and notes? Say plainly
   what happens: you only read text and markdown files, you skip anything that looks like a secret, and
   nothing leaves this computer until they have seen the list and said go ahead. Offer the other way in the
   same message: they can paste text, or name the files or folders to read.

2. **If they say yes, scan, and keep it small.** Use only your own file tools.
   - Start in the current working directory, then the usual document folders (Documents, Desktop, Downloads,
     a notes folder or vault if you see one).
   - Read only `.md`, `.markdown` and `.txt` files. A `.pdf` or `.docx` only when a text copy already exists
     next to it: do not convert anything.
   - Skip dependency and build folders (`node_modules`, `.git`, `dist`, `build`, caches), hidden folders,
     and anything that looks like a secret: `.env*`, keys, tokens, credentials, password exports.
   - Skip files over about 1 MB, and stop at about 50 files. A longer file is fine: only its first 64 KB is
     kept. Prefer names and headings that point at an ideal customer, personas, offers, pitch, positioning, pricing or proof (case studies, testimonials).
   - Do not open files that are plainly personal, such as taxes, medical, banking or chat exports.

3. **If they say no, ask what they want to give you.** They can paste text straight into the chat, or give
   you file paths or folders. Read only what they name. Do not scan around it.

4. **Show the list and let them drop items.** One line per file: the name, the kind it looks like (`icp`,
   `persona`, `offer`, `pitch`, `proof` or `other`) and a one-line summary. Say these will be saved for
   everyone in their workspace and their teammates' agents will read them. Ask which to remove. Send nothing
   until they confirm.

5. **Import the confirmed files.** Call `hyreflow_knowledge_import` with `files`: for each, `name`, the text as
   `content` and its `kind`. Send only the first 64 KB of each file, at most 50 files and about 100 KB of text per
   call: split a longer list across calls. Never send a file they dropped, and remove any secret you notice
   inside a file before sending it.

6. **Report back.** Say how many notes were written, and list anything skipped with the reason (for example
   an empty file, or one already imported) and any note marked `truncated`, which kept only its first 64 KB.
   If the call is refused because the brain is full, say how many notes it has room for and ask which files
   to drop, then send the shorter list. If a call returns nothing (a timeout), resend it: files already
   imported are skipped, not saved twice. Tell them the notes are saved as drafts in the Imported folder, and to review them on the
   Knowledge page in their dashboard. If their workspace has no Knowledge page, offer to list or read the imported
   notes with the knowledge tools instead. Importing never replaces a note they already have.

## Don't

- Don't read, list or send anything before they have said yes to step 1 or named the files themselves.
- Don't mark the imported notes `active` yourself: the user does that after reading them.
- Don't scan again after a "no", or widen the scan beyond what you said you would read.
