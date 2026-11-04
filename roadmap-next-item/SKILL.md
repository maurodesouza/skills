---
name: roadmap-next-item
description: Select the next ready item of a roadmap backlog by status, dependencies and order. Sub-skill of roadmap-implementer.
---

# User Input

```text
$ARGUMENTS
```

The input must contain the roadmap folder path. It may also contain an item id.

# Objective

Return the one item `roadmap-implementer` must work on next, or nothing.

This skill only reads. It does not change statuses.

The backlog format is defined in `roadmap/references/format.md`.

# 1. Read the Items

Read the frontmatter of every file in `<roadmap>/items/`.

Ignore files with invalid frontmatter and report them.

Read the live claims with `backlog.sh claims <roadmap>` (`scripts/` of the `roadmap` skill): one `<id> <pid>` line per item another run is working on.

# 2. Ready Items

An item is ready when:

* `status` is `pending`, and
* every id in `depends-on` exists and its item is `done`, and
* it has no live claim, except a claim held by the caller's runner (its pid equals the environment variable `ROADMAP_CLAIM_OWNER`).

Items depending on a `blocked`, `pending`, `in-progress` or missing item are not ready. They are skipped, not blocked.

# 3. Select

With an item id in the input, evaluate only that item: select it when it is ready, otherwise return `NONE` with the reason (not found, not `pending`, waiting on a dependency, claimed by another run).

Without an id, sort the ready items by `order`, then `created`, then `id`, all ascending. Select the first.

# 4. Final Output

Return:

* Decision: `READY` or `NONE`
* Selected item: path, id, title, type, project, `Request` and `Details` sections
* Reason, when an explicit item is not ready
* Items waiting on dependencies (id and the dependency they wait on)
* Items claimed by other runs
* Invalid item files

Return this output to the calling skill and continue its flow. Do not end the run here unless this skill was invoked directly by the user.
