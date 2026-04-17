---
# Compound — Translations catalog for v0.1

**Date**: 2026-04-17
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**Branch / PR**: [feature/translations-catalog](https://github.com/scastiel/kado/tree/feature/translations-catalog) → [kado#9](https://github.com/scastiel/kado/pull/9)

## Summary

Populated `Localizable.xcstrings` with ~60 hand-authored entries,
each carrying a translator comment and — for three count-driven
interpolations — EN plural variants. Source code was already largely
localization-ready; only two genuine fixes landed. The headline
lesson: **research over-counted the work** because it conflated
"raw string literal" with "bypasses localization." Most SwiftUI
`Text`/`Button`/`Label`/`ContentUnavailableView` inits accept
`LocalizedStringKey`, so a bare `Text("Today")` is already on the
localized path.

## Decisions made

- **Use `Calendar.*StandaloneWeekdaySymbols` for weekday labels**:
  replaces 21 hand-rolled catalog entries (short + full × 7 days)
  with system-localized symbols that work in every language Apple
  ships, and sidesteps the EN-level `"T"/"T"` / `"S"/"S"` collision
  problem entirely.
- **English text as catalog keys**: Xcode 16's default, no
  namespacing except where EN collisions force it (none ended up
  needing it post-weekday pivot).
- **Hand-author the catalog JSON** instead of relying on Xcode
  auto-extraction: `xcodebuild` (MCP) doesn't sync the `.xcstrings`
  file during non-interactive builds, only Xcode IDE does. Hand-
  authoring is additive — Xcode will merge new extractions with
  existing entries on the next IDE open.
- **Plural variants on 3 keys only**: `"%lld days per week"`,
  `"Every %lld days"`, `"%lld days ago"`. Other count-driven keys
  like `"Target: %lld"` and `"of %lld"` appear after a colon or
  inside a phrase where the singular form reads naturally in EN
  and most target languages — not worth the plural machinery.
- **Time formatter migration (`String(format:)` →
  `DateComponentsFormatter`) deferred**: scoped out of this PR.
  Separate pre-v1.0 task, tracked only in `research.md`'s
  out-of-scope.
- **Pseudo-locale verification deferred**: MCP can't toggle Xcode's
  scheme-level "Include accented pseudo-language" option. Formal
  accented-pseudo sweep happens at v1.0 pre-FR from the Xcode IDE.

## Surprises and how we handled them

### Research over-counted the work

- **What happened**: the Explore agent's inventory flagged ~15–20
  "raw literals that bypass localization." Upon close reading,
  almost all of them were already going through `LocalizedStringKey`
  via SwiftUI initializers (`Tab(_:systemImage:)`,
  `ContentUnavailableView(_:systemImage:description:)`,
  `Button("..")`, `Label("..", systemImage:)`,
  `.navigationTitle("..")`, `Text("..")`).
- **What we did**: verified each call site against Apple's signatures
  before writing Swift. Tasks 2 and 3 collapsed to no-ops. Only two
  genuine fixes remained: a ternary `Text(cond ? "A" : "B")` that
  risks collapsing to the non-localizing `StringProtocol` overload,
  and a raw `"\(habit.name), \(state)"` concatenation in
  `HabitRowView.accessibilityLabelText`.
- **Lesson**: "raw literal" is not a reliable heuristic for "needs
  fixing." Before concluding a call site leaks, check the init
  signature — SwiftUI's APIs default to `LocalizedStringKey` more
  often than you'd expect.

### Weekday labels had a latent bug we nearly papered over

- **What happened**: the plan called for hand-rolled catalog entries
  for each weekday, matching the pre-existing `String(localized: "M", comment: "Short Monday label")` pattern in
  `WeekdayPicker`. That pattern has a latent bug: Xcode collapses
  `"T"` with a Tuesday comment and `"T"` with a Thursday comment
  into one catalog entry. The FR translator would be forced to pick
  one of `"M"`/`"J"` for both.
- **What we did**: switched to `Calendar.*StandaloneWeekdaySymbols`,
  eliminating the hand-rolled entries entirely.
- **Lesson**: when Swift's localization API lets two distinct
  concepts share a key, the only safe options are (a) let the
  system provide the strings, or (b) disambiguate keys explicitly.
  Relying on comments to keep them separate does not work —
  Xcode merges by key.

### `xcodebuild` doesn't auto-populate `.xcstrings`

- **What happened**: `LOCALIZATION_PREFERS_STRING_CATALOGS=YES` and
  `SWIFT_EMIT_LOC_STRINGS=YES` are both on. Built the app five
  times during Task 1; the catalog stayed empty after each build.
- **What we did**: confirmed via project.pbxproj that the catalog
  is included via `PBXFileSystemSynchronizedRootGroup` (so Xcode
  *should* see it), but accepted that the auto-populate step only
  runs in the Xcode IDE. Pivoted to hand-authoring.
- **Lesson**: for non-interactive (CI/MCP) workflows, treat the
  `.xcstrings` file as source code, not a build artifact. It's
  fine — Xcode merges hand-authored entries with future extractions.

### Pseudo-locale launch args don't accent output without scheme config

- **What happened**: tried `-AppleLanguages (en-XA) -AppleLocale en_XA`
  via both launch args and simulator-wide defaults. Neither produced
  accented output (`"T̂ôd̂áŷ"`).
- **What we did**: confirmed runtime behavior manually against the
  Today view, deferred full accented-pseudo sweep to v1.0 pre-FR
  with Xcode IDE scheme option enabled.
- **Lesson**: the accented pseudo-locale is a scheme-level Xcode
  feature, not a pure runtime locale trick. CLI verification needs
  either an additional `en_XA` localization in the catalog or the
  IDE scheme option. Document this as a v1.0 prereq.

## What worked well

- **Conductor's research → plan → build → compound flow** gave each
  stage room to surface its own discoveries. The research-level
  scope locks made the build straightforward even when specific
  assumptions turned out wrong.
- **Small commits** (one per task, sometimes per pivot) kept the PR
  reviewable and the rollback granularity tight.
- **Reading every call site before editing** caught the Tasks 2/3
  no-ops early, saving a round of pointless diffs.
- **Plural variants in `.xcstrings` JSON** were cleaner than feared
  — the `variations.plural.{one,other}` structure is obvious once
  seen, and EN's two forms map directly.

## For the next person

- **Don't hand-roll weekday labels anywhere else**. Use
  `Weekday.localizedShort` / `.localizedMedium` / `.localizedFull`
  on [Weekday.swift](Kado/Models/Weekday.swift). The system-provided
  symbols are correct in every locale Apple supports.
- **When adding a new user-facing string**: if it's in a SwiftUI
  init that accepts `LocalizedStringKey`, just type the literal —
  that's already localized. Only wrap in `String(localized:)` when
  you're passing to a `String`-typed API (e.g. `.accessibilityLabel(_:)`
  with a dynamic value, or `confirmationDialog(_:isPresented:)`).
- **Ternaries inside localized-key APIs are a trap**:
  `Text(cond ? "A" : "B")` may resolve to the non-localizing
  `StringProtocol` overload because the ternary's type collapses
  to `String`. Either split (`cond ? Text("A") : Text("B")`) or
  wrap each arm in `String(localized:)` explicitly.
- **The catalog file is source code, not an artifact**. Edit it
  directly when needed; commit it alongside the source change
  that introduces a new key. Xcode (when opened) will merge new
  extractions, not overwrite existing entries.
- **Interpolated accessibility labels need
  `String(localized: "...")` around the whole format**, not around
  individual substitutions. `"\(name), \(state)"` without a wrap
  is a raw concat and never hits the catalog.
- **Pseudo-locale testing is Xcode-IDE-only** for this project
  today. Before shipping FR (v1.0), add that to a pre-FR checklist
  rather than fighting MCP for it.

## Generalizable lessons

- **[→ CLAUDE.md]** Add to the Localization section: "Prefer
  SwiftUI's `LocalizedStringKey`-typed initializers over explicit
  `String(localized:)` wrapping. Use `String(localized:)` only for
  `String`-typed APIs or when a ternary would otherwise collapse
  to `StringProtocol`."
- **[→ CLAUDE.md]** Add to the Localization section: "For weekday
  and month labels, use `Weekday.localizedShort` /
  `.localizedMedium` / `.localizedFull` (system-symbol-backed).
  Never hand-roll catalog entries for calendar abbreviations —
  Xcode collapses identical keys and loses per-language
  disambiguation."
- **[→ CLAUDE.md]** Add a note about `xcodebuild` not auto-syncing
  `.xcstrings` under MCP / CI. Treat the catalog as hand-authored
  source.
- **[local]** The three plural-variant keys shipped
  (`"%lld days per week"`, `"Every %lld days"`, `"%lld days ago"`)
  cover EN's two forms. FR translator will likely want plural
  variants on a few more (`"Target: %lld"` for target >1 sounds
  fine, but e.g. some Slavic languages have 3+ forms). Revisit
  per-language during v1.0.

## Metrics

- Tasks completed: 8 of 8 (2 no-ops; 1 partial/deferred)
- Tests added: 0 (none required — localization validated at
  build-extraction time; no behavior changes)
- Commits: 7 (3 docs, 1 refactor, 3 chore(l10n))
- Files touched: 7 source + 3 docs = 10
  - Source: `Weekday.swift`, `WeekdayPicker.swift`,
    `MonthlyCalendarView.swift`, `HabitDetailView.swift`,
    `HabitRowView.swift`, `NewHabitFormView.swift`,
    `Localizable.xcstrings`
  - Docs: `research.md`, `plan.md`, `compound.md`
- Net LOC: +793 / -57 (the catalog JSON dominates)
- Build/test status: all green throughout, 106/106 tests passing

## References

- [Xcode 16 String Catalogs documentation](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog)
- [`Calendar.standaloneWeekdaySymbols`](https://developer.apple.com/documentation/foundation/calendar/2293301-standaloneweekdaysymbols) — source of the weekday pivot
- CLAUDE.md → Localization section (current)
- `docs/ROADMAP.md` v0.1 → "EN localization (FR arrives in v1.0,
  strings prepared now via String Catalog)"
