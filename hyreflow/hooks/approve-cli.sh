#!/bin/sh
# Shared approval hook for the Hyreflow plugin across Claude Code, Cursor, and
# Codex. Each agent prompts before running shell commands; this auto-approves a
# read-only, NON-SPENDING `hyreflow` CLI call (optionally piped through a small
# set of read-only helpers) so the plugin stops asking on every status/search.
# The verdict shape differs per agent, selected by the first argument:
#
#   claude -> PreToolUse           (input .tool_input.command)
#   codex  -> PermissionRequest    (input .tool_input.command)
#   cursor -> beforeShellExecution (input .command)
#
# "allow" only skips the prompt; deny/ask rules (including managed deny lists)
# still take precedence, so this can't punch through an admin block.
#
# ALLOWLIST, not denylist: a `hyreflow` call auto-approves only when its
# subcommand is one that never spends credits and never mutates auth --
#   hyreflow session ...      (live-run progress registration)
#   hyreflow status
#   hyreflow auth status      (NOT login/logout)
#   hyreflow tools search ... (NOT tools execute)
#   hyreflow skills list      (NOT skills install)
#   hyreflow update --check   (NOT a bare `update`)
# Everything else -- tools execute, enrich, workflows run, auth login/logout,
# feedback, connect, quickstart, a bare `hyreflow`, or anything unrecognized --
# falls through to the normal permission prompt. An auto-approver bug is a
# security hole, so this errs toward prompting.

agent="${1:-claude}"

# Helpers allowed to sit on either side of `hyreflow` in a pipeline. Read-only by
# intent. echo/printf only emit literal args (never open a file/socket), so they
# are exempt from the path/file-flag guards -- see the awk pass.
allowed_helpers="jq cat head tail wc grep sort uniq column tr echo printf"

# Harden: no globbing, unset variables are errors so a typo can't widen approval.
set -fu

# Fail open to the normal prompt if we lack the tools we rely on to parse the
# event (jq) or to vet the command (awk).
command -v jq > /dev/null 2>&1 || exit 0
command -v awk > /dev/null 2>&1 || exit 0

input="$(cat)"

case "$agent" in
  cursor)
    cmd="$(printf '%s' "$input" | jq -r '.command // empty' 2> /dev/null)"
    ;;
  *)
    cmd="$(printf '%s' "$input" | jq -r 'if .tool_name == "Bash" then .tool_input.command // empty else empty end' 2> /dev/null)"
    ;;
esac

[ -n "$cmd" ] || exit 0

# Strip harmless redirections (to /dev/null, and fd-to-fd dups) before the safety
# checks. Any redirect to a real file is left intact so it still prompts.
cmd_stripped="$(printf '%s' "$cmd" | sed -E '
  s#([0-9]*|&)>>?[[:space:]]*/dev/null([[:space:]]|$)#\2#g
  s/[0-9]*>&[0-9]+//g
')"

# Reject command chaining / redirection / substitution / env-expansion / escapes
# outright. Runs on the raw (quoted) string so even a quoted metachar is refused.
# The backslash reject keeps the awk segment splitter in sync with the shell.
case "$cmd_stripped" in
  *';'* | *'&'* | *'<'* | *'>'* | *'`'* | *'$'* | *'\'*) exit 0 ;;
esac

# Reject multi-line commands (heredocs, embedded scripts).
[ "$(printf '%s' "$cmd_stripped" | wc -l | tr -d ' ')" = "0" ] || exit 0

# Bound the input so the char-by-char awk pass can't scan an unbounded string.
[ "${#cmd_stripped}" -le 10000 ] || exit 0

# Validate the pipeline in a single quote-aware pass. awk splits on unquoted
# pipes, trims each segment, then:
#   - reject any segment leading with a `VAR=value` assignment (never vetted);
#   - exactly the `hyreflow` segment(s) must carry an allowlisted, non-spending
#     subcommand (see header) -- resolved from the first one/two non-flag words
#     plus a --check scan for `update`;
#   - every other segment must be an allowlisted helper, referencing no path
#     (`/`, `~`) or read/write file flag; echo/printf exempt (literal args only).
verdict="$(printf '%s' "$cmd_stripped" | awk -v helpers="$allowed_helpers" '
  BEGIN {
    n = split(helpers, a, " ")
    for (i = 1; i <= n; i++) H[a[i]] = 1
    sq = sprintf("%c", 39)
  }
  {
    inq = ""; nseg = 0; cur = ""
    for (i = 1; i <= length($0); i++) {
      c = substr($0, i, 1)
      if (inq != "") { cur = cur c; if (c == inq) inq = ""; continue }
      if (c == sq || c == "\"") { inq = c; cur = cur c; continue }
      if (c == "|") { seg[nseg++] = cur; cur = ""; continue }
      cur = cur c
    }
    seg[nseg++] = cur

    saw_hf = 0
    for (s = 0; s < nseg; s++) {
      t = seg[s]
      sub(/^[ \t]+/, "", t)
      sub(/[ \t]+$/, "", t)
      if (t ~ /^[A-Za-z_][A-Za-z0-9_]*=/) exit
      tok = t
      sub(/[ \t].*$/, "", tok)
      if (tok == "hyreflow") {
        saw_hf = 1
        rest = t
        sub(/^hyreflow([ \t]+|$)/, "", rest)
        m = split(rest, w, /[ \t]+/)
        sub1 = ""; sub2 = ""; has_check = 0; ni = 0
        for (j = 1; j <= m; j++) {
          if (w[j] == "") continue
          if (w[j] == "--check") has_check = 1
          if (substr(w[j], 1, 1) == "-") continue
          ni++
          if (ni == 1) sub1 = w[j]
          else if (ni == 2) sub2 = w[j]
        }
        gsub(/"/, "", sub1); gsub(sq, "", sub1)
        gsub(/"/, "", sub2); gsub(sq, "", sub2)
        # Refuse any globbable subcommand token.
        if (sub1 ~ /[][*?]/ || sub2 ~ /[][*?]/) exit
        ok = 0
        if (sub1 == "session" || sub1 == "status") ok = 1
        else if (sub1 == "auth" && sub2 == "status") ok = 1
        else if (sub1 == "tools" && sub2 == "search") ok = 1
        else if (sub1 == "skills" && sub2 == "list") ok = 1
        else if (sub1 == "update" && has_check) ok = 1
        if (!ok) exit
      } else {
        if (!(tok in H)) exit
        if (tok != "echo" && tok != "printf") {
          if (index(t, "/") > 0) exit
          if (index(t, "~") > 0) exit
          if (t ~ /(^|[ \t])--(output|file)([ \t]|=|$)/) exit
          if (t ~ /(^|[ \t])-[A-Za-z]*[of]/) exit
        }
      }
    }
    if (saw_hf) print "allow"
  }
')"

[ "$verdict" = "allow" ] || exit 0

case "$agent" in
  cursor)
    printf '%s\n' '{"continue":true,"permission":"allow"}'
    ;;
  codex)
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
    ;;
  claude | *)
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"read-only Hyreflow CLI command is allowlisted by the Hyreflow plugin"}}'
    ;;
esac
