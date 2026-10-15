# Research — Natural-language habit creation

**Date**: 2026-10-15
**Status**: ready for plan
**Related**: `Kado/ViewModels/NewHabitFormModel.swift`, `Kado/Views/Today/TodayView.swift`, [smoke-test.swift](./smoke-test.swift)

## Problem

Creating a habit today means walking the New Habit form: name, frequency picker, type picker, a number, an icon. People think of a habit as one sentence — *"I want to go for a run every couple of days"*, *"I want to stop smoking"*, *"I want to floss twice each day"* — and the form makes them translate it into Kadō's vocabulary by hand.

The feature: type or dictate the sentence, see the habit Kadō understood, create it in one tap or adjust it first.

The framing constraint is Kadō's privacy rule: **no network calls outside CloudKit and HealthKit**. Any cloud LLM is out. The parsing has to happen on the device.

## Decisions taken with the user (2026-10-15)

- **Parser: Apple Foundation Models only.** No rule-based fallback parser. The feature is simply absent on iOS 18–25 and on devices without Apple Intelligence; the manual form is unchanged for everyone.
- **Audio = keyboard dictation.** The system keyboard's mic already transcribes on device. No `Speech` framework, no microphone or speech-recognition permission.
- **Result = a preview card** with *Create* and *Edit*, not a silent create and not a jump straight into the form.
- **This job stops at research + plan.**

## Current state of the codebase

- **The domain already covers every example sentence.** `Frequency` has `.daily`, `.daysPerWeek(Int)`, `.specificDays(Set<Weekday>)`, `.everyNDays(Int)`. `HabitType` has `.binary`, `.counter(target:)`, `.timer(targetSeconds:)`, `.negative`. "Run every couple of days" = `.everyNDays(2)` + `.binary`; "stop smoking" = `.daily` + `.negative`; "floss twice each day" = `.daily` + `.counter(target: 2)`. **No schema change is needed.**
- **`NewHabitFormModel`** holds the draft with one stored property per variant (the "picker over associated-value enums" pattern) and already has a second init, `init(editing:)`. A third, `init(draft:)`, is the natural seam for *Edit*. `isValid` rejects `.negative` + `.daysPerWeek` — the parser must never hand the form that combination.
- **Entry points**: the Today toolbar `+` (`TodayView.swift:187`, `AccessibilityID.Today.newHabitButton`) and the empty state's "Create your first habit" (`TodayView.swift:270`). Both set `sheet = .newHabit`, which renders `NewHabitFormView(model: NewHabitFormModel())`.
- **`HabitIcon.curated`** is a ~30-symbol list the model can choose from with a `.anyOf` guide, so it can't invent a symbol that doesn't exist.
- **Nothing imports `FoundationModels`, `Speech` or `NaturalLanguage` today.** Every target's deployment floor is 18.0 and must stay there (#97), so all model code is `@available(iOS 26, *)`; the framework weak-links automatically.

## SDK facts verified (Xcode 27.1, iOS 27.1 SDK `.swiftinterface`)

- `SystemLanguageModel` is iOS 26.0+. `availability` is `.available` or `.unavailable(.deviceNotEligible | .appleIntelligenceNotEnabled | .modelNotReady)`. `supportsLocale(_:)` is synchronous on it.
- `@Generable` / `@Guide` support `.anyOf([String])`, `.range(ClosedRange<Int>)`, `.count(...)` on arrays, and `@Generable` enums with associated `@Generable` payloads.
- **iOS 27 adds `PrivateCloudComputeLanguageModel`** — a server-side model behind the same `LanguageModel` protocol. Using it would be a network call and breaks the privacy rule. The code must name `SystemLanguageModel` explicitly and never accept a generic `any LanguageModel`.
- `Guardrails.permissiveContentTransformations` exists but does **not** cover structured (`@Generable`) generation — verified below.

## Smoke test (the load-bearing claim)

Ran [smoke-test.swift](./smoke-test.swift) against the real on-device model on the host Mac (macOS 26.6, same system model as iOS 26) with 19 EN/FR sentences, three schema shapes. Full output is in the job log; the shape of it:

| Schema | Frequency right | Type right | Notes |
|---|---|---|---|
| v1 flat strings + ints | ~3/10 | ~5/10 | "every couple of days", "3×/week", "Mon/Wed/Fri" all became a daily counter |
| v2 `Schedule` enum + `Measure` enum, few-shot examples | ~12/17 | ~3/17 | schedule fixed; measure collapsed onto `.count` with junk (10, 20, 30) |
| v3 `Schedule` enum + flat `measure` `anyOf` + optional numbers | ~10/12 | ~9/12 | best; numbers sometimes nil |

Findings that shape the design:

1. **Latency is fine**: ~4 s cold, ~1.1–1.7 s warm. `prewarm()` when the input appears hides the cold start.
2. **Schema shape matters more than prompt wording.** Schedule as an enum with one case per `Frequency` and its own payload, generated *before* the measure, cut frequency/count confusion sharply. Declaration order is generation order.
3. **The numbers are unreliable.** `"Brush teeth twice a day"` → `measure: timesPerDay, timesPerDay: nil`; `"Lire 20 minutes chaque soir"` → `minutes, minutes: nil`. Non-optional ranged ints are worse (they get filled with junk). A deterministic post-pass over the sentence (digits, *once/twice/thrice*, *deux fois*, *half an hour*, *une demi-heure*) should own the literals.
4. **Weekday literals slip**: "le mardi et le jeudi" → `[monday, thursday]`. Same remedy: an EN/FR weekday lexicon corrects the list when the sentence names days.
5. **Guardrail false positives are deterministic and phrase-specific.** `"I want to floss twice each day"` and `"Meditate 10 minutes every morning"` are refused (`GenerationError.refusal`, "May contain sensitive content") every time, with either guardrail setting; `"floss twice a day"` and `"meditate every day"` pass. Refusal must be a first-class, non-scary outcome that routes to the manual form.
6. **The model accepts nonsense as habits unless asked.** An `isHabit: Bool` field generated first correctly rejected "kill my neighbour" and "what's the weather".
7. **Names drift language**: "Méditer 10 minutes" → name "Meditate". Telling the model the sentence's language (via `NLLanguageRecognizer`, on device) is the cheap fix to try.
8. **Icons are weak** (`figure.yoga` for Gym, Call mom, snacking). Accept it: the card shows the icon and Edit fixes it; constrain to `HabitIcon.curated` so it's at least valid.

Overall: the model gets the *structure* mostly right and the *literals* often wrong. A preview card is not optional polish; it's what makes ~70–80% accuracy acceptable.

## Proposed approach

**Model decides the structure; deterministic code owns the literals and the validity.**

```
sentence ──▶ HabitSentenceParser (FoundationModels, iOS 26+)
                │  GeneratedHabit (@Generable: isHabit, schedule, measure, numbers?, name, icon)
                ▼
            HabitDraftNormalizer (KadoCore, pure, fully unit-tested)
                │  + SentenceLiterals (number / duration / weekday lexicon, EN+FR)
                ▼
            HabitDraft (domain value: name, Frequency, HabitType, icon) — always valid
                ▼
            HabitDraftCard ── Create ──▶ NewHabitFormModel(draft:).save(in:)
                          └─ Edit ────▶ NewHabitFormView(model: NewHabitFormModel(draft:))
```

### Key components

- **`HabitDraft`** (KadoCore, `nonisolated struct`): name, `Frequency`, `HabitType`, icon. Model-free, so the normalizer, form model and previews never touch FoundationModels.
- **`SentenceLiterals`** (KadoCore, pure): extracts times-per-day, a duration in minutes, and named weekdays from EN/FR text. Small lexicons, no NLP.
- **`HabitDraftNormalizer`** (KadoCore, pure): maps a model-agnostic `RawHabitGuess` (strings/optionals, what the model returned) plus the sentence into a valid `HabitDraft`. Owns every rule: fill nil numbers from literals; weekday lexicon overrides the model's list; `specificDays` of all 7 → `.daily`; `daysPerWeek(7)` → `.daily`; `everyNDays(1)` → `.daily`; `.negative` + `.daysPerWeek` → `.negative` + `.daily`; counter target 1 → `.binary`; clamp ranges; icon outside `HabitIcon.curated` → default; name trimmed and capped.
- **`HabitSentenceParsing`** protocol (`func parse(_:) async throws(HabitParseError) -> HabitDraft`) with `HabitParseError`: `.notAHabit`, `.refused`, `.unavailable`, `.failed`. Injected via `@Entry` so previews and tests use a mock.
- **`FoundationModelsHabitParser`** (`@available(iOS 26, *)`): the `@Generable GeneratedHabit` (v3 shape), instructions with few-shot examples, `SystemLanguageModel.default` named explicitly, `prewarm()`, a fresh session per parse, language hint, error mapping.
- **`HabitParserAvailability`**: one place answering "show the describe entry?" — iOS 26+, `.available`, and `supportsLocale(.current)`.

### Data model changes

None. No `@Model` change, no schema bump, nothing for CloudKit.

### UI changes

- **`DescribeHabitView`** — a sheet: multi-line `TextField` ("e.g. Run every couple of days"), auto-focused where the OS allows (CLAUDE.md: never *depend* on it), Submit button, "Set it up manually" link. The keyboard's mic is the audio path; a footer line says so. View state is an enum: `.editing`, `.parsing`, `.preview(HabitDraft)`, `.failed(HabitParseError)`.
- **`HabitDraftCard`** — icon + name, a frequency line and a type line rendered with the same formatters the habit rows use, *Create* (prominent) and *Edit*. Failure states say why in human terms and offer the manual form.
- **Entry**: when the parser is available, `+` opens `DescribeHabitView` instead of the blank form; when it isn't, nothing changes. (Open question below on whether `+` should be a menu instead.)
- EN + FR catalog entries with comments; VoiceOver labels on the card; Dynamic Type XXXL.

### Tests to write

- `SentenceLiteralsTests`: `"twice a day"` → 2, `"8 glasses"` → 8, `"deux fois par jour"` → 2, `"half an hour"` → 30, `"une demi-heure"` → 30, `"1h30"` → 90, `"le mardi et le jeudi"` → `[.tuesday, .thursday]`, `"weekends"` → `[.saturday, .sunday]`, no false weekday hit on `"Sundays are hard"`… (decide on that one in build).
- `HabitDraftNormalizerTests`: one test per rule above, plus the three headline sentences end-to-end from a canned `RawHabitGuess`.
- `NewHabitFormModelTests`: `init(draft:)` round-trips every `Frequency` × `HabitType` and the result `isValid`.
- `HabitParserEvalTests` (opt-in, not in `make test`): the EN/FR corpus from the smoke test against the real model, reporting per-field accuracy. Runs on a simulator only if the host Mac has Apple Intelligence on — to be confirmed in build.

## Alternatives considered

### Rule-based parser (alone or as fallback)
- Idea: regex/lexicon grammar for EN/FR; works on iOS 18 and every device.
- Why not: the user chose FM only. Note that `SentenceLiterals` is a deliberately tiny slice of it — literals, not structure.

### Dedicated mic button with the `Speech` framework
- Idea: tap-to-talk, on-device `SpeechAnalyzer` (iOS 26) transcription.
- Why not now: adds microphone + speech permissions (EN/FR usage strings, revoke UI, fallback) for something the keyboard mic already does. Revisit if users don't discover dictation.

### Prefill the form directly
- Idea: skip the card, open the form filled in.
- Why not: the user chose the card; it also keeps the one-tap path for the common case.

### Private Cloud Compute model (iOS 27)
- Why not: it's a network call. Excluded by the privacy principles, not a trade-off.

## Risks and unknowns

- **Accuracy**: ~75% field accuracy in the smoke test. Mitigated by the normalizer and the card; measured by the eval suite. If it stays low, the card leans harder on Edit.
- **Refusals on harmless sentences** (finding 5). Mitigation: friendly copy + one tap to the manual form with the sentence carried as the name. Possibly retry once with the sentence stripped of "I want to"; measure first.
- **Simulator support**: unverified whether an iOS 26.5 simulator can run `SystemLanguageModel` (it borrows the host model when Apple Intelligence is on). Verify in Task 1; if not, verification is the Mac smoke harness + a device.
- **Model drift**: the system model changes with OS updates; the eval corpus is how we notice.
- **`supportsLocale`** for French on device — true on the Mac; confirm on an iOS device set to French.
- **Programmatic focus** is unreliable on 26.5 (CLAUDE.md); the sheet must work with a manual tap into the field.

## Open questions

- [ ] Should `+` open the describe sheet directly (one tap to type), or become a menu "Describe a habit / Set up manually" (discoverable, one tap more)? Recommendation: open the sheet, with "Set it up manually" inside it.
- [ ] On refusal / not-a-habit, carry the raw sentence into the manual form's name field, or open the form empty? Recommendation: carry it, trimmed.
- [ ] Should the card guess a colour, or keep the form's default? Recommendation: default — colour is taste, not content.
- [ ] Ship the eval corpus as a test target member (opt-in env flag) or as a Mac script beside this doc? Recommendation: test, so it uses the real types.

## References

- FoundationModels: https://developer.apple.com/documentation/foundationmodels
- Guided generation: https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation
- Availability: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum
- NaturalLanguage `NLLanguageRecognizer`: https://developer.apple.com/documentation/naturallanguage/nllanguagerecognizer
