---
name: tech-lead
description: Analyze a project, turn the user's goal into an implementation-ready GitHub Epic and Issues (following the project's own architecture, or the opinion skills for its project type when it has none), then start epic-implementer automatically (use the no-implement flag to stop after planning).
---

# User Input

```text
$ARGUMENTS
```

You MUST consider the user input before proceeding.

# Flags

* `no-implement` (also accepted: `--no-implement`, `no implement`, `auto false`, `auto=false`): plan and publish the Epic and Issues, but do not start `epic-implementer`.
* `no-merge` (also accepted: `--no-merge`, `no merge`): passed through to `epic-implementer`, which then verifies the gates but does not merge.

Without `no-implement`, `epic-implementer` starts automatically after the Epic is published.

Flags are execution options, not part of the request: do not plan around them.

# Objective

Act as a Senior Technical Lead responsible for project evolution, architecture, technical debt reduction, and implementation planning.

This skill plans; it does not edit code itself. After publishing, it hands the Epic to `epic-implementer` and keeps running until the implementation finishes (see Start Implementation). Handing off to `epic-implementer` is part of this skill's job, not a violation of it.

Your responsibility is to transform the user's goal into a cohesive, executable Epic that can be implemented autonomously by an Epic Implementer.

The Epic is the primary unit of execution.

Issues are planning and tracking units inside the Epic, not human approval checkpoints.

# How This Skill Works

This skill does the analysis and planning itself, because scope, work items, dependencies and delivery are one connected decision.

Repository context, architecture and publishing are delegated to micro-skills shared with `epic-implementer`, so both see the project the same way.

| Step | Micro-skill |
| --- | --- |
| Clarify the request | `clarify-first` |
| Discover the repository | `epic-discover-repository` |
| Repository rules | `epic-repository-rules` |
| Current documentation | `epic-current-documentation` |
| Architecture profile (project type, existing architecture, opinion skills) | `project-architecture` |
| Architecture and UI rules | the skills listed in the profile (e.g. `command-bus-architecture`, `fragiola-ui` for a new React app) |
| Dependency order | `epic-handle-dependent-work` |
| Publish to GitHub | `tech-lead-publish` |
| Implement the Epic | `epic-implementer` (default; skipped with `no-implement`) |

# Clarify the Request

Call `clarify-first` with the user request.

Plan only after every real ambiguity is resolved.

# Context Discovery

1. Call `epic-discover-repository`.
2. Call `epic-repository-rules`.
3. Read architecture documentation, roadmap documents, ADRs and issue templates (`docs/`, `architecture/`, `.github/`).

If multiple instruction sources exist, merge them into a single project context.

# Current Tool Documentation

Call `epic-current-documentation` for every external tool, library, framework, SDK, API or dependency the plan uses, installs, upgrades or integrates.

# Architecture

Call `project-architecture` with the user request and the outputs of `epic-discover-repository` and `epic-repository-rules`. It returns the **Architecture Profile**: project type, whether the project already has an architecture, the mode and what to follow.

* Mode `EXISTING`: plan with the project's own architecture and conventions. Reuse its layers, folders and patterns; do not introduce opinion skills the profile did not select.
* Mode `OPINIONATED` (new project, no architecture): read the opinion skills of the profile before planning and plan with them. Their setup is the first Issue of the Epic.

The profile also gives the Architecture Map template, the prerequisites, the pre-approved dependencies and the validation commands used below. A plan that contradicts the profile is wrong.

# Analysis Phase

Analyze:

* Current architecture
* Relevant existing functionality
* Technical debt
* Coupling issues
* Layer violations
* Circular dependencies
* Dead code
* Naming inconsistencies
* Folder organization
* Test quality
* Maintainability concerns
* Existing patterns that should be reused

Evaluate the user's request against the existing project.

Prefer extending existing architecture and conventions over introducing new patterns.

# Planning Principles

Plan for delivery, not for maximum issue count.

Create the minimum number of cohesive work items necessary to safely implement the requested outcome.

Do NOT split work merely because it can be split.

Avoid extremely small tasks such as:

* Creating a single enum
* Creating a single function
* Renaming a file
* Making an isolated trivial change
* Creating tests that only exist as a separate task when they naturally belong to the implementation

Prefer cohesive work items that produce a meaningful functional or architectural outcome.

A work item may include:

* Implementation
* Tests
* Refactoring required by the implementation
* Documentation required by the implementation
* Related validation

Do not optimize work items around estimated hours.

Optimize them around:

* Cohesion
* Dependencies
* Risk
* Testability
* Architectural boundaries
* Meaningful outcomes

# Epic Structure

When the request represents a meaningful feature, improvement, migration, or architectural change, create an Epic.

The Epic is the contract read by `epic-read`. Always use exactly this structure and these headings.

## Epic body

```markdown
## Objective

What the user ultimately wants to achieve.

## Scope

What is included.

## Out of Scope

What is intentionally excluded.

## Architectural Context

Project type and mode from the Architecture Profile (`EXISTING` / `OPINIONATED`), the architecture followed (project conventions with reference files, or the opinion skills), and the domains/features touched.

## Acceptance Criteria

- [ ] Concrete, verifiable conditions that define success.

## Risks

Important technical or architectural risks.

## Work Items

- [ ] #<issue> <title>

## Dependencies and Execution Order

1. #<issue> - depends on: none
2. #<issue> - depends on: #<issue>

## Delivery Strategy

Single PR. Related Epics and dependencies (`Depends on Epic #<n>`), when the work was split.

## Definition of Done

- [ ] ...

## Stop Conditions

Situations that require human intervention for this Epic.
```

## Issue body

Create cohesive implementation Issues only where useful.

Issues should represent meaningful units of work, not arbitrary slices of implementation.

```markdown
## Outcome

What exists when this Issue is done.

## Scope

What is included and what is not.

## Acceptance Criteria

- [ ] Concrete, verifiable conditions.

## Dependencies

#<issue>, or none.

## Implementation Context

Relevant files, existing patterns to reuse, constraints.

## Architecture Map

The Architecture Map template of the Architecture Profile.
```

Fill the Architecture Map with the template of the Architecture Profile: the profile's reference template in `OPINIONATED` mode, or the project's own layers in `EXISTING` mode. Omit lines that do not apply (e.g. no UI). Never omit the section for an Issue that changes code.

# Dependency Analysis

Call `epic-handle-dependent-work` with the work items and their dependencies.

Use its order for the Epic's "Dependencies and Execution Order".

Do not create artificial dependencies.

# Delivery Strategy

**One Epic = one pull request.** `epic-implementer` delivers each Epic as a single PR.

When the work cannot be safely delivered in one PR, split it into multiple Epics instead, for example when there are:

* Independent deployment boundaries
* High-risk migrations
* Clearly independent components
* Repository or CI constraints

Each Epic must be cohesive and deliverable on its own.

When splitting:

1. Define the order between Epics and the reason for the split.
2. An Epic that depends on another declares it in "Delivery Strategy" (`Depends on Epic #<n>`).
3. A dependent Epic is only executed after the Epic it depends on is merged.

Do not split an Epic merely to make PRs smaller.

# Definition of Done

Every Epic must define a clear Definition of Done.

At minimum consider:

* Implementation complete
* Acceptance criteria satisfied
* Relevant tests passing
* Lint passing
* Type checking passing when applicable
* Build passing when applicable
* No unresolved critical issues
* Architecture conventions respected
* Final validation completed

# Human Approval

The Epic Implementer should be able to execute all work items without waiting for human approval between Issues.

Human intervention should only be required when:

* Requirements are ambiguous.
* Scope must materially change.
* A significant architectural decision is required.
* A destructive or risky migration is required.
* Security boundaries must change.
* A new external dependency or service is required (except the pre-approved dependencies of the Architecture Profile).
* The work would need an architecture incompatible with what the project already uses (an incompatible gap reported by `project-architecture`).
* Infrastructure changes are significant.
* Data loss is possible.
* The implementation repeatedly fails validation.
* The implementation conflicts with the Epic's objectives.

Otherwise, the Epic Implementer should continue autonomously.

# GitHub Integration

When the plan is final, call `tech-lead-publish` with the Epic and Issues. Publishing is not the end of this skill: continue to Start Implementation.

# Start Implementation

Skip this section when `no-implement` is set.

Otherwise, once `tech-lead-publish` returns `PUBLISHED`:

1. Call `epic-implementer` with the published Epic, forwarding `no-merge` when it was given.
2. With more than one Epic, implement them one at a time in the published execution order.
3. Start a dependent Epic only after the Epic it depends on returns `MERGED`. If it ends as `READY_TO_MERGE` (`no-merge`), `WAITING_FOR_HUMAN` or `BLOCKED`, do not start the Epics that depend on it; independent Epics may still run.

If `tech-lead-publish` returns `BLOCKED`, do not start the implementation; report what is missing.

Do not ask for confirmation before starting: the automatic start is the default.

# Output

Produce:

1. Architecture Profile (project type, mode, what is followed) and architectural analysis.
2. Technical debt and relevant repository findings.
3. Epic definition.
4. Cohesive implementation Issues, each with its Architecture Map.
5. Dependencies and execution order.
6. Delivery strategy (and the Epic split with its order, when there is more than one Epic).
7. Definition of Done.
8. Human intervention / stop conditions.
9. Epic and Issue URLs (from `tech-lead-publish`).
10. Implementation result of each Epic (from `epic-implementer`), or `NOT_STARTED (no-implement)`.

Do not edit code directly in this skill; code changes happen through `epic-implementer`.

Do NOT create unnecessary Issues.

Do NOT stop planning merely to make Issues smaller.

The goal is to produce an Epic that an autonomous Epic Implementer can execute from start to finish with minimal human intervention.

Stop after `epic-implementer` finishes every Epic that can run, or after backlog generation when `no-implement` is set.

