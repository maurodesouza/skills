# Skills

This repository is the set of AI agent skills I use in my development workflow.

They came out of my [AI Kanban App Lab](https://github.com/maurodesouza/ai-kanban-app-lab), where I built the same Kanban app many times with AI to understand how to work with it in a real workflow, with as little manual intervention as possible. After each lab I improved the skills, and now they live here so I can maintain them separately from the labs.

The skills follow the `SKILL.md` format, so they work with Claude Code (`.claude/skills`), Codex (`.agents/skills`) and other agents that support it.

## How it works

The main flow is two skills: the **Tech Lead** and the **Epic Implementer**.

The **Tech Lead** clarifies the request, reads the repository, plans one Epic with cohesive Issues and publishes them to GitHub. When planning is done, it hands the Epic straight to the **Epic Implementer**.

The **Epic Implementer** orchestrates the work: it reads the Epic, creates a worktree, implements each Issue, writes tests, reviews, commits, opens the pull request and merges it (unless `no-merge` is set).

Both are broken into small sub-skills with a single responsibility. This was the change that gave me the best code quality in the labs.

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
| `tech-lead` | Turns the request into an Epic and Issues and starts the Epic Implementer (`no-implement` stops after planning) |
| `tech-lead-publish` | Publishes the Epic and its Issues to GitHub, linked and labeled |
| `clarify-first` | Asks only the questions the request and the context don't already answer (always in Portuguese) |
| `project-architecture` | Identifies the project type and its architecture, and selects the opinion skills when there is none |

</details>

<details>
<summary>Implementation</summary>

| Skill | What it does |
| --- | --- |
| `epic-implementer` | Orchestrates the whole Epic, from reading it to merging the pull request |
| `epic-read` | Reads the Epic and its Issues |
| `epic-discover-repository` | Reports the stack, scripts, structure and existing patterns |
| `epic-repository-rules` | Collects the project conventions |
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

Then start with the Tech Lead:

```text
/tech-lead <what you want to build>
```

## Notes

* The library and back-end profiles don't have their own opinion skills yet. For now they only follow the defaults in `project-architecture/references/`.
* The skills are written in English, but `clarify-first` asks its questions in Portuguese, because that is how I work.
