# Conductor — Compound stage

The compound stage is a structured retrospective. It captures what
was decided, what surprised us, what we learned, and what a future
person touching this code should know. The output is `compound.md`.

The name "compound" is deliberate: the value compounds over time.
One compound doc is a curiosity. Fifty compound docs are an
institutional memory.

## What compound is for

- Recording decisions so they don't have to be re-derived.
- Capturing dead ends explicitly so we don't rediscover them.
- Distilling lessons that generalize beyond this feature.
- Giving future-you (or a future contributor) a shortcut to
  understanding.

## What compound is not

- A celebration or a punishment. Neither praise nor blame.
- A duplicate of `research.md` or `plan.md`. The value is in what
  changed between plan and reality.
- A place for TODOs. Things to do next go in `docs/ROADMAP.md` or
  new research docs.

## Workflow

### 1. Gather inputs

Read whichever of these exist for the feature:
- `research.md`
- `plan.md` (especially the **Notes during build** section if it
  exists)
- The git log of the feature branch

If only a subset exists (e.g. user did research + compound without
planning or building), adapt — compound works on whatever inputs are
available.

### 2. Identify what to compound

Go through four questions:

**A. What decisions were made?**
List the concrete choices that shaped the feature. Include both
big-picture decisions (algorithm choice, architecture) and tactical
ones (naming, file organization) if they required thought.

**B. What surprised us?**
Things that didn't go as planned: wrong assumptions, missing
constraints, framework quirks, performance issues discovered late.

**C. What worked well?**
Approaches, patterns, or tools that paid off. Worth generalizing if
possible.

**D. What should the next person know?**
If someone touches this code in six months, what's non-obvious? What
would save them half a day?

### 3. Distinguish local vs general lessons

Some lessons apply only to this feature ("the HabitScoreCalculator
uses α = 0.05 because..."). Others generalize ("SwiftData's
`@Relationship` with `.cascade` delete behaves unexpectedly when the
parent is in a fetched snapshot"). Both belong, but flag the general
ones — they're candidates to propagate into `CLAUDE.md` as
conventions.

### 4. Write the artifact

Create the file at:

```
docs/plans/<YYYY-MM>/<feature-slug>/compound.md
```

Use the template below.

### 5. Propagate lessons

After writing `compound.md`, check if any lesson deserves to be
lifted into a more durable doc:

- **A new convention or rule** → propose an edit to `CLAUDE.md`
- **A product insight** → propose an edit to `docs/PRODUCT.md`
- **A future feature idea** → add to `docs/ROADMAP.md` post-v1.0
  section
- **A known gotcha** → keep in the compound, maybe reference from
  `CLAUDE.md`

Ask the user: "Lesson X feels general. Should I propose an edit to
`CLAUDE.md` to capture it?"

Don't edit those files silently. The compound doc is the user's to
decide what graduates.

### 6. Mark the PR ready

If a draft PR is open for this feature, this is the moment to suggest
marking it ready for review (or merging if the user is the only
reviewer).

## Artifact template

```markdown
# Compound — <Feature name>

**Date**: <YYYY-MM-DD>
**Status**: complete
**Research**: [research.md](./research.md) *(if exists)*
**Plan**: [plan.md](./plan.md) *(if exists)*
**Branch / PR**: <link>

## Summary

<Two to four sentences: what was built, how it differs from the
initial plan, and what the headline lesson is.>

## Decisions made

<List the concrete choices. For each, one line on the choice and one
line on the reason. Use present tense.>

- **<Decision>**: <One-sentence rationale.>
- **<Decision>**: <One-sentence rationale.>

## Surprises and how we handled them

<Anything that deviated from the plan. Structure each as: what
happened, what we did, what we'd do differently.>

### <Surprise 1 short name>

- **What happened**: <short>
- **What we did**: <short>
- **Lesson**: <short>

## What worked well

<Approaches worth keeping or generalizing.>

- <Thing 1>
- <Thing 2>

## For the next person

<What a future contributor should know when touching this code.
Non-obvious constraints, gotchas, places where the code is cleverer
than it looks.>

## Generalizable lessons

<Lessons that might belong in CLAUDE.md or PRODUCT.md. Mark each with
a suggested destination.>

- **[→ CLAUDE.md]** <Convention or rule.>
- **[→ ROADMAP.md]** <Deferred idea.>
- **[local]** <Only relevant to this feature.>

## Metrics

<Optional. Time spent, lines changed, tests added, etc. Only if
useful.>

- Tasks completed: <n> of <n>
- Tests added: <n>
- Commits: <n>
- Files touched: <n>

## References

<Any external docs, prior art, or issues that ended up being useful.>
```

## Scope discipline

Compound docs should be short — typically 100-200 lines. If it's
longer, the feature was probably too big. Next time, split earlier
at the research or plan stage.

## When to skip compound

Compound is valuable but not always needed. Skip it for:

- Trivial features (one-line fixes, cosmetic changes)
- Experiments that didn't ship
- Features where nothing surprised us and nothing generalizes

When in doubt, do it anyway — it's the cheapest stage.

## No further transition

Compound is the end of the conductor loop for this feature. The next
feature starts with a new research (or plan, or build, depending on
what's needed).
