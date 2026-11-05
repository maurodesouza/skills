---
name: epic-implementer
description: Implement a GitHub Epic, open the pull request, verify its gates and auto-merge it (use the no-merge flag to skip the merge).
---

# User Input

```text
$ARGUMENTS
```

The input must contain a GitHub Epic.

# Flags

* `no-merge` (also accepted: `--no-merge`, `no merge`): create the pull request and verify all gates, but do not merge.

Without the flag, the pull request is merged automatically once every gate passes.

# Objective

Act as an autonomous Epic Implementer.

Your responsibility is to implement the complete Epic from start to finish, open the pull request, verify its gates and merge it (unless `no-merge` is set).

The Epic is the primary unit of execution.

Individual Issues are implementation work items, not human approval checkpoints.

Do not stop after completing an individual Issue.

# How This Skill Works

This skill is an orchestrator. It does not do the work itself.

Each step is delegated to a micro-skill with a single responsibility. Call the micro-skill, use its output as input for the next step, and follow its result.

Do not re-implement inside this skill what a micro-skill is responsible for.

Shared skills (`project-architecture`, the opinion skills it selects, `test-writer`, `reviewer`) are loaded once. While their instructions are still in context, follow them without loading them again for every Issue.

# Autonomy

Work as if the user is not watching.

* When a problem can be solved within the Epic scope and the Architecture Profile (failing import, type error, missing config, lint issue, small adaptation of reference code), decide, fix it and continue. Note the decision in the pull request Notes.
* Never ask the user to choose: decide, record and continue (section 10). Only the hard stops of section 10 wait for the user.
* `clarify-first` does not apply inside this skill; requirements were clarified when the Epic was planned.

# Architecture

All code produced for the Epic follows the **Architecture Profile** returned by `project-architecture` (step 4):

* Mode `EXISTING`: the project's own architecture, conventions and reference files. Do not introduce patterns the project does not use.
* Mode `OPINIONATED`: the opinion skills the profile selects for the project type (for a new React app: `command-bus-architecture`, `fragiola-ui`, `command-handle-implementation`, `utils-implementation`).

The Epic's Architectural Context and Architecture Maps were written from the same profile; when they disagree with the current repository, the repository wins and the decision goes into the pull request Notes.

# 1. Read the Epic

Call `epic-read` with the Epic.

If it returns `BLOCKED`, stop and present the reason to the user (open questions or an Epic it depends on that is not merged).

# 2. Discover the Repository

Call `epic-discover-repository`.

# 3. Repository Rules

Call `epic-repository-rules`.

Repository rules always override workflow defaults.

Commits, the pull request, comments and documentation follow the languages resolved here, not the language of the request or of the conversation.

# 4. Architecture Profile

Call `project-architecture` with the Epic and the outputs of steps 2-3. Load the opinion skills it selects, and only those.

# 5. Current Documentation

Call `epic-current-documentation` whenever any step is about to use, install, upgrade, configure or integrate an external tool or dependency.

# 6. Plan Execution

Call `epic-plan-execution` with the outputs of steps 1-4.

`epic-plan-execution` uses `epic-handle-dependent-work` to order the Issues.

# 7. Epic Worktree

Call `epic-worktree`.

All following steps run inside the Epic worktree.

# 8. Prerequisites

If the plan lists prerequisites (from the Architecture Profile), run them first. For a new React app they are `setup-command-system`, the MobX install and the Fragiola registry setup (`project-architecture/references/react-app.md`).

Then call `epic-commit-progressively`.

# 9. Execute the Epic

For each Issue, in the order returned by the plan, call `epic-execution`.

`epic-execution` implements, tests (`test-writer`), reviews (`reviewer`) and commits (`epic-commit-progressively`) one Issue.

Continue automatically to the next Issue.

Do NOT wait for human approval between Issues.

Do NOT open a pull request for individual Issues.

Do NOT stop merely because an Issue is complete.

If the work reveals a new dependency between Issues, call `epic-handle-dependent-work` again and continue with the updated order.

# 10. Decisions and Stop Conditions

Never stop to ask the user to choose between options. The user follows the agent's recommendation, so asking only wastes time.

When the work needs a decision - validation keeps failing, a fix needs a scope, rule or architecture change, a stop condition written in the Epic is reached, the Epic leaves a choice open - decide it yourself:

1. Pick the option you would recommend (the smallest one that meets the Epic objective).
2. Record it: what was decided, why, and the alternatives discarded, in the pull request Notes and as a comment on the Epic.
3. Continue.

A stop condition written in the Epic is a decision point handled the same way, unless it guards one of the hard stops below.

Stop only before an action that is irreversible or reaches outside the repository and that neither the Epic nor the user authorized:

* Data loss, or a destructive migration.
* A production release or deploy.
* A change to security boundaries.
* A new paid external service, or spending far beyond a budget the Epic states.

Even then, finish every other piece of work first, then stop with your recommendation and the one action that waits for the user.

# 11. Final Validation

After all Issues are implemented:

1. Verify every Epic acceptance criterion.
2. Verify every Issue acceptance criterion.
3. Run the complete relevant test suite.
4. Run lint.
5. Run type checking when applicable.
6. Run build when applicable.
7. Run the validation commands of the Architecture Profile.
8. Call `reviewer` for final Epic-level review.
9. Address all blocking findings.
10. Confirm the repository is merge-ready.

Do not open the pull request until the Epic passes final validation.

# 12. Open Pull Request

Call `epic-pull-request`.

# 13. Gates and Merge

Call `epic-merge` with the pull request and the `no-merge` flag.

* Default: verify all gates (checks, conflicts, mergeability) and merge when everything passes.
* `no-merge`: verify all gates the same way, but do not merge.

If `epic-merge` returns `BLOCKED` or `WAITING_FOR_HUMAN`, stop and explain what is required from the user.

# 14. Cleanup

When `epic-merge` returns `MERGED`, call `epic-cleanup` to delete the remote branch, the local branch and the Epic worktree.

With `no-merge`, skip this step: the branch and worktree stay for the pending pull request.

# 15. Final Output

Return:

* Epic number
* Issues implemented
* Worktree path
* Branch name
* Commits created
* Pull request URL
* Gates status (checks, conflicts)
* Merge status: `MERGED`, `READY_TO_MERGE` (no-merge), `WAITING_FOR_HUMAN` or `BLOCKED`
* Cleanup status: `CLEANED`, `SKIPPED` or `BLOCKED`
* Architecture Profile (type and mode)
* Final validation status

Stop after the cleanup, or after the gates pass when `no-merge` is set. When invoked by `tech-lead`, return this output to it so it can continue with the next Epic.
