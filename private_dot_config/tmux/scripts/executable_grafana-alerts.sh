#!/bin/bash
# tmux status badge for the team's firing Grafana alerts (see
# grafana-common.sh). tmux calls this every second, so the answer is cached
# for 60s. prefix+A lists them and can hand one to a Claudette.
#
#   🚨 Oho Webhook is up    one alert firing, by name
#   🚨 3 firing             several, red when any is critical

. "$(dirname "$0")/grafana-common.sh"

CACHE="${TMPDIR:-/tmp}/tmux-grafana-alerts"
if [ -f "$CACHE" ] && [ $(( $(date +%s) - $(stat -f %m "$CACHE") )) -lt 60 ]; then
  cat "$CACHE"
  exit 0
fi

# save writes the badge to the cache and prints it.
save() {
  printf '%s' "$1" > "$CACHE.tmp" && mv -f "$CACHE.tmp" "$CACHE"
  printf '%s' "$1"
}

if ! grafana_configured || [ -z "$(grafana_token)" ]; then
  save ""
  exit 0
fi
if ! alerts=$(grafana_alerts); then
  # Keep the last answer through a blip, and wait out the cache before retrying.
  save "$(cat "$CACHE" 2>/dev/null)"
  exit 0
fi

count=$(printf '%s' "$alerts" | "$JQ" 'length' 2>/dev/null)
if [ -z "$count" ] || [ "$count" -eq 0 ]; then
  save ""
  exit 0
fi

style="#[fg=#E5C07B,bold]"
if printf '%s' "$alerts" | "$JQ" -e 'any(.[]; (.labels.severity // "" | ascii_downcase) == "critical")' >/dev/null; then
  style="#[fg=#FF0066,bold,reverse]"
fi

if [ "$count" -eq 1 ]; then
  name=$(printf '%s' "$alerts" | "$JQ" -r '.[0].labels.alertname // "alert"')
  name=${name//#/##} # escape tmux formats
  if (( ${#name} > 28 )); then name="${name:0:27}…"; fi
  save "${style}🚨 ${name}#[default]"
else
  save "${style}🚨 ${count} firing#[default]"
fi
