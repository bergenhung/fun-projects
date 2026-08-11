import Foundation
import SwiftData

// Every stored property has an inline default, as required for a SwiftData
// model to be CloudKit-syncable (see Milestone 6 notes in CLAUDE.md).
@Model
final class PlannerTask: Identifiable {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String?
    var scheduledDate: Date = Date()
    var startHour: Int = 0
    /// Minute within `startHour`, one of 0/15/30/45. Additive field (default 0)
    /// so existing rows — which were always implicitly :00 — need no migration.
    var startMinute: Int = 0
    var durationMinutes: Int = 60
    var reminderMinutesBefore: Int = 15
    var isCompleted: Bool = false
    var checkInSent: Bool = false
    var createdAt: Date = Date()

    /// Non-nil when this task is one occurrence of a recurring series; every
    /// occurrence in the same series shares a `recurrenceParentId` but is
    /// otherwise an independent row (own isCompleted/checkInSent/notifications),
    /// so completing or editing one day's occurrence never affects the others.
    var recurrenceParentId: UUID?

    /// Flat, primitive-only storage for recurrence — deliberately not
    /// `RecurrenceRule` directly (see `SchemaV1` in PlannerSchema.swift and
    /// CLAUDE.md's "Past crash" note: SwiftData's automatic storage for that
    /// enum's associated-value case caused a real crash). `recurrenceRule`
    /// below is a computed bridge so every other call site is unaffected.
    var recurrenceFrequencyRaw: String?
    var recurrenceCustomDays: [Int] = []
    var recurrenceEndDate: Date?

    var recurrenceRule: RecurrenceRule? {
        get {
            guard let raw = recurrenceFrequencyRaw else { return nil }
            let frequency: RecurrenceFrequency
            switch raw {
            case "daily": frequency = .daily
            case "weekly": frequency = .weekly
            case "weekdays": frequency = .weekdays
            case "custom": frequency = .custom(days: recurrenceCustomDays.compactMap(Weekday.init(rawValue:)))
            default: return nil
            }
            return RecurrenceRule(frequency: frequency, endDate: recurrenceEndDate)
        }
        set {
            guard let newValue else {
                recurrenceFrequencyRaw = nil
                recurrenceCustomDays = []
                recurrenceEndDate = nil
                return
            }
            switch newValue.frequency {
            case .daily:
                recurrenceFrequencyRaw = "daily"
                recurrenceCustomDays = []
            case .weekly:
                recurrenceFrequencyRaw = "weekly"
                recurrenceCustomDays = []
            case .weekdays:
                recurrenceFrequencyRaw = "weekdays"
                recurrenceCustomDays = []
            case .custom(let days):
                recurrenceFrequencyRaw = "custom"
                recurrenceCustomDays = days.map(\.rawValue)
            }
            recurrenceEndDate = newValue.endDate
        }
    }

    init(
        title: String,
        notes: String? = nil,
        scheduledDate: Date,
        startHour: Int,
        startMinute: Int = 0,
        durationMinutes: Int = 60,
        reminderMinutesBefore: Int = 15,
        isCompleted: Bool = false,
        checkInSent: Bool = false,
        recurrenceParentId: UUID? = nil,
        recurrenceRule: RecurrenceRule? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.scheduledDate = scheduledDate
        self.startHour = startHour
        self.startMinute = startMinute
        self.durationMinutes = durationMinutes
        self.reminderMinutesBefore = reminderMinutesBefore
        self.isCompleted = isCompleted
        self.checkInSent = checkInSent
        self.createdAt = Date()
        self.recurrenceParentId = recurrenceParentId
        self.recurrenceRule = recurrenceRule
    }
}
