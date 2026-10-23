#!/bin/bash
# prefix+F: the feature flags you've added, newest first, with what each is
# for, its tickets and where it's on in Split.
#
#   ↑/↓  move          enter  copy the flag name
#   t    open its ticket       n  write a note on it
#   ctrl-a  show removed flags too
#   ctrl-r  rescan now (the store also rescans itself when it's 12h old)
#   esc  close
#
# The list comes from flags-scan.sh's store. fzf calls back into this script
# with --list, --preview, --ticket and --note and a flag's name.

. "$(dirname "$0")/flags-common.sh"
SELF="$0"
SCAN="$(dirname "$0")/flags-scan.sh"
STALE_MINUTES=720

notes() { cat "$FLAGS_NOTES" 2>/dev/null || echo '{}'; }

# icon is a flag's Production state at a glance.
ICONS='def icon: if . == null then "🗑️" elif all(.[]; .state == "none") then "👻" else
    (map(select(.env == "Production"))[0] // {state: "none"}).state as $s
    | {on: "🟢", targeted: "🎯", off: "⚪", split: "🎲", killed: "🔴", none: "·", error: "⚠️"}[$s] // "·" end;'

# cleanup: on for everyone in Production, unchanged for 30 days.
CLEANUP='def cleanup: (.split // [] | map(select(.env == "Production"))[0]) as $p
    | $p.state == "on" and ($p.updated // null) != null
      and ((now - ($p.updated | fromdate)) > 30 * 86400);'

list() {
  "$JQ" -r --arg all "${1:-}" --argjson notes "$(notes)" "$ICONS $CLEANUP"'
    .flags[] | select($all == "all" or .inCode)
    | [.name,
       "\(.split | icon) \(.name)\(if cleanup then " 🧹" else "" end)\(if $notes[.name] then " 📝" else "" end)",
       (.repos | map(.repo) | unique | join(" ")),
       .added]
    | @tsv' "$FLAGS_STORE"
}

preview() {
  "$JQ" -r --arg name "$1" --arg jira "${JIRA_URL:-}" --argjson notes "$(notes)" "$ICONS $CLEANUP"'
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

rescan() {
  printf '\n  🔄 Rescanning your flags (about a minute)...\n'
  "$SCAN" || { printf '  Scan failed. Press a key.'; read -rsn1; }
}

case "$1" in
  --list) list "$2"; exit ;;
  --preview) preview "$2"; exit ;;
  --ticket) open_ticket "$2"; exit ;;
  --note) note "$2"; exit ;;
  --rescan) rescan; exit ;;
esac

if ! flags_configured; then
  echo "Set FLAGS_REPOS and FLAGS_AUTHOR in ~/.config/tmux/work.env. Press a key."
  read -rsn1
  exit 0
fi

# First run: build the store while you wait. After that, a stale store is
# rescanned in the background and this popup shows what it has.
if [ ! -s "$FLAGS_STORE" ]; then
  rescan
elif [ -n "$(find "$FLAGS_STORE" -mmin +"$STALE_MINUTES" 2>/dev/null)" ]; then
  (nohup "$SCAN" >/dev/null 2>&1 &)
fi
[ -s "$FLAGS_STORE" ] || exit 0

scanned=$("$JQ" -r '.scanned | fromdate | strflocaltime("%a %-d %b %H:%M")' "$FLAGS_STORE")
header="enter copy · t ticket · n note · ctrl-a removed too · ctrl-r rescan · esc · scanned $scanned
🟢 on 🎯 targeted ⚪ off · not in Prod 👻 not in Split 🔴 killed 🧹 time to remove 📝 note"

list | fzf --delimiter='\t' --with-nth=2,3,4 --tabstop=2 --reverse --no-sort \
  --header="$header" --header-first \
  --preview="$SELF --preview {1}" --preview-window='right,55%,wrap,nohidden' \
  --bind="enter:execute-silent(printf %s {1} | pbcopy; tmux display-message 'Copied {1}')+abort" \
  --bind="t:execute-silent($SELF --ticket {1})" \
  --bind="n:execute($SELF --note {1})+reload($SELF --list)" \
  --bind="ctrl-a:reload($SELF --list all)" \
  --bind="ctrl-r:execute($SELF --rescan)+reload($SELF --list)"
