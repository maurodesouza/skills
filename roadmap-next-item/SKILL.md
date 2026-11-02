---
name: roadmap-next-item
description: Select the next ready item of a roadmap backlog by status, dependencies and order. Sub-skill of roadmap-implementer.
---

# User Input

```text
$ARGUMENTS
```

The input must contain the roadmap folder path.

# Objective

Return the one item `roadmap-implementer` must work on next, or nothing.

This skill only reads. It does not change statuses.

The backlog format is defined in `roadmap/references/format.md`.

# 1. Read the Items

Read the frontmatter of every file in `<roadmap>/items/`.

Ignore files with invalid frontmatter and report them.

# 2. Ready Items

An item is ready when:

* `status` is `pending`, and
* every id in `depends-on` exists and its item is `done`.

Items depending on a `blocked`, `pending`, `in-progress` or missing item are not ready. They are skipped, not blocked.

# 3. Select

Sort the ready items by `order`, then `created`, then `id`, all ascending. Select the first.

# 4. Final Output

Return:

* Decision: `READY` or `NONE`
* Selected item: path, id, title, type, project, `Request` and `Details` sections
* Items waiting on dependencies (id and the dependency they wait on)
* Invalid item files

Return this output to the calling skill and continue its flow. Do not end the run here unless this skill was invoked directly by the user.
