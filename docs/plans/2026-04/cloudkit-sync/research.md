# Research — CloudKit sync (v0.1)

**Date**: 2026-04-17
**Status**: ready for plan
**Related**:
- [`docs/ROADMAP.md`](../../../ROADMAP.md) — v0.1 Infrastructure bullet:
  "CloudKit sync opt-in, via SwiftData CloudKit container"; Exit
  criterion: "iCloud sync works between 2 devices"
- [`docs/plans/2026-04/swiftdata-models/research.md`](../swiftdata-models/research.md)
  — CloudKit-shape schema decisions already made
- Settings placeholder: [`Kado/Views/Settings/SettingsView.swift`](../../../../Kado/Views/Settings/SettingsView.swift)

## Problem

v0.1 needs habits and completions logged on one device to appear on
the user's other devices (iPhone ↔ iPad primarily), with no account
creation, no server we run, and no telemetry. CloudKit's private
database through the user's Apple ID is the only option consistent
with Kadō's privacy-first ethos. The schema was built CloudKit-shaped
from the first commit ([swiftdata-models/research.md](../swiftdata-models/research.md)),
so this PR wires the remaining plumbing: entitlements, the
`cloudKitDatabase:` configuration, an account-state surface in
Settings, and whatever validation we want before two-device sync is
claimed working.

Why now, not in v0.2: the roadmap's v0.1 exit gate says "iCloud sync
works between 2 devices," and any schema change after CloudKit
deployment becomes a breaking-production-schema problem — so we want
the container pushed to CloudKit Dev, ideally to Production, before
anything ships to TestFlight. Getting this right early is cheap; late
is expensive.

## Current state of the codebase

**Persistence layer, CloudKit-ready.** Both `@Model` types satisfy
CloudKit's constraints — no `@Attribute(.unique)`, every scalar has a
default, the to-many relationship has an explicit inverse with
cascade delete, no ordered relationships:

- [`HabitRecord`](../../../../Kado/Models/Persistence/HabitRecord.swift) —
  `id`, `name`, `createdAt`, `completions: []` all defaulted;
  `archivedAt: Date?` nullable; `frequencyData: Data` and `typeData:
  Data` as JSON blobs (SwiftData/Xcode 26 quirk with composite-Codable
  enums, already documented in [`CLAUDE.md`](../../../../CLAUDE.md)).
- [`CompletionRecord`](../../../../Kado/Models/Persistence/CompletionRecord.swift) —
  `habit: HabitRecord?` nullable per CloudKit's rule that
  relationships cannot be required.

**Container wiring.** [`KadoApp`](../../../../Kado/App/KadoApp.swift)
builds a `ModelContainer` with no `cloudKitDatabase:` parameter today.
The `ModelConfiguration` is the one lever to flip; everything
downstream (`@Query`, `modelContext.insert`) continues to work
unchanged.

**Missing.**
- No `Kado.entitlements` file; project.pbxproj has no
  `CODE_SIGN_ENTITLEMENTS` setting. Adding the iCloud capability in
  Xcode creates both.
- No CloudKit container provisioned under `iCloud.dev.scastiel.kado`
  in the Apple Developer portal yet (user will handle out of band).
- No CKContainer/CKAccountStatus observation — nothing surfaces
  "you're not signed in" or "iCloud is restricted."
- Settings view is a `ContentUnavailableView` placeholder.

**Schema version**: `KadoSchemaV1` with `Schema.Version(1,0,0)`. Any
future CloudKit-breaking change (removing a required field, changing
a type) means a new `KadoSchemaVN` + a migration stage + a fresh
CloudKit deployment.

## Proposed approach

**Wire CloudKit unconditionally. No in-app on/off toggle in v0.1.**

This diverges from the literal ROADMAP bullet ("iCloud sync on/off").
I want to surface the reasoning so the user can push back before
planning locks it in — see *Open questions* §1. Short version: the
in-app toggle is harder than it sounds, and the system-level control
(iOS Settings → Apple ID → iCloud → Kado) already exists, is the
native pattern, and satisfies the spirit of "opt-in" because the user
can always turn it off there.

### Why no in-app toggle

SwiftData's `ModelConfiguration` takes `cloudKitDatabase:` at
container construction. To honor an in-app toggle you'd need one of:

1. **Two stores, switch at launch.** Read a `@AppStorage` bool,
   build `.private(...)` or `.none` accordingly. Problem: toggling
   off → on (or vice-versa) leaves data in the "old" store. First
   flip-on requires walking every `HabitRecord`/`CompletionRecord`
   and re-inserting into the new store — a migration we don't want
   to own in v0.1.
2. **Rebuild the container at runtime.** Same data-migration
   problem, plus SwiftData doesn't love having its container swapped
   out from under live `@Query` observers.
3. **CloudKit always, fake toggle.** The switch does nothing but
   deep-link to iOS Settings. Honest but confusing UX.

The native pattern (Streaks, Apple Journal, Reminders) is #4: always
use the CloudKit container; account-level control is the user's
Apple ID iCloud settings. SwiftData-CloudKit respects that
automatically — if iCloud is off for Kado, writes stay local.

### Key components

- **`Kado.entitlements`** — new file, created by Xcode when the
  iCloud+CloudKit capability is added. Declares the container
  identifier `iCloud.dev.scastiel.kado` and the
  `com.apple.developer.icloud-services = [CloudKit]` array.
- **`ModelConfiguration`** in `KadoApp.swift` — add
  `cloudKitDatabase: .private("iCloud.dev.scastiel.kado")`.
- **`CloudAccountStatusObserver`** (new service,
  `Kado/Services/CloudAccountStatusObserver.swift`) —
  `@Observable` wrapper around `CKContainer.accountStatus(completionHandler:)`
  and `.CKAccountChanged` notifications. Exposes an enum:
  ```swift
  enum CloudAccountStatus {
      case available
      case noAccount
      case restricted
      case couldNotDetermine
      case temporarilyUnavailable
  }
  ```
  Injected via `Environment` per the DI pattern in CLAUDE.md.
- **`SyncStatusSection`** (new view,
  `Kado/Views/Settings/SyncStatusSection.swift`) — rendered inside
  `SettingsView`. Shows:
  - Current account status with a clear icon and one-line
    explanation.
  - If `.available`: plain status row "Syncing with iCloud". Apple
    Settings link for control.
  - If `.noAccount` / `.restricted`: an inline instruction and a
    `SettingsLink` (iOS 17+) that deep-links to iOS Settings.
  - No "sync now" button in v0.1; no live progress indicator.

### Data model changes

None. The CloudKit-shape work is already done in `KadoSchemaV1`. The
first time the app runs with `cloudKitDatabase: .private(...)`, the
SwiftData stack pushes record types to CloudKit Development
automatically.

### UI changes

1. **Settings** goes from a single `ContentUnavailableView` to a
   `Form` with one `Section("iCloud")` containing the sync status
   row. Future sections (About, Export) stack below.
2. **First-run**: no onboarding sheet in v0.1. If iCloud is off at
   first launch the user sees local-only behavior; the Settings row
   tells them what to do.

### Tests to write

Swift Testing unless noted.

```swift
@Test("CloudAccountStatusObserver maps CKAccountStatus.available")
@Test("CloudAccountStatusObserver maps .noAccount to .noAccount")
@Test("CloudAccountStatusObserver maps .restricted to .restricted")
@Test("CloudAccountStatusObserver refreshes on CKAccountChanged")
```
Backed by a `MockCKAccountStatusProvider` protocol the observer
depends on, so tests don't need an iCloud account.

```swift
@Test("HabitRecord defaults satisfy CloudKit 'all-defaults' rule")
@Test("CompletionRecord defaults satisfy CloudKit 'all-defaults' rule")
```
Pure-Swift assertions: construct with no args, verify every
persistent property has a non-nil default or is optional. Guards
against a future commit that adds a required property and breaks
CloudKit silently at first production sync.

**Not unit-testable**: the actual CloudKit round-trip. That's
manual, covered by the exit gate.

### Manual verification (exit gate)

1. Build and run on iPhone 16 Pro simulator signed into iCloud Dev
   account.
2. Create three habits with varied frequencies, log completions.
3. Build and run on iPad Air (M2) simulator with same iCloud
   account.
4. Confirm all habits + completions appear within ~30s.
5. Complete a habit on iPad, confirm it appears on iPhone.
6. Archive a habit on iPhone, confirm archivedAt syncs.
7. Toggle iCloud off in iOS Settings → Apple ID → iCloud → Kado;
   confirm Settings surface reflects status, local writes still
   succeed, nothing crashes.
8. Toggle back on; confirm re-sync.

## Alternatives considered

### Alternative A: In-app sync toggle (literal roadmap bullet)

- Idea: `@AppStorage("iCloudSyncEnabled")` gate; two ModelContainer
  shapes.
- Why not: data-migration cost (flip-on needs walk-and-copy) is
  non-trivial and error-prone; the native pattern covers the same
  user need. Deferring to the user under Open questions §1.

### Alternative B: `CKSyncEngine` (iOS 17+)

- Idea: skip SwiftData's CloudKit integration, own the sync engine.
  Gives fine-grained control over conflict resolution and record
  mapping.
- Why not: massive scope increase. SwiftData-CloudKit's
  last-writer-wins defaults are fine for single-user habit tracking.
  Revisit only if we hit concrete conflict bugs.

### Alternative C: Custom sync over iCloud Drive / CKRecord directly

- Idea: store JSON exports in iCloud Drive; "sync" = pull latest
  blob.
- Why not: not real sync (no delta, no concurrency), defeats
  CloudKit's whole point, coarse-grained conflicts.

## Risks and unknowns

- **CloudKit Development vs Production schema deployment.**
  Development auto-pushes schema on app run; Production requires a
  manual "Deploy Schema Changes" click in CloudKit Console. Easy to
  forget before TestFlight → confusing sync failures in production
  only. Mitigation: add a checklist item to the v0.1 release doc
  (not this PR).
- **First-launch schema bootstrap race.** SwiftData pushes record
  types on first use of the container. If the user's network is
  offline on first launch, the push is deferred; subsequent
  connectivity usually resolves it. Needs manual spot-check.
- **`@Attribute(.allowsCloudEncryption)` not applied.** CloudKit
  supports field-level encryption that protects data even against
  iCloud backend access. Arguably aligns with privacy ethos but
  encrypted fields can't be queried server-side or used in
  `CKQuery` — irrelevant for us since we don't query CloudKit
  directly. Worth considering for `note` and `name` as a v1.0
  hardening pass; out of scope for v0.1.
- **iPad multi-window / background sync timing.** SwiftData-CloudKit
  syncs on app foreground and periodically in background. Gaps can
  be long (minutes). Two-device verification should allow for that.
- **Crashlog / silent failure mode.** If entitlements are
  misconfigured, the `ModelContainer` may still build and silently
  drop to local-only. Mitigation: observe
  `NSPersistentCloudKitContainer.eventChangedNotification` in debug
  builds to log sync events to Xcode console. (Investigation: is
  this notification visible through SwiftData's abstraction? Needs
  a smoke test.)
- **Container identifier mismatch.** If the entitlements file says
  `iCloud.dev.scastiel.kado` but the `ModelConfiguration` uses a
  different string, the sync silently does nothing. Keep both
  values in one named constant (e.g., `CloudContainerID.kado =
  "iCloud.dev.scastiel.kado"`) referenced by
  `ModelConfiguration`.

## Open questions

_All resolved during planning on 2026-04-17:_

- [x] **§1 — Roadmap divergence.** Resolved: drop the in-app toggle.
      Settings surfaces account status only; user control is iOS
      Settings → iCloud → Kado. The roadmap bullet "iCloud sync on/off"
      should be reinterpreted as "iCloud sync surface (status)."
- [x] **§2 — Pre-CloudKit local data.** Resolved: wipe and start
      clean is acceptable for v0.1 dogfood. No migration code.
- [x] **§3 — Schema deploy timing.** Resolved: stay on CloudKit
      Development through v0.1–v0.3. Production deploy is a v1.0
      release-prep checklist item.

## External prerequisites (not code tasks)

User-managed, captured here so they don't get lost:

- [ ] Enable iCloud + CloudKit on the `dev.scastiel.kado` App ID in
      Apple Developer portal.
- [ ] Create `iCloud.dev.scastiel.kado` container under *Identifiers
      → iCloud Containers*, associate with the App ID.
- [ ] Xcode will handle entitlements/provisioning refresh
      automatically via "+ Capability → iCloud → CloudKit".

## References

- Apple — [Syncing model data across a user's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-users-devices)
- Apple — [`ModelConfiguration.cloudKitDatabase`](https://developer.apple.com/documentation/swiftdata/modelconfiguration/init(_:schema:url:allowssave:isstoredinmemoryonly:groupcontainer:cloudkitdatabase:))
- Apple — [CloudKit Console](https://icloud.developer.apple.com/dashboard)
- Fatbobman — [Rules for Adapting Data Models to CloudKit](https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/)
  (already applied in swiftdata-models)
- Apple — [`CKContainer.accountStatus`](https://developer.apple.com/documentation/cloudkit/ckcontainer/1399180-accountstatus)
- Apple — [`SettingsLink`](https://developer.apple.com/documentation/swiftui/settingslink)
