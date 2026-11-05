# Skills

This repository is the set of AI agent skills I use in my development workflow.

They came out of my [AI Kanban App Lab](https://github.com/maurodesouza/ai-kanban-app-lab), where I built the same Kanban app many times with AI to understand how to work with it in a real workflow, with as little manual intervention as possible. After each lab I improved the skills, and now they live here so I can maintain them separately from the labs.

The skills follow the `SKILL.md` format, so they work with Claude Code (`.claude/skills`), Codex (`.agents/skills`) and other agents that support it.

## How it works

The main flow is two skills: the **Tech Lead** and the **Epic Implementer**.

The **Tech Lead** clarifies the request, reads the repository, plans one Epic with cohesive Issues and publishes them to GitHub. When planning is done, it hands the Epic straight to the **Epic Implementer**.

The **Epic Implementer** orchestrates the work: it reads the Epic, creates a worktree, implements each Issue, writes tests, reviews, commits, opens the pull request and merges it (unless `no-merge` is set).

Both are broken into small sub-skills with a single responsibility. This was the change that gave me the best code quality in the labs.

## Roadmap: feed ideas, let the agent build

On top of that flow, two skills split the work between me and an autonomous agent:

```text
me ─► roadmap ─► backlog ─► roadmap-implementer ─► tech-lead ─► epic-implementer
                    ▲                                                   │
                    └───────────────── next item ◄──────────────────────┘
```

* **`roadmap`** is the only part I talk to. I dump ideas (new projects, features, changes) and it organizes them into a backlog, asking only what is really ambiguous. That is the last time anyone asks me anything.
* **`roadmap-implementer`** consumes the backlog: it picks the next ready item, creates the project when it is a new one (private GitHub repository), calls the Tech Lead with the `autonomous` flag (no questions, assumptions written in the Epic) and records the result. An item that needs me is marked `blocked` with the reason, and the agent moves on.

The backlog is a `roadmap/` folder with its own git repository, one Markdown file per item (format in `roadmap/references/format.md`):

* Organization roadmap: `~/organizations/<org>/roadmap/`, covering every project of the organization, including projects that don't exist yet.
* Project roadmap: `<project>/roadmap/`, ignored by the project's own git.

### Running it 24h

A skill ends when its session ends, so a small script keeps it going. It starts a fresh Claude Code session for each ready item, and while nothing is ready it only reads the item files, without spending tokens:

```bash
# from the organization root, in tmux or with nohup
~/.claude/skills/roadmap-implementer/scripts/run.sh ./roadmap
```

New items added with `/roadmap` while it works are picked up on the next cycle. Per-run logs go to `roadmap/.logs/`. Options are environment variables: `ROADMAP_WORKERS` (items implemented in parallel, default 1), `ROADMAP_POLL_INTERVAL` (seconds, default 300), `ROADMAP_MAX_FAILURES` (failed runs before an item is blocked, default 3), `ROADMAP_FAILURE_BACKOFF`, `ROADMAP_CLAUDE_ARGS` and `CLAUDE_BIN`.

### Parallel runs

Several items can be implemented at the same time, on the same roadmap:

```bash
ROADMAP_WORKERS=4 ~/.claude/skills/roadmap-implementer/scripts/run.sh ./roadmap   # 4 items at once
```

Or by hand, one chat per item, also alongside the runner and alongside `/roadmap`:

```text
/roadmap-implementer          # next ready item
/roadmap-implementer 0007     # that item, if it is ready
```

Each run claims its own item (`roadmap/.claims/`) and only takes the backlog write lock (`roadmap/.lock`) for the few seconds it reads or commits roadmap files, never while planning or implementing. Each Epic is built in its own worktree, so the main checkout of every project stays free for testing. A run that dies (closed chat, crash) leaves its item `in-progress`; the next run returns it to `pending`. The lock and claims are handled by `roadmap/scripts/backlog.sh` and need `flock` (util-linux).

To run it as a `systemd --user` service (`~/.config/systemd/user/roadmap-fragiola.service`):

```ini
[Unit]
Description=Roadmap Implementer - fragiola

[Service]
WorkingDirectory=%h/organizations/fragiola
ExecStart=%h/.claude/skills/roadmap-implementer/scripts/run.sh %h/organizations/fragiola/roadmap
Restart=on-failure

[Install]
WantedBy=default.target
```

```bash
systemctl --user enable --now roadmap-fragiola   # start
journalctl --user -u roadmap-fragiola -f          # follow
systemctl --user stop roadmap-fragiola            # stop
```

> **Warning:** the runner starts Claude Code with `--dangerously-skip-permissions`, and the Epic Implementer merges its own pull requests. The agent has full access to the machine and to GitHub with your credentials, 24 hours a day. Run it only where that is acceptable, check `roadmap/.logs/` and the merged pull requests, and stop it with `Ctrl+C` (or `systemctl --user stop`) whenever you want: items being implemented go back to `pending` and the next start continues from the backlog.

## Architecture: the project first

The Tech Lead and the Epic Implementer don't impose an architecture.

Before planning or implementing, `project-architecture` identifies the project type (React app, library, back-end or other) and checks if the project already has its own architecture, structure or rules:

* **The project already has an architecture:** follow it. Nothing is migrated unless I ask for it.
* **New project, no architecture yet:** use the opinion skills for that project type.

My opinions are still here, but they are only applied where they fit. A library or a back-end never gets the React app architecture.

| Project type | Opinion skills |
| --- | --- |
| React app | `command-bus-architecture`, `command-handle-implementation`, `setup-command-system`, `fragiola-ui`, `utils-implementation` |
| Library | `utils-implementation` (no library architecture skill yet) |
| Back-end | `utils-implementation` (no back-end architecture skill yet) |

## Skills

<details>
<summary>Planning</summary>

| Skill | What it does |
| --- | --- |
| `tech-lead` | Turns the request into an Epic and Issues and starts the Epic Implementer (`no-implement` stops after planning, `autonomous` never asks) |
| `tech-lead-publish` | Publishes the Epic and its Issues to GitHub, linked and labeled |
| `clarify-first` | Asks only the questions the request and the context don't already answer (always in Portuguese) |
| `project-architecture` | Identifies the project type and its architecture, and selects the opinion skills when there is none |

</details>

<details>
<summary>Roadmap</summary>

| Skill | What it does |
| --- | --- |
| `roadmap` | Turns free-form ideas into a versioned backlog for an organization or a project |
| `roadmap-implementer` | Executes the next ready item autonomously (project creation, Tech Lead, Epic Implementer) and records the result; `scripts/run.sh` keeps it running |
| `roadmap-next-item` | Selects the next ready item by status, dependencies and order |
| `roadmap-create-project` | Creates the folder and the private GitHub repository of a new project |

</details>

<details>
<summary>Implementation</summary>

| Skill | What it does |
| --- | --- |
| `epic-implementer` | Orchestrates the whole Epic, from reading it to merging the pull request |
| `epic-read` | Reads the Epic and its Issues |
| `epic-discover-repository` | Reports the stack, scripts, structure and existing patterns |
| `epic-repository-rules` | Collects the project conventions and resolves the language of its records, from the rule files and the recent history |
| `epic-current-documentation` | Checks the current docs before using any tool or dependency |
| `epic-plan-execution` | Maps each Issue to the architecture and orders the work |
| `epic-handle-dependent-work` | Resolves the order of the Issues from their dependencies |
| `epic-worktree` | Creates the Epic worktree and branch |
| `epic-execution` | Implements, tests, reviews and commits one Issue |
| `epic-commit-progressively` | Creates atomic commits with emoji messages |
| `epic-pull-request` | Pushes the branch and opens the pull request |
| `epic-merge` | Verifies the gates and merges |
| `epic-cleanup` | Deletes the branches and the worktree after the merge |

</details>

<details>
<summary>Quality</summary>

| Skill | What it does |
| --- | --- |
| `reviewer` | Reviews the changes against the requirements, the architecture and the conventions |
| `test-writer` | Writes tests for the current implementation |

</details>

<details>
<summary>Opinions (React app)</summary>

| Skill | What it does |
| --- | --- |
| `command-bus-architecture` | Every interaction is a Command Bus action, MobX stores only have state, setters and `$` derived values, all logic lives in Handles, components only read and present, and there is one modal for the whole app |
| `command-handle-implementation` | How Handles are written and registered |
| `setup-command-system` | Installs the Command Bus |
| `fragiola-ui` | Every interface is built with Fragiola UI, with headless parts assembled explicitly |
| `utils-implementation` | A util must earn its existence: no wrappers of one native operation, one namespace per domain |

`command-bus-architecture` also has a small script (`scripts/check-architecture.mjs`) that checks the main rules in seconds, without running a full lab.

</details>

## Usage

Copy the skills you want into your project (`.claude/skills` for Claude Code, `.agents/skills` for Codex), or into your user skills folder to use them everywhere.

To keep the global skills in sync with this repository, run `/sync-skills` (or `sync-skills/scripts/sync.sh`, `--dry-run` to preview). It copies every skill to `~/.agents/skills` (Codex) and links it in `~/.claude/skills` (Claude Code), removes skills deleted from the repository and never touches skills installed from other sources.

Then start with the Tech Lead:

```text
/tech-lead <what you want to build>
```

Or feed the roadmap and let the runner do the rest:

```text
/roadmap <ideas, projects, features, changes>
```

## Notes

* The library and back-end profiles don't have their own opinion skills yet. For now they only follow the defaults in `project-architecture/references/`.
* The skills are written in English, but `clarify-first` asks its questions in Portuguese, because that is how I work.
* Commits, pull requests, issues and documentation never follow the language of the conversation. `epic-repository-rules` reads the rule files and the last 20 commits, pull requests and issues, and those records follow the language and conventions established there. Without a pattern, they are in English.
