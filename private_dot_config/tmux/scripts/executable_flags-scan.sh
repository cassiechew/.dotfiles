#!/bin/bash
# Builds the store behind prefix+F: every feature flag you've added to a
# repo's flags.ts, with what it's for (the comment above it), its ticket, and
# its state in Split. flags-pick.sh runs it when the store is stale.
#
# Settings come from ~/.config/tmux/work.env, kept out of the dotfiles repo:
#   FLAGS_REPOS="api web"        # repos under ~/projects, read from origin/main
#   FLAGS_AUTHOR=me@example.com  # whose commits count as yours
#   SPLIT_WORKSPACE=<id>         # Split workspace the flags live in
# and SPLIT_API_KEY (a Split admin API key) from the environment or
# ~/.zshrc.local.
#
# Writes ~/.local/share/flags/flags.json: one entry per flag, newest first.

. "$(dirname "$0")/flags-common.sh"

flags_configured || { echo "Set FLAGS_REPOS and FLAGS_AUTHOR in ~/.config/tmux/work.env" >&2; exit 1; }
mkdir -p "$FLAGS_DIR"
# One scan at a time: a popup opened mid-scan shows the old store. The lock is
# a symlink to this scan's pid (ln -s is atomic); a stale one is taken over.
if ! ln -s "$$" "$FLAGS_LOCK" 2>/dev/null; then
  scan_running && exit 0
  rm -f "$FLAGS_LOCK"
  ln -s "$$" "$FLAGS_LOCK" 2>/dev/null || exit 0
fi
rmdir "$FLAGS_DIR/.scanning" 2>/dev/null  # the old mkdir lock, if one was left
WORK=$(mktemp -d "${TMPDIR:-/tmp}/flags-scan.XXXXXX")
trap 'rm -rf "$WORK"; rm -f "$FLAGS_LOCK"' EXIT

# registered reads a flags.ts and prints each flag it registers, with the
# comment above it (or beside it), its ticket and its created date, tab
# separated.
registered() {
  awk '
    function quoted(s) { match(s, /\047[a-z0-9-]+\047/); return substr(s, RSTART + 1, RLENGTH - 2) }
    function field(s, key) {
      if (!match(s, key ":[ \t]*\047[^\047]*\047")) return ""
      s = substr(s, RSTART, RLENGTH); sub(/^[^\047]*\047/, "", s); sub(/\047$/, "", s); return s
    }
    /^[ \t]*\/\// { line = $0; sub(/^[ \t]*\/\/[ \t]?/, "", line); cmt = cmt (cmt == "" ? "" : " ") line; next }
    /^[ \t]*\|[ \t]*\047[a-z0-9-]+\047/ {
      name = quoted($0); if (!(name in why)) order[++n] = name
      line = $0; if (sub(/^[^\/]*\/\/[ \t]?/, "", line)) cmt = cmt (cmt == "" ? "" : " ") line
      why[name] = cmt; cmt = ""; next
    }
    /^[ \t]*\047[a-z0-9-]+\047[ \t]*:[ \t]*\{/ { cur = quoted($0); cmt = ""; next }
    cur != "" && /ticketNo:/ { ticket[cur] = field($0, "ticketNo") }
    cur != "" && /createdDate:/ { created[cur] = field($0, "createdDate") }
    cur != "" && /^[ \t]*\},?[ \t]*$/ { cur = "" }
    { cmt = "" }
    END { for (i = 1; i <= n; i++) { k = order[i]; gsub(/\t/, " ", why[k]); print k "\t" why[k] "\t" ticket[k] "\t" created[k] } }'
}

# added prints each flag your commits added to a flags.ts, with the date and
# commit of the first one, tab separated.
added() {
  awk '
    /^COMMIT / { sha = $2; date = $3; next }
    /^\+[ \t]*\|[ \t]*\047[a-z0-9-]+\047/ {
      match($0, /\047[a-z0-9-]+\047/); name = substr($0, RSTART + 1, RLENGTH - 2)
      if (!(name in seen)) { seen[name] = 1; print name "\t" date "\t" sha }
    }'
}

for repo in $FLAGS_REPOS; do
  git=(git -C "$HOME/projects/$repo")
  "${git[@]}" fetch -q origin main:refs/remotes/origin/main --force 2>/dev/null
  file=$("${git[@]}" ls-tree -r --name-only origin/main | grep -E '(^|/)flags\.ts$' | grep -v test | head -n 1)
  [ -n "$file" ] || continue
  "${git[@]}" show "origin/main:$file" | registered > "$WORK/$repo.registered"
  "${git[@]}" log origin/main --author="$FLAGS_AUTHOR" --reverse --format='COMMIT %h %as' -p -- "$file" |
    added > "$WORK/$repo.added"
  # A flag that's gone from flags.ts was removed by the last commit to touch it.
  while IFS=$'\t' read -r name date sha; do
    if grep -q "^$name	" "$WORK/$repo.registered"; then
      removed=""
    else
      removed=$("${git[@]}" log origin/main -1 --format=%as -S"'$name'" -- "$file")
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$repo" "$date" "$sha" "$removed"
  done < "$WORK/$repo.added" >> "$WORK/added.tsv"
  sed "s/^/$repo	/" "$WORK/$repo.registered" >> "$WORK/registered.tsv"
done
[ -s "$WORK/added.tsv" ] || { echo "No flags found for $FLAGS_AUTHOR in: $FLAGS_REPOS" >&2; exit 1; }

# Split: each flag in each environment, including flags gone from the code
# (still in Split, they're ghosts). A 404 means the flag isn't set up there.
# Flags gone from both the code and Split are retired: they're carried over
# from the last scan, not asked about again.
mkdir -p "$WORK/split"
"$JQ" -r '.flags[] | select((.inCode | not) and .split != null and all(.split[]; .state == "none")) | .name' \
  "$FLAGS_STORE" 2>/dev/null > "$WORK/retired"
key=$(split_key)
# Without Split every flag's state would be blanked, so keep the last store.
if [ -z "$key" ] || [ -z "$SPLIT_WORKSPACE" ]; then
  echo "Set SPLIT_API_KEY and SPLIT_WORKSPACE; keeping the last store" >&2
  exit 1
fi
if [ -n "$key" ] && [ -n "$SPLIT_WORKSPACE" ]; then
  api="https://api.split.io/internal/api/v2"
  curl -sf --max-time 10 -H "Authorization: Bearer $key" "$api/environments/ws/$SPLIT_WORKSPACE" |
    "$JQ" -r --argjson want "$(printf '%s\n' "${FLAGS_ENVS[@]}" | "$JQ" -R . | "$JQ" -s .)" \
      '.[] | select(.name as $n | $want | index($n)) | "\(.id)\t\(.name)"' > "$WORK/envs.tsv"
  [ -s "$WORK/envs.tsv" ] || { echo "Couldn't list Split environments; keeping the last store" >&2; exit 1; }
  cut -f1 "$WORK/added.tsv" | sort -u | grep -v -x -F -f "$WORK/retired" | while read -r name; do
    while IFS=$'\t' read -r env_id env_name; do
      printf '%s\t%s\t%s\n' "$name" "$env_id" "$env_name"
    done < "$WORK/envs.tsv"
  done | while IFS=$'\t' read -r name env_id env_name; do
    # One at a time: Split allows about 20 calls every few seconds per org,
    # and answers 429 with how long to wait.
    out="$WORK/split/$name.$env_name"
    for _ in 1 2 3 4 5; do
      code=$(curl -s --max-time 15 -o "$out.json" -D "$out.headers" -w '%{http_code}' \
        -H "Authorization: Bearer $key" "$api/splits/ws/$SPLIT_WORKSPACE/$name/environments/$env_id")
      [ "$code" = 429 ] || break
      wait=$(tr -d '\r' < "$out.headers" | awk -F': ' 'tolower($1) == "x-ratelimit-reset-seconds-org" { print $2 }')
      sleep $(( ${wait:-2} + 1 ))
    done
    echo "$code" > "$out.code"
  done
fi

# Gather Split's answers as {name: {env: definition or null or "error"}}.
for f in "$WORK"/split/*.code; do
  [ -e "$f" ] || continue
  base=${f%.code}; base=${base##*/}
  code=$(cat "$f")
  case "$code" in
    200) def=$(cat "$WORK/split/$base.json") ;;
    404) def=null ;;
    *) def='"error"' ;;
  esac
  printf '%s\t%s\t%s\n' "${base%.*}" "${base##*.}" "$(printf '%s' "$def" | "$JQ" -c .)"
done > "$WORK/split.tsv"
while read -r name; do
  for env in "${FLAGS_ENVS[@]}"; do printf '%s\t%s\tnull\n' "$name" "$env"; done
done < "$WORK/retired" >> "$WORK/split.tsv"

"$JQ" -n \
  --rawfile added "$WORK/added.tsv" \
  --rawfile registered "$WORK/registered.tsv" \
  --rawfile split "$WORK/split.tsv" \
  --arg scanned "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson envs "$(printf '%s\n' "${FLAGS_ENVS[@]}" | "$JQ" -R . | "$JQ" -s .)" '
  def rows($s): $s | split("\n") | map(select(length > 0) | split("\t"));
  # state turns a Split definition into a headline and the rules behind it.
  def state:
    . as $def
    | if . == null then {state: "none", text: "not set up"}
    elif . == "error" then {state: "error", text: "could not load"}
    elif .killed then {state: "killed", text: "KILLED (serving \(.defaultTreatment))"}
    else
      ([.defaultRule // [] | .[] | select(.size > 0)]) as $d
      | (if ($d | length) == 1 then $d[0].treatment else ($d | map("\(.treatment) \(.size)%") | join(" / ")) end) as $default
      | if ((.rules // []) | length) == 0 then
          {state: (if $default == "on" then "on" elif $default == "off" then "off" else "split" end), text: "\($default) for everyone"}
        else
          {state: "targeted", text: "\(.rules | length) rule\(if (.rules | length) > 1 then "s" else "" end), otherwise \($default)",
           rules: [.rules[] |
             ([.buckets[] | select(.size > 0) | if .size == 100 then .treatment else "\(.treatment) \(.size)%" end] | join(" / ")) as $to
             | ([.condition.matchers[] |
                 (.strings // []) as $v
                 | "\(.attribute // "id") \(if .negate then "not " else "" end)\(.type | ascii_downcase | gsub("_"; " ") | sub("^in list string$"; "in") | sub("^whitelist$"; "in"))"
                   + (if ($v | length) > 0 then " " + ($v[:4] | join(", ")) + (if ($v | length) > 4 then " +\(($v | length) - 4) more" else "" end) else "" end)
               ] | join(" and ")) as $when
             | "\($to) when \($when)"]}
        end
      | . + {id: $def.id, envId: $def.environment.id,
             updated: (if $def.lastUpdateTime then ($def.lastUpdateTime / 1000 | todate) else null end),
             lastSeen: (if ($def.lastTrafficReceivedAt // 0) > 0 then ($def.lastTrafficReceivedAt / 1000 | todate) else null end)}
    end;

  (rows($registered) | map({key: "\(.[0])/\(.[1])", value: {why: .[2], ticket: .[3], created: .[4]}}) | from_entries) as $reg
  | (rows($split) | reduce .[] as $r ({}; .[$r[0]][$r[1]] = ($r[2] | fromjson))) as $live
  | rows($added)
  | group_by(.[0])
  | map(
      .[0][0] as $name
      | {name: $name,
         added: (map(.[2]) | min),
         # Still registered in any repo, by anyone: a registration by a teammate
         # elsewhere keeps the flag alive even after you removed yours.
         inCode: (any(.[]; .[4] == "") or ($reg | keys | any(endswith("/" + $name)))),
         repos: map({repo: .[1], added: .[2], commit: .[3], removed: (if .[4] == "" then null else .[4] end)}
                    + ($reg["\(.[1])/\($name)"] // {}))
                | sort_by(.added),
         why: ([.[] | $reg["\(.[1])/\($name)"].why // empty | select(length > 0)] | first // null),
         tickets: ([.[] | $reg["\(.[1])/\($name)"].ticket // empty | scan("[A-Z][A-Z0-9]+-[0-9]+")] | unique),
         split: (if $live[$name] then [$envs[] as $e | {env: $e} + ($live[$name][$e] | state)] else null end)})
  | sort_by(.added) | reverse
  | {scanned: $scanned, flags: .}' > "$WORK/flags.json" &&
  mv "$WORK/flags.json" "$FLAGS_STORE"
