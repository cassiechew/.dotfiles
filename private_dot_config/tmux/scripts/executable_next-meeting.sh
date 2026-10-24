#!/bin/bash
# tmux status badge for the next meeting, from the macOS calendar (whatever
# Calendar.app syncs) via icalBuddy. tmux calls this every second, so the
# answer is cached for 30s.
#
#   📅 Standup in 12m          a meeting within the hour
#    📅 Standup in 3m          five minutes or less, highlighted
#   🔴 Standup · ends 10:30    the meeting you're in
#
# Calendar access was granted to the terminal, so this only sees events when
# tmux runs it.

# Titles that aren't meetings (holds, focus blocks). icalBuddy can't tell
# free or declined events apart, so they're skipped by name. Case-insensitive.
IGNORE='focus|lunch|hold|ooo|out of office|busy|block|commute|working hours'

CACHE="${TMPDIR:-/tmp}/tmux-next-meeting"
# NEXT_MEETING_NOW (epoch seconds) pretends it's another time, for testing.
if [ -n "$NEXT_MEETING_NOW" ]; then
  CACHE=/dev/null
elif [ -f "$CACHE" ] && [ $(( $(date +%s) - $(stat -f %m "$CACHE") )) -lt 30 ]; then
  cat "$CACHE"
  exit 0
fi

ICALBUDDY=/opt/homebrew/bin/icalBuddy
now=${NEXT_MEETING_NOW:-$(date +%s)}
next="" next_start=0
cur="" cur_start=0 cur_end=0

while IFS= read -r line; do
  # 2026-10-22 at 10:00 - 14:00 ~ Title  (an end on another day has its own date)
  [[ $line =~ ^([0-9-]+)\ at\ ([0-9:]+)\ -\ (([0-9-]+)\ at\ )?([0-9:]+)\ ~\ (.*)$ ]] || continue
  start_date=${BASH_REMATCH[1]} start_time=${BASH_REMATCH[2]}
  end_date=${BASH_REMATCH[4]:-$start_date} end_time=${BASH_REMATCH[5]}
  title=${BASH_REMATCH[6]}
  echo "$title" | grep -qiE "$IGNORE" && continue

  # Explicit :00 seconds: BSD date fills fields missing from the format with
  # the current time, so "10:00" parsed as 10:00:<now's seconds>.
  start=$(date -j -f "%Y-%m-%d %H:%M:%S" "$start_date $start_time:00" +%s 2>/dev/null) || continue
  end=$(date -j -f "%Y-%m-%d %H:%M:%S" "$end_date $end_time:00" +%s 2>/dev/null) || continue
  (( end <= now )) && continue

  if (( start <= now )); then
    # The meeting you're in is the one that started most recently.
    if (( start >= cur_start )); then cur=$title cur_start=$start cur_end=$end; fi
  elif (( next_start == 0 || start < next_start )); then
    next=$title next_start=$start
  fi
done < <("$ICALBUDDY" -ea -nc -nrd -b "" -ps "| ~ |" -iep "datetime,title" -po "datetime,title" \
  -df "%Y-%m-%d" -tf "%H:%M" eventsToday+1 2>/dev/null)

short() {
  local t=${1//#/##}  # escape tmux formats
  if (( ${#t} > 28 )); then t="${t:0:27}…"; fi
  printf '%s' "$t"
}

out=""
until_next=$(( next_start - now ))
if [ -n "$next" ] && (( until_next <= 300 )); then
  # About to start, even mid-meeting: it matters most.
  out="#[fg=#FF0066,bold,reverse] 📅 $(short "$next") in $(( (until_next + 59) / 60 ))m #[default]"
elif [ -n "$cur" ]; then
  out="#[fg=#FF0066,bold]🔴 $(short "$cur") · ends $(date -r "$cur_end" +%H:%M)#[default]"
elif [ -n "$next" ] && (( until_next <= 3600 )); then
  out="#[fg=#F77AB0,bold]📅 $(short "$next") in $(( (until_next + 59) / 60 ))m#[default]"
fi

if [ "$CACHE" != /dev/null ]; then
  printf '%s' "$out" > "$CACHE.tmp" && mv -f "$CACHE.tmp" "$CACHE"
fi
printf '%s' "$out"
