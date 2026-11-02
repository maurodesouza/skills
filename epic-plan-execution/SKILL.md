---
name: epic-plan-execution
description: Produce the execution plan for an Epic from the Epic summary, repository report and conventions. Sub-skill of epic-implementer.
---

# User Input

```text
$ARGUMENTS
```

The input must contain the outputs of `epic-read`, `epic-discover-repository`, `epic-repository-rules` and `project-architecture`.

# Objective

Decide what will be done, in which order, and how it maps to the architecture of the Architecture Profile.

This skill does not modify code.

# 1. Order the Work

Use `epic-handle-dependent-work` to resolve the order of the Issues.

# 2. Map Each Issue to the Architecture

Start from the Issue's Architecture Map (written by `tech-lead`). Verify it against the current code and complete or correct it.

For each Issue, list every element of the profile's Architecture Map template (in `EXISTING` mode, the project's own layers) with its location, plus the tests to create or change.

In `OPINIONATED` mode for a React app, that is: flat action domains and their single Handle, MobX stores (fields, plain setters, `$` derived values with one `$<part>UI` per component), dialogs as modal content, components and their Fragiola UI parts. Every interaction must appear as an action + handler, never as logic inside a component or store (`command-bus-architecture`).

In `EXISTING` mode, map the Issue onto the patterns the project already uses; do not add layers it does not have.

# 3. Prerequisites

Mark as the first step the prerequisites of the Architecture Profile that are missing (for a new React app: `setup-command-system`, the MobX install verified with `epic-current-documentation`, and the Fragiola registry setup).

# 4. Scope Check

Do not create unnecessary work.

Do not add anything outside the Epic scope.

If implementation details need to change while remaining within scope, adapt the plan and note why.

# 5. Final Output

Return:

* Ordered list of Issues
* Per-Issue architecture map (section 2)
* Prerequisite steps
* Risks or decisions that may trigger a stop condition

Return this output to the calling skill and continue its flow. Do not end the run here unless this skill was invoked directly by the user.
