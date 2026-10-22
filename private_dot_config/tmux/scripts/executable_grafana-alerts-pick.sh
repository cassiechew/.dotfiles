#!/bin/bash
# prefix+A: pick one of the team's firing Grafana alerts in an fzf popup.
#
#   ↑/↓  move      o / enter  open in Grafana
#   i    investigate: a background Claudette (`claude agents`) digs in
#   esc  close
#
# fzf calls back into this script with --preview, --open and --investigate
# and an alert's index in the list it was given.

. "$(dirname "$0")/grafana-common.sh"
SELF="$0"

alert() { "$JQ" ".[$1]" "$ALERTS_FILE"; }

# age prints how long ago an ISO-8601 UTC time was, like "2h 5m".
age() {
  local then mins
  then=$(date -j -u -f "%Y-%m-%dT%H:%M:%S" "${1%%.*}" +%s 2>/dev/null) || return
  mins=$(( ($(date +%s) - then) / 60 ))
  if (( mins >= 1440 )); then printf '%dd %dh' $((mins / 1440)) $((mins % 1440 / 60))
  elif (( mins >= 60 )); then printf '%dh %dm' $((mins / 60)) $((mins % 60))
  else printf '%dm' "$mins"; fi
}

preview() {
  local a since
  a=$(alert "$1")
  since=$(printf '%s' "$a" | "$JQ" -r .startsAt)
  printf '%s' "$a" | "$JQ" -r --arg age "$(age "$since")" '
    "🚨 \(.labels.alertname)",
    "severity \(.labels.severity // "none") · firing \($age) · \(.labels.grafana_folder // "")",
    "",
    (.annotations.summary // empty),
    "",
    (.annotations.description // empty),
    "",
    "labels: " + ([.labels | to_entries[] | select(.key | startswith("__") or . == "alertname" or . == "team_name" or . == "grafana_folder" | not) | "\(.key)=\(.value)"] | join(", ")),
    "",
    .generatorURL'
}

open_alert() {
  local url
  url=$(alert "$1" | "$JQ" -r '.generatorURL // empty')
  [ -n "$url" ] && open "$url"
}

investigate() {
  local a name prompt claude out
  a=$(alert "$1")
  name=$(printf '%s' "$a" | "$JQ" -r '.labels.alertname // "alert"')
  prompt=$(printf '%s' "$a" | "$JQ" -r --arg team "$GRAFANA_TEAM" '
    "Investigate this firing Grafana alert for team \(.labels.team_name // $team) and tell me whether it is a real problem.",
    "",
    "Alert: \(.labels.alertname)",
    "Severity: \(.labels.severity // "none")",
    "Firing since: \(.startsAt)",
    "Rule: \(.generatorURL) (uid \(.labels.__alert_rule_uid__ // "unknown"), folder \(.labels.grafana_folder // "unknown"))",
    "Labels: \(.labels | tojson)",
    "Summary: \(.annotations.summary // "")",
    "Description and runbook:",
    (.annotations.description // "(none)"),
    "",
    "How to investigate:",
    "1. Read the rule with the Grafana MCP (GET /api/v1/provisioning/alert-rules/<uid>) to see exactly what it queries and its threshold.",
    "2. Run that query yourself, broken down by tenant and the other labels that matter, over the time it has been firing, and look at a few matching log lines or series.",
    "3. Find the code path that produces this signal. Read code from origin/main, never a possibly stale worktree, and consult the relevant domain specialist.",
    "4. Decide: real problem (who is affected, since when, likely cause), or a false positive in the rule (show why, and what the rule should check instead).",
    "",
    "This is a read-only investigation: do not edit alert rules, silence alerts, or change code without asking me first.",
    "Report back briefly: verdict, evidence, affected tenants, and the recommended next step."')
  claude=$(command -v claude || echo "$HOME/.local/bin/claude")
  # Opus: the verdict (real problem or a wrong rule) is a judgment call, and
  # it runs in the background, so speed doesn't matter.
  if out=$(cd "$HOME/projects" && "$claude" --bg --model opus -n "Alert: ${name:0:60}" "$prompt" 2>&1); then
    tmux display-message "🔍 Investigating '${name:0:40}' in the background. See: claude agents"
  else
    printf '%s\n%s\n' "$(date)" "$out" >> "$HOME/.cache/grafana-alerts-investigate.log"
    tmux display-message "Couldn't start the investigation (see ~/.cache/grafana-alerts-investigate.log)"
  fi
}

case "$1" in
  --preview) preview "$2"; exit ;;
  --open) open_alert "$2"; exit ;;
  --investigate) investigate "$2"; exit ;;
esac

if ! grafana_configured; then
  echo "Set GRAFANA_URL and GRAFANA_TEAM in ~/.config/tmux/work.env. Press a key."
  read -rsn1
  exit 0
fi

ALERTS_FILE=$(mktemp "${TMPDIR:-/tmp}/grafana-alerts.XXXXXX")
export ALERTS_FILE
trap 'rm -f "$ALERTS_FILE"' EXIT

if ! grafana_alerts > "$ALERTS_FILE"; then
  echo "Couldn't reach Grafana (or no token). Press a key."
  read -rsn1
  exit 0
fi
if [ "$("$JQ" length "$ALERTS_FILE")" -eq 0 ]; then
  echo "✨ Nothing firing for team $GRAFANA_TEAM. Press a key."
  read -rsn1
  exit 0
fi

"$JQ" -r 'to_entries[] | "\(.key)\t🚨 \(.value.labels.alertname)\t\(.value.labels.severity // "none")"' "$ALERTS_FILE" |
  fzf --delimiter='\t' --with-nth=2,3 --tabstop=4 --reverse --no-sort \
    --header='o/enter open in Grafana · i investigate in the background · esc close' \
    --preview="$SELF --preview {1}" --preview-window='right,60%,wrap,nohidden' \
    --bind="enter:execute-silent($SELF --open {1})" \
    --bind="o:execute-silent($SELF --open {1})" \
    --bind="i:execute-silent($SELF --investigate {1})+abort"
