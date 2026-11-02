---
name: epic-discover-repository
description: Inspect the repository and return its stack, structure, scripts and current architecture. Sub-skill of epic-implementer.
---

# User Input

```text
$ARGUMENTS
```

# Objective

Build an accurate picture of the repository before any code is changed.

This skill only reads. It does not modify files.

# 1. Stack

Identify:

* Language and framework (and versions from the manifest / lockfile)
* Package manager
* Router, styling, state management, data fetching
* Test framework
* Lint / format tooling
* Path aliases (`tsconfig.json`)

# 2. Scripts

List the commands for:

* dev
* build
* test
* lint
* typecheck
* format

Only report scripts that actually exist.

# 3. Structure

Map the main directories and what lives in each (`src/features`, `src/components`, `src/lib`, `src/hooks`, etc.).

# 4. Project Type and Architecture Signals

Report the facts `project-architecture` needs (it decides; this skill only reports):

* Project type signals: app entry (`index.html`, routes), library signals (`exports` / `main` / `peerDependencies`, library build), back-end signals (server framework, ORM, server entry), or none (empty / template only).
* Architecture documentation: `docs/`, ADRs, architecture sections in `README.md` / `AGENTS.md` / `CLAUDE.md`.
* How existing features are organized, and whether the organization is consistent.
* Known opinion patterns already in use, if any: Command Bus (`src/lib/command/` with `command-bus.ts`, `index.ts`, `global.ts`, `types.ts`; `*-handle.tsx`, `*-actions.ts`), MobX stores (`mobx`, `mobx-react-lite`), Fragiola UI (`components.json` with the `@fragiola` registry, installed components).

Skills installed in `.claude/skills`, `.agents/skills` or `.codex/skills` are agent tooling, not project architecture.

# 5. Existing Patterns

Find 1-3 representative examples of existing code for each layer the project has (e.g. route, service, component, store, Handle, test) so later steps can imitate them.

# 6. Final Output

Return:

* Stack summary
* Available scripts (exact commands)
* Directory map
* Project type signals
* Architecture documentation and organization of existing features (consistent or not)
* Opinion patterns in use: Command Bus, MobX, Fragiola UI (`INSTALLED` / `NOT_INSTALLED` / `PARTIAL`, with details)
* Reference files for each layer (paths)

Return this output to the calling skill and continue its flow. Do not end the run here unless this skill was invoked directly by the user.
