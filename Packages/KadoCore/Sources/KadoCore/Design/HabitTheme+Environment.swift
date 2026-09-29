import SwiftUI

public extension EnvironmentValues {
    /// The habit colour theme views paint every `HabitColor` in.
    /// `KadoApp` injects the stored choice at the root and each widget
    /// injects it from `HabitThemeDefaults`, so a switch in Settings
    /// re-renders every reader — which a global `HabitColor.color`
    /// read implicitly could not do without an `.id(...)` remount.
    @Entry var habitTheme: HabitTheme = HabitThemeDefaults.defaultValue
}
