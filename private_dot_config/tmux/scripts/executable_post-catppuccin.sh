#!/bin/bash
# Runs AFTER catppuccin loads (queued via run-shell in 04-post-style.conf).
# Writes overrides to a temp file and tells tmux to source it,
# avoiding run-shell's format expansion hell.

CONF=/tmp/tmux-post-catppuccin.conf
MODE=$(defaults read -g AppleInterfaceStyle 2>/dev/null)

if [ "$MODE" = "Dark" ]; then
  cat > "$CONF" << 'DARK'
set -wg pane-border-style "fg=#F77AB0,bg=#161616"
set -wg pane-active-border-style "fg=#FF0066,bg=#161616"
set -g window-style "bg=#161616"
set -g window-active-style "bg=#161616"
DARK
else
  cat > "$CONF" << 'LIGHT'
set -wg pane-border-style "fg=#F77AB0,bg=#FFF0F5"
set -wg pane-active-border-style "fg=#FF0066,bg=#FFF0F5"
set -g window-style "bg=#FFF0F5"
set -g window-active-style "bg=#FFF0F5"
LIGHT
fi

# Rebuild status-right with fresh catppuccin colors
cat >> "$CONF" << 'STATUS'
set -g status-right "#{E:@catppuccin_status_application}"
set -agF status-right "#{E:@catppuccin_status_cpu}"
set -ag status-right "#{E:@catppuccin_status_session}"
set -ag status-right "#{E:@catppuccin_status_uptime}"
set -agF status-right "#{E:@catppuccin_status_battery}"
STATUS

tmux source-file "$CONF"

# Re-run cpu/battery plugins to interpolate #{cpu_percentage} etc.
# into #(script_path) shell commands. These plugins ran via TPM BEFORE
# our status-right rebuild, so the tokens were never replaced.
tmux run-shell ~/.config/tmux/plugins/tmux-cpu/cpu.tmux
tmux run-shell ~/.config/tmux/plugins/tmux-battery/battery.tmux
