#!/bin/bash
# prefix+F: the feature flags you've added, newest first, with what each is
# for, its tickets and where it's on in Split.
#
#   ↑/↓  move          enter  open the flag in Harness
#   y    copy its name         t  open its ticket
#   n    write a note on it    ctrl-a  show removed flags too
#   ctrl-r  refresh now        esc  close
#
# The list draws straight from flags-scan.sh's store. When the store is more
# than REFRESH_MINUTES old, a scan runs in the background and the list
# redraws itself when it lands (fzf listens on a local port for that).
#
# fzf calls back into this script with --list, --header, --preview, --open,
# --ticket, --note, --toggle-all and --refresh.

. "$(dirname "$0")/flags-common.sh"
SELF="$0"
SCAN="$(dirname "$0")/flags-scan.sh"
REFRESH_MINUTES=10

notes() { cat "$FLAGS_NOTES" 2>/dev/null || echo '{}'; }

# icon is a flag's Production state at a glance.
ICONS='def icon: if . == null then "🗑️" elif all(.[]; .state == "none") then "👻" else
    (map(select(.env == "Production"))[0] // {state: "none"}).state as $s
    | {on: "🟢", targeted: "🎯", off: "⚪", split: "🎲", killed: "🔴", none: "·", error: "⚠️"}[$s] // "·" end;'

# cleanup: on for everyone in Production, unchanged for 30 days.
CLEANUP='def cleanup: (.split // [] | map(select(.env == "Production"))[0]) as $p
    | $p.state == "on" and ($p.updated // null) != null
      and ((now - ($p.updated | fromdate)) > 30 * 86400);'

# The popup's own state: whether removed flags are shown. Exported so fzf's
# callbacks into this script see the same files.
show_all() { [ -n "$FLAGS_SHOW_ALL" ] && [ -e "$FLAGS_SHOW_ALL" ]; }

list() {
  local all=""
  show_all && all=all
  "$JQ" -r --arg all "$all" --argjson notes "$(notes)" "$ICONS $CLEANUP"'
    .flags[] | select($all == "all" or .inCode)
    | [.name,
       "\(.split | icon) \(.name)\(if cleanup then " 🧹" else "" end)\(if $notes[.name] then " 📝" else "" end)",
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
    "$status · enter open in Harness · y copy · t ticket · n note · ctrl-a removed too · ctrl-r refresh" \
    "🟢 on 🎯 targeted ⚪ off · not in Prod 👻 not in Split 🔴 killed 🧹 time to remove 📝 note"
}

preview() {
  "$JQ" -r --arg name "$1" --argjson notes "$(notes)" "$ICONS $CLEANUP"'
    def ago: if . == null then "never" else ((now - fromdate) / 86400 | floor) as $d
      | if $d == 0 then "today" elif $d == 1 then "yesterday" else "\($d) days ago" end end;
    .flags[] | select(.name == $name)
    | "\(.split | icon) \(.name)",
      "added \(.added)" + (if .tickets | length > 0 then " · " + (.tickets | join(", ")) else "" end),
      (if cleanup then "🧹 on for everyone in Production for 30+ days: time to remove it?" else empty end),
      (if $notes[.name] then "", "📝 \($notes[.name])" else empty end),
      "",
      (.why // "(no comment above it in flags.ts)"),
      "",
      "Split",
      (if .split == null then "  (not checked: the flag is gone from the code)"
       else .split[] | "  \(.env | . + " " * (11 - length))\(.text)\(if .lastSeen then " · last evaluated \(.lastSeen | ago)" else "" end)",
         (.rules // [] | .[] | "      → \(.)") end),
      "",
      "Repos",
      (.repos[] | "  \(.repo | . + " " * (10 - length))added \(.added) (\(.commit))"
         + (if .ticket and .ticket != "" then " · \(.ticket)" else "" end)
         + (if .removed then " · removed \(.removed)" else "" end))' "$FLAGS_STORE"
}

# open_flag opens the flag's Harness page in the furthest environment it's
# set up in: Production, then UAT, then QA.
open_flag() {
  local path
  path=$("$JQ" -r --arg name "$1" '
    .flags[] | select(.name == $name) | .split // [] | map(select(.id and .envId)) | last
    | if . then "/splits/\(.id)/env/\(.envId)/definition" else empty end' "$FLAGS_STORE")
  if [ -z "$FME_URL" ]; then
    tmux display-message "Set FME_URL in ~/.config/tmux/work.env to open flags in Harness"
  elif [ -n "$path" ]; then
    open "$FME_URL$path"
  else
    tmux display-message "👻 $1 isn't set up in Split, so there's no page to open"
  fi
}

open_ticket() {
  local ticket
  ticket=$("$JQ" -r --arg name "$1" '.flags[] | select(.name == $name) | .tickets[-1] // empty' "$FLAGS_STORE")
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
  --bind="y:execute-silent(printf %s {1} | pbcopy; tmux display-message 'Copied {1}')+abort" \
  --bind="t:execute-silent($SELF --ticket {1})" \
  --bind="n:execute($SELF --note {1})+reload($SELF --list)" \
  --bind="ctrl-a:execute-silent($SELF --toggle-all)+reload($SELF --list)" \
  --bind="ctrl-r:execute-silent($SELF --refresh \$FZF_PORT force)"
