# shellcheck shell=bash
# Shared by grafana-alerts.sh (the status badge) and grafana-alerts-pick.sh
# (the prefix+A popup). Source it; don't run it.
#
# Which Grafana and team come from ~/.config/tmux/work.env, kept out of the
# dotfiles repo:
#   GRAFANA_URL=https://example.grafana.net
#   GRAFANA_TEAM=platform        # matched against the team_name alert label

[ -f "$HOME/.config/tmux/work.env" ] && . "$HOME/.config/tmux/work.env"
JQ=$(command -v jq || echo /opt/homebrew/bin/jq)

# grafana_configured fails until work.env names a Grafana and a team.
grafana_configured() {
  [ -n "$GRAFANA_URL" ] && [ -n "$GRAFANA_TEAM" ]
}

# grafana_token prints GRAFANA_SERVICE_ACCOUNT_TOKEN if set, else the Grafana
# MCP's token from ~/.claude.json, so rotating the MCP's token updates this.
grafana_token() {
  if [ -n "$GRAFANA_SERVICE_ACCOUNT_TOKEN" ]; then
    printf '%s' "$GRAFANA_SERVICE_ACCOUNT_TOKEN"
    return
  fi
  "$JQ" -r 'first(.. | objects | select(has("GRAFANA_SERVICE_ACCOUNT_TOKEN")) | .GRAFANA_SERVICE_ACCOUNT_TOKEN) // empty' ~/.claude.json 2>/dev/null
}

# grafana_alerts prints the team's firing alerts as JSON, oldest first,
# leaving out silenced and inhibited ones. It fails when Grafana can't be
# reached or there's no token.
grafana_alerts() {
  local token filter body
  grafana_configured || return 1
  token=$(grafana_token)
  [ -n "$token" ] || return 1
  filter=$(printf 'team_name="%s"' "$GRAFANA_TEAM" | "$JQ" -sRr @uri)
  # Checked before sorting: piped straight into jq, a failed curl looked like
  # an empty, all-clear answer (jq exits 0 on empty input).
  body=$(curl -sf --max-time 5 -H "Authorization: Bearer $token" \
    "$GRAFANA_URL/api/alertmanager/grafana/api/v2/alerts?active=true&silenced=false&inhibited=false&filter=$filter") || return 1
  printf '%s' "$body" | "$JQ" -e 'type == "array"' >/dev/null 2>&1 || return 1
  printf '%s' "$body" | "$JQ" 'sort_by(.startsAt)'
}
