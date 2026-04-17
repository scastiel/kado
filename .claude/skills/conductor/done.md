# Conductor — Done stage

The done stage is the final pre-merge checklist. It runs after
`compound` (or after `build` if compound was skipped) and answers one
question: **is this PR ready to be merged?**

Unlike earlier stages, `done` produces no Markdown artifact. It's a
structured sweep through everything that should be true before a
merge, reporting gaps to the user.

## What done is for

- Catching the things that are easy to forget right before merge:
  stale PR title, unchecked plan boxes, missing compound, no review.
- Giving the user a single clear verdict: ready to merge, or here
  are the N things blocking.

## What done is not

- A replacement for CI. It doesn't run tests. If the user wants a
  green build, they can say so.
- A gate. The user is still in charge; they may merge despite
  warnings. Done surfaces the state, not a veto.

## The five checks

Run them in this order. **Default to auto-passing a check when the
evidence is already in hand** — don't ask the user to re-confirm
things you can see for yourself. Only escalate to an `AskUserQuestion`
prompt when evidence is actually missing.

Auto-pass rules:

- **Check 1 (code ready)**: auto-pass if you're not aware of any
  remaining temp code, TODOs, debug prints, or stubs in the diff. If
  you planted scaffolding you haven't cleaned up, flag it — otherwise
  assume ready.
- **Check 2 (reviewed)**: auto-pass if `/review` ran earlier in this
  session, or if the user has already responded to review feedback.
  Only ask if there's no trace of review in the conversation.
- **Check 3 (docs up to date)**: auto-pass if `plan.md` status is
  `done`, all checkboxes are `[x]`, and no `## Open questions`
  section remains unresolved. If any of these are off, flag the
  specific gap.
- **Check 4 (compound ran)**: auto-pass if `compound.md` exists and
  is non-trivial (more than the bare template). If it's missing or a
  stub, flag it.
- **Check 5 (PR title/body fresh)**: **just fix it**. If the title or
  description is stale, rewrite and apply via `gh pr edit` without
  asking — the user can always amend afterward. Report what you
  changed in the final verdict.

Only fall back to `AskUserQuestion` when an auto-pass rule actually
can't fire (e.g. no `/review` in session, no `compound.md`, plan
still has open tasks). In that case, batch the remaining questions
into a single tool call.

### 1. Is the code ready to be shipped?

Default: **auto-pass**. Assume the code is ready unless you have
specific reason to doubt it — leftover scaffolding, a TODO you
planted, a known-broken path, an unresolved test failure you saw
earlier. If anything like that lingers, flag it specifically. Don't
re-run `test_sim` / `build_sim` to "be sure" — the user already
verified the feature.

### 2. Has the PR been reviewed?

Default: **auto-pass** if `/review` ran earlier in this session, or
if the user has already iterated on review feedback. Only ask when
there's no trace of review in the conversation — in that case,
suggest running `/review` before proceeding.

### 3. Are the conductor documents up to date?

Read whichever of these exist for the feature:

- `docs/plans/<YYYY-MM>/<feature-slug>/research.md`
- `docs/plans/<YYYY-MM>/<feature-slug>/plan.md`

Auto-pass if all of:
- `plan.md` status line says `done`.
- Every task checkbox in `plan.md` is `[x]` (or explicitly
  skipped/deferred with an inline note).
- No unresolved `## Open questions` section remains.

If any of these are off, flag the specific gap and ask how to
resolve it — don't silently edit the docs, since the user may have
intentionally left a task open.

### 4. Has the compound process run?

Auto-pass if `docs/plans/<YYYY-MM>/<feature-slug>/compound.md` exists
and is non-trivial. If it's missing or a stub, flag it and offer to
run the `compound` stage. Don't write `compound.md` yourself here.

### 5. Are the PR title and description up to date?

This is the one check where the skill **should act** when drift
is detected.

1. Identify the PR: run `gh pr view --json number,title,body` for
   the current branch.
2. Compare the title to the commits on the branch (especially the
   most recent `feat(...)` / `fix(...)` commit subjects). If the
   title still reflects the initial research-stage scope but the
   branch has shipped the full feature, the title is stale.
3. Compare the body to the actual state of the work:
   - Does **Why?** still match?
   - Does **What?** list what actually shipped, not what was
     proposed?
   - Does **How?** link to the current `compound.md` (if it
     exists) alongside `research.md` / `plan.md`?
   - Is **Next steps** still listing resolved open questions as
     if they were open?
4. If drift is found, **just rewrite and apply** with
   `gh pr edit <number> --title ... --body ...`. Don't ask for
   approval first — the user can amend afterward. Show the new
   title + body in the final verdict so the user knows what
   changed.

If the PR title and body already match the shipped state, say so
explicitly — silence looks like failure to check.

## Final verdict

After all five checks, print a single clear verdict:

- **Ready to merge** — all checks passed, no blockers.
- **Ready with caveats** — passes but user chose to override one
  or more warnings (e.g. "skip compound, merging anyway"). List
  the accepted caveats.
- **Not ready** — one or more blockers. List them as bullets, in
  priority order.

Keep the verdict to ~5 lines. The user should be able to read it
and act without scrolling.

## Invocation patterns

The user may start this stage with:

- "Is this ready to merge?"
- "Run done"
- "Let's wrap up and merge"
- "/conductor done"

## When to skip done

For trivial PRs (typo fixes, doc-only changes), the done checklist
is overkill. If the user says "just merge it" on a one-line PR,
don't force the ceremony. For any PR that went through the full
research → plan → build → compound loop, run done before merge.

## No transition after done

Done is terminal. After the user confirms the verdict and merges,
the conductor loop for this feature is closed. The next feature
starts fresh with a new `research` (or whichever stage fits).
