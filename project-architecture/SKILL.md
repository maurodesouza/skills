---
name: project-architecture
description: Identify the project type (React app, library, back-end, other) and whether it already has an architecture, then decide which architecture to follow - the project's own, or the opinion skills for that project type. Use before planning, implementing or reviewing code with tech-lead or epic-implementer.
---

# User Input

```text
$ARGUMENTS
```

The input may contain the user request and the outputs of `epic-discover-repository` and `epic-repository-rules`. Call them first if they are not in context.

# Objective

Decide which architecture the work must follow, so opinionated patterns are only applied where they fit.

This skill only reads. It does not modify files.

The opinion skills (Command Bus, Fragiola UI, composition, ...) are references for projects that have **no architecture of their own**. They are never imposed on a project that already has one, and never applied to a project type they were not written for.

# 1. Identify the Project Type

Use the manifests and the structure, not the folder name.

| Type | Signals |
| --- | --- |
| `react-app` | `react` in dependencies plus an app entry: `index.html`, `src/main.tsx`, `src/routes/` / `app/` (TanStack Start, React Router, Next.js), a dev server script |
| `library` | published package: `exports` / `main` / `module` / `types` in `package.json`, `files`, `peerDependencies`, library build (`tsup`, `tsdown`, Vite library mode, `tsc` to `dist/`), no app entry. A React component library is a `library`, not a `react-app` |
| `backend` | HTTP / RPC / worker server: `express`, `fastify`, `hono`, `koa`, `@nestjs/*`, `elysia`, ORMs (`prisma`, `drizzle-orm`), a server entry (`src/server.ts`, `main.ts` listening on a port); or a back-end language manifest (`go.mod`, `pyproject.toml` with FastAPI/Django, `pom.xml`, `Cargo.toml` with a web framework) |
| `other` | CLI, scripts, infrastructure, monorepo root without code, anything else |

In a monorepo, identify the type of the package the work touches, not of the root.

When the repository is empty or has no manifest yet, the type comes from the user request ("create a React app", "a library that ...", "an API that ...").

# 2. Identify the Existing Architecture

Look for what the project already decided. Any of these counts:

* Architecture rules in the project instructions (`AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `.cursor/rules`, `.github/copilot-instructions.md`, `docs/`, ADRs).
* A consistent structure in the existing code: two or more features organized the same way, one state approach, one UI library, one way of calling APIs, one testing style.

Do **not** count:

* The workflow and opinion skills installed in `.claude/skills`, `.agents/skills` or `.codex/skills` (this skill, `command-bus-architecture`, `fragiola-ui`, ...). They are tools available to the agent, not decisions of the project.
* Files that only come from a framework template (a fresh `create-vite` / `create-start` scaffold).

Classify:

| Status | Meaning |
| --- | --- |
| `ESTABLISHED` | rules or consistent patterns exist |
| `PARTIAL` | some code exists, but without a consistent pattern for the area the work touches |
| `NONE` | new project, empty repository or only a template |

# 3. Decide the Mode

Precedence, from strongest to weakest:

1. Explicit choices in the user request ("use MobX", "use the Command Bus").
2. Repository rules.
3. Existing code patterns.
4. Opinion skills of the project type.

| Status | Mode | What to follow |
| --- | --- | --- |
| `ESTABLISHED` | `EXISTING` | The project's rules and patterns. When those patterns are the ones of an opinion profile (e.g. the Command Bus in `src/lib/command/`, MobX stores, the Fragiola registry), select that profile's opinion skills: they document the project's own convention |
| `PARTIAL` | `EXISTING` | What exists, for the areas it covers. For areas with no precedent, use the opinion skills of the type **only if they are compatible** with what exists (never add MobX next to Zustand, or Fragiola next to another UI library). An incompatible gap is a significant architectural decision: report it as a stop condition |
| `NONE` | `OPINIONATED` | The opinion skills of the project type (section 4) |

Never migrate existing code to an opinion skill unless the user asked for it.

# 4. Opinion Profiles

Each project type has its own profile. Read the one that matches and only that one.

| Type | Profile | Opinion skills |
| --- | --- | --- |
| `react-app` | `references/react-app.md` | `command-bus-architecture`, `command-handle-implementation`, `setup-command-system`, `fragiola-ui`, `utils-implementation` |
| `library` | `references/library.md` | `utils-implementation` (TypeScript) |
| `backend` | `references/backend.md` | `utils-implementation` (TypeScript) |
| `other` | none | The language's standard conventions |

Opinion skills of one type are never loaded for another: a library or a back-end never receives the Command Bus, MobX stores or Fragiola UI.

To add opinions for a type, create the skill and list it in this table and in the profile.

# 5. Load the Selected Skills

Invoke every opinion skill the profile selects (with the Skill tool) before planning or writing code, and follow it. Reading the existing code is not a substitute: the skills hold rules the code does not show. For a React app on the Command Bus, that means at least `command-bus-architecture`, plus `fragiola-ui` before UI work.

# 6. Final Output

Return the **Architecture Profile**:

* Project type, with the signals that decided it
* Architecture status (`ESTABLISHED` / `PARTIAL` / `NONE`), with the evidence (rule files, reference folders)
* Mode: `EXISTING` or `OPINIONATED`
* Architecture to follow: the project conventions (with reference files) and/or the opinion skills to load
* Architecture Map template for Issues (from the profile in `OPINIONATED` mode; built from the existing layers in `EXISTING` mode)
* Implementation order per Issue
* Prerequisites (setup steps; only in `OPINIONATED` mode, or for a compatible gap)
* Pre-approved dependencies (only those of the selected opinion skills)
* Validation commands (project scripts, plus the checks of the opinion skills that are loaded)
* Conflicts or incompatible gaps (possible stop conditions)

`tech-lead`, `epic-implementer`, `epic-plan-execution`, `epic-execution`, `test-writer` and `reviewer` follow this profile instead of assuming an architecture.

Return this output to the calling skill and continue its flow. Do not end the run here unless this skill was invoked directly by the user.
