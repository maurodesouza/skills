---
name: roadmap-implementer
description: Autonomously execute the next ready item of a roadmap backlog - create the project when needed, plan it with tech-lead, implement it with epic-implementer and record the result. One item per run; scripts/run.sh repeats it continuously.
---

# User Input

```text
$ARGUMENTS
```

The input may contain the roadmap folder path and an item id (for example `0003`). Without a path, resolve the roadmap from the current directory. Without an id, the next ready item is selected.

# Objective

Act as an autonomous Roadmap Implementer.

Each run processes **at most one** item from start to finish and records the result in the backlog. Continuous execution comes from `scripts/run.sh`, which starts a fresh session for every item and keeps watching the backlog.

Several runs may work on the same roadmap at the same time (chats started by the user and `run.sh` workers), each on its own item. The backlog is only touched inside short sections under the write lock, and each run owns its item through a claim (`roadmap/references/format.md`, section 7).

The backlog format, statuses and commit messages are defined in `roadmap/references/format.md`. Read it first and follow it exactly.

# How This Skill Works

This skill is an orchestrator. Planning is done by `tech-lead`, implementation by `epic-implementer` (started by `tech-lead`), item selection by `roadmap-next-item` and project creation by `roadmap-create-project`.

Do not re-implement inside this skill what those skills are responsible for.

Lock, claims and recovery go through `backlog.sh`, in the `scripts/` folder of the `roadmap` skill (installed next to this skill: `../roadmap/scripts/backlog.sh` from this skill's folder). Below, `<pid>` is the pid of the Claude Code process: `$PPID` of the shell.

# Autonomy

Work as if the user is not watching. Nobody will answer.

* Never ask the user anything and never use a question tool. `clarify-first` does not apply: questions were asked when the item was added by `roadmap`.
* Every problem has one of two outcomes: decide and continue, or record the item as `blocked` with a reason the user can act on.
* A blocked item never stops the backlog: the next run continues with the next ready item.

# 1. Resolve the Roadmap

Resolve the roadmap folder with the rules of `roadmap/references/format.md` (section 1). Read the `ROADMAP.md` header.

If no roadmap exists, finish with `ERROR` (section 9): the backlog is created by `roadmap`, not here.

# 2. Lock and Recover

1. `backlog.sh lock <roadmap> <pid> roadmap-implementer`. It waits while another run is writing to the backlog. If it fails (timeout), finish with `LOCKED`.
2. `backlog.sh recover <roadmap> <pid>`: items left `in-progress` by a run that died go back to `pending`, or to `blocked` after repeated failures. Never touch an `in-progress` item that has a live claim: another run is working on it.

The lock is held only while reading or writing the backlog (sections 2-4 and section 7), never while planning or implementing. Release it with `backlog.sh unlock <roadmap> <pid>` on every exit path, including errors, as soon as the commit of that section is done.

# 3. Select and Claim the Item

Call `roadmap-next-item` with the roadmap path and the item id from the input, when there is one.

If it returns `NONE`, release the lock and finish with `IDLE` (with an id, report why that item is not ready).

Claim the selected item: `backlog.sh claim <roadmap> <id> <pid>`.

* When the environment variable `ROADMAP_CLAIM_OWNER` is set and the item claim already holds that pid, the runner (`scripts/run.sh`) claimed it for this run: keep that claim and do not claim it again.
* If the claim fails (another live run holds it), release the lock and finish with `IDLE`.

From here on, remove the claim on every exit path (`backlog.sh unclaim <roadmap> <id>`), after recording the result.

# 4. Start the Item

Set the item `status: in-progress`, `updated`, append a log line, regenerate `ROADMAP.md`, commit (`🚧 chore: start <id> <title>`) and release the lock.

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

Decide the result first, without the lock:

| Result | Item status | Details |
| --- | --- | --- |
| Every Epic `MERGED` | `done` | `epics`, `pull-requests` |
| `tech-lead` `BLOCKED` | `blocked` | `blocked-reason`: its questions |
| Any Epic `WAITING_FOR_HUMAN`, `BLOCKED` or `READY_TO_MERGE` | `blocked` | `blocked-reason`: what the Epic needs, `epics`, `pull-requests` |
| Project creation or project not found | `blocked` | `blocked-reason`: the reason |
| Unexpected error (crash, tool failure) | `blocked` | `blocked-reason`: the error |

Before marking an item `done`, verify that the merged Epics cover the item's `Request` and `Details`. When a meaningful part is not covered, still mark it `done` and create a new `pending` item for the remaining part (same project, `depends-on` this item, log `created by roadmap-implementer: follow-up of <id>`).

A `blocked-reason` must say what the user has to decide or do, in one or two sentences, so they can answer it through `roadmap`.

Then write it under the lock (`backlog.sh lock <roadmap> <pid> roadmap-implementer`; on timeout keep retrying: the result must be recorded): re-read the item, set the status and details, create the follow-up item (next free id read under the lock), update `updated`, append a log line, regenerate `ROADMAP.md` from the current `items/` (other runs may have changed other items meanwhile), commit (`✅ chore: complete <id> <title>` or `⛔ chore: block <id> <title>`), remove the claim and release the lock.

# 8. Rules

* One item per run. Do not pick another item after finishing: the runner starts a fresh session for it.
* Only this skill changes an item to `in-progress`, `done` or `blocked` (besides the failed-run recovery of `backlog.sh`). Never edit other items, except creating a follow-up item.
* Items added to the backlog during the run are not touched; the next run sees them.
* Commit only roadmap files in the roadmap repository, and only while holding the lock. Stage only the files this run changed (the item, follow-up items and `ROADMAP.md`).
* Never hold the lock while planning or implementing, and never edit, start or record an item claimed by another live run.

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
| `LOCKED` | The backlog write lock could not be taken in time |
| `ERROR` | The run could not record a result (no roadmap, the backlog itself could not be read or committed) |
