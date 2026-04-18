import Foundation

/// How often a habit is expected to be performed.
///
/// Codable shape is owned explicitly (not synthesized) so the on-disk
/// format survives compiler upgrades and stays human-readable. See
/// `FrequencyCodingTests` for the canonical JSON per case.
nonisolated public enum Frequency: Hashable, Codable, Sendable {
    case daily
    case daysPerWeek(Int)
    case specificDays(Set<Weekday>)
    case everyNDays(Int)

    private enum Kind: String, Codable {
        case daily, daysPerWeek, specificDays, everyNDays
    }

    private enum CodingKeys: String, CodingKey {
        case kind, count, days, interval
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .daily:
            try container.encode(Kind.daily, forKey: .kind)
        case .daysPerWeek(let count):
            try container.encode(Kind.daysPerWeek, forKey: .kind)
            try container.encode(count, forKey: .count)
        case .specificDays(let days):
            try container.encode(Kind.specificDays, forKey: .kind)
            try container.encode(days.map(\.rawValue).sorted(), forKey: .days)
        case .everyNDays(let interval):
            try container.encode(Kind.everyNDays, forKey: .kind)
            try container.encode(interval, forKey: .interval)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .daily:
            self = .daily
        case .daysPerWeek:
            self = .daysPerWeek(try container.decode(Int.self, forKey: .count))
        case .specificDays:
            let rawValues = try container.decode([Int].self, forKey: .days)
            self = .specificDays(Set(rawValues.compactMap { Weekday(rawValue: $0) }))
        case .everyNDays:
            self = .everyNDays(try container.decode(Int.self, forKey: .interval))
        }
    }
}
