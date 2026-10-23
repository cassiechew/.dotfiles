# shellcheck shell=bash
# Shared by the Claude agent scripts (claude-agents-pick.sh, agent-watch.sh,
# projects-pick.sh). Source it; don't run it.

JQ=$(command -v jq || echo /opt/homebrew/bin/jq)
# shellcheck disable=SC2034  # used by the scripts that source this file
CLAUDE=$(command -v claude || echo "$HOME/.local/bin/claude")

# transcript_path prints where Claude Code keeps a session's log: under
# ~/.claude/projects, in a folder named for its working directory with / and
# . as -.
transcript_path() {
  local cwd=$1 sid=$2
  printf '%s/.claude/projects/%s/%s.jsonl' "$HOME" "$(printf '%s' "$cwd" | tr '/.' '--')" "$sid"
}

# last_message prints a session's latest assistant message.
last_message() {
  local file
  file=$(transcript_path "$1" "$2")
  [ -f "$file" ] || return
  "$JQ" -rs '[.[] | select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text] | last // empty' "$file" 2>/dev/null
}

# last_message_line prints the first line of a session's latest message,
# without markdown, for notifications and lists.
last_message_line() {
  last_message "$1" "$2" | grep -v '^[[:space:]]*$' | head -n 1 |
    sed -E 's/[*`_#>]//g; s/^[-[:space:]]+//' | cut -c1-180
}
