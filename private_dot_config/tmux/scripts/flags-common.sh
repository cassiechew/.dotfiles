# shellcheck shell=bash disable=SC2034  # the scripts that source this use its settings
# Shared by flags-scan.sh and flags-pick.sh (prefix+F). Source it; don't run
# it. Settings are in ~/.config/tmux/work.env; see flags-scan.sh.

[ -f "$HOME/.config/tmux/work.env" ] && . "$HOME/.config/tmux/work.env"
JQ=$(command -v jq || echo /opt/homebrew/bin/jq)
FLAGS_DIR="$HOME/.local/share/flags"
FLAGS_STORE="$FLAGS_DIR/flags.json"
FLAGS_NOTES="$FLAGS_DIR/notes.json"
FLAGS_ACTIONS="$FLAGS_DIR/actions.json"
# A symlink naming the running scan's pid; see scan_running.
FLAGS_LOCK="$FLAGS_DIR/.scan.lock"
# The environments shown, in promotion order, by their Split names.
FLAGS_ENVS=(QA UAT Production)

flags_configured() {
  [ -n "$FLAGS_REPOS" ] && [ -n "$FLAGS_AUTHOR" ]
}

# scan_running succeeds while a scan holds the lock. A lock left by a scan that
# was killed (its pid is gone) or older than 30 minutes doesn't count, so a
# crash can't stop refreshes for good.
scan_running() {
  local pid
  pid=$(readlink "$FLAGS_LOCK" 2>/dev/null) || return 1
  [ -z "$(find "$FLAGS_LOCK" -maxdepth 0 -mmin +30 2>/dev/null)" ] && kill -0 "$pid" 2>/dev/null
}

# split_key prints SPLIT_API_KEY from the environment, or from the export in
# ~/.zshrc.local when tmux didn't inherit it.
split_key() {
  if [ -n "$SPLIT_API_KEY" ]; then
    printf '%s' "$SPLIT_API_KEY"
    return
  fi
  sed -n 's/^export SPLIT_API_KEY=//p' "$HOME/.zshrc.local" 2>/dev/null | head -n 1 | tr -d "\"'"
}
