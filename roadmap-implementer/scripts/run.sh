#!/usr/bin/env bash
# Runs roadmap-implementer continuously: one fresh headless Claude Code session per ready item.
#
# Usage: run.sh [roadmap-path]   (default: ./roadmap)
#
# Env:
#   ROADMAP_POLL_INTERVAL     seconds between checks when nothing is ready (default 300)
#   ROADMAP_MAX_FAILURES      failed runs of the same item before the runner blocks it (default 3)
#   ROADMAP_FAILURE_BACKOFF   seconds to wait after blocking a failing item (default 600)
#   CLAUDE_BIN                Claude Code binary (default claude)
#   ROADMAP_CLAUDE_ARGS       extra arguments for Claude Code (word-split)
#
# WARNING: Claude runs with --dangerously-skip-permissions and epic-implementer auto-merges.

set -uo pipefail

POLL_INTERVAL="${ROADMAP_POLL_INTERVAL:-300}"
MAX_FAILURES="${ROADMAP_MAX_FAILURES:-3}"
FAILURE_BACKOFF="${ROADMAP_FAILURE_BACKOFF:-600}"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
read -r -a EXTRA_ARGS <<< "${ROADMAP_CLAUDE_ARGS:-}"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
die() { log "error: $*" >&2; exit 1; }

ROADMAP_INPUT="${1:-./roadmap}"
[ -f "$ROADMAP_INPUT" ] && ROADMAP_INPUT="$(dirname "$ROADMAP_INPUT")"
[ -f "$ROADMAP_INPUT/roadmap/ROADMAP.md" ] && ROADMAP_INPUT="$ROADMAP_INPUT/roadmap"
[ -f "$ROADMAP_INPUT/ROADMAP.md" ] || die "no ROADMAP.md in $ROADMAP_INPUT (create the roadmap with the roadmap skill first)"
ROADMAP="$(cd "$ROADMAP_INPUT" && pwd)"

LOCK="$ROADMAP/.lock"
LOGS="$ROADMAP/.logs"
mkdir -p "$LOGS"

# Claude runs from the root in the ROADMAP.md header (organization or project), falling back to the roadmap's parent.
header_root="$(awk '/^---$/{n++; next} n==1 && /^root:/{sub(/^root:[[:space:]]*/, ""); sub(/[[:space:]]+#.*$/, ""); print; exit}' "$ROADMAP/ROADMAP.md")"
WORKDIR="${header_root/#\~/$HOME}"
[ -d "$WORKDIR" ] || WORKDIR="$(dirname "$ROADMAP")"

lock_pid() { sed -n 's/^pid=//p' "$LOCK" 2>/dev/null | head -n 1; }

if [ -f "$LOCK" ]; then
  pid="$(lock_pid)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    die "roadmap $ROADMAP is already locked by pid $pid"
  fi
  log "recovering stale lock (pid ${pid:-unknown})"
fi
printf 'pid=%s\nowner=run.sh\nstarted=%s\n' "$$" "$(date -Iseconds)" > "$LOCK"
export ROADMAP_LOCK_OWNER="$$"

child=""
cleanup() {
  [ -n "$child" ] && kill "$child" 2>/dev/null
  [ "$(lock_pid)" = "$$" ] && rm -f "$LOCK"
}
trap cleanup EXIT
trap 'log "stopping"; exit 130' INT TERM

# Sleeps in the background so INT/TERM interrupt it immediately.
pause() { sleep "$1" & child=$!; wait "$child"; child=""; }

# Prints the id of the next ready item (pending, all depends-on done), by order, created, id.
# Mirrors roadmap-next-item so idle checks never start Claude.
next_ready() {
  local files=("$ROADMAP"/items/*.md)
  [ -e "${files[0]}" ] || return 0
  awk '
    function clean(v) { gsub(/["'\''[:space:]]/, "", v); return v }
    FNR == 1 { fm = 0; inlist = 0 }
    /^---[[:space:]]*$/ { fm++; inlist = 0; next }
    fm != 1 { next }
    inlist && /^[[:space:]]*-[[:space:]]*/ { v = $0; sub(/^[[:space:]]*-/, "", v); deps[FILENAME] = deps[FILENAME] " " clean(v); next }
    { inlist = 0 }
    /^id:/          { v = $0; sub(/^id:/, "", v); id[FILENAME] = clean(v) }
    /^status:/      { v = $0; sub(/^status:/, "", v); sub(/#.*/, "", v); status[FILENAME] = clean(v) }
    /^order:/       { v = $0; sub(/^order:/, "", v); sub(/#.*/, "", v); order[FILENAME] = clean(v) }
    /^created:/     { v = $0; sub(/^created:/, "", v); created[FILENAME] = clean(v) }
    /^depends-on:/  {
      v = $0; sub(/^depends-on:/, "", v); sub(/#.*/, "", v)
      if (clean(v) == "") { inlist = 1; deps[FILENAME] = ""; next }
      gsub(/[\[\]]/, "", v); gsub(/,/, " ", v); gsub(/["'\'']/, "", v); deps[FILENAME] = v
    }
    END {
      for (f in id) state[id[f]] = status[f]
      for (f in id) {
        if (status[f] != "pending") continue
        ready = 1
        n = split(deps[f], d, /[[:space:]]+/)
        for (i = 1; i <= n; i++) if (d[i] != "" && state[d[i]] != "done") ready = 0
        if (ready) printf "%010d\t%s\t%s\n", (order[f] == "" ? 0 : order[f]), created[f], id[f]
      }
    }
  ' "${files[@]}" | sort | head -n 1 | cut -f 3
}

# Records an item that keeps failing as blocked, so it stops consuming runs (roadmap/references/format.md).
block_item() {
  local id="$1" reason="$2" file
  file="$(grep -l -E "^id:[[:space:]]*[\"']?$id[\"']?[[:space:]]*$" "$ROADMAP"/items/*.md | head -n 1)"
  [ -n "$file" ] || return 1
  sed -i -E \
    -e "s/^status:.*/status: blocked/" \
    -e "s/^updated:.*/updated: $(date +%F)/" \
    -e "s|^blocked-reason:.*|blocked-reason: \"$reason\"|" "$file"
  grep -q '^blocked-reason:' "$file" || sed -i "0,/^status:/s|^status:.*|&\nblocked-reason: \"$reason\"|" "$file"
  printf -- '- %s blocked by run.sh: %s\n' "$(date +%F)" "$reason" >> "$file"
  git -C "$ROADMAP" add "$file" >/dev/null 2>&1 &&
    git -C "$ROADMAP" commit -q -m "⛔ chore: block $id after failed runs" >/dev/null 2>&1
  return 0
}

log "watching $ROADMAP (workdir $WORKDIR, poll ${POLL_INTERVAL}s)"
failures=0
last_item=""

while true; do
  item="$(next_ready)"
  if [ -z "$item" ]; then
    pause "$POLL_INTERVAL"
    continue
  fi

  [ "$item" = "$last_item" ] || failures=0

  if [ "$failures" -ge "$MAX_FAILURES" ]; then
    reason="$failures runs ended without recording a result; see the logs in $LOGS"
    if block_item "$item" "$reason"; then
      log "item $item blocked: $reason"
    else
      log "item $item failed $failures times and could not be blocked"
    fi
    failures=0
    last_item=""
    pause "$FAILURE_BACKOFF"
    continue
  fi

  logfile="$LOGS/$(date '+%Y%m%d-%H%M%S')-$item.log"
  log "starting item $item (log $logfile)"
  (cd "$WORKDIR" && exec "$CLAUDE_BIN" -p "/roadmap-implementer $ROADMAP" \
    --dangerously-skip-permissions "${EXTRA_ARGS[@]}") > "$logfile" 2>&1 &
  child=$!
  wait "$child"
  code=$?
  child=""

  result="$(grep -o 'ROADMAP_IMPLEMENTER_STATUS: [A-Z]*' "$logfile" | tail -n 1 | cut -d ' ' -f 2)"
  log "item $item finished: ${result:-no status} (exit $code)"

  # A run counts as failed when it has no status, or reports DONE/BLOCKED but left the item ready.
  case "$result" in
    DONE|BLOCKED)
      if [ "$(next_ready)" = "$item" ]; then
        failures=$((failures + 1))
        log "item $item is still pending after its run ($failures/$MAX_FAILURES)"
      fi
      ;;
    IDLE|LOCKED)
      pause "$POLL_INTERVAL"
      ;;
    *)
      failures=$((failures + 1))
      pause "$(( POLL_INTERVAL < 60 ? POLL_INTERVAL : 60 ))"
      ;;
  esac
  last_item="$item"
done
