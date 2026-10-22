#!/bin/bash
# prefix+?: every tmux key binding, searchable. Your own bindings come first
# (★, the ones given -N notes in conf.d), then plugins' (🔌, which ship
# without notes, so they're named here), then tmux's built-ins. The preview
# shows the command a key runs.
#
# fzf calls back into this script with --command TABLE KEY.

CONF_DIR="$HOME/.config/tmux/conf.d"

if [ "$1" = "--command" ]; then
  tmux list-keys -T "$2" -- "$3" 2>/dev/null | sed -E 's/^bind-key +(-r +)?(-N +"[^"]*" +)?-T +[^ ]+ +[^ ]+ +//' | fold -s -w 60
  exit 0
fi

PREFIX=$(tmux show -gv prefix)

# Notes given in conf.d mark your own bindings.
custom_notes=$(grep -hoE -- '-N "[^"]+"' "$CONF_DIR"/*.conf 2>/dev/null | sed -E 's/^-N "(.*)"$/\1/')

# plugin_note names a plugin binding from its command, or prints nothing.
plugin_note() {
  case "$1" in
    *extrakto*) echo "Extract text from the pane (extrakto)" ;;
    *install_plugins*) echo "Install plugins (tpm)" ;;
    *update_plugins*) echo "Update plugins (tpm)" ;;
    *clean_plugins*) echo "Remove unused plugins (tpm)" ;;
    *resurrect*restore*) echo "Restore saved session (resurrect)" ;;
    *resurrect*save*) echo "Save session (resurrect)" ;;
    *tmux-menus*) echo "Menus (tmux-menus)" ;;
    *nunchux*) echo "Launcher (nunchux)" ;;
  esac
}

rows() {
  local table label noted key desc rank
  for table in prefix root; do
    label=""
    [ "$table" = prefix ] && label="$PREFIX "
    noted=$(tmux list-keys -N -T "$table" | awk '{print $1}')
    tmux list-keys -N -a -T "$table" | while read -r key desc; do
      case "$key" in *Mouse*|*Wheel*|*Drag*|*Double*|*Triple*) continue ;; esac
      if grep -qxF -- "$key" <<< "$noted"; then
        if grep -qxF -- "$desc" <<< "$custom_notes"; then rank="1	★"; else rank="3	 "; fi
      else
        note=$(plugin_note "$desc")
        if [ -n "$note" ]; then desc=$note; rank="2	🔌"; else desc="${desc:0:60}"; rank="3	 "; fi
      fi
      printf '%s\t%s\t%-12s\t%s\t%s\n' "$rank" "$table" "$label$key" "$desc" "$key"
    done
  done | sort -t$'\t' -k1,1n -s | cut -f2-
}

rows |
  fzf --delimiter='\t' --with-nth=1,3,4 --tabstop=2 --reverse --no-sort \
    --header="type to search · ★ yours · 🔌 plugins · esc close" \
    --preview="$0 --command {2} {5}" --preview-window='right,40%,wrap,nohidden' \
    --bind='enter:ignore' >/dev/null
