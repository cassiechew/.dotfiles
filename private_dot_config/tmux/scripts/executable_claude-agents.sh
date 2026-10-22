#!/bin/bash
# tmux status badge for background Claude sessions (`claude agents`).
# tmux calls this every second, so the answer is cached for 10s.
#
#   🤖 2            two agents working
#   🤖 2 ⏳ 1 waiting  and one waiting on you (pink)
#
# Only sessions with a live process count: `claude agents` also keeps old
# sessions that stopped while blocked, which will never move.

CACHE="${TMPDIR:-/tmp}/tmux-claude-agents"
if [ -f "$CACHE" ] && [ $(( $(date +%s) - $(stat -f %m "$CACHE") )) -lt 10 ]; then
  cat "$CACHE"
  exit 0
fi

save() {
  printf '%s' "$1" > "$CACHE.tmp" && mv -f "$CACHE.tmp" "$CACHE"
  printf '%s' "$1"
}

JQ=$(command -v jq || echo /opt/homebrew/bin/jq)
CLAUDE=$(command -v claude || echo "$HOME/.local/bin/claude")

if ! agents=$("$CLAUDE" agents --json 2>/dev/null); then
  save "$(cat "$CACHE" 2>/dev/null)"
  exit 0
fi

read -r working waiting < <(printf '%s' "$agents" | "$JQ" -r '
  [.[] | select(.kind == "background" and .pid != null)] |
  "\(map(select(.state == "working")) | length) \(map(select(.state == "blocked")) | length)"')

out=""
if (( working > 0 )); then
  out="#[fg=#A9A1E1,bold]🤖 ${working}#[default]"
fi
if (( waiting > 0 )); then
  out="${out:+$out }#[fg=#FF0066,bold]⏳ ${waiting} waiting#[default]"
fi
save "$out"
