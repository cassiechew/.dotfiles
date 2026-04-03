#!/bin/bash
# Generates /tmp/tmux-theme-mode.conf based on macOS appearance.
# Called by tmux 02-style.conf via run-shell.

CONF=/tmp/tmux-theme-mode.conf
MODE=$(defaults read -g AppleInterfaceStyle 2>/dev/null)

# Unset all @thm_* vars so catppuccin's -ogq can re-apply for the new flavor
cat > "$CONF" << 'UNSET'
set -gu @thm_bg
set -gu @thm_fg
set -gu @thm_rosewater
set -gu @thm_flamingo
set -gu @thm_pink
set -gu @thm_mauve
set -gu @thm_red
set -gu @thm_maroon
set -gu @thm_peach
set -gu @thm_yellow
set -gu @thm_green
set -gu @thm_teal
set -gu @thm_sky
set -gu @thm_sapphire
set -gu @thm_blue
set -gu @thm_lavender
set -gu @thm_subtext_1
set -gu @thm_subtext_0
set -gu @thm_overlay_2
set -gu @thm_overlay_1
set -gu @thm_overlay_0
set -gu @thm_surface_2
set -gu @thm_surface_1
set -gu @thm_surface_0
set -gu @thm_mantle
set -gu @thm_crust
UNSET

# Unset catppuccin options that embed @thm_* refs (expanded at set-time)
cat >> "$CONF" << 'UNSET_CTP'
set -gu @catppuccin_flavor
set -gu @catppuccin_menu_selected_style
set -gu @catppuccin_pane_border_style
set -gu @catppuccin_pane_active_border_style
set -gu @catppuccin_pane_color
set -gu @catppuccin_pane_background_color
set -gu @catppuccin_window_text_color
set -gu @catppuccin_window_number_color
set -gu @catppuccin_window_current_text_color
set -gu @catppuccin_window_current_number_color
set -gu @catppuccin_status_module_text_bg
set -gu @_ctp_status_bg
UNSET_CTP

# Unset status module options (color + icon_fg/text_fg bake in @thm_* at set-time)
for mod in application cpu session uptime battery; do
  cat >> "$CONF" << EOF
set -gu @catppuccin_${mod}_color
set -gu @catppuccin_status_${mod}_icon_fg
set -gu @catppuccin_status_${mod}_text_fg
set -gu @catppuccin_status_${mod}_icon_bg
set -gu @catppuccin_status_${mod}_text_bg
EOF
done

# Unset cpu plugin color options (also bake in @thm_*)
cat >> "$CONF" << 'UNSET_CPU'
set -gu @cpu_low_fg_color
set -gu @cpu_medium_fg_color
set -gu @cpu_high_fg_color
set -gu @cpu_low_bg_color
set -gu @cpu_medium_bg_color
set -gu @cpu_high_bg_color
UNSET_CPU

# Set flavor + our overrides
if [ "$MODE" = "Dark" ]; then
  cat >> "$CONF" << 'DARK'
set -g @catppuccin_flavor "frappe"
set -gq @thm_pink "#FF0066"
set -gq @thm_mauve "#F77AB0"
set -gq @thm_bg "#161616"
set -gq @thm_mantle "#111111"
set -gq @thm_crust "#0D0D0D"
set -gq @thm_fg "#f2f4f8"
set -g window-style "bg=#161616"
set -g window-active-style "bg=#161616"
DARK
else
  cat >> "$CONF" << 'LIGHT'
set -g @catppuccin_flavor "latte"
set -gq @thm_pink "#FF0066"
set -gq @thm_mauve "#F77AB0"
set -gq @thm_bg "#FFF0F5"
set -gq @thm_mantle "#FFE4ED"
set -gq @thm_crust "#FFD6E3"
set -gq @thm_surface_0 "#FFD6E3"
set -gq @thm_surface_1 "#FFCADB"
set -gq @thm_surface_2 "#FFBFD3"
set -g window-style "bg=#FFF0F5"
set -g window-active-style "bg=#FFF0F5"
LIGHT
fi
