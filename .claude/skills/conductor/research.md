# Conductor — Research stage

The research stage understands the problem before any code gets
written. It produces a `research.md` artifact that captures the
current state of the codebase, the problem being solved, and an
initial solution sketch.

## What research is for

- Making implicit knowledge explicit.
- Surfacing constraints and dependencies that the implementer would
  otherwise discover mid-work.
- Identifying open questions to resolve before planning.
- Documenting alternative approaches considered and why the preferred
  one was chosen.

## What research is not

- An academic exercise. Keep it practical.
- A replacement for reading code. You still read code, but you
  capture what you found.
- A commitment. Research can conclude "we shouldn't build this" or
  "let's defer this."

## Workflow

### 1. Clarify the feature name and scope

Before writing anything, confirm with the user:
- A short feature name that will become the slug (e.g.
  `habit-score-calculator`)
- The core problem in one or two sentences
- The intended scope: MVP only? Full feature? Specific sub-problem?

If the user hasn't given a clear scope, ask. Don't guess on something
this foundational.

### 2. Survey the codebase

Read the relevant parts of the project:
- Existing models, services, views that will be touched or adjacent
- Related specs in `docs/` (for Kadō: `PRODUCT.md`, `ROADMAP.md`,
  `habit-score.md` when relevant)
- Any prior `docs/plans/` entries for related features

Use the codebase tools efficiently. Don't dump entire files into the
research doc — summarize and link.

### 3. Formulate the problem

Write the problem clearly. A well-formed problem statement usually
answers:
- What does the user need that they don't have now?
- What constraint (technical, product, UX, time) frames the solution?
- What does "done" look like from the user's perspective?

### 4. Sketch a solution (or several)

Propose one or more approaches. For each:
- Core idea in plain language
- Key components it would touch
- Trade-offs vs alternatives
- Approximate effort

If the approach is obvious, one sketch is fine. If there's genuine
uncertainty, sketch 2-3 and note which you'd recommend and why.

### 5. Ask open questions

When something can't be resolved without input from the user, note it
as an **open question**. Examples:
- "Should the score be recomputed on every view render or cached?"
- "Do we expose α as a power-user setting now, or defer?"
- "Is this feature gated behind a user preference?"

The user may answer immediately, or defer. Both are fine. Deferred
questions carry forward to the planning stage.

### 6. Write the artifact

Create the file at:

```
docs/plans/<YYYY-MM>/<feature-slug>/research.md
```

Use the template below. Keep it skimmable — headers, short
paragraphs, bullet points for lists of items, prose for reasoning.

### 7. Suggest a draft PR

Once the file is committed, suggest opening a draft PR. Something
like:

> The research is captured. Want me to open a draft PR so we can
> iterate on it and track the work? I'd branch off `main` as
> `feature/<slug>` and push this commit.

If the user agrees, do it. If they decline or prefer a different
workflow, move on without pushing.

## Artifact template

```markdown
# Research — <Feature name>

**Date**: <YYYY-MM-DD>
**Status**: draft | ready for plan | archived
**Related**: <links to ROADMAP section, other docs, issues>

## Problem

<One to three paragraphs. What needs solving, why it matters, who
benefits.>

## Current state of the codebase

<What exists today that this feature will touch or build on. Link to
specific files/types. Include what's missing, not just what's there.>

## Proposed approach

<The recommended solution. If multiple were considered, state the
chosen one here and move alternatives to the section below.>

### Key components

- <Component 1>: <what it does>
- <Component 2>: <what it does>

### Data model changes

<If any. SwiftData @Model changes, new types, migrations needed.>

### UI changes

<If any. New views, modified flows.>

### Tests to write

<Concrete test cases, ideally in `@Test("…")` format.>

## Alternatives considered

<One subsection per alternative. Why it was rejected or deferred.>

### Alternative A: <name>

- Idea: <short>
- Why not: <short>

## Risks and unknowns

<Things that might go wrong or need validation during build.>

## Open questions

- [ ] <Question 1>
- [ ] <Question 2>

## References

<Links to Apple docs, prior art, relevant PRs, external articles.>
```

## Scope discipline

Keep `research.md` under ~300 lines. If it's ballooning, the feature
is probably too big and should be split. Suggest splitting to the
user before writing a 500-line research doc.

## Transition to plan

When research is sufficient, the user will typically say something
like "ok, let's plan this" or "looks good, break it down." That's the
cue to load `plan.md` and move to the planning stage.

If the user wants to skip planning and go straight to build, confirm
once: "Sure — skipping the plan stage. We'll build directly from the
research. Want me to proceed?" Then proceed.
