# Plan — Natural-language habit creation

**Date**: 2026-10-15
**Status**: ready to build
**Research**: [research.md](./research.md)

## Summary

Let people create a habit from one typed or dictated sentence — *"run every couple of days"*, *"stop smoking"*, *"floss twice a day"*. Apple's on-device Foundation Models picks the habit's structure; a pure, tested normalizer in KadoCore fixes the literals (counts, durations, weekdays) and guarantees a valid `Frequency` × `HabitType`; a preview card offers *Create* or *Edit*. iOS 26+ with Apple Intelligence only; everyone else keeps today's form, untouched. No network, no new permissions, no schema change.

## Decisions locked in

- Parser is `SystemLanguageModel` (on device), named explicitly. Never `PrivateCloudComputeLanguageModel`, never a generic `any LanguageModel`.
- No rule-based fallback parser; the feature is hidden where the model isn't available.
- Audio is the keyboard's dictation mic. No `Speech` framework, no new `NSUsageDescription`.
- Result is a preview card with *Create* / *Edit*.
- Model output shape is research's v3: `isHabit` first, `Schedule` enum, flat `measure` `anyOf`, optional numbers, `name`, `icon` from `HabitIcon.curated`.
- Deterministic code owns literals and validity (`SentenceLiterals` + `HabitDraftNormalizer`), never the model.
- No SwiftData / CloudKit change.
- *Assumed, pending confirmation (research open questions)*: `+` opens the describe sheet directly with "Set it up manually" inside; refusal / not-a-habit carries the trimmed sentence into the manual form's name; the card keeps the default colour; the eval corpus is an opt-in test.

## Task list

### Task 1: Verify the toolchain path

**Goal**: Know where the real model can run before building on it.

**Changes**:
- None committed except a note appended to `research.md`.

**Tests / verification**:
- `make run` on an iOS 26.5 simulator with a throwaway `#if DEBUG` button printing `SystemLanguageModel.default.availability` and one `respond(to:generating:)` result. Record whether the simulator borrows the host model.
- Same on an iOS 27 simulator.
- Check `supportsLocale(Locale(identifier: "fr_FR"))` there.

**Commit message (suggested)**: `docs(nl-habit): record where the on-device model runs`

---

### Task 2: `HabitDraft` + `SentenceLiterals` (tests first)

**Goal**: Pure EN/FR extraction of times-per-day, minutes and named weekdays.

**Changes**:
- `Packages/KadoCore/Sources/KadoCore/Models/HabitDraft.swift` — `nonisolated struct HabitDraft: Hashable, Sendable { name, frequency, type, icon }`.
- `Packages/KadoCore/Sources/KadoCore/Services/SentenceLiterals.swift` — `timesPerDay(in:) -> Int?`, `minutes(in:) -> Int?`, `weekdays(in:) -> Set<Weekday>?`. Diacritic- and case-insensitive.
- `KadoTests/SentenceLiteralsTests.swift`.

**Tests / verification**:
- `@Test("'twice a day' is 2")`, `"8 glasses"` → 8, `"deux fois par jour"` → 2, `"three times a day"` → 3.
- `"half an hour"` / `"une demi-heure"` → 30, `"1h30"` / `"an hour and a half"` → 90, `"10 min"` → 10.
- `"le mardi et le jeudi"` → `[.tuesday, .thursday]`, `"Mondays, Wednesdays and Fridays"` → three days, `"weekends"` / `"le week-end"` → `[.saturday, .sunday]`, `"weekdays"` → Mon–Fri.
- `"Read three times a week"` → `timesPerDay` nil (per-week counts are not per-day).
- `test_sim` red, implement, green.

**Commit message (suggested)**: `feat(core): extract counts, durations and weekdays from a habit sentence`

---

### Task 3: `HabitDraftNormalizer` (tests first)

**Goal**: Turn any model guess into a valid `HabitDraft`.

**Changes**:
- `Packages/KadoCore/Sources/KadoCore/Services/HabitDraftNormalizer.swift` — input `RawHabitGuess` (plain struct mirroring the model's fields: schedule kind + payload, measure string, optional numbers, name, icon) plus the original sentence.
- `KadoTests/HabitDraftNormalizerTests.swift`.

**Tests / verification**: one test per rule.
- nil `timesPerDay` filled from the sentence; still nil → 2.
- nil `minutes` filled from the sentence; still nil → 10 (the form's default).
- Counter target 1 → `.binary`.
- Weekday lexicon overrides the model's `specificDays` when the sentence names days.
- All 7 specific days → `.daily`; `daysPerWeek(7)` → `.daily`; `everyNDays(1)` → `.daily`.
- `.negative` + `.daysPerWeek` → `.negative` + `.daily`; output always satisfies `NewHabitFormModel.isValid`. Assert that one as an invariant over every schedule × measure combination, not as examples.
- Icon outside `HabitIcon.curated` → `HabitIcon.default`; empty name → capitalised first words of the sentence; name capped at the form's practical length.
- The three headline sentences end-to-end from canned guesses (including research's real wrong outputs).

**Commit message (suggested)**: `feat(core): normalize a model's habit guess into a valid draft`

---

### Task 4: `NewHabitFormModel(draft:)`

**Goal**: The *Edit* and *Create* paths share the existing form model.

**Changes**:
- `Kado/ViewModels/NewHabitFormModel.swift` — `convenience init(draft: HabitDraft)`. Factor the `Frequency`/`HabitType` → kind+params mapping out of `init(editing:)` so both inits use it.
- `KadoTests/NewHabitFormModelTests.swift` — additions.

**Tests / verification**:
- Round-trip: for every `Frequency` × `HabitType`, `NewHabitFormModel(draft:).frequency/.type` equal the draft's.
- `init(editing:)` behaviour unchanged (existing tests stay green).

**Commit message (suggested)**: `refactor(new-habit): seed the form model from a habit draft`

---

### Task 5: Parser protocol + Foundation Models implementation

**Goal**: Sentence in, `HabitDraft` or a typed error out.

**Changes**:
- `Packages/KadoCore/Sources/KadoCore/Services/HabitSentenceParsing.swift` — protocol, `HabitParseError { notAHabit, refused, unavailable, failed }`.
- `Packages/KadoCore/Sources/KadoCore/Services/FoundationModelsHabitParser.swift` — `#if canImport(FoundationModels)`, `@available(iOS 26, *)`; `@Generable GeneratedHabit` (v3), instructions + few-shot examples from `smoke-test.swift`, language hint from `NLLanguageRecognizer`, `prewarm()`, fresh session per call, `GenerationError.refusal` → `.refused`, `isHabit == false` → `.notAHabit`, maps to `RawHabitGuess` → normalizer.
- `HabitParserAvailability` — iOS 26+ ∧ `.available` ∧ `supportsLocale(.current)`.
- `Kado/App/EnvironmentValues+Services.swift` — `@Entry var habitSentenceParser: (any HabitSentenceParsing)?` (nil = feature hidden), set at app root.
- `Kado/Preview Content/MockHabitSentenceParser.swift` — canned drafts and each error, with a delay.

**Tests / verification**:
- Unit: error mapping via a fake that throws each case (the model itself isn't unit-tested).
- `build_sim` on an iOS 26 *and* a 27 destination; `make deployment-check` still passes (no target floor moved).
- Grep the target for `PrivateCloudCompute` — zero hits.

**Commit message (suggested)**: `feat(nl-habit): parse a habit sentence with the on-device model`

---

### Task 6: `DescribeHabitView` + `HabitDraftCard`

**Goal**: The UI, wired to the mock first.

**Changes**:
- `Kado/Views/NewHabit/DescribeHabitView.swift` — enum state `.editing / .parsing / .preview(HabitDraft) / .failed(HabitParseError, sentence)`; vertical `TextField`, Submit guarded synchronously against double taps (CLAUDE.md pattern), "Set it up manually", footer hint about the keyboard mic. Focus is attempted, not relied on.
- `Kado/Views/NewHabit/HabitDraftCard.swift` — icon, name, frequency + type lines via the existing label formatters, *Create* / *Edit*.
- Accessibility identifiers on leaves in the same commit; VoiceOver labels; previews per state plus a `#Preview("Dark")`.
- `Localizable.xcstrings` — EN + FR (`tu`) with comments, hand-authored.

**Tests / verification**:
- `LocalizationCoverageTests` green.
- Previews render every state; screenshots light + dark, Dynamic Type XXXL.

**Commit message (suggested)**: `feat(nl-habit): describe a habit and preview what Kadō understood`

---

### Task 7: Wire into Today

**Goal**: `+` and the empty-state button reach the describe sheet when available.

**Changes**:
- `Kado/Views/Today/TodayView.swift` — new `TodaySheet.describeHabit`; both entry points pick it when `habitSentenceParser != nil`. *Create* saves via `NewHabitFormModel(draft:).save(in:createdAt:)` with the logical-day instant the form already uses; *Edit* swaps to `.newHabit` with the draft-seeded model; failure → manual form with the sentence as name.
- `Kado/Support/UITestSupport.swift` — a launch flag injecting the mock parser so `KadoUITests` doesn't need the model.
- `KadoUITests/DescribeHabitTests.swift` — type a sentence, see the card, Create, row appears on Today; Edit opens a prefilled form.

**Tests / verification**:
- `make test` (26.5 sim), `make e2e`.
- `build_sim` iPhone + iPad; screenshots of each state on the real flow.
- Manual on device / 27 sim with the real model: the three headline sentences in EN and FR, plus one refusal phrase.

**Commit message (suggested)**: `feat(today): open habit creation on a sentence when the model is available`

---

### Task 8: Opt-in eval corpus

**Goal**: A repeatable accuracy number, so prompt tweaks and OS updates are measured, not guessed.

**Changes**:
- `KadoTests/HabitParserEvalTests.swift` — ~30 EN/FR sentences with expected `Frequency` / `HabitType` (from research + new held-out ones), `.enabled(if:)` an env flag *and* model availability. Prints per-field accuracy; asserts a floor (start at what Task 5 achieves, e.g. 80% frequency / 80% type).
- Document the command in `docs/plans/.../compound.md` and CLAUDE.md's testing section.

**Tests / verification**:
- Runs green where the model exists; skipped (not failed) under plain `make test`.

**Commit message (suggested)**: `test(nl-habit): measure the parser against an EN/FR sentence corpus`

## Risks and mitigation

- **Simulator can't run the model** (Task 1): verify with the Mac harness + a device; UI tests already use the mock.
- **Accuracy below the floor**: iterate schema order / guides / examples against the eval corpus before shipping; widen the normalizer only for literals, not structure.
- **Guardrail refusals on harmless sentences**: the friendly failure state + carrying the sentence keeps it to one extra tap. Optionally one retry with the "I want to" prefix stripped — only if the corpus shows it helps.
- **Cold start ~4 s**: `prewarm()` on sheet appear; a progress state in the card area, never a frozen button.
- **Model drift across OS updates**: the eval suite is the canary; run it in each release's checklist.

## Open questions

- [ ] Confirm the four assumptions in "Decisions locked in" (entry point, failure carry-over, colour, eval as test).
- [ ] Should the describe sheet also exist as an App Intent ("Add a habit in Kadō")? Deferred; natural follow-up once the parser exists.

## Out of scope

- Dedicated mic button / `Speech` framework.
- Rule-based parsing for iOS 18–25 or non-Apple-Intelligence devices.
- Parsing reminders ("at 8am") — the draft has no reminder; Edit covers it. A follow-up could add `reminderTime` to the guess.
- Editing an existing habit by sentence.
- Languages beyond EN/FR.
