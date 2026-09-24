# Research — Widget habit selection, second attempt (#77)

**Date**: 2026-09-20
**Status**: complete
**Issue**: [#77](https://github.com/scastiel/kado/issues/77)
**Plan**: [plan.md](./plan.md) · **Compound**: [compound.md](./compound.md)

## Question

The first attempt (#76) built the whole feature and reverted it because the widget extension could not read back a stored pick:

```
Failed to build EntityIdentifier. HabitEntity is not a registered AppEntity identifier
```

The issue's diagnosis was that `HabitEntity` living in the KadoCore package kept it out of AppIntents' runtime registry, and its suggested next step was to move the entity and the configuration intents into the extension target. This pass had to answer, before any of that was built: **what does "registered" mean inside AppIntents, and why does the extension miss a type its own manifest and binary both contain?**

## Answer, in one paragraph

Nothing was wrong with the code. The pick failed to decode because **the simulator build is ad-hoc signed, and on iOS 26.x `linkd` refuses to serve AppIntents metadata to a client it cannot attribute to a team**. The reverted code — `SelectHabitsIntent` with `[HabitEntity]?` in KadoCore — decodes a stored pick correctly on an iOS 27 simulator as-is, and on an iOS 26.5 simulator the moment the build is re-signed with a development identity. A TestFlight or App Store build is team-signed and never had the problem. The same applies to the lock-screen `PickHabitIntent`, which #77 feared was broken in production: it is not.

## How it was established

### 1. Where the message comes from

`strings` / `nm` / `otool` on `AppIntents.framework` (iOS 26.5 runtime; identical strings in the iOS 27 shared cache):

- `AppIntents.EntityIdentifier.init(LNEntityIdentifier)` reads the stored identifier's `typeIdentifier` (the **unqualified** type name, `"HabitEntity"`) and asks `AppManager` for an `AppEntity.Type` under that name; `nil` logs `Failed to build EntityIdentifier. %s is not a registered AppEntity identifier`.
- `AppManager.TypeCache.appEntities` is filled from metadata records, either handed over XPC by `linkd` or read from `Bundle.main/Metadata.appintents`, each materialised with `swift_getTypeByMangledNameInContext2(mangledTypeName)`.
- `AppIntentsPackage` has **no runtime code** in the framework; it is a build-time / `linkd`-index concept for dynamic frameworks. It could never have fixed this, and #76 saw that it didn't. Not restored.
- The appex manifest and binary both carry `KadoCore.HabitEntity` (`8KadoCore11HabitEntityV`, descriptors, conformance). Nothing is missing on disk.

### 2. The single-entity path, watched live (iOS 27.0 simulator, ad-hoc build)

`main`'s lock-widget path — `PickHabitIntent` + `PickedSnapshotProvider`, both in KadoCore — hosted on the small home widget for the experiment, one `Logger.debug` in the provider, the `com.apple.appintents` subsystem streamed at debug level:

```
[ValueConversion] Converting single entity value type with identifier: HabitEntity, isTransient: false, bundleIdentifier: com.apple.siriactionsd, boxed: true
[ValueConversion] Non-transient entity, converting to EntityIdentifier
[Metadata] Cache miss for <unknown>:HabitEntity
[Metadata] Loading <unknown>:HabitEntity from provider
linkd: Created AppShortcutClient with bundleId: dev.scastiel.kado.KadoWidgets from dev.scastiel.kado
linkd: Request from dev.scastiel.kado.KadoWidgets for AppEntity:local:HabitEntity
linkd: Searching bundles: dev.scastiel.kado, com.apple.AppIntents
[Execution] Prepared habit to HabitEntity(<mask.hash>)
[Execution] Building resolver: EntityIdentifier → Optional<HabitEntity>:PickHabitIntent:habit
[Execution] Perform HabitEntityQuery with: 717D7226-…
[dev.scastiel.kado:widget] timeline family=systemSmall picked=1 snapshotHabits=7
```

The registry is **not** the static manifest: `Registering AppManager tables from static metadata bundle` never appears. The extension asks `linkd` over XPC, and `linkd` answers from the *app's* bundle.

### 3. The array path, watched live (iOS 27.0 simulator, ad-hoc build)

#76's exact `SelectHabitsIntent` (`[HabitEntity]?`, per-family `size:` caps), two habits picked out of app order through the widget-edit sheet, then the extension process killed so the next decode is cold:

```
[ValueConversion] Converting entity array of HabitEntity with 2 elements, bundleIdentifier: com.apple.siriactionsd, boxed: true
[Metadata] Cache miss for <unknown>:HabitEntity
[Metadata] Loading <unknown>:HabitEntity from provider
linkd: Request from dev.scastiel.kado.KadoWidgets for AppEntity:local:HabitEntity
[Execution] Prepared habits to Array<HabitEntity>(<mask.hash>)
[Execution] Building resolver: Array<EntityIdentifier> → Optional<Array<HabitEntity>>:SelectHabitsIntent:habits
[dev.scastiel.kado:widget] timeline family=systemSmall picked=2 paramNil=false snapshotHabits=7
```

`picked=2`. The code #76 reverted works, cold and warm.

### 4. The same build on an iOS 26.5 simulator — the failure, with its cause

```
[ValueConversion] Converting entity array of HabitEntity with 2 elements, bundleIdentifier: nil, boxed: true
[ValueConversion] Array contains non-transient entities, converting to EntityIdentifier array
[Metadata] Cache miss for <unknown>:HabitEntity
[Metadata] Loading <unknown>:HabitEntity from provider
linkd: Failed to generate bundleIdentity:
 -Not a platform binary, checking teamId...
 -Unable to get teamId from dev.scastiel.kado.KadoWidgets PID [21916]
linkd: Rejecting invalid client due to requiresValidBundle: connection from pid 21916 on mach service named com.apple.linkd.autoShortcut
[Execution] Prepared habits to Array<HabitEntity>(<mask.hash>)
[Execution] Building resolver: Array<EntityIdentifier> → Optional<Array<HabitEntity>>:SelectHabitsIntent:habits
[dev.scastiel.kado:widget] timeline family=systemSmall picked=0 paramNil=false snapshotHabits=7
```

`linkd` on 26.5 wants a team identifier from the client's code signature. Xcode signs simulator builds ad hoc (`codesign -dvv`: `Signature=adhoc`, `TeamIdentifier=not set`, for the app **and** the appex), and it refuses to do otherwise — `AD_HOC_CODE_SIGNING_ALLOWED=NO` fails with `Ad Hoc code signing is not allowed with SDK 'Simulator - iOS 27.0'`, and a `CODE_SIGN_IDENTITY` override is ignored. The app process was rejected on the same service too (`Unable to get teamId from dev.scastiel.kado PID [21964]`), so on that runtime the Shortcuts intents' entity parameters fail in the simulator as well. The picker itself keeps working because the widget-edit sheet fetches options through a different service.

### 5. The proof

Re-sign the built products with the development identity (nested code first: debug dylibs, the appex, then the app, each with its own entitlements), reinstall over the same placed widget, kill the extension, reload:

```
$ codesign -dvv Kado.app/PlugIns/KadoWidgetsExtension.appex
TeamIdentifier=VKY5EKKU47
```
```
linkd: Created AppShortcutClient with bundleId: dev.scastiel.kado.KadoWidgets from dev.scastiel.kado
[Execution] Prepared habits to Array<HabitEntity>(<mask.hash>)
[dev.scastiel.kado:widget] timeline family=systemSmall picked=2 paramNil=false snapshotHabits=7
```

Same code, same stored pick, same runtime; the only change is a team identifier on the signature.

## What this means for the design

- **Keep every intent and entity in KadoCore**, as the project's rule says. The issue's step 2 (move them into the extension target) would have been a large change that did not address the cause — the rejected client is the *process*, wherever the type is compiled.
- **The lock-screen widgets are fine in production.** Their picks failed on iOS 26.x simulators for the same reason and only there.
- **Verifying AppIntents on a simulator needs a team-signed build on iOS 26.x, or an iOS 27 runtime.** A post-build re-sign is the only way to get the former; `Scripts/resign-simulator.sh` does it and `make run` calls it when an Apple Development identity is on the machine.
- **Verify by the log, not the tile**: `dev.scastiel.kado` for `picked=N paramNil=…`, and `com.apple.appintents` at debug level for `Rejecting invalid client` / `Loading … from provider`.

## Ruled out (from #77, still standing — with the cause now known, none of them could have helped)

| Suspect | Result |
|---|---|
| Stale widget record after `StaticConfiguration` → `AppIntentConfiguration` | Deleting and re-adding changes nothing |
| Xcode's debug dylib | `ENABLE_DEBUG_DYLIB=NO` — identical |
| KadoCore linked statically | `type: .dynamic` — identical; reverted |
| Missing or malformed metadata | Present and correct |
| Missing `AppIntentsPackage` | Added; not sufficient — and inert at runtime |
| Unit-test probe of `EntityIdentifier` | Proves nothing: the test host loads no registry |
| *(this pass)* Entity defined in a Swift package | Decodes on iOS 27 as-is and on 26.5 once signed |
| *(this pass)* Array vs single entity | Both decode once the client is accepted |
| *(this pass)* Cold vs warm extension process | Both decode once the client is accepted |

## Tooling notes

- XcodeBuildMCP's bundled `axe` reads the accessibility tree and takes screenshots on this runtime but its HID taps never land under Xcode 27 / iOS 27. A throwaway XCUITest driving `com.apple.springboard` (long-press → Edit → Add Widget → search → Add Widget → Done → long-press → Edit Widget → `editor.list.add-item` → cell) places the widget and picks habits reliably. It is deliberately not part of the suite (see plan, Out of scope) — the follow-up issue carries it.
- `xcodebuild test` on this runtime sometimes does not exit after the suite finishes; the console log is complete when that happens. `pkill -f "xcodebuild test"`.
- Uninstall between iterations when comparing builds: `linkd` caches installed manifests.
