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
- **ViewModels**: `@Observable` classes, one per complex view. Simple
  views can skip them.
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

### File organization
```
Kado/
├── App/                    # Entry point, app setup
├── Models/                 # SwiftData @Model + domain types
├── Views/                  # SwiftUI, organized by feature
├── ViewModels/             # @Observable classes
├── Services/               # Business logic (protocols + impls)
├── Managers/               # System API wrappers
├── UIComponents/           # Reusable views
├── Extensions/             # Swift extensions
├── Resources/              # Assets, Localizable
└── Preview Content/        # SwiftUI preview data

KadoWidgets/                # Widget target
KadoWatch/                  # watchOS target
KadoLiveActivity/           # Live Activities target
KadoTests/                  # Unit tests (Swift Testing)
KadoUITests/                # UI tests (XCTest)
```

### SwiftUI
- Factor subviews out as soon as a `body` exceeds ~40 lines or when
  display logic repeats. Also helps avoid "compiler unable to type-check
  this expression in reasonable time" errors.
- Use `ViewThatFits`, `ContainerRelativeShape`, `Layout` protocol
  rather than manual size calculations when possible.
- Systematic previews for every non-trivial view, with multiple states.

### SwiftData
- One `@Model` per persistent type, explicit relationships with
  `@Relationship(deleteRule:inverse:)`.
- Migrations: use `VersionedSchema` and `SchemaMigrationPlan` from the
  first post-v0.1 schema change onward.
- Queries: prefer `@Query` in simple views, explicit descriptor + fetch
  in services for complex logic.

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
- Every user-facing string goes through `String(localized:)`.

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
3. SwiftUI previews work for new views (human visual check or
   `screenshot` for simple cases).
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
