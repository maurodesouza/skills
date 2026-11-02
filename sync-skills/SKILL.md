---
name: sync-skills
description: Sync the skills of the ~/organizations/me/skills repository into the global skills of Codex (~/.agents/skills) and Claude Code (~/.claude/skills). Use for "sync skills", "/sync-skills", or after changing skills in the repository.
---

# User Input

```text
$ARGUMENTS
```

# Flags

* `dry-run` (also accepted: `--dry-run`): show what would change without changing anything.

# Objective

Keep the global skills of Codex and Claude Code identical to the skills repository, so skills are only edited in one place.

The repository is the source of truth. Do not edit skills in the global folders.

# 1. Source

The source is the repository `~/organizations/me/skills`. Every top-level folder with a `SKILL.md` is a skill.

Before syncing, check its state (`git -C ~/organizations/me/skills status` and current branch):

* Not on `main`, or with uncommitted changes: the sync installs exactly what is in the working tree. Mention it in the output; do not stop.
* Behind `origin/main` with a clean working tree: `git pull --ff-only` first, so merged skills are installed.

# 2. Sync

Run the script of this skill, from the repository copy:

```bash
~/organizations/me/skills/sync-skills/scripts/sync.sh          # sync
~/organizations/me/skills/sync-skills/scripts/sync.sh --dry-run # preview
```

The script:

| Target | What it does |
| --- | --- |
| `~/.agents/skills/<name>` | Copy of the skill (`rsync --delete`), read by Codex |
| `~/.claude/skills/<name>` | Symlink to `../../.agents/skills/<name>`, read by Claude Code. A real folder that already exists is kept as a folder and only its content is synced |
| `~/.agents/skills/.skills-sync-manifest` | Skills installed by the last sync, used to remove the ones deleted from the repository |

Skills installed from other sources (caveman, hyperframes, ...) are never touched: only names from the repository or from the manifest are changed.

# 3. Final Output

Report in Portuguese, from the script output:

* Source branch and uncommitted changes
* Skills added, updated and removed
* Number of unchanged skills
* Claude Code notes (repointed symlinks, real folders)
* That a new session is needed for added or removed skills to show up

Stop after the report.
