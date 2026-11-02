---
name: roadmap-create-project
description: Create the folder, local git repository and private GitHub repository of a new project from a roadmap item, reusing what already exists. Sub-skill of roadmap-implementer.
---

# User Input

```text
$ARGUMENTS
```

The input must contain a `type: project` roadmap item and the `ROADMAP.md` header (`root`, `github-owner`, `visibility`).

# Objective

Leave an empty project repository, local and on GitHub, ready for `tech-lead` to plan its first version.

This skill does not choose a stack, scaffold code or plan anything. The project type and architecture are decided later by `tech-lead` and `project-architecture` (an empty repository is planned in `OPINIONATED` mode).

Never overwrite or delete existing work.

# 1. Target

* Folder: `<root>/<project>`, where `root` comes from the `ROADMAP.md` header and `project` from the item.
* Repository: `<github-owner>/<project>`, with the `visibility` of the header (`private` by default).

# 2. Local Folder

| State | Action |
| --- | --- |
| Does not exist | Create it |
| Exists and is empty | Use it |
| Exists, is a git repository and its `origin` is the target repository | Reuse it and skip to section 4 |
| Exists with other content | Return `BLOCKED`: the folder belongs to something else |

Then:

1. `git init -b main`
2. Write a `README.md` with the project name and the goal from the item (`Request` and `Details`, summarized in two or three sentences).
3. Commit it: `🎉 chore: initialize <project>`.

# 3. GitHub Repository

1. Check it with `gh repo view <github-owner>/<project>`.
2. If it does not exist: `gh repo create <github-owner>/<project> --<visibility> --source . --remote origin --push`.
3. If it exists and is empty: add it as `origin` and push.
4. If it exists with content: when the local folder was just created, clone it instead of using the new local repository (remove only the folder created in section 2); otherwise return `BLOCKED`.

If `gh` is not authenticated or the owner is not accessible, return `BLOCKED` with the error.

# 4. Verify

* `git -C <folder> remote get-url origin` points to the target repository.
* The default branch exists on the remote.

# 5. Final Output

Return:

* Decision: `CREATED`, `REUSED` or `BLOCKED`
* Project folder (absolute path)
* Repository URL and visibility
* Reason (when `BLOCKED`)

Return this output to the calling skill and continue its flow. Do not end the run here unless this skill was invoked directly by the user.
