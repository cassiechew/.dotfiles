#!/bin/bash
# prefix+F: the feature flags you've added, newest first, with what each is
# for, its tickets and where it's on in Split.
#
#   ↑/↓  move          enter  open the flag in Harness
#   x    retire it: what that means depends on where the flag is
#        - on for everyone in Production: confirm, then a background agent
#          files a cleanup ticket and runs /ticket:run to take it out of the code
#        - a ghost (gone from the code, still in Split, unread for 14 days):
#          open it in Harness to delete. One still being read (👀) is left alone.
#   y    copy its name         t  open its ticket
#   n    write a note on it    ctrl-a  show removed flags too
#   ctrl-r  refresh now        esc  close
#
# The list draws straight from flags-scan.sh's store. When the store is more
# than REFRESH_MINUTES old, a scan runs in the background and the list
# redraws itself when it lands (fzf listens on a local port for that).
#
# fzf calls back into this script with --list, --header, --preview, --open,
# --retire, --ticket, --note, --toggle-all and --refresh.

. "$(dirname "$0")/flags-common.sh"
SELF="$0"
SCAN="$(dirname "$0")/flags-scan.sh"
REFRESH_MINUTES=10

notes() { cat "$FLAGS_NOTES" 2>/dev/null || echo '{}'; }
# actions records the retirements started from here: {flag: {started, session}}.
actions() { cat "$FLAGS_ACTIONS" 2>/dev/null || echo '{}'; }

# kind is where a flag is in its life, and icon shows it. A phantom is in the
# code but in no Split environment (it always serves control); a ghost is gone
# from the code but still in Split; retired is gone from both.
LIFECYCLE='
  def prod: (.split // [] | map(select(.env == "Production"))[0]) // {state: "none"};
  def nowhere: .split != null and all(.split[]; .state == "none");
  def lastread: prod.lastSeen;
  def recent: . != null and ((now - fromdate) < 14 * 86400);
  # Split still seeing Production evaluations means something there reads the
  # flag. Deleting it would flip that reader to control, so a ghost only counts
  # once Production has been quiet 14 days. QA and UAT reads are only noted.
  def quiet: lastread | recent | not;
  def testreads: [.split[]? | select(.env != "Production" and (.lastSeen | recent)) | .env];
  def kind:
    if (.inCode | not) then
      if .split == null then "removed" elif nowhere then "retired" elif quiet then "ghost" else "read" end
    elif $actions[.name] then "retiring"
    elif nowhere then "phantom"
    else prod.state end;
  def cleanup: .inCode and prod.state == "on" and (prod.updated // null) != null
    and ((now - (prod.updated | fromdate)) > 30 * 86400);
  def icon: {removed: "🗑️", retired: "✅", ghost: "👻", read: "👀", retiring: "🛠️", phantom: "🫥",
    on: "🟢", targeted: "🎯", off: "⚪", split: "🎲", killed: "🔴", none: "·", error: "⚠️"}[kind] // "·";
  def ago: if . == null then "never" else ((now - fromdate) / 86400 | floor) as $d
    | if $d == 0 then "today" elif $d == 1 then "yesterday" else "\($d) days ago" end end;'

# flag runs a jq program on one flag, with the lifecycle helpers and the
# notes and actions in scope.
flag() {
  "$JQ" -r --arg name "$1" --argjson notes "$(notes)" --argjson actions "$(actions)" \
    "$LIFECYCLE .scanned as \$scanned | .flags[] | select(.name == \$name) | $2" "$FLAGS_STORE"
}

# The popup's own state: whether removed flags are shown. Exported so fzf's
# callbacks into this script see the same file.
show_all() { [ -n "$FLAGS_SHOW_ALL" ] && [ -e "$FLAGS_SHOW_ALL" ]; }

list() {
  local all=""
  show_all && all=all
  "$JQ" -r --arg all "$all" --argjson notes "$(notes)" --argjson actions "$(actions)" "$LIFECYCLE"'
    .flags[] | select($all == "all" or .inCode)
    | [.name,
       "\(icon) \(.name)\(if cleanup and kind != "retiring" then " 🧹" else "" end)\(if $notes[.name] then " 📝" else "" end)",
       (.repos | map(.repo) | unique | join(" ")),
       .added]
    | @tsv' "$FLAGS_STORE"
}

# header says how fresh the list is; "refreshing" while a scan runs.
header() {
  local when status
  when=$("$JQ" -r '.scanned | fromdate | strflocaltime("%a %-d %b %H:%M")' "$FLAGS_STORE" 2>/dev/null)
  case "$1" in
    refreshing) status="🔄 refreshing, showing $when" ;;
    failed) status="⚠️ refresh failed, showing $when" ;;
    *) status="✨ updated $when" ;;
  esac
  printf '%s\n%s' \
    "$status · enter Harness · x retire · y copy · t ticket · n note · ctrl-a removed too · ctrl-r refresh" \
    "🟢 on 🎯 targeted ⚪ off · not in Prod 🧹 time to retire 🛠️ retiring 🫥 phantom 👻 ghost 👀 still read ✅ retired 📝 note"
}

preview() {
  flag "$1" '
    "\(icon) \(.name)",
    "added \(.added)" + (if .tickets | length > 0 then " · " + (.tickets | join(", ")) else "" end),
    ({retiring: "🛠️ retirement started \($actions[.name].started) (agent: \($actions[.name].session))",
      phantom: "🫥 phantom: in the code but in no Split environment, so it always serves control",
      ghost: ("👻 ghost: gone from the code, still in Split, and not evaluated in Production for 14+ days. x opens it in Harness to delete"
        + (if (testreads | length) > 0 then " (\(testreads | join(" and ")) still read it)" else "" end)),
      read: "👀 gone from the code, but Split saw it evaluated in Production \(lastread | ago). Something outside these flags.ts files still reads it: find that before deleting it",
      retired: "✅ retired: gone from the code and from Split",
      removed: "🗑️ gone from the code (ctrl-r checks whether it is still in Split)"}[kind] // empty),
    (if cleanup and kind != "retiring" then "🧹 on for everyone in Production for 30+ days: x retires it" else empty end),
    (if $notes[.name] then "", "📝 \($notes[.name])" else empty end),
    "",
    (.why // "(no comment above it in flags.ts)"),
    "",
    "Split",
    (if .split == null then "  (not checked yet)"
     else .split[] | "  \(.env | . + " " * (11 - length))\(.text)\(if .lastSeen then " · last evaluated \(.lastSeen | ago)" else "" end)",
       (.rules // [] | .[] | "      → \(.)") end),
    "",
    "Repos",
    (.repos[] | "  \(.repo | . + " " * (10 - length))added \(.added) (\(.commit))"
       + (if .ticket and .ticket != "" then " · \(.ticket)" else "" end)
       + (if .removed then " · removed \(.removed)" else "" end))'
}

# open_flag opens the flag's Harness page in the furthest environment it's
# set up in: Production, then UAT, then QA.
open_flag() {
  local path
  path=$(flag "$1" '.split // [] | map(select(.id and .envId)) | last
    | if . then "/splits/\(.id)/env/\(.envId)/definition" else empty end')
  if [ -z "$FME_URL" ]; then
    tmux display-message "Set FME_URL in ~/.config/tmux/work.env to open flags in Harness"
  elif [ -n "$path" ]; then
    open "$FME_URL$path"
  else
    tmux display-message "🫥 $1 isn't set up in Split, so there's no page to open"
  fi
}

# retire_prompt briefs the agent that takes a fully rolled out flag out of
# the code.
retire_prompt() {
  flag "$1" '
    "Retire the feature flag `\(.name)`: it is fully rolled out, so take it out of the code and keep the behaviour it gates as the only behaviour.",
    "",
    "What my flag registry knows (scanned \($scanned)):",
    "- What it was for: \(.why // "(no comment above it in flags.ts)")",
    "- Registered in: " + ([.repos[] | select(.removed == null) | "\(.repo) (added \(.added)\(if .ticket and .ticket != "" then ", \(.ticket)" else "" end))"] | join(", ")),
    "- Original tickets: \(if .tickets | length > 0 then .tickets | join(", ") else "none recorded" end)",
    "- Split: " + ([.split[] | "\(.env) \(.text)"] | join("; ")) + "; Production unchanged since \(prod.updated // "unknown")",
    "",
    "How:",
    "1. Check it is really fully on before touching anything. Read its definitions with the Harness MCP (harness_list on fme_feature_flag_definition with filters {\"feature_flag_name\": \"\(.name)\"}) and confirm Production serves on to everyone: no targeting rules, not killed. If it does not, stop and tell me what you found.",
    "2. Find every use, not only the repos above: git grep the flag name on origin/main across the repos under ~/projects, since a frontend can read a backend flag. Never read a possibly stale worktree.",
    "3. File a GO chore ticket for the cleanup in the current sprint, intent first (\"Remove the \(.name) flag now it is fully rolled out\"), linked to the original ticket.",
    "4. Run /ticket:run on that ticket and follow every gate. The change: remove the flag from each repo flags.ts and every call site, keep the on path, delete the off path and the tests that only cover it, and update tests that toggle the flag.",
    "5. Leave Split alone. Deleting the flag in Harness comes after the code is merged and deployed, and I will do it.",
    "",
    "Ask me before anything outward-facing that /ticket:run does not already cover."'
}

# start_retirement confirms, then hands the flag to a background agent and
# records it so the list shows it as retiring.
start_retirement() {
  local name=$1 repos since answer claude session out tmp
  repos=$(flag "$name" '[.repos[] | select(.removed == null) | .repo] | join(", ")')
  since=$(flag "$name" 'prod.updated // "unknown" | .[0:10]')
  printf '\n  🧹 Retire %s?\n\n' "$name"
  printf '  Production serves on to everyone (unchanged since %s).\n' "$since"
  printf '  A background agent will:\n'
  printf '    1. re-check that in Harness, and stop if it is not so\n'
  printf '    2. file a cleanup ticket in the current sprint\n'
  printf '    3. run /ticket:run on it: take the flag out of %s, keeping the on path\n' "$repos"
  printf '  It leaves Split alone. Once the PRs are merged the flag shows 👻 here,\n'
  printf '  and x then opens it in Harness to delete.\n\n'
  printf '  Start it? [y/N] '
  read -rsn1 answer
  [ "$answer" = y ] || [ "$answer" = Y ] || return

  claude=$(command -v claude || echo "$HOME/.local/bin/claude")
  session="Retire flag: $name"
  # Opus: it decides what the off path is and deletes code across repos.
  if out=$(cd "$HOME/projects" && "$claude" --bg --model opus -n "${session:0:70}" "$(retire_prompt "$name")" 2>&1); then
    tmp=$(mktemp "$FLAGS_DIR/actions.XXXXXX")
    actions | "$JQ" --arg name "$name" --arg session "$session" --arg started "$(date +%F)" \
      '.[$name] = {started: $started, session: $session}' > "$tmp" && mv "$tmp" "$FLAGS_ACTIONS"
    tmux display-message "🛠️ Retiring $name in the background. See: prefix+G"
  else
    printf '%s\n%s\n' "$(date)" "$out" >> "$HOME/.cache/flags-retire.log"
    tmux display-message "Couldn't start the agent (see ~/.cache/flags-retire.log)"
  fi
}

# retire does what retiring means for the flag where it is now.
retire() {
  local name=$1 kind
  kind=$(flag "$name" 'kind')
  case "$kind" in
    on) start_retirement "$name" ;;
    ghost)
      open_flag "$name"
      tmux display-message "👻 $name is gone from the code: delete it in Harness (each environment, then the flag)" ;;
    read) tmux display-message "👀 Something still evaluates $name, so it isn't safe to delete yet (see the preview)" ;;
    retiring) tmux display-message "🛠️ $name is already being retired: see prefix+G" ;;
    phantom) tmux display-message "🫥 $name was never set up in Split: create it there, or it always serves control" ;;
    retired) tmux display-message "✅ $name is already retired" ;;
    removed) tmux display-message "🗑️ $name is gone from the code; ctrl-r checks whether it's still in Split" ;;
    *) tmux display-message "$name is still rolling out (Production: $kind), so there's nothing to retire yet" ;;
  esac
}

open_ticket() {
  local ticket
  ticket=$(flag "$1" '.tickets[-1] // empty')
  if [ -n "$ticket" ] && [ -n "$JIRA_URL" ]; then
    open "$JIRA_URL/browse/$ticket"
  else
    tmux display-message "No ticket for $1 (or JIRA_URL isn't set in work.env)"
  fi
}

note() {
  local current text tmp
  current=$(notes | "$JQ" -r --arg name "$1" '.[$name] // ""')
  printf '\n  📝 Note for %s (empty to clear)\n' "$1"
  [ -n "$current" ] && printf '  now: %s\n' "$current"
  printf '\n  > '
  read -r text
  tmp=$(mktemp "$FLAGS_DIR/notes.XXXXXX")
  notes | "$JQ" --arg name "$1" --arg text "$text" \
    'if $text == "" then del(.[$name]) else .[$name] = $text end' > "$tmp" && mv "$tmp" "$FLAGS_NOTES"
}

toggle_all() {
  if show_all; then rm -f "$FLAGS_SHOW_ALL"; else : > "$FLAGS_SHOW_ALL"; fi
}

# tell sends fzf an action through its --listen port; quietly does nothing
# once the popup has closed. change-header goes last in its "action:text"
# form, since the header has parentheses in it.
tell() {
  curl -s --max-time 2 -X POST "http://127.0.0.1:$PORT" -d "$1" >/dev/null 2>&1
}

# refresh rescans in the background, then redraws the open list. Without
# "force" it only does that when the store is older than REFRESH_MINUTES. A
# scan that's already running (another popup's) is waited for, not repeated.
refresh() {
  PORT=$1
  if [ "$2" != force ] && [ -z "$(find "$FLAGS_STORE" -mmin +"$REFRESH_MINUTES" 2>/dev/null)" ]; then
    return
  fi
  (
    tell "change-header:$(header refreshing)"
    if [ -d "$FLAGS_DIR/.scanning" ]; then
      for _ in $(seq 600); do [ -d "$FLAGS_DIR/.scanning" ] || break; sleep 1; done
      result="done"
    elif "$SCAN" >/dev/null 2>&1; then
      result="done"
    else
      result=failed
    fi
    tell "reload($SELF --list)+change-header:$(header "$result")"
  ) </dev/null >/dev/null 2>&1 &
}

case "$1" in
  --list) list; exit ;;
  --header) header "$2"; exit ;;
  --preview) preview "$2"; exit ;;
  --open) open_flag "$2"; exit ;;
  --retire) retire "$2"; exit ;;
  --retire-prompt) retire_prompt "$2"; exit ;;
  --ticket) open_ticket "$2"; exit ;;
  --note) note "$2"; exit ;;
  --toggle-all) toggle_all; exit ;;
  --refresh) refresh "$2" "$3"; exit ;;
esac

if ! flags_configured; then
  echo "Set FLAGS_REPOS and FLAGS_AUTHOR in ~/.config/tmux/work.env. Press a key."
  read -rsn1
  exit 0
fi

# The very first run has nothing to draw, so it scans while you wait.
if [ ! -s "$FLAGS_STORE" ]; then
  printf '\n  🔄 Finding your flags for the first time (a couple of minutes)...\n'
  "$SCAN" || { printf '  Scan failed. Press a key.'; read -rsn1; exit 0; }
fi

FLAGS_SHOW_ALL=$(mktemp "${TMPDIR:-/tmp}/flags-all.XXXXXX")
rm -f "$FLAGS_SHOW_ALL"
export FLAGS_SHOW_ALL
trap 'rm -f "$FLAGS_SHOW_ALL"' EXIT

# --listen picks a free port and hands it to callbacks as $FZF_PORT; the
# start event uses it to launch the background refresh.
list | fzf --listen --delimiter='\t' --with-nth=2,3,4 --tabstop=2 --reverse --no-sort \
  --header="$(header)" --header-first \
  --preview="$SELF --preview {1}" --preview-window='right,55%,wrap,nohidden' \
  --bind="start:execute-silent($SELF --refresh \$FZF_PORT)" \
  --bind="enter:execute-silent($SELF --open {1})" \
  --bind="x:execute($SELF --retire {1})+reload($SELF --list)" \
  --bind="y:execute-silent(printf %s {1} | pbcopy; tmux display-message 'Copied {1}')+abort" \
  --bind="t:execute-silent($SELF --ticket {1})" \
  --bind="n:execute($SELF --note {1})+reload($SELF --list)" \
  --bind="ctrl-a:execute-silent($SELF --toggle-all)+reload($SELF --list)" \
  --bind="ctrl-r:execute-silent($SELF --refresh \$FZF_PORT force)"
