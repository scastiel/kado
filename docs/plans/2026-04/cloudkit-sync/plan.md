# Plan — CloudKit sync (v0.1)

**Date**: 2026-04-17
**Status**: ready to build
**Research**: [research.md](./research.md)

## Summary

Wire Kadō's `ModelContainer` to CloudKit's private database so habits
and completions sync across a user's own devices via their Apple ID,
with no server we run and no telemetry. Control is at the iOS system
level (Settings → Apple ID → iCloud → Kado); the app surfaces the
resulting account status in its own Settings screen but owns no
toggle. Schema stays on CloudKit Development for all of v0.1–v0.3; a
Production deploy is a v1.0 release-prep checklist item.

## Decisions locked in

- Use `cloudKitDatabase: .private("iCloud.dev.scastiel.kado")` in
  `ModelConfiguration`, unconditionally. No runtime switch.
- Settings shows CloudKit account status, no toggle, no "sync now" or
  "reset zone" actions in v0.1.
- Pre-CloudKit local data on the author's dogfood install is wiped;
  no migration code path.
- Schema stays on CloudKit **Development** environment through v0.1–
  v0.3. Production deploy deferred to v1.0 release prep.
- `CloudAccountStatus` enum maps all five `CKAccountStatus` cases
  explicitly so a future Apple-added case triggers a compile error.
- Observer is protocol-based (`CloudAccountStatusObserving`) and
  injected via `Environment`, matching the services DI pattern in
  [`CLAUDE.md`](../../../../CLAUDE.md).
- The container identifier lives in one Swift constant referenced by
  both `ModelConfiguration` and the observer, so a typo can't split
  them.

## External prerequisites (user-managed)

These are not code tasks. Build work proceeds without them but the
exit gate (two-device sync) cannot be verified until they land.

- [ ] **Apple Developer portal**: enable iCloud capability on the
      `dev.scastiel.kado` App ID; create `iCloud.dev.scastiel.kado`
      container and associate it.
- [ ] **Xcode capability**: Kado target → Signing & Capabilities →
      + Capability → iCloud → tick CloudKit → add
      `iCloud.dev.scastiel.kado` container. Xcode creates
      `Kado.entitlements` and updates `project.pbxproj`. Commit both.

## Task list

### Task 1: Add `CloudContainerID` constant

**Goal**: One source of truth for the CloudKit container identifier
shared between `ModelConfiguration` and the upcoming observer.

**Changes**:
- New file `Kado/App/CloudContainerID.swift` with
  ```swift
  enum CloudContainerID {
      static let kado = "iCloud.dev.scastiel.kado"
  }
  ```

**Tests / verification**:
- `build_sim` succeeds.

**Commit message**: `feat(cloudkit): add CloudContainerID constant`

---

### Task 2: Wire `cloudKitDatabase:` into `KadoApp`

**Goal**: Flip the app's `ModelContainer` to use the CloudKit private
database.

**Changes**:
- [`Kado/App/KadoApp.swift`](../../../../Kado/App/KadoApp.swift) —
  change `ModelConfiguration(schema: schema)` to
  `ModelConfiguration(schema: schema, cloudKitDatabase: .private(CloudContainerID.kado))`.

**Tests / verification**:
- `build_sim` succeeds with no new warnings.
- Launch on iPhone 16 Pro simulator signed into an iCloud Dev
  account; app opens without crash; create one habit, no runtime
  error in the log.
- If entitlements file missing (external prereq not done),
  `ModelContainer` init may fail loudly or silently drop to
  local — log what happens. Re-verify after prereq is in place.

**Commit message**: `feat(cloudkit): use CloudKit private database in ModelContainer`

---

### Task 3: CloudKit-shape regression tests

**Goal**: Guard against a future commit that silently adds a required
property or an `@Attribute(.unique)` and breaks CloudKit sync in
production only.

**Changes**:
- New file `KadoTests/CloudKitShapeTests.swift` with Swift Testing
  cases.

**Tests / verification**:
```swift
@Test("HabitRecord can be constructed with no arguments")
@Test("HabitRecord.completions defaults to empty array")
@Test("HabitRecord.archivedAt is optional")

@Test("CompletionRecord can be constructed with no arguments")
@Test("CompletionRecord.habit is optional")
@Test("CompletionRecord.note is optional")
```
Each test instantiates the model with no args and asserts the
CloudKit-relevant properties (defaults, nullability). `test_sim`
passes.

**Commit message**: `test(cloudkit): add shape invariants for HabitRecord and CompletionRecord`

---

### Task 4: `CloudAccountStatus` enum + `CloudAccountStatusObserving` protocol + tests (red)

**Goal**: Define the account-status surface the UI will consume, with
tests written first per the TDD workflow in
[`CLAUDE.md`](../../../../CLAUDE.md).

**Changes**:
- New file `Kado/Services/CloudAccountStatus.swift` with
  ```swift
  enum CloudAccountStatus: Equatable {
      case available
      case noAccount
      case restricted
      case couldNotDetermine
      case temporarilyUnavailable
  }
  ```
- New file `Kado/Services/CloudAccountStatusObserving.swift` with
  the protocol:
  ```swift
  @MainActor protocol CloudAccountStatusObserving: Observable {
      var status: CloudAccountStatus { get }
      func refresh() async
  }
  ```
- New file `KadoTests/Mocks/MockCloudAccountStatusObserver.swift`
  — an `@Observable` mock whose `refresh()` copies a test-controlled
  seed into `status`.
- New file `KadoTests/CloudAccountStatusTests.swift` covering the
  `CKAccountStatus` → `CloudAccountStatus` mapping for all five
  cases, using a `MockCKAccountStatusProvider` the default observer
  will depend on (introduced in Task 5).

**Tests / verification**:
```swift
@Test("maps CKAccountStatus.available to .available")
@Test("maps CKAccountStatus.noAccount to .noAccount")
@Test("maps CKAccountStatus.restricted to .restricted")
@Test("maps CKAccountStatus.couldNotDetermine to .couldNotDetermine")
@Test("maps CKAccountStatus.temporarilyUnavailable to .temporarilyUnavailable")
@Test("starts in .couldNotDetermine before refresh")
@Test("refresh() propagates provider error as .couldNotDetermine")
```
Tests fail to compile (no default observer yet). **Red.**

**Commit message**: `test(cloudkit): add CloudAccountStatus tests and observer protocol`

---

### Task 5: `DefaultCloudAccountStatusObserver` (green)

**Goal**: Production implementation wired to `CKContainer` that makes
the tests from Task 4 pass.

**Changes**:
- New file `Kado/Services/DefaultCloudAccountStatusObserver.swift`
  with:
  - A tiny `CKAccountStatusProviding` protocol (one async method
    returning `CKAccountStatus`).
  - `DefaultCKAccountStatusProvider` wrapping
    `CKContainer(identifier: CloudContainerID.kado).accountStatus()`.
  - `@Observable final class DefaultCloudAccountStatusObserver`
    implementing `CloudAccountStatusObserving`. Stores the provider.
    On `refresh()`, calls the provider and maps the result. On
    `init`, schedules an initial `refresh` and subscribes to
    `.CKAccountChanged` via
    `NotificationCenter.default.notifications(named:)` to re-refresh
    on account changes.

**Tests / verification**:
- Task 4's tests now pass. `test_sim` green.
- `build_sim` succeeds.

**Commit message**: `feat(cloudkit): add DefaultCloudAccountStatusObserver`

---

### Task 6: Wire observer into `Environment` and `KadoApp`

**Goal**: Make the observer available to any view via
`@Environment(\.cloudAccountStatus)`, consistent with the other
services.

**Changes**:
- [`Kado/App/EnvironmentValues+Services.swift`](../../../../Kado/App/EnvironmentValues+Services.swift)
  — add an `EnvironmentKey` and computed property for
  `cloudAccountStatus`.
- [`Kado/App/KadoApp.swift`](../../../../Kado/App/KadoApp.swift)
  — build one `DefaultCloudAccountStatusObserver()` alongside the
  `ModelContainer` and inject with `.environment(\.cloudAccountStatus, observer)`.

**Tests / verification**:
- `build_sim` succeeds.
- A preview or a throwaway view can read the observer without
  crash — visually confirm on simulator with known iCloud account
  status.

**Commit message**: `feat(cloudkit): inject CloudAccountStatusObserver via Environment`

---

### Task 7: `SyncStatusSection` view and `SettingsView` overhaul

**Goal**: Replace the `ContentUnavailableView` placeholder with a
real `Form`, show the current CloudKit account status clearly, and
deep-link to iOS Settings when the user needs to act.

**Changes**:
- New file `Kado/Views/Settings/SyncStatusSection.swift` with a
  `View` that consumes `@Environment(\.cloudAccountStatus)` and
  renders a `Section("iCloud")` with:
  - `.available`: title "Syncing with iCloud", subtitle "Your
    habits are kept in sync across devices signed into the same
    Apple ID.", green checkmark icon.
  - `.noAccount`: title "Not signed in to iCloud", subtitle
    instructing the user to sign in, a `SettingsLink` row labeled
    "Open Settings".
  - `.restricted`: title "iCloud restricted on this device",
    subtitle explaining Screen Time / MDM, `SettingsLink`.
  - `.temporarilyUnavailable`: title "iCloud temporarily
    unavailable", subtitle "Try again shortly", no link.
  - `.couldNotDetermine`: title "Checking iCloud…", subtle,
    non-alarming styling.
- Rich SwiftUI preview feeding each case via a
  `MockCloudAccountStatusObserver`.
- [`Kado/Views/Settings/SettingsView.swift`](../../../../Kado/Views/Settings/SettingsView.swift)
  — replace the `ContentUnavailableView` body with
  ```swift
  Form {
      SyncStatusSection()
  }
  .navigationTitle("Settings")
  ```

**Tests / verification**:
- `build_sim` succeeds.
- Previews render all five status states legibly under light and
  dark, at Dynamic Type XXXL.
- `snapshot_ui` on iPhone 16 Pro for `SettingsView` on the
  simulator (signed-in account → .available row).
- VoiceOver announces each row's title + subtitle.

**Commit message**: `feat(cloudkit): surface iCloud account status in Settings`

---

### Task 8: Two-device exit-gate verification

**Goal**: Confirm the v0.1 exit criterion "iCloud sync works between
2 devices" is satisfied. This is the real test CloudKit is working.

**Prerequisite**: External prereqs above must be done.

**Changes**:
- Append a short **Verification log** section to this plan file
  with date, devices used (iPhone 16 Pro sim / iPad Air M2 sim,
  both signed into the same iCloud Dev account), and
  pass/fail per step.

**Verification script** (from research.md):
1. Create three habits with varied frequencies on iPhone, log
   completions.
2. Open iPad sim, wait ≤30s, confirm habits + completions appear.
3. Complete a habit on iPad; confirm reflection on iPhone.
4. Archive a habit on iPhone; confirm `archivedAt` syncs.
5. Toggle iCloud off for Kado in iOS Settings on iPhone; confirm
   Settings status shows `.noAccount`-ish state, local writes
   still succeed.
6. Toggle back on; confirm re-sync.

**Commit message**: `docs(cloudkit): log two-device verification results`

## Risks and mitigation

- **Entitlements mismatch silently drops to local-only.** Mitigate
  by logging a warning in debug builds when the observer first
  returns `.available` but the persistent store URL suggests a
  local-only fallback. Keep this under a `#if DEBUG` guard so
  release builds stay quiet. If implementation complexity grows,
  defer to a follow-up PR — the two-device exit gate catches it
  anyway.
- **First-launch schema bootstrap on flaky network.** Mitigate by
  running the verification script on Wi-Fi. Document if it fails
  cold-start and passes after reconnect.
- **SwiftData-CloudKit API quirks on current Xcode toolchain.**
  The app has already hit one SwiftData/Xcode-26 quirk (composite
  Codable enums). If a similar bug blocks CloudKit wiring, fall
  back to `.private()` with no identifier (uses default container)
  as a short-term workaround and log a TODO.
- **Background sync timing**. Two-device verification may need to
  foreground the target app to trigger the pull. Documented in
  Task 8, not a regression.

## Open questions

_None carrying forward. All three research-stage questions were
resolved on 2026-04-17 — see research.md._

## Out of scope

- **`CKSyncEngine`-based custom sync.** SwiftData's built-in is
  enough.
- **Shared CloudKit database** (habit sharing with partner). Post-
  v1.0 per ROADMAP.
- **Conflict-resolution UI.** Last-writer-wins is acceptable for
  single-user usage.
- **"Sync now" button, live progress indicator, "reset zone" action.**
  Not needed for v0.1 acceptance.
- **Production schema deploy.** v1.0 release-prep.
- **`NSPersistentCloudKitContainer.eventChangedNotification`
  observation** for in-app sync telemetry. Apple-internal-ish;
  SwiftData abstracts it. Revisit only if verification surfaces
  issues we can't diagnose from the outside.
- **Field-level encryption (`@Attribute(.allowsCloudEncryption)`).**
  Worth considering for `name` and `note` in v1.0 hardening.
- **Onboarding sheet** explaining sync on first launch. Settings
  row is enough for dogfood; v1.0 may add an onboarding pass.
