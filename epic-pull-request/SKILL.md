---
name: epic-pull-request
description: Push the Epic branch and open the pull request for a fully validated Epic. Sub-skill of epic-implementer.
---

# User Input

```text
$ARGUMENTS
```

The input must contain the Epic summary, the Issues implemented, the worktree path, the branch name, the validation performed and the PR conventions and language from `epic-repository-rules` (call it if they are not in context).

# Objective

Open one pull request for the whole Epic.

Run only after the Epic passed final validation.

Write the title and the body in the language resolved for pull requests (English when there is no pattern), whatever language the request or the Epic is in.

# 1. Push

Push the Epic branch to the remote.

If a pull request for this branch already exists, update it instead of opening a new one.

# 2. Body

Check whether the repository provides a pull request template.

If one exists:

Use it.

Otherwise, when the recent pull requests have an established body structure, follow it.

Otherwise generate:

```markdown
## Summary

Describe the complete Epic implementation.

Closes #{issue-number}
Closes #{issue-number-2}
...

### Verification

List all validation steps performed.

### Notes

Include relevant implementation and architectural notes.

Requested by: @maurodesouza
```

The pull request must always contain, even when using a template:

```markdown
Closes #{issue-number}
Closes #{issue-number-2}. (if applicable)
...

Requested by: @maurodesouza
```

Include all Issues belonging to the Epic that should be automatically closed after merge.

# 3. Create

Create the pull request against the repository default branch.

Title follows the repository PR convention; otherwise use the commit convention with the Epic title.

# 4. Final Output

Return:

* Pull request number and URL
* Base and head branches
* Issues referenced with `Closes`

Return this output to the calling skill and continue its flow. Do not end the run here unless this skill was invoked directly by the user.
