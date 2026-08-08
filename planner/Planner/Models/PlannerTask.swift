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
    var durationMinutes: Int = 60
    var reminderMinutesBefore: Int = 15
    var isCompleted: Bool = false
    var checkInSent: Bool = false
    var createdAt: Date = Date()

    init(
        title: String,
        notes: String? = nil,
        scheduledDate: Date,
        startHour: Int,
        durationMinutes: Int = 60,
        reminderMinutesBefore: Int = 15,
        isCompleted: Bool = false,
        checkInSent: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.scheduledDate = scheduledDate
        self.startHour = startHour
        self.durationMinutes = durationMinutes
        self.reminderMinutesBefore = reminderMinutesBefore
        self.isCompleted = isCompleted
        self.checkInSent = checkInSent
        self.createdAt = Date()
    }
}
