---
name: epic-execution
description: Implement a single Epic Issue following the project's Architecture Profile, then test, review and commit it. Sub-skill of epic-implementer.
---

# User Input

```text
$ARGUMENTS
```

The input must contain one Issue, its architecture map from `epic-plan-execution`, the Architecture Profile, the worktree path and the repository report.

# Objective

Implement exactly one Issue until its acceptance criteria are met.

Work only inside the Epic worktree.

# 1. Understand

1. Read the Issue and its acceptance criteria.
2. Read the reference files from the repository report.
3. Inspect the existing code that will change.

# 2. Implement

Follow the Architecture Profile for every change, in its implementation order:

* Mode `EXISTING`: imitate the reference files of the closest existing feature (same layers, folders, naming and patterns).
* Mode `OPINIONATED`: follow the opinion skills of the profile. For a React app, `project-architecture/references/react-app.md` gives the order (actions, store, Handle, mounting, components) and the skills used at each step.

Write helpers with `utils-implementation` when the profile selects it; otherwise follow the project's existing helpers.

Before using any external library API, run `epic-current-documentation`.

Match the surrounding code style and the reference files.

# 3. Validate

1. Call `test-writer` when tests are applicable.
2. Run lint, typecheck, the relevant tests and the validation commands of the Architecture Profile (for a React app with the Command Bus: `node <command-bus-architecture>/scripts/check-architecture.mjs src`, which must report no violations).
3. Call `reviewer`, passing the validation results from step 2.
4. Address all critical, high and relevant medium findings, then re-run validation.
5. Do not continue with known blocking findings.

# 4. Close the Issue

1. Verify every acceptance criterion of the Issue.
2. Call `epic-commit-progressively`.
3. Mark the Issue as completed when supported.

# 5. Final Output

Return:

* Issue number
* Files changed
* Architecture elements created or changed (per the Architecture Map)
* Validation results
* Reviewer decision
* Commits created
* Acceptance criteria status

Return this output to `epic-implementer`, which continues with the next Issue. Do not end the run here.
