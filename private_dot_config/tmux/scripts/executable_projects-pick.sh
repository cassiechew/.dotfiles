#!/bin/bash
# prefix+P: projects, and the background Claude sessions working on them.
#
# Projects live in $PROJECTS_FILE (default ~/projects/.projects.json): a name,
# status, next step, links, and keywords. Sessions join a project when their
# name contains one of its keywords or its id, or when filed with f; the rest
# are Unfiled.
#
#   projects:  enter sessions · n next step · s status · a new agent
#   sessions:  enter attach · f file under a project
#   inbox:     enter attach and mark seen · o mark seen
#
# tab switches between Projects and Inbox. Inbox is every session that needs
# Cassie: waiting on her first, then ones with unseen assumptions (logged with
# `inbox assume`, see ~/projects/harness/runtime/inbox), newest first.
#
# fzf calls back into this script with the --flags below.

. "$(dirname "$0")/claude-common.sh"
SELF="$0"
INBOX=$(command -v inbox || echo "$HOME/.local/bin/inbox")
PROJECTS_FILE=${PROJECTS_FILE:-$HOME/projects/.projects.json}
STATUSES=(active exploring proposed "done")

# Telescope-style boxes, matching nvim's "center" layout: preview on top, then
# the prompt, then the results. nohidden overrides FZF_DEFAULT_OPTS, which
# hides previews.
TELESCOPE=(--reverse --input-border=rounded --list-border=rounded --list-label=' Results '
  --preview-window='up,55%,wrap,nohidden,border-rounded')

# Sessions shown: live ones, ones finished in the last 14 days, and stale ones
# (blocked with no process) so they can be filed or noticed.
JQ_DEFS='
  def icon: {"active": "🔥", "exploring": "🌱", "proposed": "💤", "done": "✅"}[.] // "•";
  def project_of($p):
    . as $s
    | $p.sessions[$s.id] // (
        first($p.projects[]
          | select((.keywords + [.id]) | map(ascii_downcase)
              | any(. as $k | ($s.name // "" | ascii_downcase) | contains($k))))
        | .id) // "unfiled";
  def kind:
    if .state == "working" then "working"
    elif .state == "blocked" and .pid != null then "waiting"
    elif .state == "blocked" then "stale"
    else "done" end;
  def sessions($p; $now):
    [.[] | select(.kind == "background")
         | . + {project: project_of($p), k: kind}
         | select(.k != "done" or (.startedAt / 1000) > ($now - 14 * 86400))];
  def session_icon: {"working": "🤖", "waiting": "⏳", "done": "✅", "stale": "🕸"}[.k];
'

refresh_agents() {
  "$CLAUDE" agents --json > "$AGENTS_FILE" 2>/dev/null || echo '[]' > "$AGENTS_FILE"
  "$INBOX" pending --json > "$PENDING_FILE" 2>/dev/null || echo '[]' > "$PENDING_FILE"
}

# save_projects applies a jq filter to the projects file, atomically.
save_projects() {
  local tmp
  tmp=$(mktemp "$PROJECTS_FILE.XXXXXX") || return 1
  if "$JQ" "$@" "$PROJECTS_FILE" > "$tmp"; then mv -f "$tmp" "$PROJECTS_FILE"; else rm -f "$tmp"; fi
}

project_rows() {
  "$JQ" -r --slurpfile p "$PROJECTS_FILE" --slurpfile q "$PENDING_FILE" --argjson now "$(date +%s)" "$JQ_DEFS"'
    sessions($p[0]; $now) as $all
    | ($q[0] | map(.session)) as $unseen
    | def counts($id): [$all[] | select(.project == $id)]
        | [(map(select(.sessionId as $s | any($unseen[]; . == $s))) | length | if . > 0 then "❓\(.)" else empty end),
           (map(select(.k == "working")) | length | if . > 0 then "🤖\(.)" else empty end),
           (map(select(.k == "waiting")) | length | if . > 0 then "⏳\(.)" else empty end),
           (map(select(.k == "done")) | length | if . > 0 then "✅\(.)" else empty end),
           (map(select(.k == "stale")) | length | if . > 0 then "🕸\(.)" else empty end)] | join(" ");
      ($p[0].projects | sort_by({"active": 0, "exploring": 1, "proposed": 2, "done": 3}[.status] // 9)[]
        | "\(.id)\t\(.status | icon) \(.name)\t\(counts(.id))"),
      "unfiled\t   Unfiled\t\(counts("unfiled"))"' "$AGENTS_FILE"
}

project_preview() {
  local id=$1
  case "$id" in s:*) inbox_preview "${id#s:}"; return ;; esac
  "$JQ" -r --slurpfile p "$PROJECTS_FILE" --arg id "$id" --argjson now "$(date +%s)" "$JQ_DEFS"'
    ($p[0].projects[] | select(.id == $id)) as $pr
    | (if $pr then
        "\($pr.status | icon) \($pr.name) · \($pr.status)",
        "",
        "Next: \(if ($pr.next // "") == "" then "(none yet, press n)" else $pr.next end)",
        (if ($pr.links | length) > 0 then "", "Links:", ($pr.links[] | "  • \(.)") else empty end)
      else "Unfiled sessions: press enter, then f to file one under a project." end),
      "",
      "Sessions:",
      (sessions($p[0]; $now) | map(select(.project == $id)) | sort_by(-.startedAt)
        | if length == 0 then "  (none)" else .[] | "  \(session_icon) \(.name // .id)" end)' "$AGENTS_FILE"

  # The latest finished session says where the project got to.
  local latest
  latest=$("$JQ" -r --slurpfile p "$PROJECTS_FILE" --arg id "$id" --argjson now "$(date +%s)" "$JQ_DEFS"'
    sessions($p[0]; $now) | map(select(.project == $id and .k == "done")) | sort_by(-.startedAt)
    | first // empty | "\(.cwd)\t\(.sessionId)\t\(.name // .id)"' "$AGENTS_FILE")
  if [ -n "$latest" ]; then
    IFS=$'\t' read -r cwd sid name <<< "$latest"
    printf '\n── last update: %s ──\n' "$name"
    last_message "$cwd" "$sid" | head -n 25
  fi
}

session_rows() {
  "$JQ" -r --slurpfile p "$PROJECTS_FILE" --arg id "$1" --argjson now "$(date +%s)" "$JQ_DEFS"'
    sessions($p[0]; $now) | map(select(.project == $id))
    | sort_by({"waiting": 0, "working": 1, "done": 2, "stale": 3}[.k], -.startedAt)[]
    | "\(.id)\t\(session_icon) \(.name // .id)\t\(.k) · \((.startedAt / 1000) | strflocaltime("%d %b"))"' "$AGENTS_FILE"
}

session_preview() {
  local s
  s=$("$JQ" -c --arg id "$1" '.[] | select(.id == $id)' "$AGENTS_FILE")
  printf '%s' "$s" | "$JQ" -r '"\(.name // .id)", "\(.state) · \(.cwd)", "", "── latest message ──"'
  last_message "$(printf '%s' "$s" | "$JQ" -r .cwd)" "$(printf '%s' "$s" | "$JQ" -r .sessionId)"
}

# inbox_rows lists the sessions that need Cassie: waiting on her first, then
# ones with unseen assumptions, most recent first. A session that logged
# assumptions but has left `claude agents` still shows (👻) so it can be
# marked seen. Ids are prefixed s: so the shared bindings can tell rows apart.
inbox_rows() {
  "$JQ" -r --slurpfile q "$PENDING_FILE" "$JQ_DEFS"'
    def inbox_icon: {"waiting": "⏳", "working": "🤖", "done": "✅", "stale": "🕸",
                     "interactive": "💬", "gone": "👻"}[.k] // "•";
    ($q[0] | to_entries | map({key: .value.session, value: (.value + {rank: .key})}) | from_entries) as $pend
    | [.[] | select(.kind == "background" or $pend[.sessionId])
           | . + {k: (if .kind == "background" then kind else "interactive" end), p: $pend[.sessionId]}
           | select(.k == "waiting" or .p)] as $live
    | ($live | map(.sessionId)) as $listed
    | [$pend[] | select(.session as $s | any($listed[]; . == $s) | not)
        | {id: .session[0:8], name: (.ticket // .cwd), k: "gone", p: ., startedAt: 0}] as $gone
    | ($live + $gone)
    | sort_by((if .k == "waiting" then 0 else 1 end), (.p.rank // 1e9), -.startedAt)[]
    | "s:\(.id)\t\(inbox_icon) \(.name // .id)\t\(.k)\(if .p then " · ❓\(.p.assumptions | length)" else "" end)"' "$AGENTS_FILE"
}

# inbox_preview shows what Cassie needs to steer a session: where it is, its
# ticket and project, the ticket's latest checkpoint, the unseen assumptions,
# and its latest message.
inbox_preview() {
  local s p ticket cp
  s=$("$JQ" -c --arg id "$1" 'first(.[] | select(.id == $id)) // empty' "$AGENTS_FILE")
  p=$("$JQ" -c --arg id "$1" 'first(.[] | select(.session | startswith($id))) // empty' "$PENDING_FILE")
  ticket=$("$JQ" -rn --argjson s "${s:-null}" --argjson p "${p:-null}" '
    $p.ticket // ($s.name // "" | [match("[A-Za-z]+-[0-9]+").string][0] // empty | ascii_upcase)')

  "$JQ" -rn --argjson s "${s:-null}" --argjson p "${p:-null}" --arg t "$ticket" '
    "\($s.name // $p.ticket // "Session \($p.session[0:8])")",
    "\(if $s then ($s.state // $s.kind) else "no longer running" end) · \($s.cwd // $p.cwd)",
    (if $t != "" then "Ticket: \($t)" else empty end)'
  [ -n "$s" ] && "$JQ" -rn --slurpfile pr "$PROJECTS_FILE" --argjson s "$s" "$JQ_DEFS"'
    ($s | project_of($pr[0])) as $id
    | $pr[0].projects[] | select(.id == $id)
    | "Project: \(.name)", "Next: \(if (.next // "") == "" then "(none yet)" else .next end)"'

  cp="${CHECKPOINT_DIR:-$HOME/projects/.checkpoints}/$ticket.jsonl"
  if [ -n "$ticket" ] && [ -f "$cp" ]; then
    printf '\n── latest checkpoint ──\n'
    tail -n 1 "$cp" | "$JQ" -r '
      "\(.stage // "?") · \(.timestamp // "")", .title,
      (if (.next_steps // [] | length) > 0 then "Next steps:", (.next_steps[:4][] | "  • \(.)") else empty end)'
  fi

  if [ -n "$p" ]; then
    printf '%s' "$p" | "$JQ" -r '
      "", "── ❓ \(.assumptions | length) unseen assumption\(if (.assumptions | length) == 1 then "" else "s" end) ──",
      (.assumptions[] | "  \(.at | fromdate | strflocaltime("%d %b %H:%M"))  \(.text)")'
  fi

  if [ -n "$s" ]; then
    printf '\n── latest message ──\n'
    last_message "$(printf '%s' "$s" | "$JQ" -r .cwd)" "$(printf '%s' "$s" | "$JQ" -r .sessionId)" | head -n 20
  fi
}

# attach_session opens a background session in a new window and marks its
# assumptions seen, since attaching is how Cassie answers them.
attach_session() {
  local s
  s=$("$JQ" -c --arg id "$1" 'first(.[] | select(.id == $id)) // empty' "$AGENTS_FILE")
  if [ "$(printf '%s' "$s" | "$JQ" -r '.kind // empty')" != background ]; then
    tmux display-message "Not a background session, so it can't be attached (o marks it seen)"
    return
  fi
  "$INBOX" ack "$1" >/dev/null 2>&1
  tmux new-window -n "$(printf '%s' "$s" | "$JQ" -r '.name // .id' | cut -c1-30)" "$CLAUDE attach $1"
}

projects_header() {
  echo "Projects │ tab Inbox ❓$(inbox_rows | wc -l | tr -d ' ') · enter · n next · s status · a agent"
}

inbox_header() {
  echo "Inbox │ tab Projects · enter attach · o seen · ctrl-r refresh"
}

# The functions below print fzf actions for transform bindings. The prompt
# says which tab is showing.
enter_action() {
  case "$1" in
    s:*) echo "execute($SELF --attach ${1#s:})+execute-silent($SELF --refresh)+reload($SELF --inbox-rows)" ;;
    *) echo "execute($SELF --sessions $1)+reload($SELF --rows)" ;;
  esac
}

ack_action() {
  case "$1" in
    s:*) "$INBOX" ack "${1#s:}" >/dev/null 2>&1; refresh_agents; echo "reload($SELF --inbox-rows)" ;;
  esac
}

tab_action() {
  refresh_agents
  case "$FZF_PROMPT" in
    inbox*) echo "change-prompt(projects › )+change-input-label( Projects )+change-header~$(projects_header)~+reload($SELF --rows)+first" ;;
    *) echo "change-prompt(inbox › )+change-input-label( Inbox )+change-header~$(inbox_header)~+reload($SELF --inbox-rows)+first" ;;
  esac
}

reload_action() {
  refresh_agents
  case "$FZF_PROMPT" in
    inbox*) echo "change-header~$(inbox_header)~+reload($SELF --inbox-rows)" ;;
    *) echo "change-header~$(projects_header)~+reload($SELF --rows)" ;;
  esac
}

sessions_view() {
  local id=$1 pick
  pick=$(session_rows "$id" |
    fzf --delimiter='\t' --with-nth=2,3 --tabstop=4 "${TELESCOPE[@]}" --no-sort \
      --input-label=" Sessions · $id " --header='enter attach · f file under a project · esc back' \
      --preview="$SELF --session-preview {1}" --bind="focus,result:transform-preview-label($SELF --label {2})" \
      --bind="f:execute($SELF --file {1})+reload($SELF --session-rows $id)")
  [ -n "$pick" ] || return
  local sid name
  sid=$(printf '%s' "$pick" | cut -f1)
  name=$(printf '%s' "$pick" | cut -f2 | cut -c1-30)
  tmux new-window -n "$name" "$CLAUDE attach $sid"
}

# ask prints a line typed into a one-line fzf prompt, prefilled with $2. It
# fails when cancelled with esc.
ask() {
  local out
  out=$(printf '' | fzf --print-query --query "$2" --prompt "$1 › " --no-info --reverse --height=3 \
    --header='enter save · esc cancel')
  [ $? -eq 130 ] && return 1
  printf '%s' "$out" | head -n 1
}

edit_next() {
  local current next
  current=$("$JQ" -r --arg id "$1" '.projects[] | select(.id == $id) | .next // ""' "$PROJECTS_FILE")
  next=$(ask "Next step" "$current") || return
  save_projects --arg id "$1" --arg next "$next" '(.projects[] | select(.id == $id) | .next) = $next'
}

cycle_status() {
  local current i
  current=$("$JQ" -r --arg id "$1" '.projects[] | select(.id == $id) | .status' "$PROJECTS_FILE")
  for i in "${!STATUSES[@]}"; do
    if [ "${STATUSES[$i]}" = "$current" ]; then
      save_projects --arg id "$1" --arg s "${STATUSES[$(( (i + 1) % ${#STATUSES[@]} ))]}" \
        '(.projects[] | select(.id == $id) | .status) = $s'
      return
    fi
  done
}

file_session() {
  local target
  target=$("$JQ" -r '.projects[] | "\(.id)\t\(.name)"' "$PROJECTS_FILE" |
    fzf --delimiter='\t' --with-nth=2 --reverse --prompt='File under › ' --header='esc cancel' | cut -f1)
  [ -n "$target" ] || return
  save_projects --arg sid "$1" --arg pid "$target" '.sessions[$sid] = $pid'
}

new_agent() {
  local id=$1 task brief
  [ "$id" = unfiled ] && return
  task=$(ask "New agent for this project" "") || return
  [ -n "$task" ] || return
  brief=$("$JQ" -r --arg id "$id" --arg task "$task" '
    .projects[] | select(.id == $id) |
    "You are working on the project \"\(.name)\" (status: \(.status)).",
    "Next step on record: \(if (.next // "") == "" then "none written yet" else .next end)",
    (if (.links | length) > 0 then "Links: \(.links | join("; "))" else empty end),
    "",
    "Task: \($task)",
    "",
    "Start by reading the relevant memory files and .architecture docs for this project. Check with me before anything outward-facing: posting in Slack, editing tickets, or opening PRs."' "$PROJECTS_FILE")
  if (cd "$HOME/projects" && "$CLAUDE" --bg --model opus -n "[$id] ${task:0:50}" "$brief" >/dev/null 2>&1); then
    tmux display-message "🤖 [$id] ${task:0:40} started (see prefix+P)"
  else
    tmux display-message "Couldn't start the agent"
  fi
}

# Project actions do nothing on Inbox rows.
case "$1:${2:-}" in --next:s:*|--status:s:*|--new:s:*) exit ;; esac

case "$1" in
  --rows) project_rows; exit ;;
  --inbox-rows) inbox_rows; exit ;;
  --current-rows) case "${FZF_PROMPT:-}" in inbox*) inbox_rows ;; *) project_rows ;; esac; exit ;;
  --attach) attach_session "$2"; exit ;;
  --enter) enter_action "$2"; exit ;;
  --ack) ack_action "$2"; exit ;;
  --tab) tab_action; exit ;;
  --reload) reload_action; exit ;;
  --refresh) refresh_agents; exit ;;
  --label) printf ' %s ' "$2"; exit ;;
  --preview) project_preview "$2"; exit ;;
  --sessions) sessions_view "$2"; exit ;;
  --session-rows) session_rows "$2"; exit ;;
  --session-preview) session_preview "$2"; exit ;;
  --next) edit_next "$2"; exit ;;
  --status) cycle_status "$2"; exit ;;
  --file) file_session "$2"; exit ;;
  --new) new_agent "$2"; exit ;;
esac

if [ ! -f "$PROJECTS_FILE" ]; then
  echo "No projects yet: create $PROJECTS_FILE. Press a key."
  read -rsn1
  exit 0
fi

AGENTS_FILE=$(mktemp "${TMPDIR:-/tmp}/claude-projects.XXXXXX")
PENDING_FILE=$(mktemp "${TMPDIR:-/tmp}/claude-inbox.XXXXXX")
export AGENTS_FILE PENDING_FILE PROJECTS_FILE
trap 'rm -f "$AGENTS_FILE" "$PENDING_FILE"' EXIT
refresh_agents

project_rows |
  fzf --delimiter='\t' --with-nth=2,3 --tabstop=4 "${TELESCOPE[@]}" --no-sort \
    --prompt='projects › ' --input-label=' Projects ' --header="$(projects_header)" \
    --preview="$SELF --preview {1}" --bind="focus,result:transform-preview-label($SELF --label {2})" \
    --bind="tab:transform($SELF --tab)" \
    --bind="enter:transform($SELF --enter {1})" \
    --bind="o:transform($SELF --ack {1})+refresh-preview" \
    --bind="ctrl-r:transform($SELF --reload)" \
    --bind="n:execute($SELF --next {1})+reload($SELF --current-rows)+refresh-preview" \
    --bind="s:execute-silent($SELF --status {1})+reload($SELF --current-rows)+refresh-preview" \
    --bind="a:execute($SELF --new {1})+reload($SELF --current-rows)"
