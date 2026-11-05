---
name: epic-repository-rules
description: Collect the repository conventions (branch, commit, PR, issue, language, code style, architecture rules) from its rule files and recent history. Sub-skill of epic-implementer.
---

# User Input

```text
$ARGUMENTS
```

# Objective

Find every project convention that must be respected during the Epic.

This skill only reads. It does not modify files.

# 1. Look for Rules

Look in:

* .agents/
* .devin/
* .github/
* .cursor/
* .windsurf/
* .claude/
* .codex/
* AGENTS.md
* CLAUDE.md
* CONTRIBUTING.md
* README.md

Also check parent directories up to the git root, since rules may live there.

# 2. Extract Conventions

Extract, when present:

* Branch naming
* Commit message format
* Pull request template and requirements
* Issue templates, titles and labels
* Language of commits, pull requests, issues and documentation
* Code style and naming
* Architecture rules
* Testing rules
* Forbidden patterns

# 3. Read the Recent History

The history shows the conventions the rule files do not write down. Read it even when rule files exist:

```bash
git log -n 20 --format='%h %s%n%b'
gh pr list --state all --limit 20 --json number,title,body,headRefName,labels
gh issue list --state all --limit 20 --json number,title,body,labels
```

Ignore records made by bots (Dependabot, Renovate, release tools) and automatic merge commits.

For each kind of record (commits, pull requests, issues), extract:

* The language
* How titles and messages are written (format, type prefixes, emoji, tone, length)
* How bodies are organized (sections, links, checklists)
* Branch names and labels in use

Also note the language of the existing documentation (README, `docs/`).

A pattern is established when most of the recent records of that kind follow it. A single record, or a split history, establishes nothing. When `gh` or a remote is unavailable, use what can be read and report what could not.

Reproduce what is established. Do not introduce a different language or convention, and do not "improve" an existing one.

# 4. Language

The language of commits, pull requests, issues and documentation is resolved **per kind of record**, in this order:

1. An explicit rule in the repository rule files.
2. The pattern established by the recent history (section 3) or, for documentation, by the existing documentation.
3. English.

The language the user writes in is never a signal. A request in Portuguese does not make these records Portuguese.

Report the resolved language of each kind. Every skill that writes one of these records follows it, including comments on them. Text quoted verbatim, code identifiers and commands stay as they are. The language of the product itself (UI copy, messages shown to its users) is not covered here: it follows the project and the request.

# 5. Precedence

Repository rules always override workflow defaults. Conventions established by the recent history count as repository rules, below the written ones.

When two repository rules conflict, apply the more specific one (closer to the code being changed) and report the conflict in the output. Do not stop for it.

Repository rules also override the opinion skills (`command-bus-architecture`, `fragiola-ui`, ...): `project-architecture` only applies those when the project has no architecture of its own.

Skills installed in `.claude/skills`, `.agents/skills` or `.codex/skills` are agent tooling, not repository rules. Report the project's own rules (instruction files, docs, configs) only.

# 6. Final Output

Return:

* Each convention with its source (file path, or `history`)
* The resolved language of commits, pull requests, issues and documentation, with its source (`rule`, `history` or `default`)
* Defaults that apply because no rule exists (mark them as `default`)
* Conflicts found

Return this output to the calling skill and continue its flow. Do not end the run here unless this skill was invoked directly by the user.
