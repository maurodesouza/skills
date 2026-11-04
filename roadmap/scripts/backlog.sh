#!/usr/bin/env bash
# Shared state of a roadmap backlog, so several runs can work on it at the same time:
# the short write lock, item claims, the next ready item and the recovery of failed runs.
# Used by roadmap, roadmap-implementer and roadmap-implementer/scripts/run.sh (roadmap/references/format.md, section 7).
#
# Usage: backlog.sh <command> <roadmap> [args]
#   lock     <roadmap> <pid> [owner]        take the write lock for <pid>, waiting up to ROADMAP_LOCK_WAIT; exit 1 on timeout
#   unlock   <roadmap> <pid>                release the write lock when <pid> holds it
#   claims   <roadmap>                      print "<id> <pid>" for every live claim
#   claim    <roadmap> <id> <pid>           claim an item for <pid> (hold the lock); exit 1 when another live process holds it
#   unclaim  <roadmap> <id> [pid]           remove the claim (only when <pid> holds it, when given)
#   next     <roadmap>                      print the id of the next ready, unclaimed item
#   status   <roadmap> <id>                 print the status of an item
#   fail     <roadmap> <id> <pid> <reason>  record a run that ended without a result: back to pending, blocked after ROADMAP_MAX_FAILURES
#   requeue  <roadmap> <id> <pid> <reason>  put an in-progress item back to pending without counting a failure (runner stopped)
#   recover  <roadmap> <pid>                fail every in-progress item whose claim is missing or dead (its run died)
#
# fail, requeue and recover take the lock themselves (reentrant for <pid>), edit the item and commit it.
# They do not regenerate ROADMAP.md: the next write of roadmap or roadmap-implementer does.
#
# Env:
#   ROADMAP_LOCK_WAIT     seconds to wait for the lock (default 600)
#   ROADMAP_LOCK_TTL      seconds after which a lock is abandoned even if its process is alive (default 900)
#   ROADMAP_MAX_FAILURES  failed runs of an item before it is blocked (default 3)

set -uo pipefail

LOCK_WAIT="${ROADMAP_LOCK_WAIT:-600}"
LOCK_TTL="${ROADMAP_LOCK_TTL:-900}"
MAX_FAILURES="${ROADMAP_MAX_FAILURES:-3}"

die() { printf 'backlog.sh: %s\n' "$*" >&2; exit 2; }

command -v flock >/dev/null 2>&1 || die "flock is required (util-linux; on macOS: brew install flock)"

cmd="${1:-}"
input="${2:-}"
[ -n "$cmd" ] && [ -n "$input" ] || die "usage: backlog.sh <command> <roadmap> [args]"
shift 2

[ -f "$input" ] && input="$(dirname "$input")"
[ -f "$input/roadmap/ROADMAP.md" ] && input="$input/roadmap"
[ -f "$input/ROADMAP.md" ] || die "no ROADMAP.md in $input"
ROADMAP="$(cd "$input" && pwd)"
LOCK="$ROADMAP/.lock"
CLAIMS="$ROADMAP/.claims"

alive() { [ -n "${1:-}" ] && kill -0 "$1" 2>/dev/null; }
now() { date +%s; }

# ---------------------------------------------------------------- lock

lock_value() { sed -n "s/^$1=//p" "$LOCK" 2>/dev/null | head -n 1; }

# The lock file is never deleted: flock guards it and an empty file means free.
try_lock() {
  local pid="$1" owner="$2"
  (
    flock -w 30 9 || exit 1
    holder="$(lock_value pid)"
    since="$(lock_value since)"
    [ "$holder" = "$pid" ] && exit 0
    if alive "$holder"; then
      # A lock without since comes from an older runner: keep it while its process lives.
      [ -z "$since" ] && exit 1
      [ $(( $(now) - since )) -lt "$LOCK_TTL" ] && exit 1
    fi
    printf 'pid=%s\nowner=%s\nsince=%s\nstarted=%s\n' "$pid" "$owner" "$(now)" "$(date -Iseconds)" > "$LOCK"
  ) 9>>"$LOCK"
}

do_lock() {
  local pid="$1" owner="${2:-unknown}" deadline
  deadline=$(( $(now) + LOCK_WAIT ))
  until try_lock "$pid" "$owner"; do
    if [ "$(now)" -ge "$deadline" ]; then
      printf 'backlog.sh: lock held by pid %s (%s) for more than %ss\n' "$(lock_value pid)" "$(lock_value owner)" "$LOCK_WAIT" >&2
      return 1
    fi
    sleep 2
  done
}

do_unlock() {
  local pid="$1"
  ( flock -w 30 9 || exit 1; [ "$(lock_value pid)" = "$pid" ] && : > "$LOCK"; exit 0 ) 9>>"$LOCK"
}

# Runs a command under the lock for <pid>; keeps the lock when <pid> already held it.
with_lock() {
  local pid="$1" had=0 code
  shift
  [ "$(lock_value pid)" = "$pid" ] && had=1
  [ "$had" = 1 ] || do_lock "$pid" backlog.sh || return 1
  "$@"
  code=$?
  [ "$had" = 1 ] || do_unlock "$pid"
  return "$code"
}

# ---------------------------------------------------------------- claims

ensure_claims() {
  mkdir -p "$CLAIMS"
  git -C "$ROADMAP" check-ignore -q .claims/x 2>/dev/null && return 0
  local gitdir
  gitdir="$(git -C "$ROADMAP" rev-parse --absolute-git-dir 2>/dev/null)" || return 0
  mkdir -p "$gitdir/info"
  printf '.claims/\n' >> "$gitdir/info/exclude"
}

claim_pid() { sed -n 's/^pid=//p' "$CLAIMS/$1" 2>/dev/null | head -n 1; }

live_claims() {
  local f pid
  for f in "$CLAIMS"/*; do
    [ -f "$f" ] || continue
    pid="$(claim_pid "$(basename "$f")")"
    alive "$pid" && printf '%s %s\n' "$(basename "$f")" "$pid"
  done
}

do_claim() {
  local id="$1" pid="$2" holder
  ensure_claims
  holder="$(claim_pid "$id")"
  if [ -n "$holder" ] && [ "$holder" != "$pid" ] && alive "$holder"; then
    printf 'backlog.sh: item %s is claimed by pid %s\n' "$id" "$holder" >&2
    return 1
  fi
  printf 'pid=%s\nsince=%s\n' "$pid" "$(date -Iseconds)" > "$CLAIMS/$id"
}

do_unclaim() {
  local id="$1" pid="${2:-}"
  [ -f "$CLAIMS/$id" ] || return 0
  [ -z "$pid" ] || [ "$(claim_pid "$id")" = "$pid" ] || return 0
  rm -f "$CLAIMS/$id"
}

# ---------------------------------------------------------------- items

item_file() {
  grep -l -E "^id:[[:space:]]*[\"']?$1[\"']?[[:space:]]*(#.*)?$" "$ROADMAP"/items/*.md 2>/dev/null | head -n 1
}

# Prints a frontmatter field.
field() {
  awk -v k="$2" '
    /^---[[:space:]]*$/ { if (++fm == 2) exit; next }
    fm == 1 && index($0, k ":") == 1 {
      v = substr($0, length(k) + 2)
      sub(/[[:space:]]+#.*$/, "", v)
      gsub(/^[[:space:]"'\'']+|[[:space:]"'\'']+$/, "", v)
      print v
      exit
    }
  ' "$1"
}

# Sets a frontmatter field, adding it at the end of the frontmatter when missing.
set_field() {
  local file="$1" tmp
  tmp="$(mktemp)"
  awk -v k="$2" -v v="$3" '
    /^---[[:space:]]*$/ { fm++; if (fm == 2 && !done) { print k ": " v; done = 1 } print; next }
    fm == 1 && !done && index($0, k ":") == 1 { print k ": " v; done = 1; next }
    { print }
  ' "$file" > "$tmp" && cat "$tmp" > "$file"
  rm -f "$tmp"
}

log_line() {
  [ -n "$(tail -c 1 "$1")" ] && printf '\n' >> "$1"
  printf -- '- %s %s\n' "$(date +%F)" "$2" >> "$1"
}

commit_item() {
  git -C "$ROADMAP" add -- "$1" >/dev/null 2>&1 &&
    git -C "$ROADMAP" commit -q -m "$2" -- "$1" >/dev/null 2>&1
}

# Failed runs since the item was last unblocked.
count_failures() {
  awk '/unblocked by roadmap/ { n = 0 } /run failed/ { n++ } END { print n + 0 }' "$1"
}

# Prints the id of the next ready item: pending, every depends-on done, no live claim; by order, created, id.
do_next() {
  local files=("$ROADMAP"/items/*.md) claimed
  [ -e "${files[0]}" ] || return 0
  claimed=" $(live_claims | cut -d ' ' -f 1 | tr '\n' ' ') "
  awk -v claimed="$claimed" '
    function clean(v) { gsub(/["'\''[:space:]]/, "", v); return v }
    FNR == 1 { fm = 0; inlist = 0 }
    /^---[[:space:]]*$/ { fm++; inlist = 0; next }
    fm != 1 { next }
    inlist && /^[[:space:]]*-[[:space:]]*/ { v = $0; sub(/^[[:space:]]*-/, "", v); deps[FILENAME] = deps[FILENAME] " " clean(v); next }
    { inlist = 0 }
    /^id:/          { v = $0; sub(/^id:/, "", v); sub(/#.*/, "", v); id[FILENAME] = clean(v) }
    /^status:/      { v = $0; sub(/^status:/, "", v); sub(/#.*/, "", v); status[FILENAME] = clean(v) }
    /^order:/       { v = $0; sub(/^order:/, "", v); sub(/#.*/, "", v); order[FILENAME] = clean(v) }
    /^created:/     { v = $0; sub(/^created:/, "", v); sub(/#.*/, "", v); created[FILENAME] = clean(v) }
    /^depends-on:/  {
      v = $0; sub(/^depends-on:/, "", v); sub(/#.*/, "", v)
      if (clean(v) == "") { inlist = 1; deps[FILENAME] = ""; next }
      gsub(/[\[\]]/, "", v); gsub(/,/, " ", v); gsub(/["'\'']/, "", v); deps[FILENAME] = v
    }
    END {
      for (f in id) state[id[f]] = status[f]
      for (f in id) {
        if (status[f] != "pending" || index(claimed, " " id[f] " ")) continue
        ready = 1
        n = split(deps[f], d, /[[:space:]]+/)
        for (i = 1; i <= n; i++) if (d[i] != "" && state[d[i]] != "done") ready = 0
        if (ready) printf "%010d\t%s\t%s\n", (order[f] == "" ? 0 : order[f]), created[f], id[f]
      }
    }
  ' "${files[@]}" | sort | head -n 1 | cut -f 3
}

# fail / requeue body; runs under the lock. Prints "<id> <new status>" when the item changed.
settle() {
  local mode="$1" id="$2" reason="${3//\"/\'}" file st n
  file="$(item_file "$id")"
  [ -n "$file" ] || return 0
  st="$(field "$file" status)"

  if [ "$mode" = requeue ]; then
    [ "$st" = in-progress ] || return 0
    set_field "$file" status pending
    set_field "$file" updated "$(date +%F)"
    log_line "$file" "returned to pending: $reason"
    commit_item "$file" "♻️ chore: requeue $id after a stopped run"
    printf '%s pending\n' "$id"
    return 0
  fi

  case "$st" in pending|in-progress) ;; *) return 0 ;; esac
  n=$(( $(count_failures "$file") + 1 ))
  set_field "$file" updated "$(date +%F)"
  if [ "$n" -ge "$MAX_FAILURES" ]; then
    set_field "$file" status blocked
    set_field "$file" blocked-reason "\"$n runs ended without a result (last: $reason). Check the run logs, fix the cause and unblock it with roadmap.\""
    log_line "$file" "run failed ($n/$MAX_FAILURES), blocked: $reason"
    commit_item "$file" "⛔ chore: block $id after failed runs"
    printf '%s blocked\n' "$id"
  else
    set_field "$file" status pending
    log_line "$file" "run failed ($n/$MAX_FAILURES), returned to pending: $reason"
    commit_item "$file" "♻️ chore: retry $id after a failed run"
    printf '%s pending\n' "$id"
  fi
}

recover_all() {
  local f id claimed
  claimed=" $(live_claims | cut -d ' ' -f 1 | tr '\n' ' ') "
  for f in "$ROADMAP"/items/*.md; do
    [ -f "$f" ] && [ "$(field "$f" status)" = in-progress ] || continue
    id="$(field "$f" id)"
    case "$claimed" in *" $id "*) continue ;; esac
    settle fail "$id" "the run that owned it is no longer running"
  done
}

# ---------------------------------------------------------------- commands

case "$cmd" in
  lock)    [ $# -ge 1 ] || die "lock <roadmap> <pid> [owner]"; do_lock "$1" "${2:-unknown}" ;;
  unlock)  [ $# -ge 1 ] || die "unlock <roadmap> <pid>"; do_unlock "$1" ;;
  claims)  live_claims ;;
  claim)   [ $# -ge 2 ] || die "claim <roadmap> <id> <pid>"; do_claim "$1" "$2" ;;
  unclaim) [ $# -ge 1 ] || die "unclaim <roadmap> <id> [pid]"; do_unclaim "$1" "${2:-}" ;;
  next)    do_next ;;
  status)  [ $# -ge 1 ] || die "status <roadmap> <id>"; f="$(item_file "$1")"; [ -n "$f" ] && field "$f" status ;;
  fail)    [ $# -ge 3 ] || die "fail <roadmap> <id> <pid> <reason>"; with_lock "$2" settle fail "$1" "$3" ;;
  requeue) [ $# -ge 3 ] || die "requeue <roadmap> <id> <pid> <reason>"; with_lock "$2" settle requeue "$1" "$3" ;;
  recover) [ $# -ge 1 ] || die "recover <roadmap> <pid>"; with_lock "$1" recover_all ;;
  *)       die "unknown command: $cmd" ;;
esac
