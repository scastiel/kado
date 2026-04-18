# CLAUDE.md — Kadō

Instructions for Claude Code working on Kadō, an open source privacy-first
iOS habit tracker.

This file defines **how** to code on this project. For **what** to build and
**why**, see `docs/PRODUCT.md` and `docs/ROADMAP.md`.

---

## Project context

Kadō is a native iOS habit tracker, open source (MIT), offline-first.
Differentiators: non-binary habit score algorithm (inspired by Loop,
reimplemented), HealthKit integration, native Apple Watch, frictionless
export/import. No subscription, no telemetry, no required account.

Target: iOS 18.0+, Xcode 16.0+, Swift 5.10+.

---

## Tech stack

- **SwiftUI** with `@Observable` (iOS 17+) for state. **No Combine**
  unless there's no alternative.
- **SwiftData** for local persistence, with explicit migrations.
- **CloudKit** via SwiftData for multi-device sync (user opt-in).
- **ActivityKit** for Live Activities and Dynamic Island.
- **WidgetKit** for home screen and lock screen widgets.
- **App Intents** for Siri/Shortcuts (not legacy SiriKit).
- **HealthKit** for read-only activity data (habit auto-completion).
- **WatchKit** + SwiftUI for the native Apple Watch app.

**Zero third-party dependencies for v0.x.** If RevenueCat becomes
necessary later for a Pro tier, it will be the only exception. No
Firebase, no analytics, no SaaS crash reporting.

---

## Architecture

### General pattern
Lightweight MVVM with strict separation:

- **Models**: SwiftData types (`@Model`), pure domain types (structs).
- **ViewModels**: `@Observable` classes, only for views that mutate
  state outside of `@Query`-driven updates or share state across
  multiple views. A view whose logic fits in `@Query` + small
  computed properties + inline actions is a "simple view" — skip
  the ViewModel. Extract business logic into a free struct with
  injected `Calendar` (pattern: `CompletionToggler`) rather than
  wrapping it in a ViewModel for structure's sake.
  - **Picker over associated-value enums**: when a domain enum has
    associated values (e.g. `Frequency.daysPerWeek(Int)`) and the
    UI presents it as a `Picker`, the ViewModel holds a paired
    case-only "kind" enum plus one stored property per variant's
    params. Switching the kind stays non-destructive — the user's
    partially-entered count/set/target isn't lost when they
    explore options. Pattern: `NewHabitFormModel.FrequencyKind` +
    `daysPerWeek`/`specificDays`/`everyNDays`, with one regression
    test guarding the invariant.
- **Views**: SwiftUI, ideally with no business logic.
- **Services**: reusable business logic (HabitScoreCalculator,
  ExportService, NotificationScheduler…). Protocol-defined, injected.
- **Managers**: stateful wrappers around system APIs (HealthKitManager,
  NotificationManager, BiometricManager).

### Dependency Injection
Via SwiftUI `Environment`. No third-party DI framework.

```swift
// Definition
private struct HabitScoreCalculatorKey: EnvironmentKey {
    static let defaultValue: any HabitScoreCalculating = DefaultHabitScoreCalculator()
}

extension EnvironmentValues {
    var habitScoreCalculator: any HabitScoreCalculating {
        get { self[HabitScoreCalculatorKey.self] }
        set { self[HabitScoreCalculatorKey.self] = newValue }
    }
}

// Usage
struct HabitDetailView: View {
    @Environment(\.habitScoreCalculator) private var calculator
    // ...
}
```

Each service is protocol-defined. Default implementations are used in
production, mocks in tests.

**`@Entry` macro for `@MainActor`-isolated reference types.** The
`EnvironmentKey` pattern above works for value-type defaults
(structs, simple references). It does **not** compose with a
`@MainActor`-isolated `@Observable` class — the static
`defaultValue` is evaluated nonisolated and Swift complains about
calling a MainActor init from there. Use the `@Entry` macro
instead, which generates the right isolation:

```swift
extension EnvironmentValues {
    @Entry var cloudAccountStatus: any CloudAccountStatusObserving = MockCloudAccountStatusObserver()
}
```

Pattern in use: `EnvironmentValues+Services.swift`'s
`cloudAccountStatus` entry, backed by a Debug-only mock in
`Preview Content/`.

### View state
Prefer enums for view state over multiple booleans:

```swift
// ✅ Good
enum HabitListState {
    case loading
    case empty
    case loaded([Habit])
    case error(Error)
}

// ❌ Bad
var isLoading: Bool
var isEmpty: Bool
var error: Error?
var habits: [Habit]
```

### Concurrency
Swift Concurrency (`async`/`await`, actors). No callback closures
unless forced by a system API. Respect `MainActor` for anything
UI-related.

The project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (Xcode's
"approachable concurrency" default), which propagates MainActor
isolation to every type by default. Domain value types that need
cross-actor use (typically those with `Codable` or `Sendable`
conformances consumed from off-MainActor tests or background
encoders) must be marked `nonisolated` at the type declaration:

```swift
nonisolated enum Frequency: Hashable, Codable, Sendable { ... }
nonisolated struct Habit: Hashable, Sendable { ... }
```

Without `nonisolated`, the synthesized conformances inherit MainActor
isolation and emit "main actor-isolated conformance cannot be used in
nonisolated context" warnings (errors under Swift 6 mode).

The same rule extends to **service types whose default-argument
sites are evaluated outside MainActor** — most commonly providers
fed into a `@MainActor`-isolated init. `DefaultCKAccountStatusProvider`
is the canonical example: it wraps `CKContainer.accountStatus()` (an
async call that doesn't need MainActor) and serves as the default
argument to `DefaultCloudAccountStatusObserver.init`. Both the
class and any constants it references (e.g. `CloudContainerID`)
need `nonisolated`, otherwise the init evaluation site warns.

The same rule also extends to **static properties and static
functions on a `@MainActor` type that are used as default-argument
expressions on that type's init**. Even when the init itself is
MainActor-isolated, Swift evaluates the default expression in the
caller's context and warns ("converting `@MainActor () -> T` to
`() -> T` loses global actor 'MainActor'"). Mark such defaults
`nonisolated static` when they don't touch MainActor state — e.g.
`DevModeController.defaultDevStoreURL` and
`DevModeController.defaultProductionContainer()` are both
`nonisolated static` because `URL` math and `ModelContainer.init`
don't need MainActor.

### Dates and calendars
Day arithmetic always goes through `Calendar` — never raw seconds.
`addingTimeInterval(86400)` silently breaks across DST boundaries
(a "day" is 23 or 25 hours twice a year). Use:

- `calendar.startOfDay(for: date)` to anchor a `Date` to a day.
- `calendar.date(byAdding: .day, value: n, to: date)` to advance days.
- `calendar.dateComponents([.day], from: a, to: b).day` for day deltas.

Any service that does date math accepts an injected `Calendar` (with
default `.current`). Tests pin to `Calendar(identifier: .gregorian)`
in UTC for determinism, and to `Europe/Paris` (or another DST-crossing
zone) when DST behavior is under test. The `TestCalendar` helper in
`KadoTests/Helpers/` is the canonical pattern.

---

## Code conventions

### Naming
- Types: `UpperCamelCase`.
- Properties, methods, variables: `lowerCamelCase`.
- Protocols: describe a capability (`HabitScoreCalculating`,
  `NotificationScheduling`) rather than a form (`HabitScoreCalculatorProtocol`).
- Files: one primary type per file, filename = type name.

### Switch-returning computed properties
When a `switch` inside a computed property has **any arm** with
multi-statement logic, put explicit `return` on **every** arm.
Swift's implicit-return-from-switch only applies when every arm
is a single expression; mixing `case .x: "literal"` with a
multi-statement arm that uses `return` raises
`"missing return in getter expected to return 'T'"` — a confusing
error for an easy fix. When in doubt, be consistent.

### File organization
```
Kado/                       # Main iOS app target (views, VMs, managers)
├── App/                    # Entry point, app setup
├── Views/                  # SwiftUI, organized by feature
├── ViewModels/             # @Observable classes
├── UIComponents/           # Reusable views
├── Extensions/             # Swift extensions
├── Resources/              # Assets, Localizable
└── Preview Content/        # SwiftUI preview data

Packages/
└── KadoCore/               # Local Swift Package shared across targets
    └── Sources/KadoCore/   # @Model + domain types, calculators,
                            #   intents, widget snapshot types,
                            #   anything extensions need to compile.
                            # Don't duplicate @Model types into
                            # targets — share via this package only
                            # (see SwiftData section for why).

KadoWidgets/                # Widget extension target (reads the
                            #   App Group snapshot; no SwiftData)
KadoWatch/                  # watchOS target
KadoLiveActivity/           # Live Activities target
KadoTests/                  # Unit tests (Swift Testing)
KadoUITests/                # UI tests (XCTest)
```

Because `Packages/KadoCore/` is a local package, the standard
`Packages/` line in `.gitignore` would silently drop it from the
repo. Guard against that with an explicit
`!Packages/KadoCore/` whitelist.

### SwiftUI
- Factor subviews out as soon as a `body` exceeds ~40 lines or when
  display logic repeats. Also helps avoid "compiler unable to type-check
  this expression in reasonable time" errors.
- Use `ViewThatFits`, `ContainerRelativeShape`, `Layout` protocol
  rather than manual size calculations when possible.
- Systematic previews for every non-trivial view, with multiple states.
  Include one `#Preview("Dark") { ... .preferredColorScheme(.dark) }`
  per view file — pick a demanding state (accent-on-dark, mixed cell
  states, filled form) rather than a neutral one.
- **Prefer semantic colors; avoid hardcoded literals.** Use
  `Color.primary` / `Color.secondary` for text, `Color.accentColor`
  for tint, `Color(.secondarySystemBackground)` / `.tertiarySystemFill`
  / `.secondarySystemFill` for surfaces. These auto-adapt to light /
  dark / Increase Contrast. `Color.white` is acceptable only as text
  on an accent-tinted fill (the standard tinted-button pattern); any
  other use will not adapt. `Color.black` similarly needs justification.
  Hex strings, `Color(red:green:blue:)`, and custom palette constants
  require discussion.
- **`@State` defaults that depend on `@Environment` must initialize
  in `.onAppear`, not `init`.** `@State` is seeded before the env is
  injected, so `Calendar.current` (or any fallback) will leak into
  `init` instead of the overridden env value. Pattern:
  ```swift
  @State private var value: T? = nil
  var body: some View {
      ContentView(value: value ?? fallback)
          .onAppear { if value == nil { value = computeDefault() } }
  }
  ```
  Applied in `TimerLogSheet` so the env calendar drives today-
  completion prefill, matching the save path.
- **`.onChange(of: X, initial: true)` is stateless** — the callback
  fires on launch and on change with the same signature, so it
  can't distinguish "launched with X already true" from "user just
  set X to true." If those two paths need different behavior, use
  edge-triggered `.onChange(of: X) { old, new in ... }` and handle
  the at-launch case via lazy init keyed on the presence/absence
  of the underlying state. `DevModeController.devContainer()` uses
  a "seed if empty" check for this — launches with dev mode already
  on read the existing sqlite as-is; off→on transitions wipe the
  file so the next lazy build reseeds.
- **Swapping `.modelContainer(_:)` at runtime propagates to `@Query`
  in place** — no `.id(...)` remount is required. `@Query` re-fetches
  from the new container on the same view identity, so navigation
  state, selected tab, and scroll position are preserved. Adding
  `.id(flag)` as a defensive swap-trigger (as the Dev mode work
  initially did) quietly resets all of that. Trust the swap; don't
  rebuild the tree unless you've reproduced a real staleness bug.

### SwiftData
- One `@Model` per persistent type, explicit relationships with
  `@Relationship(deleteRule:inverse:)`.
- Migrations: `VersionedSchema` + `SchemaMigrationPlan` are wired from
  day one (`KadoSchemaV1` + `KadoMigrationPlan` with empty `stages`).
  When schema evolves, copy `KadoSchemaV1`'s models into a
  `KadoSchemaV2` namespace, append a `MigrationStage.lightweight(...)`
  (or `.custom`), and append `KadoSchemaV2.self` to
  `KadoMigrationPlan.schemas`.
- Queries: prefer `@Query` in simple views, explicit descriptor + fetch
  in services for complex logic.
- CloudKit-shape from day one: every property has a default value or
  is optional, **every relationship is optional on both sides**
  (the to-one and the to-many — `[CompletionRecord]?` not
  `[CompletionRecord]`), the to-many relationship has an explicit
  inverse, no `@Attribute(.unique)`, no `Deny` delete rule, no
  ordered relationships. The "both sides optional" rule is enforced
  by CloudKit at `ModelContainer.init` runtime only — a non-optional
  to-many compiles, mounts under a local-only configuration, and
  crashes the moment `cloudKitDatabase: .private(...)` is set with
  `NSCocoaErrorDomain 134060`. Pin the rules with a regression test
  that walks `Schema.entities` and asserts `relationship.isOptional`
  / `!attribute.isUnique` — see `KadoTests/CloudKitShapeTests.swift`
  for the canonical pattern.
- **Custom-enum storage workaround**: SwiftData on Xcode 26 / iOS 18
  does not reliably support **any** custom enum type as a direct
  `@Model` stored property — not just associated-value enums. Even
  plain `String`-raw-value enums (e.g. `HabitColor`) crash at load
  with `Could not cast Optional<Any> to <EnumType>` despite Codable
  / Sendable / RawRepresentable being satisfied. Workarounds:
  - For associated-value enums, store `private var fooData: Data`
    and expose `var foo: Foo` with explicit JSON encode/decode.
    Canonical: `HabitRecord.frequency`, `.type` in every schema
    version.
  - For `RawRepresentable` enums with primitive raw values, store
    `private var fooRaw: String` (or the enum's raw type) and
    expose `var foo: Foo { Foo(rawValue: fooRaw) ?? .default }`.
    Canonical: `HabitRecord.color` in `KadoSchemaV2`.

  Re-evaluate when Apple fixes the underlying bug.
- **Share `@Model` types via the `KadoCore` package, never via
  duplicated target membership.** SwiftData's schema uses the
  generic type of a `FetchDescriptor<Model>` to map to its
  persisted entity. If the same source file is compiled into
  *both* the main app and the widget extension (via a
  synchronized folder with dual target membership), SwiftData
  sees `Kado.HabitRecord` and `KadoWidgetsExtension.HabitRecord`
  as **distinct** types. A SQLite file stamped by one won't fetch
  from the other — `context.fetch(descriptor)` traps with
  `EXC_BREAKPOINT` on even a no-predicate descriptor. Cost us ~10
  commits before we figured it out. All `@Model` classes live in
  `Packages/KadoCore/`; main app + extensions link the one
  compiled module.
- **Do not open a CloudKit-mirrored SwiftData store from two
  processes.** `cloudKitDatabase: .private(...)` claims exclusive
  sync ownership. A second process with the same config traps
  `NSCocoaErrorDomain 134422` ("another instance of this
  persistent store actively syncing"). Opening the same file
  with `.none` from the second process traps at the first fetch
  because the on-disk metadata is CloudKit-stamped. `allowsSave: false`
  doesn't help — read-only mode still registers a sync handler.
  The pattern for extensions is **read-only JSON snapshots in an
  App Group**: the main app's `WidgetSnapshotBuilder` writes
  pre-computed data to `group.dev.scastiel.kado/.../widget-snapshot.json`
  on every mutation; the widget's `SnapshotTimelineProvider`
  decodes it. No SwiftData in the widget process.
- **Avoid `#Predicate` in widget / extension code paths.** Even a
  trivial `#Predicate { $0.archivedAt == nil }` traps with
  `EXC_BREAKPOINT` on first fetch inside the widget extension on
  this toolchain. Main-app code is fine; extensions should use a
  `FetchDescriptor(sortBy: …)` with a Swift-side `.filter { }`
  pass. Canonical: `HabitEntity.fetchSuggestions` and
  `WidgetSnapshotBuilder.build`.
- **AppIntents that mutate SwiftData reuse the app's live
  container.** `CompleteHabitIntent` sets `openAppWhenRun = true`
  and reads the container via `ActiveContainer.shared.get()` —
  which `KadoApp` primes at scene build and on every dev-mode
  swap. Opening `SharedStore.productionContainer()` fresh per
  `perform()` invocation would instantiate a second
  CloudKit-attached container in the same process and trap the
  same way two processes would. Every new `AppIntent` that
  mutates state should follow this pattern.
- **`@Model` default-argument values must be fully qualified.**
  `var color: HabitColor = .blue` fails with "A default value
  requires a fully qualified domain named value (from macro
  'Model')" plus a cascade of "type 'Any?' has no member 'blue'"
  errors. Write `var color: HabitColor = HabitColor.blue` instead.
  Only `@Model` class bodies need this — plain struct initializers
  tolerate leading-dot shorthand as usual.

---

## Testing

### Philosophy
Tests where they add value, not everywhere. **Mandatory** for:
- Any calculation logic (habit score first and foremost).
- Any date, scheduling, or streak logic.
- Any import/export parser.
- Any service with conditional business logic.

**Optional** for:
- SwiftUI views (previews + manual testing suffice in MVP phase).
- Trivial system API wrappers.

### Framework
**Swift Testing** (`@Test`, `#expect`) by default. XCTest only for UI
tests.

**Match numeric types on both sides of `#expect`.** Swift's permissive
binding lets `#expect(value == 25 * 60)` compile when `value` is
`Double?` and `25 * 60` is `Int`, but the runtime comparison returns
`false` for the same logical value — the failure message reads
`"1500.0 == 1500"` with no hint that the types differ. Always use
an explicit `Double(...)` or `1500.0` literal when asserting against
a `Double` value. Same rule applies to `#require`.

### Workflow
For any calculation function (score, streak, frequency), **write the
test before the implementation**. Example:

```swift
@Test("Habit score with perfect 10-day streak equals ~100%")
func perfectStreakScore() {
    let calculator = DefaultHabitScoreCalculator()
    let completions = (0..<10).map { Completion(date: .daysAgo($0), value: 1.0) }
    let score = calculator.score(for: completions, frequency: .daily)
    #expect(score > 0.95)
}
```

### Style
When a result can be expressed as "equal to a simpler analytical
computation," prefer that comparison over a hard-coded numeric
expectation. Example: instead of asserting a specific-days perfect
score equals `0.7854`, assert it equals the score of N daily-perfect
days. Reads better, survives small algorithm tweaks, and the failure
message points at the intent rather than at a magic number.

### Mocks
Since services are protocol-based, create mocks inline in tests or in
`KadoTests/Mocks/` if reused.

---

## Privacy and data

### Non-negotiable principles
- **No network calls** outside CloudKit (native Apple sync) and
  HealthKit (local read). No telemetry, no analytics, no SaaS crash
  reporter.
- **Sensitive data**: none. No location, no contacts, no photos.
  HealthKit only if the user enables it for auto-completion.
- **Export/Import**: the user must be able to extract 100% of their
  data as CSV and JSON, lossless. Test the round-trips.

### Permissions
Each requested permission must have:
- A clear, honest `NSUsageDescription` in both EN and FR.
- A functional fallback if refused.
- UI to revoke and re-request.

---

## Security

- Biometrics via `LocalAuthentication` (v0.3+), never mandatory.
- CloudKit: only `privateCloudDatabase`. Never `publicCloudDatabase`.
- No API keys, no secrets in the repo (shouldn't be needed given no
  third-party services).

---

## Accessibility

Non-negotiable from MVP:
- `accessibilityLabel` on all tappable non-textual elements.
- Full Dynamic Type support (no fixed frames for text).
- VoiceOver tested on every view before merge.
- Colors with AA minimum contrast ratio.
- `reduceMotion` respected for animations.

---

## Localization

- EN and FR by v1.0. FR must be native French (no machine translation),
  with attention to gender-neutral phrasing when possible.
- Use String Catalogs (`.xcstrings`), not legacy `Localizable.strings`.
- Every user-facing string goes through localization — but **prefer
  SwiftUI's `LocalizedStringKey`-typed initializers over explicit
  `String(localized:)` wrapping**. `Text("foo")`, `Button("foo")`,
  `Label("foo", systemImage: …)`, `.navigationTitle("foo")`,
  `Tab("foo", systemImage: …)`, `ContentUnavailableView("foo", …)`,
  `Section("foo")`, `Picker("foo", selection:)`, etc. all accept
  `LocalizedStringKey` — the literal is already on the localized
  path. Reach for `String(localized:)` only when the API is
  `String`-typed (e.g. `.accessibilityLabel(_:)` with a dynamic
  value, `TextField` placeholders, `confirmationDialog(_:)` titles),
  or when a ternary `Text(cond ? "A" : "B")` would otherwise
  collapse to the non-localizing `StringProtocol` overload (in which
  case split the `Text` or wrap each arm).
- **Interpolated strings must be wrapped as a whole**:
  `String(localized: "\(name), \(state)")` works;
  `"\(name), \(state)"` is a raw concat that never reaches the
  catalog.
- **For weekday labels, use `Weekday.localizedShort`,
  `.localizedMedium`, or `.localizedFull`** — backed by
  `Calendar.*StandaloneWeekdaySymbols`, so they auto-localize in
  every language Apple ships. Never hand-roll catalog entries for
  weekday abbreviations: Xcode collapses identical keys (e.g.
  `"T"` with a Tuesday comment and `"T"` with a Thursday comment
  merge into one entry), and the FR translator is then forced to
  pick a single letter for both. The same principle applies to
  month names (use `Calendar.monthSymbols` / `.shortMonthSymbols`
  when the need arises).
- **`Localizable.xcstrings` is source code, not a build artifact**.
  Under `xcodebuild` / XcodeBuildMCP, the `.xcstrings` is NOT
  auto-populated from source — only the Xcode IDE runs that sync.
  Hand-author entries when a new key is introduced, commit the
  catalog alongside the source change. Xcode will merge future
  extractions with existing entries rather than overwrite.
- Every catalog entry needs a `comment` describing its on-screen
  context (imperative, context-first, under ~80 chars). For
  count-driven interpolations, declare plural variants via
  `variations.plural.{one,other}`.

---

## Tooling: XcodeBuildMCP

This project uses **XcodeBuildMCP** (getsentry/XcodeBuildMCP, MIT) to
give Claude Code structured access to Xcode, the simulator, and tests.
It's the difference between "Claude writes code that you compile
yourself" and "Claude writes, compiles, tests, fixes in an autonomous
loop."

### Installation (once per machine)

Prerequisites: macOS 14.5+, Xcode 16.x+, Node.js 18+.

Recommended option (Homebrew):

```bash
brew tap getsentry/xcodebuildmcp
brew install xcodebuildmcp

claude mcp add XcodeBuildMCP -s user -- xcodebuildmcp mcp
```

Alternative option (npx, no global install):

```bash
claude mcp add XcodeBuildMCP -s user -- npx -y xcodebuildmcp@latest mcp
```

Verify the server is connected:

```bash
claude mcp list
# XcodeBuildMCP: ... - Connected
```

### Telemetry opt-out

XcodeBuildMCP sends runtime errors to Sentry by default. **Inconsistent
with our privacy-first philosophy** — disable it:

```bash
claude mcp remove XcodeBuildMCP -s user
claude mcp add XcodeBuildMCP -s user \
  -e XCODEBUILDMCP_SENTRY_DISABLED=true \
  -- xcodebuildmcp mcp
```

(Or add the env var to the existing config depending on your MCP
client.)

### Optional skills

XcodeBuildMCP ships optional agent skills that prime Claude on the
correct tool usage. Install once:

```bash
xcodebuildmcp init
```

This adds instructions to guide Claude toward the right tools rather
than `xcodebuild` via Bash.

### Tools to prefer

Claude should **prefer MCP tools over equivalent Bash commands**:

| Need | MCP tool | Not this |
|---|---|---|
| Simulator build | `build_sim` | `xcodebuild` via Bash |
| Device build | `build_device` | `xcodebuild` via Bash |
| Run tests | `test_sim` | `xcodebuild test` via Bash |
| List simulators | `list_sims` | `xcrun simctl list` |
| Boot a simulator | `boot_sim` | `xcrun simctl boot` |
| Screenshot | `screenshot` | — |
| UI inspection | `snapshot_ui` | — |
| LLDB debug | `debug_attach_sim`, `debug_stack` | `lldb` via Bash |
| Project/scheme discovery | `discover_projs`, `list_schemes` | — |

Tools return structured JSON (categorized errors, file paths, line
numbers) instead of raw logs. This saves context and makes debugging
deterministic.

### Expected TDD workflow for any business logic feature

1. Read the spec (`docs/habit-score.md`, `docs/ROADMAP.md`)
2. Write the Swift Testing tests
3. Call `test_sim` to confirm they fail (red)
4. Implement the feature
5. Call `test_sim` again (green)
6. Call `build_sim` to verify the full app still compiles
7. For UI features: call `screenshot` to visually verify
8. Commit

### Default simulator

Boot and use **iPhone 16 Pro** (iOS 18.x) as default target. For iPad
layout testing: iPad Air (M2). For accessibility testing: enable
Dynamic Type XXXL and VoiceOver via `simctl` before `snapshot_ui`.

On the current Xcode 26 toolchain, fresh installs ship only the
iPhone 17 family — iPhone 17 Pro is the practical default and was
used for the v0.1 CloudKit two-device verification.

If the named sim isn't installed on the machine (`list_sims` doesn't
show it), substituting a +1 generation (iPhone 17 Pro, iPad Air M4)
is fine — the layout class and dark-mode/accessibility behavior are
identical for audit purposes. Note the substitution in the plan /
compound so the record is accurate; don't pretend the nominal sim
ran.

### When to open Xcode manually

XcodeBuildMCP works headless (Xcode doesn't need to be open). Cases
where you still open Xcode:
- Visual verification of a subtle layout bug (MCP can't see "off by
  10 pixels")
- Provisioning profile / code signing debugging (not structured by MCP)
- Interactive SwiftUI Previews exploration
- Initial project configuration (capabilities, entitlements)

### Known limitations to manage

- No automatic visual debugging: a `screenshot` must be humanly
  interpreted if the bug is visual-only.
- No incremental build: every `build_sim` is a full build (+15-30s on
  large projects, negligible on Kadō early on).
- Code signing: errors remain opaque, ask the human to fix in Xcode
  when needed.
- **Tap / type / gesture primitives are not enabled in the default
  XcodeBuildMCP install.** `build_run_sim` and `screenshot` work, but
  you cannot tap a habit row to push into Detail, or fill a form
  field in the New Habit sheet — only the launched screen is
  reachable. Multi-screen sim audits need either `idb` installed
  separately, Simulator.app hands-on, or an explicit XcodeBuildMCP
  reconfigure that enables the UI-automation workflow. Until that's
  done, plan audits around the single reachable surface + SwiftUI
  previews for the rest, and flag the gap in the finding notes.
  First hit in [kado#5](https://github.com/scastiel/kado/pull/5), hit
  again in [kado#8](https://github.com/scastiel/kado/pull/8).
- **Destination resolution flakiness**: `test_sim` and
  `build_run_sim` occasionally fail with `Unable to find a
  destination matching { platform:iOS Simulator, OS:latest, name:… }`
  even though the simulator is booted and its SDK is installed —
  the error text cites the missing iOS *device* SDK. xcodebuild
  appears to walk all scheme destinations and abort when
  device-side resolution fails, poisoning the simulator build.
  Try fixes in this order:
  1. `xcrun simctl shutdown all && xcrun simctl boot "<sim name>"`,
     then rerun.
  2. If that doesn't work, fall back to direct xcodebuild with a
     **pinned OS version** (the MCP tool sends `OS:latest`, which
     xcodebuild can't always match even when the SDK is present):
     ```
     xcodebuild -project Kado.xcodeproj -scheme Kado \
       -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1" \
       test
     ```
     Find the real OS version via
     `xcrun simctl list devices available | grep -A1 "iOS"`.
  3. Cleaning DerivedData (`rm -rf ~/Library/Developer/Xcode/DerivedData/Kado-*`)
     occasionally helps.
  No source-level change is needed — the code is fine, the
  runtime state is not.

---

## Git and commits

### Branches
- `main`: always deployable.
- `feature/<short-name>` for development.
- One PR per feature or logical fix, not per file.

### Commit messages
Lightweight conventional commits format:

```
feat(score): implement exponential moving average calculator
fix(widget): correct date offset in weekly grid
test(score): add edge cases for frequency-adjusted scoring
docs: update ROADMAP with v0.2 scope
refactor(habit-detail): extract calendar grid into own view
```

Scope optional, description in imperative present, no trailing period.

### Pull requests

Every PR has:

- **A semantic-commit-style title** (`<type>(<scope>): <description>`)
  — same convention as commit messages. The title becomes the
  squash-merge commit on `main`, so it must stand alone.
- **A short, bullet-heavy description in four sections**, in this
  order:
  - **Why?** — the problem the PR solves
  - **What?** — product-oriented overview of the change
  - **How?** — technical notes on the implementation
  - **Next steps** — follow-ups, open questions, deferred work

Favor bullets over prose. The description should be skimmable in
30 seconds. Link to `docs/plans/<slug>/` artifacts instead of
restating their content.

---

## Interaction with Claude Code

### Operating mode
- For any new feature, start by re-reading the relevant section of
  `docs/ROADMAP.md` and `docs/PRODUCT.md`.
- Propose a brief plan before writing code for any non-trivial feature
  (more than 2 files modified).
- For a feature with business logic: tests first, implementation
  second.
- Prefer small iterations over a large PR.
- For non-trivial features, use the **conductor** skill
  (`.claude/skills/conductor/`) to structure the work through
  research → plan → build → compound stages. Load it when the user
  signals a new feature is starting. Stages can be skipped — confirm
  with the user before bypassing one.
- When research depends on a load-bearing claim about toolchain
  behavior ("this storage shape works", "this API supports X"),
  verify with a 2-minute smoke test before committing the design.
  Research helpers can be wrong about toolchain-specific specifics;
  catching it up front is far cheaper than a mid-build pivot.

### What Claude should NOT do without asking
- Add a third-party dependency (Swift Package or otherwise).
- Modify the SwiftData schema in a non-migrating way.
- Change the MVVM+Services architecture defined above.
- Introduce Combine where `@Observable` suffices.
- Suggest or add telemetry, analytics, or crash reporting.
- Introduce premium features / paywalls without product discussion.
- Use `xcodebuild` via Bash when an XcodeBuildMCP tool exists (see
  the Tooling section).

### What Claude can do freely
- Refactor while staying within the defined architecture.
- Factor out SwiftUI views that grew too long.
- Write and enrich tests.
- Propose UX improvements in PRs.
- Create rich SwiftUI previews.
- Add doc comments (`///`) on public APIs.

### Definition of "done"
A task is done when:
1. `build_sim` returns success with no new warnings.
2. `test_sim` passes all existing tests, and new ones have been added
   if business logic was involved.
3. SwiftUI previews work for new views, **and** `screenshot` (or a
   live human visual check) is captured after every visual change.
   Design bugs — wrong tint, identical states for opposite values,
   layout overflow, regressed truncation — compile fine and pass
   `test_sim`. Only a literal pixel check catches them. Cheap
   insurance, not optional.
4. Accessibility is tested (Dynamic Type XXXL, VoiceOver on iPhone 16
   Pro minimum).
5. Behavior is verified on iPhone AND iPad simulator via `build_sim`
   on both targets.
6. The commit message follows the format above.

---

## Useful references

- SwiftUI and `@Observable`: https://developer.apple.com/documentation/Observation
- SwiftData migrations: https://developer.apple.com/documentation/swiftdata/schemamigrationplan
- App Intents: https://developer.apple.com/documentation/appintents
- HealthKit: https://developer.apple.com/documentation/healthkit
- XcodeBuildMCP: https://github.com/getsentry/XcodeBuildMCP
- XcodeBuildMCP tools reference: https://github.com/getsentry/XcodeBuildMCP/blob/main/docs/TOOLS.md
- HIG habit tracking patterns: observe Streaks, (Not Boring) Habits.
