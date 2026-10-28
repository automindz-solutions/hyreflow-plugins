# Monitors: watch something on a schedule for what's new

A **monitor** checks something on a schedule and records each new item it finds. Hyreflow runs the checks:
there is nothing to build, schedule or keep running. Each monitor has a `type`, which says what it watches,
the shape of its `config` and of its items, and its price. `hyreflow_monitor_save`'s description lists every
type. Today there is one:

- `company_jobs`: a company's careers page, one item per job. For an agency, a company that just opened
  roles is the moment to pitch candidates, so it is a business-development signal. Its details are under
  "Type: company_jobs" below.

Monitors are in beta. There is no `hyreflow` CLI command for them: use the MCP tools below, or the
dashboard's **Monitors** page, or the API (`/api/v2/monitors`, see https://hyreflow.ai/docs/api-reference).

Monitors are turned on per workspace. If `hyreflow_monitor_save` isn't in your tool list, this workspace
doesn't have them: say monitors are in beta and the user can ask Hyreflow to turn them on, and don't offer one.

## When to suggest one

- The user wants to know **when** something changes, on a schedule, and a monitor type watches it. Don't
  create a monitor for a one-off answer.
- For `company_jobs`: the user wants to know **when** a company posts roles: "tell me when Acme hires again", "keep an eye on
  these companies' careers pages", "alert me to new sales jobs at Acme".
  The user asks for a company's open roles today **and** wants to follow them over time. For a one-off
  list, a single career-page scrape is enough.

A monitor watches one thing (for `company_jobs`, one company). For several, create one each (a workspace
can have up to 25). A workspace watches each thing once: call `hyreflow_monitors_list` first, and if a
monitor already watches it, change that one instead. Saving a duplicate is refused, naming the one that
watches it.

## The tools

- `hyreflow_monitor_save` creates a monitor (`type`, `config`) or changes one (`monitor_id`). Its
  description lists each type's `config` settings. The schedule is `cron` in UTC, daily at 09:00 by default
  and at most hourly.
- `hyreflow_monitors_list` lists the workspace's monitors, each with its last check and how many new items
  it found.
- `hyreflow_monitor_items` returns the items a monitor found, newest first. `since` keeps only the ones first
  seen after a time. `baseline: true` marks items that were already there when the monitor started: they
  are not new.

## Before you create one: say what it costs, and ask

A monitor spends credits on its own schedule, long after this conversation, and its first check runs
within minutes of saving. Every completed check costs the type's fee, whatever it finds, plus a price for
each NEW item; items seen before are free, and a check that fails costs nothing. The current prices are in
`hyreflow_monitor_save`'s description, after each type ("Price: ..."): quote them from there, never from
memory. The save tool only returns the price after it has created the monitor, so work the figure out first
and tell the user, before saving:

1. what it will watch,
2. how often it checks (daily is about 30 checks a month, weekly about 4),
3. about what it costs: the fee × the checks a month, plus the price of each new item it finds,

and ask them to confirm, as a structured question if your client has one. Only then call
`hyreflow_monitor_save`. Its `estimate.price` is the current price: if it differs from what you quoted, tell
the user the corrected figure right away, and pause the monitor if they no longer want it.

## After saving

- The first check runs within about 5 minutes and takes a few minutes. It records what's already there,
  marks it `baseline`, and reports none of it as new. Tell the user that, so an empty "new" list after the
  first check doesn't read as a failure.
- Point them to the dashboard. Its words differ from the API's: there, a monitor is a type (**Jobs**), each
  monitor you create is a **schedule** under it, and each check is a **run**. So: **Monitors** → **Jobs** →
  the schedule, to see what it found, its runs and the cost.
- To stop a monitor, set `status: "paused"`. There is no delete tool: the user deletes a monitor on the
  schedule's page on the dashboard.
- Changing any `config` setting starts the monitor over: the items found so far are cleared and the next
  check is a new baseline. Say so before you change one.

## Type: company_jobs

- `config`: `company_url` is the only required setting. `target_titles` and `target_locations` narrow which
  jobs are watched. `max_pages` is how many pages of the careers site a check reads: the tool's description
  gives its range and default, and what each page above the default adds to the fee.
- Price: per check, plus per new job, as the tool's description says. For example, a daily check is about 30
  checks a month: 30 × the fee, plus the price of each new job the company posts.
- Each item is a job: its title, location and link. On the dashboard: **Monitors** → **Jobs**.
