import AppIntents

/// Makes the App Intents *defined in this package* discoverable by the
/// targets that link it.
///
/// Every `AppIntent`, `AppEntity` and `WidgetConfigurationIntent` in
/// Kadō lives here rather than in the app or the widget extension, and
/// AppIntents does not find those on its own: a module that vends them
/// has to declare an `AppIntentsPackage`, and every target that
/// consumes them has to name it in `includedPackages`. See
/// `KadoAppIntentsPackage` (app) and `KadoWidgetsAppIntentsPackage`
/// (widget extension).
///
/// Skipping this compiles, links, and *mostly* works, which is what
/// makes it dangerous. Metadata extraction still writes the intents
/// into the bundle, so a widget's configuration sheet appears and its
/// habit picker populates — `HabitEntityQuery.suggestedEntities()` is
/// called live and needs no registry. What breaks is the way back:
/// a stored selection is persisted as entity *identifiers*, and
/// decoding those requires the entity type to be registered at
/// runtime. Unregistered, the decode fails with
///
///     Failed to build EntityIdentifier.
///     HabitEntity is not a registered AppEntity identifier
///
/// on the console and `nil` in the intent — so the widget receives an
/// empty selection and renders every habit, exactly as though the user
/// had never chosen. Nothing throws, nothing looks broken, and the
/// only evidence is that log line.
public struct KadoCoreAppIntentsPackage: AppIntentsPackage {
    public init() {}
}
