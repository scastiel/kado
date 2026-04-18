import Foundation

/// Habit kinds, each driving a different `value[n]` derivation in the
/// score calculator.
///
/// Codable shape is owned explicitly (not synthesized) so the on-disk
/// format survives compiler upgrades and stays human-readable. See
/// `HabitTypeCodingTests` for the canonical JSON per case.
nonisolated public enum HabitType: Hashable, Codable, Sendable {
    case binary
    case counter(target: Double)
    case timer(targetSeconds: TimeInterval)
    case negative

    private enum Kind: String, Codable {
        case binary, counter, timer, negative
    }

    private enum CodingKeys: String, CodingKey {
        case kind, target, targetSeconds
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .binary:
            try container.encode(Kind.binary, forKey: .kind)
        case .counter(let target):
            try container.encode(Kind.counter, forKey: .kind)
            try container.encode(target, forKey: .target)
        case .timer(let targetSeconds):
            try container.encode(Kind.timer, forKey: .kind)
            try container.encode(targetSeconds, forKey: .targetSeconds)
        case .negative:
            try container.encode(Kind.negative, forKey: .kind)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .binary:
            self = .binary
        case .counter:
            self = .counter(target: try container.decode(Double.self, forKey: .target))
        case .timer:
            self = .timer(targetSeconds: try container.decode(TimeInterval.self, forKey: .targetSeconds))
        case .negative:
            self = .negative
        }
    }
}
