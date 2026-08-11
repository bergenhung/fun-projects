import Foundation

enum Weekday: Int, Codable, CaseIterable, Identifiable, Hashable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .sunday: "S"
        case .monday: "M"
        case .tuesday: "T"
        case .wednesday: "W"
        case .thursday: "T"
        case .friday: "F"
        case .saturday: "S"
        }
    }

    /// `Calendar.component(.weekday, from:)` returns 1 (Sunday) ... 7 (Saturday).
    static func from(calendarWeekday: Int) -> Weekday {
        Weekday(rawValue: calendarWeekday) ?? .sunday
    }
}

enum RecurrenceFrequency: Codable, Equatable {
    case daily
    case weekly
    case weekdays
    case custom(days: [Weekday])

    var label: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .weekdays: "Weekdays"
        case .custom: "Custom"
        }
    }
}

/// Stored on the first occurrence's `recurrenceRule`; every generated occurrence
/// carries a copy so `SeriesEditor` can regenerate/top-up without needing to look
/// the rule up elsewhere.
struct RecurrenceRule: Codable, Equatable {
    var frequency: RecurrenceFrequency
    var endDate: Date?
}

enum RecurrenceEngine {
    /// How far ahead to materialize actual PlannerTask rows for a series
    /// (bounded further by the rule's `endDate`, if any).
    static let materializationWindowDays = 60

    /// How far ahead to actually schedule notifications for. Kept short because
    /// UNUserNotificationCenter hard-caps an app at 64 pending local notifications
    /// total (2 per task: reminder + check-in) — a single daily series alone would
    /// exceed that within a month if every materialized occurrence were scheduled.
    /// Occurrences beyond this window get their notifications scheduled later, when
    /// the rolling top-up in `SeriesEditor` brings them within range.
    static let notificationHorizonDays = 7

    static func occurrenceDates(startingAt startDate: Date, rule: RecurrenceRule, windowDays: Int = materializationWindowDays) -> [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        var windowEnd = calendar.date(byAdding: .day, value: windowDays, to: start) ?? start
        if let endDate = rule.endDate {
            windowEnd = min(windowEnd, calendar.startOfDay(for: endDate))
        }
        guard windowEnd >= start else { return [start] }

        var dates: [Date] = []
        var current = start
        while current <= windowEnd {
            switch rule.frequency {
            case .daily, .weekly:
                dates.append(current)
            case .weekdays:
                let weekday = Weekday.from(calendarWeekday: calendar.component(.weekday, from: current))
                if weekday != .sunday && weekday != .saturday { dates.append(current) }
            case .custom(let days):
                let weekday = Weekday.from(calendarWeekday: calendar.component(.weekday, from: current))
                if days.contains(weekday) { dates.append(current) }
            }
            let step = (rule.frequency == .weekly) ? 7 : 1
            guard let next = calendar.date(byAdding: .day, value: step, to: current) else { break }
            current = next
        }
        return dates
    }
}
