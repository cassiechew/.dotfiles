# shellcheck shell=bash disable=SC2034  # the scripts that source this use its settings
# Shared by flags-scan.sh and flags-pick.sh (prefix+F). Source it; don't run
# it. Settings are in ~/.config/tmux/work.env; see flags-scan.sh.

[ -f "$HOME/.config/tmux/work.env" ] && . "$HOME/.config/tmux/work.env"
JQ=$(command -v jq || echo /opt/homebrew/bin/jq)
FLAGS_DIR="$HOME/.local/share/flags"
FLAGS_STORE="$FLAGS_DIR/flags.json"
FLAGS_NOTES="$FLAGS_DIR/notes.json"
FLAGS_ACTIONS="$FLAGS_DIR/actions.json"
# The environments shown, in promotion order, by their Split names.
FLAGS_ENVS=(QA UAT Production)

flags_configured() {
  [ -n "$FLAGS_REPOS" ] && [ -n "$FLAGS_AUTHOR" ]
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
