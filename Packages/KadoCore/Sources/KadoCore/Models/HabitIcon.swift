import Foundation

/// A curated shortlist of SF Symbol names usable as habit glyphs. The
/// list is intentionally short (~30) to keep the picker scannable;
/// full SF Symbol search is deferred.
public enum HabitIcon {
    /// Fallback symbol for habits that haven't picked an icon (e.g. V1
    /// habits migrated to V2 without user interaction).
    public static let `default`: String = "circle"

    public static let curated: [String] = [
        // Movement
        "figure.walk",
        "figure.run",
        "dumbbell.fill",
        "figure.yoga",
        "bicycle",
        "figure.pool.swim",

        // Mind + body
        "figure.mind.and.body",
        "leaf.fill",
        "moon.stars.fill",
        "bed.double.fill",

        // Nutrition + hydration
        "drop.fill",
        "cup.and.saucer.fill",
        "fork.knife",
        "carrot.fill",

        // Learning + creative
        "book.fill",
        "pencil",
        "music.note",
        "paintbrush.fill",
        "camera.fill",

        // Health + wellbeing
        "heart.fill",
        "pills.fill",

        // Daily rhythms
        "sun.max.fill",
        "flame.fill",
        "sparkles",
        "star.fill",
        "checkmark.circle.fill",
        "target",

        // Work + home
        "laptopcomputer",
        "phone.fill",
        "house.fill",
    ]
}
