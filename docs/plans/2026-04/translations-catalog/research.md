---
# Research — Translations catalog for v0.1

**Date**: 2026-04-17
**Status**: ready for plan
**Related**: `docs/ROADMAP.md` (v0.1 → "EN localization (FR arrives in
v1.0, strings prepared now via String Catalog)"), `CLAUDE.md` →
Localization section.

## Problem

Kadō's `Kado/Resources/Localizable.xcstrings` is present but empty.
Meanwhile, the codebase has shipped five feature PRs (Today, New Habit,
Habit Detail, Detail Quick Log, etc.) and accumulated a mix of:
literals wrapped in `String(localized:)`, literals wrapped in plain
`Text(...)` / `Button(...)` (which SwiftUI auto-localizes via
`LocalizedStringKey`), and literals that bypass localization entirely
(e.g. `"Today"` as a `Tab()` title, `"No habits yet"` in
`ContentUnavailableView`). Interpolated strings like
`"\(n) days per week"` are wrapped in `String(localized:)` but have no
plural variants, so the eventual FR translator will hit grammar walls.

v0.1 ships EN only. The goal of this workpackage is to **make the
catalog complete, consistent, and translation-ready** so v1.0's FR
pass becomes a translator's job, not an archaeology expedition.

**"Done" from the user's perspective**: no visible change. Every
string that exists today still reads the same in EN. Under the hood,
the catalog lists every user-facing string, groups them sensibly,
carries a comment explaining each, and declares plural variants where
count-driven grammar will bite FR.

## Current state of the codebase

Inventoried with an Explore subagent. High-level counts (unique keys):

- **~85–95 user-facing strings** across 10 views.
- **~15–20 raw literals** that bypass `String(localized:)` (biggest
  offenders: tab labels in [ContentView.swift:12](Kado/Views/ContentView.swift:12),
  empty states in [TodayView.swift:45](Kado/Views/Today/TodayView.swift:45),
  picker options in [NewHabitFormView.swift:50](Kado/Views/NewHabit/NewHabitFormView.swift:50),
  `TimerLogSheet` buttons).
- **~12 interpolated strings** that need plural variants
  (e.g. `"\(n) days per week"`, `"\(days) days ago"`, `"\(minutes) min"`).
- **Duplicate keys** across views (weekday abbreviations appear in
  both [WeekdayPicker.swift:46–52](Kado/UIComponents/WeekdayPicker.swift)
  and [MonthlyCalendarView.swift:82–88](Kado/Views/HabitDetail/MonthlyCalendarView.swift)).
- **No `NSUsageDescription` strings** (no HealthKit / CloudKit /
  biometrics permission prompts yet — lands in v0.2+).

Nuance worth flagging:
- Accessibility labels are wrapped (`String(localized:)`) in most
  places — good. The Explore pass didn't surface any unwrapped
  accessibility strings.
- `Text(_ key: LocalizedStringKey)` and `Button(_ titleKey:)` already
  go through the catalog automatically. Much of the "raw literal"
  count is **already localized** — the `Text("Cancel")` in
  `NewHabitFormView` feeds a `LocalizedStringKey`, same as
  `String(localized:)`. The catalog just needs a populated key named
  `"Cancel"`.
- That said, `String(localized:)` vs bare string-literal-init
  (`Tab("Today", ...)`, `ContentUnavailableView("No habits yet", ...)`)
  behavior varies by API. Some are `String`-typed and won't localize
  without explicit wrapping. This needs per-call-site verification,
  not a blanket rule.

## Proposed approach

**Two passes, one catalog file, no runtime behavior change.**

### Pass 1 — Normalize call sites

Sweep every view and pick **one of two idioms** per string:
- `Text("foo")` / `Button("foo")` / `Label("foo", systemImage: ...)`
  where the SwiftUI initializer accepts `LocalizedStringKey`. This is
  the cleanest form and auto-populates the catalog on build.
- `String(localized: "foo", comment: "…")` for `String`-typed APIs
  (`Tab(_:image:)` title, `TextField` placeholder, `navigationTitle`
  when conditional, accessibility labels).

Explicitly flag which APIs need which — the `Tab()` / `ContentUnavailableView`
cases are where we currently leak.

**Rule of thumb**: if Xcode's "Use Compiler to Extract Swift Strings"
doesn't pick it up on next build, it's not localized.

### Pass 2 — Populate the catalog

1. Delete the empty catalog and rebuild so Xcode auto-extracts every
   `LocalizedStringKey` and `String(localized:)` call into the
   `.xcstrings` file. (Xcode 16 does this natively when
   `LOCALIZATION_PREFERS_STRING_CATALOGS = YES`.)
2. **Add translator comments** on every key. Comment format (short,
   imperative, context-first): `"Toolbar button that opens the new-habit sheet"`,
   `"Accessibility label announced when VoiceOver focuses the done toggle"`.
3. **Declare plural variants** for the 12 interpolated keys. In
   `.xcstrings` this is done via the "Vary by plural" UI; each entry
   gets `one`/`other` buckets. EN rarely needs this (N=1 vs N=other),
   but the structure must exist so the FR translator can write
   `"un jour"` / `"deux jours"` without touching Swift.
4. **De-duplicate**: weekday labels consolidated to one set of keys
   (`"weekday.short.monday"`-style namespaced keys, or plain `"Mon"`
   if we trust catalog de-duping — decision deferred to plan stage).
5. Verify build is warning-free and `test_sim` still green.

### Key components

- **The catalog itself** (`Kado/Resources/Localizable.xcstrings`): the
  sole source of truth. No secondary `.strings` file, no generated
  Swift enum for keys (adds a dependency-like indirection we don't
  need at v0.1 scale).
- **SwiftUI views** (all 10 under `Kado/Views/`): normalized call
  sites, no raw `String` literals on user-facing surfaces.
- **`docs/plans/…/compound.md`** (produced at wrap-up): a short "how
  we localize" note that replaces ad-hoc decisions with a team
  (currently: solo) convention.

### Data model changes

None.

### UI changes

None visible. The output of every view must be byte-identical in EN
before and after.

### Tests to write

Localization is notoriously under-tested because Xcode's build-time
extraction catches most bugs. Proposed minimal suite:

```swift
@Test("Every user-facing view builds with a pseudo-locale without fatal errors")
// Render each primary View with `.environment(\.locale, Locale(identifier: "en-XA"))`
// (Xcode's accented-pseudo-locale) and ensure no runtime crash. This
// surfaces missing keys as "[Missing]" placeholders rather than
// silent fallbacks.
```

Alternatively skip tests — the extraction step is compile-time
authoritative. **Open question below.**

## Alternatives considered

### Alternative A: Generated Swift enum for string keys

Tools like SwiftGen emit `L10n.today.emptyTitle` constants. Removes
typo risk, breaks on missing keys at compile time.

- **Why not**: adds a code-gen step and a dev dependency. CLAUDE.md
  forbids third-party deps for v0.x. Xcode 16's catalog already
  auto-extracts and warns on unused keys. Reassess if the catalog
  grows past ~300 keys or we ship multiple modules.

### Alternative B: Defer the whole pass until v1.0

Ship v0.1 as-is, fix everything when FR translation starts.

- **Why not**: ROADMAP explicitly calls this out as v0.1 scope
  ("strings prepared now via String Catalog"). The longer we wait,
  the more debt accumulates — v0.2 adds widgets, notifications,
  CSV/JSON import/export flows with tons of new strings and
  `NSUsageDescription` entries. Doing this now while the surface is
  ~90 strings is cheap; doing it at v1.0 with 300+ is not.

### Alternative C: Also seed FR translations now

Start FR in v0.1, even partial.

- **Why not** (rejected on user call — scope (b)): translator quality
  matters more than speed, and CLAUDE.md mandates native FR (not
  machine-translated). Better to do one clean FR pass at v1.0 than
  drip-feed and accumulate inconsistencies.

## Risks and unknowns

- **Catalog auto-extraction scope**: Xcode extracts from
  `LocalizedStringKey` and `String(localized:)`, but not from
  `String(...)` init with a variable. Any dynamic string (e.g.,
  `habit.name` interpolated into an accessibility label) is exempt
  from the catalog — only the **format string** gets extracted. Need
  to verify each interpolated accessibility label in
  [HabitRowView.swift:109](Kado/UIComponents/HabitRowView.swift:109)
  has its literal shell (`"%@, counter, target %lld"`) extracted
  cleanly, not the interpolated result.
- **`.xcstrings` JSON diff noise**: the file format is a big JSON
  blob. Every build rewrites key order occasionally. Pre-commit
  hook or a stable-sort script might be needed if diffs become
  unreadable. Defer unless it bites.
- **DateFormatter/NumberFormatter usage**: these are locale-aware
  already (they read `Locale.current`), so nothing to do at the
  catalog level. But calls like `String(format: "%02d:%02d", ...)`
  in [HabitRowView.swift:115–119](Kado/UIComponents/HabitRowView.swift:115)
  are not — that's a distinct concern (RTL, Arabic numerals) deferred
  to v1.0+.
- **Swift 6 warnings**: enabling strict localization (the
  `SWIFT_STRICT_CONCURRENCY`-adjacent `LOCALIZATION_EXPORT_SUPPORTED`
  setting) may surface new warnings. Verify build stays green.

## Resolved decisions

- [x] **Testing**: manual for v0.1 (compile-time extraction +
      `-AppleLocale en_XA` launch argument spot-check on each view).
      Formalize a pseudo-locale smoke test in the v1.0 pre-FR pass,
      when a regression would actually hurt.
- [x] **Key naming**: **English text as the key**. This is the Xcode 16
      default and what the catalog auto-extractor produces. If two
      different English strings need distinct translations, use
      `comment` to disambiguate; only fall back to namespaced keys
      for that specific conflict.
- [x] **Weekday labels consolidation**: extract
      `Weekday.localizedShort` / `.localizedFull` helpers on the
      `Weekday` enum. One source of truth, removes drift risk between
      `WeekdayPicker` and `MonthlyCalendarView`.
- [x] **Scope of the normalization pass**: the `String(format:)` time
      formatter in `HabitRowView` / `CompletionHistoryList` is
      **out-of-scope**. It's a formatter concern, not a catalog
      concern. Flag as follow-up; handle with a DateComponentsFormatter
      migration in a separate PR (likely pre-v1.0 alongside the FR
      pass).

## References

- [Xcode 16 String Catalogs — Apple docs](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog)
- [WWDC23 "Discover String Catalogs"](https://developer.apple.com/videos/play/wwdc2023/10155/)
- CLAUDE.md → Localization ("Every user-facing string goes through
  `String(localized:)`")
- Prior `docs/plans/2026-04/` entries for surrounding context
  (`today-view`, `new-habit-form`, `habit-detail-view`,
  `detail-quick-log`).
