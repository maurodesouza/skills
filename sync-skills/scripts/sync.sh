#!/usr/bin/env bash
# Syncs the skills of this repository into the global skills of Codex and Claude Code.
#
# Usage: sync.sh [--dry-run]
#
# Layout (the one used by the existing installs):
#   ~/.agents/skills/<name>   copy of the skill (Codex reads it)
#   ~/.claude/skills/<name>   symlink to ../../.agents/skills/<name> (Claude Code)
#
# Env (for tests):
#   SKILLS_SOURCE        repository with the skills (default: this script's repository)
#   AGENTS_SKILLS_DIR    default ~/.agents/skills
#   CLAUDE_SKILLS_DIR    default ~/.claude/skills

set -euo pipefail

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="${SKILLS_SOURCE:-$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$HOME/organizations/me/skills")}"
AGENTS_DIR="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"
CLAUDE_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
MANIFEST="$AGENTS_DIR/.skills-sync-manifest"

run() { if [ "$DRY_RUN" = 1 ]; then echo "  would: $*"; else "$@"; fi; }

# The installed copy of sync.sh may run this, so resolve the source repository explicitly.
[ -d "$SOURCE/.git" ] || [ -f "$SOURCE/.git" ] || { echo "error: $SOURCE is not the skills repository" >&2; exit 1; }

branch="$(git -C "$SOURCE" rev-parse --abbrev-ref HEAD)"
dirty="$(git -C "$SOURCE" status --porcelain | wc -l | tr -d ' ')"
echo "source: $SOURCE (branch $branch, $dirty uncommitted changes)"

# A skill is a top-level folder with a SKILL.md.
skills=()
for dir in "$SOURCE"/*/; do
  [ -f "$dir/SKILL.md" ] && skills+=("$(basename "$dir")")
done
[ "${#skills[@]}" -gt 0 ] || { echo "error: no skills found in $SOURCE" >&2; exit 1; }

run mkdir -p "$AGENTS_DIR" "$CLAUDE_DIR"

added=() updated=() unchanged=() removed=() claude_notes=()

for name in "${skills[@]}"; do
  target="$AGENTS_DIR/$name"
  if [ ! -e "$target" ]; then
    added+=("$name")
  elif [ -n "$(rsync -a --delete --dry-run --itemize-changes --exclude .git "$SOURCE/$name/" "$target/")" ]; then
    updated+=("$name")
  else
    unchanged+=("$name")
  fi
  run rsync -a --delete --exclude .git "$SOURCE/$name/" "$target/"

  link="$CLAUDE_DIR/$name"
  expected="../../.agents/skills/$name"
  [ "$AGENTS_DIR" = "$HOME/.agents/skills" ] && [ "$CLAUDE_DIR" = "$HOME/.claude/skills" ] || expected="$target"
  if [ -L "$link" ]; then
    [ "$(readlink "$link")" = "$expected" ] || { run ln -sfn "$expected" "$link"; claude_notes+=("$name: symlink repointed"); }
  elif [ -d "$link" ]; then
    # A real folder installed by something else: keep its type, only sync its content.
    run rsync -a --delete --exclude .git "$SOURCE/$name/" "$link/"
    claude_notes+=("$name: real folder, content synced")
  else
    run ln -s "$expected" "$link"
  fi
done

# Remove only skills this script installed before and that left the repository.
if [ -f "$MANIFEST" ]; then
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    printf '%s\n' "${skills[@]}" | grep -qxF "$name" && continue
    removed+=("$name")
    run rm -rf "${AGENTS_DIR:?}/$name"
    if [ -L "$CLAUDE_DIR/$name" ]; then
      run rm -f "$CLAUDE_DIR/$name"
    elif [ -d "$CLAUDE_DIR/$name" ]; then
      run rm -rf "${CLAUDE_DIR:?}/$name"
    fi
  done < "$MANIFEST"
fi

if [ "$DRY_RUN" = 0 ]; then
  printf '%s\n' "${skills[@]}" > "$MANIFEST"
fi

list() { [ "$#" -gt 0 ] && printf '%s, ' "$@" | sed 's/, $//' || printf -- '-'; }
echo "codex:  $AGENTS_DIR"
echo "claude: $CLAUDE_DIR"
echo "added (${#added[@]}): $(list "${added[@]}")"
echo "updated (${#updated[@]}): $(list "${updated[@]}")"
echo "removed (${#removed[@]}): $(list "${removed[@]}")"
echo "unchanged: ${#unchanged[@]}"
[ "${#claude_notes[@]}" -eq 0 ] || printf 'claude: %s\n' "${claude_notes[@]}"
[ "$DRY_RUN" = 1 ] && echo "dry run: nothing was changed"
exit 0
