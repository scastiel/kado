# Conductor — Build stage

The build stage is the implementation itself: writing code, running
tests, iterating until the feature works. Unlike the other stages,
build **doesn't produce a dedicated Markdown artifact** — the artifact
is the code itself, plus checkboxes ticked off in `plan.md` and
commits with clear messages.

## What build is for

- Turning the plan into working, tested, merged code.
- Keeping momentum via small, regular commits.
- Catching surprises early and updating the plan rather than working
  around them silently.

## What build is not

- A rush to the end. Velocity comes from small steps, not big ones.
- A departure from the plan. If the plan is wrong, update it
  explicitly rather than drifting.
- A solo activity. The user sees each commit in the draft PR and can
  course-correct.

## Workflow

### 1. Locate the plan

If `plan.md` exists for this feature, read it:

```
docs/plans/<YYYY-MM>/<feature-slug>/plan.md
```

If no plan exists, ask the user: "There's no plan doc for this
feature. Do you want me to plan first, or build from a verbal
description?"

If they want to build without a plan, proceed but keep extra
discipline around commits and testing.

### 2. Pick the next unchecked task

Go through the plan's task list in order. Find the first unchecked
task and announce it:

> Starting **Task N: <title>**. Plan says we'll touch <files> and verify
> with <tests>. Proceeding.

### 3. Execute the task using the project's TDD workflow

This project uses XcodeBuildMCP (see `CLAUDE.md`). For business logic
tasks, follow the TDD loop:

1. Write the Swift Testing tests first
2. Run `test_sim` → confirm they fail (red)
3. Implement the feature
4. Run `test_sim` → confirm they pass (green)
5. Run `build_sim` → confirm the full app still compiles without new
   warnings
6. For UI tasks: call `screenshot` to sanity-check the visual

If a task is purely UI or config (no business logic), skip the test
steps but still end with a successful `build_sim`.

### 4. Commit regularly

One task → one commit, ideally. Use the conventional commit format
from `CLAUDE.md`:

```
<type>(<scope>): <description>
```

Examples:
- `feat(score): implement EMA habit score calculator`
- `test(score): add edge cases for frequency-adjusted scoring`
- `refactor(today-view): extract habit row into own view`

Push after each commit if a draft PR is open.

### 5. Update the plan

After a task is done:
- Tick its checkbox in `plan.md`
- If something surprised you (a wrong assumption, a better approach,
  a missing dependency), add a note in the plan's **Notes during
  build** section

If the surprise is big enough to reorder tasks or add new ones,
**stop and discuss with the user** before continuing.

### 6. Handle blocked tasks

If a task can't be completed (waiting on decision, external blocker,
test framework limitation), mark it blocked in the plan and move to
the next task if possible. Don't silently park work.

### 7. Recognize when build is done

Build is done when:
- All plan tasks are checked off, OR
- The user says "ok, let's wrap up"

Either way, the next step is compound (unless the user explicitly
skips it).

## Handling mid-build discoveries

### The plan was wrong

Example: you start implementing Task 3 and realize Task 2's approach
doesn't scale. Don't hack around it. Say to the user:

> Task 2's approach doesn't quite work because <reason>. I'd suggest
> updating the plan: <new approach>. Want me to update `plan.md` and
> redo Task 2, or do you prefer a different direction?

### A task is bigger than expected

If a task that should take an hour balloons past two, pause and
re-assess. It's often better to split the task retroactively (update
`plan.md`, commit the partial work, create new tasks) than to push
through.

### An untested edge case appears

Add a test first, then fix the code. Never "fix it and we'll add a
test later" — later doesn't come.

## Notes during build (add to plan.md)

The `plan.md` should grow a section as build progresses:

```markdown
## Notes during build

- **Task 3**: original assumption that `Date.startOfDay` was timezone-
  stable was wrong. Switched to explicit calendar-based computation.
  Added regression test.
- **Task 5**: needed to add `@MainActor` to the ViewModel because
  CloudKit callbacks come on a background thread. Plan didn't
  anticipate this.
```

These notes feed directly into the compound stage.

## No artifact for build itself

Build doesn't create its own Markdown file. The artifacts are:
- Updated `plan.md` with checked boxes and build notes
- Commits on the feature branch
- The code itself

## Transition to compound

When build is finished, suggest to the user:

> Build is done. Want to run a compound pass to capture decisions and
> surprises for the future?

If yes, load `compound.md`. If no, mark `plan.md` status as `done` and
let the user close the PR however they prefer.
