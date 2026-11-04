#!/usr/bin/env bash
# Runs roadmap-implementer continuously: one fresh headless Claude Code session per ready item,
# with up to ROADMAP_WORKERS items in parallel. Chats running /roadmap-implementer on the same
# roadmap at the same time are safe: every run claims its own item (roadmap/references/format.md, section 7).
#
# Usage: run.sh [roadmap-path]   (default: ./roadmap)
#
# Env:
#   ROADMAP_WORKERS           items implemented in parallel (default 1)
#   ROADMAP_POLL_INTERVAL     seconds between checks when nothing is ready (default 300)
#   ROADMAP_MAX_FAILURES      failed runs of the same item before it is blocked (default 3)
#   ROADMAP_FAILURE_BACKOFF   seconds a worker waits after an item is blocked for failing (default 600)
#   CLAUDE_BIN                Claude Code binary (default claude)
#   ROADMAP_CLAUDE_ARGS       extra arguments for Claude Code (word-split)
#
# WARNING: Claude runs with --dangerously-skip-permissions and epic-implementer auto-merges.

set -uo pipefail

WORKERS="${ROADMAP_WORKERS:-1}"
POLL_INTERVAL="${ROADMAP_POLL_INTERVAL:-300}"
FAILURE_BACKOFF="${ROADMAP_FAILURE_BACKOFF:-600}"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
read -r -a EXTRA_ARGS <<< "${ROADMAP_CLAUDE_ARGS:-}"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
die() { log "error: $*" >&2; exit 1; }

# backlog.sh ships with the roadmap skill, installed next to this one.
BACKLOG="${ROADMAP_BACKLOG_SH:-$(cd "$(dirname "$0")/../.." && pwd)/roadmap/scripts/backlog.sh}"
[ -x "$BACKLOG" ] || die "backlog.sh not found at $BACKLOG (sync the roadmap skill, or set ROADMAP_BACKLOG_SH)"
[[ "$WORKERS" =~ ^[1-9][0-9]*$ ]] || die "ROADMAP_WORKERS must be a positive number"

ROADMAP_INPUT="${1:-./roadmap}"
[ -f "$ROADMAP_INPUT" ] && ROADMAP_INPUT="$(dirname "$ROADMAP_INPUT")"
[ -f "$ROADMAP_INPUT/roadmap/ROADMAP.md" ] && ROADMAP_INPUT="$ROADMAP_INPUT/roadmap"
[ -f "$ROADMAP_INPUT/ROADMAP.md" ] || die "no ROADMAP.md in $ROADMAP_INPUT (create the roadmap with the roadmap skill first)"
ROADMAP="$(cd "$ROADMAP_INPUT" && pwd)"

LOGS="$ROADMAP/.logs"
mkdir -p "$LOGS"

# Claude runs from the root in the ROADMAP.md header (organization or project), falling back to the roadmap's parent.
header_root="$(awk '/^---$/{n++; next} n==1 && /^root:/{sub(/^root:[[:space:]]*/, ""); sub(/[[:space:]]+#.*$/, ""); print; exit}' "$ROADMAP/ROADMAP.md")"
WORKDIR="${header_root/#\~/$HOME}"
[ -d "$WORKDIR" ] || WORKDIR="$(dirname "$ROADMAP")"

# One worker: claims the next ready item under the lock, runs one session for it, settles the result.
worker() {
  n="$1"
  me="$BASHPID"
  item=""
  child=""
  failures=0

  wlog() { log "[worker $n] $*"; }

  # Sleeps in the background so INT/TERM interrupt it immediately.
  pause() { sleep "$1" & child=$!; wait "$child"; child=""; }

  stop() {
    trap '' INT TERM
    if [ -n "$child" ]; then kill "$child" 2>/dev/null; wait "$child" 2>/dev/null; fi
    if [ -n "$item" ]; then
      ROADMAP_LOCK_WAIT=60 "$BACKLOG" requeue "$ROADMAP" "$item" "$me" "the runner was stopped" >/dev/null
      "$BACKLOG" unclaim "$ROADMAP" "$item" "$me"
    fi
    exit 130
  }
  trap stop INT TERM

  while true; do
    item=""
    if "$BACKLOG" lock "$ROADMAP" "$me" "run.sh"; then
      # Items left in-progress by a run that died go back to pending (or blocked after repeated failures).
      while read -r id state; do wlog "recovered $id: $state"; done < <("$BACKLOG" recover "$ROADMAP" "$me")
      item="$("$BACKLOG" next "$ROADMAP")"
      [ -z "$item" ] || "$BACKLOG" claim "$ROADMAP" "$item" "$me" || item=""
      "$BACKLOG" unlock "$ROADMAP" "$me"
    else
      wlog "could not take the roadmap lock"
    fi

    if [ -z "$item" ]; then
      pause "$POLL_INTERVAL"
      continue
    fi

    logfile="$LOGS/$(date '+%Y%m%d-%H%M%S')-$item.log"
    wlog "starting item $item (log $logfile)"
    (cd "$WORKDIR" && ROADMAP_CLAIM_OWNER="$me" exec "$CLAUDE_BIN" -p "/roadmap-implementer $ROADMAP $item" \
      --dangerously-skip-permissions "${EXTRA_ARGS[@]}") > "$logfile" 2>&1 &
    child=$!
    wait "$child"
    code=$?
    child=""

    result="$(grep -o 'ROADMAP_IMPLEMENTER_STATUS: [A-Z]*' "$logfile" | tail -n 1 | cut -d ' ' -f 2)"
    wlog "item $item finished: ${result:-no status} (exit $code)"
    delay=0

    case "$result" in
      IDLE|LOCKED)
        delay="$POLL_INTERVAL"
        ;;
      *)
        # A run failed when the item is still pending or in-progress after it, whatever it printed.
        state="$("$BACKLOG" status "$ROADMAP" "$item")"
        if [ "$state" = pending ] || [ "$state" = in-progress ]; then
          failures=$((failures + 1))
          settled="$("$BACKLOG" fail "$ROADMAP" "$item" "$me" "${result:-no status} (exit $code), log $logfile")"
          wlog "item $item failed: ${settled:-not recorded}"
          case "$settled" in
            *blocked) delay="$FAILURE_BACKOFF" ;;
            *) delay=$(( POLL_INTERVAL < 60 * failures ? POLL_INTERVAL : 60 * failures )) ;;
          esac
        else
          failures=0
        fi
        ;;
    esac

    "$BACKLOG" unclaim "$ROADMAP" "$item" "$me"
    item=""
    [ "$delay" -gt 0 ] && pause "$delay"
  done
}

pids=()
shutdown() {
  trap '' INT TERM
  log "stopping"
  kill -TERM "${pids[@]}" 2>/dev/null
  wait
  exit 130
}
trap shutdown INT TERM

log "watching $ROADMAP (workdir $WORKDIR, $WORKERS worker(s), poll ${POLL_INTERVAL}s)"
for i in $(seq 1 "$WORKERS"); do
  worker "$i" &
  pids+=("$!")
done
wait
