---
name: fragiola-ecosystem
description: Load the Fragiola ecosystem guidelines (what Fragiola is, core + adapters, the model API with its command bus and run/can/check/get/is verbs, headless primitives and composition, library integration, repository template and source layout - kebab-case files, folders by responsibility -, docs site export). Use before planning, implementing, documenting or reviewing anything in a Fragiola project (~/organizations/fragiola/*, @fragiola/* packages, fragiola.com), and when starting a new Fragiola library, app or feature.
---

# User Input

```text
$ARGUMENTS
```

# Objective

Give the agent the ecosystem's shared context so the user never has to explain Fragiola again.
The knowledge lives in the guidelines folder, not in this skill; this skill only says how to load it.

# 1. Source

* Guidelines: `~/organizations/fragiola/guidelines/` (index: `README.md`).
* Reference implementation: `~/organizations/fragiola/dockable` (`AGENTS.md`, `site/docs/concepts/`).
* If the guidelines folder does not exist, read `~/organizations/fragiola/dockable/AGENTS.md` and
  `~/organizations/fragiola/www/CONTRACT.md` instead, and say the guidelines are missing.

# 2. Load

1. Read `README.md` and `ecosystem.md` always.
2. From the README's table, read only the pages the task needs. A topic named in the input
   (`docs`, `primitives`, `integration`, ...) selects its page.
3. When a page points to a Dockable (or other project) file for detail, read that file before
   writing code that depends on it.

# 3. Apply

* The current project's own `AGENTS.md` wins for that project. The guidelines win for anything
  the project has not decided yet (a new library, a new package, a new feature).
* A library follows the library pages; a React app follows `command-bus-architecture` and
  `fragiola-ui` (through `project-architecture`), plus the ecosystem principles.
* Every source file follows `repository.md#source-layout`, whatever the task: kebab-case names,
  and folders by responsibility (never a flat `src/`). Read that section before creating, naming
  or moving a file. Code listed as drift in `decisions.md` is not a precedent: a new file follows
  the rule even when its neighbours do not, and only a dedicated change renames the old ones.
* A topic listed in `decisions.md` as open is a decision for the user, not for the agent.

# 4. Keep it current

When the work settles a rule that applies to every Fragiola project, propose the change to the
guidelines page in the same task.
