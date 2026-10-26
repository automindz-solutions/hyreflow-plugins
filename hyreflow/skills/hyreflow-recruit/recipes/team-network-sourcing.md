# Recipe — Team Network Sourcing (your team's LinkedIn connections → warm intros)

**Use when:** the user wants to source from people their team already knows: "who do we know at
Acme?", "anyone in our network who is an engineering manager?", "find warm intros for this role". Every
workspace member uploads their own LinkedIn connections once; the search then spans the whole team and
says which teammates know each person.

**Plan:** Essential and above. The search is free (0 credits).

## 1. Check who has uploaded

The dashboard shows it at **Dashboard → LinkedIn network**: each member's last upload and
connection count. Every search result also carries `uploaded_members`: how many teammates' connections it
covered. When it is `0`, nobody has uploaded yet. Say so and walk the user through step 2. Never report
that as "no one on your team knows anyone there".

## 2. Export and upload (each member, once; again whenever their network has grown)

LinkedIn delivers the export by email, so this step is the user's, not yours. Give them these steps, and
share the 16-second screen walkthrough of the same clicks: https://hyreflow.ai/docs/network-sourcing (it also
plays inside the dashboard's "How to export" guide).

1. Open LinkedIn → **Me → Settings & Privacy → Data privacy → Download your data**
   (direct link: https://www.linkedin.com/mypreferences/d/download-my-data, LinkedIn's own guides:
   https://www.linkedin.com/help/linkedin/answer/a566336/export-connections-from-linkedin and
   https://www.linkedin.com/help/linkedin/answer/a1339364/downloading-your-account-data).
2. Choose **Download larger data archive**, the first option. It is the one that includes connections:
   LinkedIn offers no connections-only export. Then click **Request archive**.
3. LinkedIn emails a download link within 24 hours. Download the zip and unzip it. `Connections.csv` is
   inside, with the columns First Name, Last Name, URL, Email Address, Company, Position, Connected On.
4. Upload only `Connections.csv` (not the zip, and none of the other files in it) at
   **Dashboard → LinkedIn network**. Re-uploading replaces the
   member's previous upload. **Remove** deletes it.

Upload the file as LinkedIn delivered it. Don't open and re-save it in a spreadsheet first, which can
change its encoding or date format. LinkedIn includes a connection's email only when that person allowed
it, so most rows carry a name, profile URL, company and position, and no email.

## 3. Search the team network

Tool `linkedin_network`, method `search`. Two ways in:

**Check a list you already have (the main play).** After sourcing, pass the candidates' LinkedIn profile URLs.
The URL is the person's identity, so this is exact: no name guessing, no namesakes. Any spelling works
(`uk.linkedin.com/in/x/?trk=…`, no scheme, trailing slash). Up to 500 per call:

```bash
hyreflow tools execute linkedin_network search --payload '{"urls":["https://www.linkedin.com/in/ada-acme","https://www.linkedin.com/in/cy-acme"]}'
```

The result lists the ones somebody on the team knows, each with `connected_via`, and **`unmatched`**: the URLs
nobody on the team is connected to. Those are cold, so they need InMail or a sequence.

**Explore by company or role** when there is no list yet:

```bash
hyreflow tools execute linkedin_network search --payload '{"company":"acme","title":"engineering manager","limit":25}'
```

On the MCP connection, call the tools-execute tool with `tool: "linkedin_network"`, `method: "search"` and the
same payload.

| Field | Meaning |
|---|---|
| `urls` | LinkedIn profile URLs to check exactly, up to 500; `unmatched` lists those nobody knows |
| `q` | free text, matched against name, company and position |
| `company` | narrows the current company (substring, case-insensitive) |
| `title` | narrows the current position (substring, case-insensitive) |
| `limit` | 1-100, default 25 (a `urls` check always answers for every URL) |
| `offset` | where the page starts, default 0: pass the previous result's `next_offset` |

At least one of `urls`, `q`, `company` or `title` is required. Each result is one person with `first_name`,
`last_name`, `url`, `email` (often empty), `company`, `position`, and **`connected_via`**: the emails of the
teammates connected to them. People known by more teammates come first. `has_more: true` means more people
match: narrow the filters first. Page only when the user wants the full list, by repeating the same search
with `offset` set to the result's `next_offset` until `has_more` is false. `uploaded_members` is the number of teammates whose connections were
searched (see step 1).

Company and position are what the person had **when the teammate exported**, so they can be stale. Before
an intro, confirm the person still holds the role (an enrichment lookup on the profile `url`).

## 4. Hand off

Present matches grouped by teammate (`connected_via`). The play is **a warm intro through that teammate**,
not a cold message. Draft the ask for the teammate to send, or a note mentioning them. Never send anything
on the user's behalf without their explicit go-ahead, and never automate LinkedIn sends.

For people nobody on the team knows, fall back to the `people_search` waterfall as usual.
