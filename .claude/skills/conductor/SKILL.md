---
name: conductor
description: Guides feature development through a five-stage workflow — research, plan, build, compound, done — with Markdown artifacts generated at each stage. Use when the user asks to work on a new feature, investigate a problem, draft a plan, start an implementation, wrap up a completed piece of work, or check whether a PR is ready to merge. Also triggers on explicit requests like "do some research on X", "let's plan Y", "build the Z feature", "let's compound what we just did", or "is this ready to merge".
---

# Conductor — Feature Development Workflow

Conductor is a lightweight workflow that structures feature development
into five optional stages: **research → plan → build → compound → done**.
Each of the first four stages produces a Markdown artifact stored under
`docs/plans/`; `done` is a pre-merge checklist with no artifact.

## Core principle: flexibility over imposition

This workflow is a **suggestion, not a mandate**. The user is always in
charge. Concretely:

- Any stage can be skipped. Plan without prior research is valid.
  Compound on research alone is valid. Build without a written plan is
  valid if the user says so.
- If a stage is skipped, **ask the user to confirm** that's what they
  want. Don't silently bypass steps.
- The user can pause at any point. Questions left open are marked as
  such and carried forward to the next stage.
- The user can return to an earlier stage. Re-running `research` on a
  feature that already has a plan should append to or revise the
  existing research doc, not overwrite blindly.

## Stages at a glance

| Stage | Purpose | Artifact |
|---|---|---|
| `research` | Understand the problem, survey the codebase, sketch solutions | `research.md` |
| `plan` | Turn research into an ordered, concrete task list | `plan.md` |
| `build` | Implement the plan, committing regularly | (code changes) |
| `compound` | Capture decisions, surprises, lessons for the future | `compound.md` |
| `done` | Pre-merge checklist: code ready, reviewed, docs current, compound run, PR title/body fresh | (no artifact) |

Detailed instructions for each stage live in separate files to keep
this overview short. Load them as needed:

- For research: read `research.md`
- For planning: read `plan.md`
- For implementation: read `build.md`
- For wrap-up: read `compound.md`
- For pre-merge checklist: read `done.md`

## Directory convention

All artifacts go under:

```
docs/plans/<YYYY-MM>/<feature-slug>/
├── research.md
├── plan.md
└── compound.md
```

Where:
- `<YYYY-MM>` is the ISO year-month of when work **started**. Example:
  `2026-04`. Work that spans multiple months stays in the month it
  started.
- `<feature-slug>` is a short, lowercase, hyphenated name derived from
  the feature. Example: `habit-score-calculator`, `csv-export`,
  `watch-app-mvp`.

Create directories as needed. Don't ask permission to `mkdir -p`.

## Git workflow (suggested, not enforced)

When a stage produces an artifact, **suggest** opening a draft PR:

1. The moment `research.md` is committed, suggest: "Want me to open a
   draft PR for this? It makes it easy to track the work and come back
   to it."
2. If the user agrees, create a branch named after the feature slug
   (e.g. `feature/habit-score-calculator`), commit the doc, push, and
   open the draft PR.
3. During `build`, suggest frequent small commits — one per logical
   unit of work, not one giant commit at the end.
4. When `compound.md` lands, the PR can be marked ready for review.

If the user prefers a different Git flow (working directly on main,
squash-and-merge, etc.), respect that. The goal is visibility and
reversibility, not a specific ceremony.

## Invocation patterns

The user may start a stage with phrasings like:

- **Research**: "Let's research X", "What's the best way to do Y?",
  "Investigate the Z module before we touch it"
- **Plan**: "Let's plan this out", "Break this down into tasks",
  "Plan the implementation"
- **Build**: "Start implementing", "Let's build this", "Work on the
  first task"
- **Compound**: "Let's wrap this up", "Capture what we learned",
  "Write the postmortem"
- **Done**: "Is this ready to merge?", "Run done", "Let's wrap up and
  merge"

When a stage is invoked, load its instruction file and follow it. Don't
try to do all stages in one go — each produces a checkpoint the user
can review before moving on.

## Asking the user questions

Every stage involves points where you need a decision from the user —
resolving open questions in `research`, confirming task order in
`plan`, picking between two implementations in `build`, confirming
pre-merge checks in `done`. **Use the `AskUserQuestion` tool for
these prompts**, not free-form prose.

Why:

- The question UI renders as a structured picker the user can answer
  with a click rather than typing.
- Multiple related questions can be batched in one call instead of
  chained round-trips.
- Options force you to pre-think the answer space, which catches
  sloppy binary framings ("yes/no") when a third option exists.

When to reach for it:

- **Any time you'd otherwise write "Should I X or Y?"** — that's an
  `AskUserQuestion` call with two options.
- Confirming a stage transition (research → plan, plan → build).
- `done`'s first four checks — each is a clean yes/no confirmation
  that belongs in the tool, not in a paragraph.
- Resolving an open question carried forward from an earlier stage.

When not to reach for it:

- Pure acknowledgments ("Ok", "Go") where you're not actually asking
  anything — just proceed.
- Open-ended prompts with no enumerable answer space ("What should
  we call this feature?") — free-form text is fine.
- Mid-sentence confirmations that interrupt flow. Batch them up and
  ask once at a checkpoint.

Keep question titles short (≤12 chars), option labels ≤12 chars, and
descriptions ≤25 chars so the UI renders cleanly. Always include an
"Other" option with `multiSelect: false` unless you're certain the
options are exhaustive.

## Open questions

Each artifact may end with an **Open questions** section. These are
things the user hasn't decided yet. When moving to a later stage,
surface these open questions again and ask whether they should be
resolved now or carried forward.

## When not to use conductor

This skill is for feature-sized work that benefits from structure. For
small tasks (fix a typo, rename a variable, one-line bug fix), skip
the workflow and act directly. If unsure, ask the user whether they
want the structured flow or a quick edit.
