import Foundation

/// One source of truth for the CloudKit container identifier so the
/// `ModelConfiguration` and the account-status observer can never
/// drift apart from a typo. Must match the entitlement string in
/// `Kado.entitlements` and the container registered in the Apple
/// Developer portal.
///
/// `nonisolated` so the provider (which runs outside MainActor) can
/// reference the identifier without the project-wide MainActor
/// default propagating in and warning.
nonisolated public enum CloudContainerID {
    public static let kado = "iCloud.dev.scastiel.kado"
}
