---
name: roadmap
description: Turn free-form ideas (new projects, features, changes, epics) into a structured, versioned backlog at the root of an organization or inside a project, ready for roadmap-implementer to execute autonomously.
---

# User Input

```text
$ARGUMENTS
```

The input contains ideas in any shape: projects to create, features, changes, priorities, items to cancel or unblock. It may also contain an explicit roadmap path.

# Objective

Keep the backlog organized so the user only has to describe what they want.

This skill writes the backlog. It does not plan Epics, write code or create repositories: `roadmap-implementer` consumes the backlog autonomously.

Because `roadmap-implementer` never asks questions, this is the **only** moment where the user is asked anything. Every item written here must be executable without further input.

The backlog format, layout, statuses and commit messages are defined in `references/format.md`. Read it first and follow it exactly.

# 1. Resolve the Roadmap

Resolve the roadmap folder with the rules of `references/format.md` (section 1).

If the folder does not exist, or exists without `ROADMAP.md`:

1. Create `roadmap/`, `roadmap/items/` and `roadmap/.gitignore` (`.logs/`, `.lock`, `.claims/`).
2. `git init` when it is not a git repository yet.
3. In `project` scope, add `roadmap/` to the project's `.git/info/exclude`.
4. Write the `ROADMAP.md` header:
   * `scope`, `name`, `root` from the resolution.
   * `github-owner`: the owner shared by the `origin` remotes of the organization's projects (or of the project). Ignore clones of third-party repositories (owners used by a single folder when another owner dominates). When it cannot be derived, ask it in step 3.
   * `visibility: private`.

# 2. Read the Context

1. Read `ROADMAP.md` and every item in `items/`.
2. List the projects that exist: in `organization` scope, the folders of the organization root that are git repositories; in `project` scope, the project itself.
3. For each project the input mentions, read its README and manifest briefly, only enough to understand what it is.

# 3. Interpret the Input

Split the input into items. For each one decide:

| Field | How |
| --- | --- |
| `type` | `project` for "create a project/app/lib called X"; `feature` for new functionality in an existing project; `change` for changes, fixes, refactors; `epic` when the user describes a large initiative as one unit |
| `project` | Match the names the user uses to the existing folders ("Data Grid" → `data-grid`). An unknown name with "create" is a new project (kebab-case folder name). An unknown name without "create" is an ambiguity |
| `topic` | The project, unless the user groups things differently |
| `depends-on` | Only obvious needs: a feature of a project that is being created depends on that project item; a change described as "after X" depends on X. Do not invent dependencies |
| `order` | Order of the input, appended after the existing pending items, in steps of 10. Explicit priorities from the user ("first", "urgent", "after the rest") win |

Then compare with the existing items:

* Same intent as an existing `pending` or `blocked` item → update that item (merge the details), do not create a duplicate.
* Same intent as an `in-progress` item, or a `pending` item with a live claim (`scripts/backlog.sh claims <roadmap>`: a run is about to start it) → create a new item that depends on it (never edit it).
* Same intent as a `done` item → a new item only if the user asks for something beyond what was done.
* Requests to cancel, re-prioritize or answer a blocked item → apply them to the existing items (`references/format.md`, section 5).

# 4. Clarify

Call `clarify-first` with the interpreted items and the roadmap context.

Typical real ambiguities: an unknown project name, two existing projects that could match, a feature whose expected behavior changes what gets built, a new project whose type (app, library, back-end) cannot be inferred.

Do not ask about planning or implementation details: `tech-lead` decides them. When there is no real ambiguity, do not ask anything.

# 5. Write the Items

`roadmap-implementer` runs may be working on the same roadmap right now. Write only under the backlog write lock (`references/format.md`, section 7):

1. `scripts/backlog.sh lock <roadmap> $PPID roadmap` (the script is in this skill's folder).
2. Re-read the items you are about to change and the claims: an item that became `in-progress` or claimed since step 2 is no longer edited (apply the rule of step 3). Read the next free id now.
3. Write, index and commit (this section and section 6), then `scripts/backlog.sh unlock <roadmap> $PPID`, also when something fails.

For each new or changed item:

1. Write `items/<id>-<slug>.md` with the frontmatter and sections of `references/format.md` (section 4).
2. `Request`: the user's words for that item, verbatim. Every other part of the item, including its `title`, follows the language rule of `references/format.md` (section 6).
3. `Details`: everything clarified or inferred, written so `tech-lead` can plan without asking (expected behavior, constraints, the project type for a new project, answers given in step 4).
4. Append a `Log` line (`created by roadmap`, `updated by roadmap: <what>`, `unblocked by roadmap: <answer>`).

# 6. Index and Commit

1. Regenerate `ROADMAP.md` below the header (`references/format.md`, section 3).
2. Commit in the roadmap repository, one commit per input, with the commit style of `references/format.md` (section 6). Stage only the files this run changed.
3. Release the lock.

# 7. Final Output

Respond to the user in Portuguese with:

* Roadmap path and scope
* Items created, updated, removed or unblocked (id, title, type, project, status, dependencies)
* Assumptions made in step 3
* The ready items, in the order `roadmap-implementer` will pick them

Stop here. Execution is done by `roadmap-implementer`, not by this skill.
