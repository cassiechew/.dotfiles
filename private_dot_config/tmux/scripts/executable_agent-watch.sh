#!/bin/bash
# Notifies when a background Claude agent (`claude agents`) finishes or starts
# waiting on you. launchd runs it every 15s (com.cassiechew.agent-watch); each
# run compares the agents with the last run's snapshot. Clicking a
# notification opens that session in a new tmux window.
#
#   agent-watch.sh              check once and notify
#   agent-watch.sh --attach ID  open session ID in tmux (the click action)
#
# For testing: AGENTS_JSON reads agents from a file instead of the CLI,
# AGENT_WATCH_STATE moves the snapshot, and DRY_RUN=1 prints instead of
# notifying.

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin"
JQ=$(command -v jq)
CLAUDE=$(command -v claude || echo "$HOME/.local/bin/claude")
NOTIFIER=$(command -v terminal-notifier)
STATE=${AGENT_WATCH_STATE:-$HOME/.cache/agent-watch.json}
SELF="$0"

if [ "$1" = "--attach" ]; then
  [[ $2 =~ ^[A-Za-z0-9-]+$ ]] || exit 1
  name=$("$CLAUDE" agents --json 2>/dev/null | "$JQ" -r --arg id "$2" '.[] | select(.id == $id) | .name // .id' | cut -c1-30)
  tmux new-window -n "${name:-agent}" "$CLAUDE attach $2"
  exit 0
fi

if [ -n "$AGENTS_JSON" ]; then
  agents=$(cat "$AGENTS_JSON")
else
  agents=$("$CLAUDE" agents --json 2>/dev/null) || exit 0
fi

# Background sessions as {id: {state, name, cwd, sessionId}}; blocked counts
# only with a live process, since stopped sessions linger as blocked.
now=$(printf '%s' "$agents" | "$JQ" -c '
  [.[] | select(.kind == "background")
       | select(.state != "blocked" or .pid != null)
       | {key: .id, value: {state, name: (.name // .id), cwd, sessionId}}]
  | from_entries')

if [ ! -f "$STATE" ]; then
  mkdir -p "$(dirname "$STATE")"
  printf '%s' "$now" > "$STATE"
  exit 0
fi
before=$(cat "$STATE")
printf '%s' "$now" > "$STATE"

# lastMessage prints the first line of a session's latest message, unstyled.
lastMessage() {
  local cwd=$1 sid=$2 file
  file="$HOME/.claude/projects/$(printf '%s' "$cwd" | tr '/.' '--')/$sid.jsonl"
  [ -f "$file" ] || return
  "$JQ" -rs '[.[] | select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text] | last // empty' "$file" 2>/dev/null |
    grep -v '^[[:space:]]*$' | head -n 1 | sed -E 's/[*`_#>]//g; s/^[-[:space:]]+//' | cut -c1-180
}

notify() {
  local id=$1 title=$2 name=$3 body=$4 sound=$5
  if [ -n "$DRY_RUN" ]; then
    printf '%s | %s | %s\n' "$title" "$name" "$body"
    return
  fi
  [ -n "$NOTIFIER" ] || return
  "$NOTIFIER" -title "$title" -subtitle "$name" -message "${body:- }" -sound "$sound" \
    -group "agent-watch-$id" -activate com.mitchellh.ghostty \
    -execute "'$SELF' --attach $id" >/dev/null 2>&1
}

# Notify for each session whose state changed into done or blocked.
printf '%s' "$now" | "$JQ" -r --argjson before "$before" '
  to_entries[]
  | select(.value.state != ($before[.key].state // "new"))
  | select(.value.state == "done" or .value.state == "blocked")
  | select(.value.state != "done" or ($before[.key] != null))
  | [.key, .value.state, .value.name, .value.cwd, .value.sessionId] | @tsv' |
while IFS=$'\t' read -r id state name cwd sid; do
  body=$(lastMessage "$cwd" "$sid")
  if [ "$state" = done ]; then
    notify "$id" "✅ Agent finished" "$name" "$body" Glass
  else
    notify "$id" "⏳ Agent needs you" "$name" "$body" Ping
  fi
done
