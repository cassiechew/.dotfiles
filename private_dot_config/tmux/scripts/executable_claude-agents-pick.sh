#!/bin/bash
# prefix+G: background Claude sessions in an fzf popup, waiting ones first,
# then working, then ones that finished in the last day. The preview shows
# each session's latest message.
#
#   ↑/↓  move      enter  attach in a new tmux window
#   esc  close
#
# fzf calls back into this script with --preview and a session id.

. "$(dirname "$0")/claude-common.sh"
SELF="$0"

session() { "$JQ" -c --arg id "$1" '.[] | select(.id == $id)' "$AGENTS_FILE"; }

preview() {
  local s
  s=$(session "$1")
  printf '%s' "$s" | "$JQ" -r '
    "\(.name // .id)",
    "\(.state) · started \((.startedAt / 1000) | strflocaltime("%a %d %b %H:%M")) · \(.cwd)",
    "attach: claude attach \(.id)",
    "",
    "── latest message ──"'
  last_message "$(printf '%s' "$s" | "$JQ" -r .cwd)" "$(printf '%s' "$s" | "$JQ" -r .sessionId)"
}

case "$1" in
  --preview) preview "$2"; exit ;;
esac

AGENTS_FILE=$(mktemp "${TMPDIR:-/tmp}/claude-agents.XXXXXX")
export AGENTS_FILE
trap 'rm -f "$AGENTS_FILE"' EXIT

if ! "$CLAUDE" agents --json > "$AGENTS_FILE" 2>/dev/null; then
  echo "Couldn't list agents. Press a key."
  read -rsn1
  exit 0
fi

# Live waiting and working sessions, then ones finished in the last 24h.
rows=$("$JQ" -r --argjson now "$(date +%s)" '
  [.[] | select(.kind == "background")
       | select((.pid != null and (.state == "blocked" or .state == "working"))
                or (.state == "done" and (.startedAt / 1000) > ($now - 86400)))
       | . + {rank: ({"blocked": 0, "working": 1, "done": 2}[.state])}]
  | sort_by(.rank, -.startedAt)[]
  | "\(.id)\t\({"blocked": "⏳", "working": "🤖", "done": "✅"}[.state]) \(.name // .id)\t\(.state)"' "$AGENTS_FILE")

if [ -z "$rows" ]; then
  echo "✨ No background agents running. Press a key."
  read -rsn1
  exit 0
fi

pick=$(printf '%s\n' "$rows" |
  fzf --delimiter='\t' --with-nth=2,3 --tabstop=4 --reverse --no-sort \
    --header='enter attach in a new window · esc close' \
    --preview="$SELF --preview {1}" --preview-window='right,60%,wrap')
[ -n "$pick" ] || exit 0

id=$(printf '%s' "$pick" | cut -f1)
name=$(printf '%s' "$pick" | cut -f2 | cut -c1-30)
tmux new-window -n "$name" "$CLAUDE attach $id"
