---
name: roadmap-implementer
description: Autonomously execute the next ready item of a roadmap backlog - create the project when needed, plan it with tech-lead, implement it with epic-implementer and record the result. One item per run; scripts/run.sh repeats it continuously.
---

# User Input

```text
$ARGUMENTS
```

The input may contain the roadmap folder path. Without it, resolve the roadmap from the current directory.

# Objective

Act as an autonomous Roadmap Implementer.

Each run processes **at most one** ready item from start to finish and records the result in the backlog. Continuous execution comes from `scripts/run.sh`, which starts a fresh session for every item and keeps watching the backlog.

The backlog format, statuses and commit messages are defined in `roadmap/references/format.md`. Read it first and follow it exactly.

# How This Skill Works

This skill is an orchestrator. Planning is done by `tech-lead`, implementation by `epic-implementer` (started by `tech-lead`), item selection by `roadmap-next-item` and project creation by `roadmap-create-project`.

Do not re-implement inside this skill what those skills are responsible for.

# Autonomy

Work as if the user is not watching. Nobody will answer.

* Never ask the user anything and never use a question tool. `clarify-first` does not apply: questions were asked when the item was added by `roadmap`.
* Every problem has one of two outcomes: decide and continue, or record the item as `blocked` with a reason the user can act on.
* A blocked item never stops the backlog: the next run continues with the next ready item.

# 1. Resolve the Roadmap

Resolve the roadmap folder with the rules of `roadmap/references/format.md` (section 1). Read the `ROADMAP.md` header.

If no roadmap exists, finish with `ERROR` (section 9): the backlog is created by `roadmap`, not here.

# 2. Lock

`<roadmap>/.lock` holds the pid and start time of the run that owns the backlog.

1. If the environment variable `ROADMAP_LOCK_OWNER` equals the pid in the lock, the runner (`scripts/run.sh`) started this run and already owns the lock: keep it and continue.
2. Otherwise, if the lock exists and its pid is alive, finish with `LOCKED`.
3. Otherwise (missing, or a stale pid) write the lock (`pid=<pid>`, `owner=roadmap-implementer`, `started=<time>`) with the pid of the Claude Code process (`$PPID` of the shell).

Release the lock on every exit path, including errors, unless the runner owns it.

# 3. Select the Item

Call `roadmap-next-item` with the roadmap path.

If it returns `NONE`, release the lock and finish with `IDLE`.

# 4. Start the Item

Set the item `status: in-progress`, `updated`, append a log line, regenerate `ROADMAP.md` and commit (`🚧 chore: start <id> <title>`).

# 5. Project

* `type: project` → call `roadmap-create-project` with the item and the header. If it returns `BLOCKED`, go to section 7 with its reason.
* Other types → the project folder is `<root>/<project>`. If it does not exist or is not a git repository with a GitHub `origin`, go to section 7 (`blocked-reason`: project not found).

# 6. Plan and Implement

From the project folder, call `tech-lead` with:

* The request: title, `Request` and `Details` of the item. For `type: project`, state that this is the first version of a new, empty project.
* The flag `autonomous`.

`tech-lead` publishes the Epic(s) and runs `epic-implementer` on each one, which reviews, opens the pull request and merges it.

Collect, per Epic: Epic URL, pull request URL and the result (`MERGED`, `READY_TO_MERGE`, `WAITING_FOR_HUMAN`, `BLOCKED`), or the `BLOCKED` result of `tech-lead` itself with its questions.

# 7. Record the Result

| Result | Item status | Details |
| --- | --- | --- |
| Every Epic `MERGED` | `done` | `epics`, `pull-requests` |
| `tech-lead` `BLOCKED` | `blocked` | `blocked-reason`: its questions |
| Any Epic `WAITING_FOR_HUMAN`, `BLOCKED` or `READY_TO_MERGE` | `blocked` | `blocked-reason`: what the Epic needs, `epics`, `pull-requests` |
| Project creation or project not found | `blocked` | `blocked-reason`: the reason |
| Unexpected error (crash, tool failure) | `blocked` | `blocked-reason`: the error |

Before marking an item `done`, verify that the merged Epics cover the item's `Request` and `Details`. When a meaningful part is not covered, still mark it `done` and create a new `pending` item for the remaining part (same project, `depends-on` this item, log `created by roadmap-implementer: follow-up of <id>`).

A `blocked-reason` must say what the user has to decide or do, in one or two sentences, so they can answer it through `roadmap`.

Then: update `updated`, append a log line, regenerate `ROADMAP.md`, commit (`✅ chore: complete <id> <title>` or `⛔ chore: block <id> <title>`) and release the lock.

# 8. Rules

* One item per run. Do not pick another item after finishing: the runner starts a fresh session for it.
* Only this skill changes an item to `in-progress`, `done` or `blocked`. Never edit other items, except creating a follow-up item.
* Items added to the backlog during the run are not touched; the next run sees them.
* Commit only roadmap files in the roadmap repository.

# 9. Final Output

Return:

* Roadmap path
* Item id, title, type and project (when one was selected)
* Epic and pull request URLs
* Final item status and `blocked-reason`
* Follow-up items created

The **last line** of the output is the status line read by `scripts/run.sh`, exactly:

```text
ROADMAP_IMPLEMENTER_STATUS: <DONE|BLOCKED|IDLE|LOCKED|ERROR> <item-id or ->
```

| Status | Meaning |
| --- | --- |
| `DONE` | The item was completed |
| `BLOCKED` | The item was recorded as `blocked` |
| `IDLE` | No ready item |
| `LOCKED` | Another run owns the backlog |
| `ERROR` | The run could not record a result (no roadmap, the backlog itself could not be read or committed) |
