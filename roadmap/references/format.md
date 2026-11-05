# Roadmap Format

The single source of truth for the backlog shared by `roadmap` (writes items) and `roadmap-implementer` (consumes them). Neither skill redefines it.

# 1. Location

A roadmap is a `roadmap/` folder that is its own git repository.

| Scope | Where | When |
| --- | --- | --- |
| `organization` | `~/organizations/<org>/roadmap/` | The current directory is an organization root: a folder whose children are project repositories, and that is not a git repository itself |
| `project` | `<project>/roadmap/` | The current directory is inside a project repository (`git rev-parse --show-toplevel` succeeds and is not a `roadmap/` folder) |

Resolution order:

1. An explicit path in the input (`roadmap/` folder, its parent, or the `ROADMAP.md` file).
2. The current directory is a `roadmap/` folder → use it.
3. Organization root → `<org>/roadmap/`.
4. Inside a project → `<project-root>/roadmap/`.

In `project` scope, `roadmap/` lives inside the project repository but keeps its own git repository: add `roadmap/` to the project's `.git/info/exclude` so the backlog never enters the project's commits or pull requests.

# 2. Layout

```text
roadmap/
├── .git/
├── .gitignore        # .logs/, .lock and .claims/
├── ROADMAP.md        # header + index (derived from items/)
└── items/
    ├── 0001-create-draggable.md
    └── 0002-data-grid-column-pinning.md
```

* `items/<id>-<slug>.md`: one file per item. `<id>` is a 4-digit sequence (next = highest existing id + 1). `<slug>` is kebab-case from the title. Ids are never reused.
* `.logs/` (run logs), `.lock` (write lock) and `.claims/` (one file per item a run is working on) are runtime state managed by `scripts/backlog.sh` and `roadmap-implementer/scripts/run.sh`, and are never committed. `backlog.sh` also adds `.claims/` to the repository's `.git/info/exclude` for roadmaps created before it existed.

# 3. ROADMAP.md

```markdown
---
scope: organization            # organization | project
name: fragiola                 # organization or project folder name
root: ~/organizations/fragiola # organization root (organization) or project root (project)
github-owner: fragiola         # owner of new repositories
visibility: private            # visibility of new repositories
---

# Roadmap - fragiola

<!-- Generated from items/. Edit the items, not this index. -->

## Pending

### data-grid

- [ ] 0002 Column pinning (feature)

### draggable

- [ ] 0001 Create Draggable (project)

## In Progress

## Blocked

- 0004 ... - <blocked-reason>

## Done

- [x] 0003 ... - <pull request URL>
```

The header is the only hand-maintained part. Everything below it is regenerated from `items/` after every change: grouped by status (`Pending`, `In Progress`, `Blocked`, `Done`), then by `project` inside `Pending`, ordered by `order` then `id`. Empty sections stay as headings.

# 4. Item

```markdown
---
id: "0002"
title: Column pinning
type: feature            # project | feature | change | epic
project: data-grid       # project folder name; for type: project, the project to create
topic: data-grid         # grouping for the user (defaults to project)
status: pending          # pending | in-progress | done | blocked
order: 20                # lower runs first; gaps of 10 allow re-prioritizing
depends-on: []           # item ids, e.g. ["0001"]
created: 2026-11-02
updated: 2026-11-02
epics: []                # filled by roadmap-implementer: Epic URLs
pull-requests: []        # filled by roadmap-implementer: PR URLs
blocked-reason: ""       # filled by roadmap-implementer when blocked
---

## Request

What the user asked, in their own words.

## Details

Everything clarified at intake: expected behavior, constraints, decisions, examples. This is what `tech-lead` receives, so it must be enough to plan without asking.

## Log

- 2026-11-02 created by roadmap
```

| Type | Meaning |
| --- | --- |
| `project` | Create a new project (folder + repository) and build its first version |
| `feature` | New functionality in an existing project |
| `change` | Change, fix or refactor in an existing project |
| `epic` | A large initiative in one project, already described as one deliverable unit |

In `project` scope, `project` is always the project's own folder name.

# 5. Lifecycle

```text
pending ──► in-progress ──► done
                 │
                 └────────► blocked ──► pending (only when the user unblocks it, via roadmap)
```

| Transition | Who | Writes |
| --- | --- | --- |
| create → `pending` | `roadmap` | the item |
| `pending` → `in-progress` | `roadmap-implementer` | `updated`, log line |
| `in-progress` → `done` | `roadmap-implementer` | `epics`, `pull-requests`, log line |
| `in-progress` → `blocked` | `roadmap-implementer` | `blocked-reason`, `epics`/`pull-requests` when they exist, log line |
| `blocked` → `pending` | `roadmap` | clears `blocked-reason`, adds the user's answer to `Details`, log line |

Rules:

* `roadmap` never edits an `in-progress` item. A change to it becomes a new item with `depends-on` the in-progress one.
* `roadmap` may edit, re-order or delete `pending` and `blocked` items. Deleting removes the file.
* `done` items are history: never edited, never deleted.
* An item is **ready** when it is `pending`, every `depends-on` item is `done` and it has no live claim (section 7). An item whose dependency is `blocked` or missing is not ready; it stays `pending`.
* `backlog.sh` records runs that ended without a result: the item goes back to `pending` with a `run failed (n/max)` log line, and to `blocked` after `ROADMAP_MAX_FAILURES` (default 3) failures since it was last unblocked.

# 6. Language and Commits

Backlog records (item titles and text, `blocked-reason`, log lines, commit messages) follow the language already established in the roadmap repository (its items and recent commits, last 20). When there is no pattern, they are in English. The language the user writes in is never a signal; the only exception is `Request`, which keeps the user's words verbatim.

Every change to the roadmap is committed in the roadmap repository, with the repository commit style:

```text
📝 docs: add 0005 data grid column pinning
🚧 chore: start 0002 column pinning
✅ chore: complete 0002 column pinning
⛔ chore: block 0002 column pinning
```

Regenerate `ROADMAP.md` before every commit. Commit only roadmap files, only under the write lock (section 7), staging only the files the run changed.

The commits of `backlog.sh` (`♻️ chore: retry <id> after a failed run`, `♻️ chore: requeue <id> after a stopped run`, `⛔ chore: block <id> after failed runs`) change only the item: the next write of `roadmap` or `roadmap-implementer` regenerates `ROADMAP.md`.

# 7. Parallel Runs

Several runs can work on one roadmap at the same time: chats running `roadmap` or `roadmap-implementer`, and the workers of `run.sh` (`ROADMAP_WORKERS`). Two mechanisms keep them apart, both handled by `scripts/backlog.sh`:

| Mechanism | What | Held |
| --- | --- | --- |
| Write lock | `.lock`: pid of the process writing the backlog (`flock`-guarded) | Only while reading and writing items, regenerating `ROADMAP.md` and committing. Never while planning or implementing |
| Claim | `.claims/<id>`: pid of the process working on that item | From the moment the item is selected until its result is recorded |

Rules:

* Take the lock before selecting an item or writing any roadmap file, release it right after the commit, on every exit path. A lock whose process died, or older than `ROADMAP_LOCK_TTL` (default 15 min), is taken over.
* Claim an item under the lock before starting it. Nobody else selects, edits or records a claimed item.
* A claim whose process died marks an abandoned item: `backlog.sh recover` returns its `in-progress` item to `pending` (counted as a failed run).
* `<pid>` is the pid of the Claude Code process (`$PPID` of the shell), or of the `run.sh` worker that claimed the item (exported to its session as `ROADMAP_CLAIM_OWNER`).
