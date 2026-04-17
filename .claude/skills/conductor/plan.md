# Conductor — Plan stage

The plan stage turns research into an ordered, concrete task list
ready for implementation. It produces a `plan.md` artifact that
another developer (or a future you) could pick up and execute
without re-doing the thinking.

## What plan is for

- Decomposing a feature into tasks small enough to commit
  individually.
- Ordering tasks so that each leaves the project in a working state.
- Identifying the test strategy before writing tests.
- Spotting integration points where things might go wrong.

## What plan is not

- A Gantt chart. No time estimates unless the user asks.
- A rigid script. Tasks can be reordered during build if the user
  wants.
- A contract. If build reveals the plan was wrong, the plan gets
  updated, not blindly followed.

## Workflow

### 1. Locate the research

If a `research.md` exists for this feature, read it first. Its
location is:

```
docs/plans/<YYYY-MM>/<feature-slug>/research.md
```

If no research exists, ask the user: "No research doc for this
feature. Want me to do a quick research pass first, or should we plan
directly from what you've described?"

If they want to plan directly, proceed but be extra careful to
surface assumptions explicitly in the plan itself.

### 2. Resolve open questions

Research artifacts often end with open questions. Before planning,
revisit them:

- Go through each open question from `research.md`.
- For each, ask the user whether it can be answered now or should
  stay open.
- Questions resolved here become decisions in the plan. Questions
  still open get copied to the plan's own Open questions section.

### 3. Decompose into tasks

Break the feature into tasks. Good tasks have these properties:

- **Small enough to commit individually** (rule of thumb: < 2 hours
  of focused work)
- **Self-contained**: the project compiles and tests pass after the
  task is done
- **Testable**: there's a clear way to verify completion
- **Ordered**: earlier tasks don't depend on later ones

For business logic (habit score, streak calculators, parsers): **tests
come first as their own task** before the implementation task. This
matches the TDD workflow described in `CLAUDE.md`.

### 4. Identify integration checkpoints

Call out moments where tasks touch system boundaries:
- SwiftData schema changes → migration needed?
- CloudKit → sync behavior to verify?
- HealthKit → permissions handling?
- Widgets → App Group data sharing?

These are risk areas. Note them explicitly in the plan.

### 5. Ask open questions

Just like research, the plan may surface new open questions that
weren't visible during research. Examples:
- "Should we add a feature flag while this is in progress?"
- "Does this task need a preview in each color theme?"
- "Do we need a migration path for existing users?"

### 6. Write the artifact

Create the file at:

```
docs/plans/<YYYY-MM>/<feature-slug>/plan.md
```

Use the template below.

### 7. Suggest a draft PR (if not already open)

If a draft PR was opened during research, this plan commit goes on
the same branch. If no PR exists yet, suggest one now.

## Artifact template

```markdown
# Plan — <Feature name>

**Date**: <YYYY-MM-DD>
**Status**: draft | ready to build | in progress | done
**Research**: [research.md](./research.md)

## Summary

<Two to four sentences restating what we're building and why. Stand
alone — someone should be able to read just this section and know
what's going on.>

## Decisions locked in

<Key decisions made during research or planning. Each decision should
be a single line.>

- <Decision 1>
- <Decision 2>

## Task list

<Ordered list. Each task has a checkbox, a title, a short description,
and test / verification notes.>

### Task 1: <Title>

**Goal**: <One sentence.>

**Changes**:
- <File or area 1>
- <File or area 2>

**Tests / verification**:
- <Test case or manual check>

**Commit message (suggested)**: `<type>(<scope>): <description>`

---

### Task 2: <Title>

...

## Risks and mitigation

<For each identified risk, what we'll do if it materializes.>

## Open questions

- [ ] <Question carried from research or new>
- [ ] <Question 2>

## Out of scope

<Things explicitly not in this plan. Helps future-you remember why
something wasn't touched.>
```

## Task size guidance

Signs a task is too big:
- More than ~200 lines of diff expected
- Touches 5+ files across unrelated modules
- Can't be described without subheadings

Split it. One "implement HabitScoreCalculator with all edge cases" task
is probably 4 tasks: base EMA calculation, frequency handling,
counter/timer value support, backfill recalculation.

## Transition to build

When the plan is ready, the user typically says "let's start building"
or "first task." That's the cue to load `build.md`.

If the user wants to jump directly to compound (e.g. they want to plan
a retrospective on work already done elsewhere), that's valid — load
`compound.md` directly.
