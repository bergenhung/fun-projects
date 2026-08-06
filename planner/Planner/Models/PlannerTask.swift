import Foundation
import SwiftData

@Model
final class PlannerTask: Identifiable {
    var id: UUID
    var title: String
    var notes: String?
    var scheduledDate: Date
    var startHour: Int
    var durationMinutes: Int
    var reminderMinutesBefore: Int
    var isCompleted: Bool
    var checkInSent: Bool
    var createdAt: Date

    init(
        title: String,
        notes: String? = nil,
        scheduledDate: Date,
        startHour: Int,
        durationMinutes: Int = 60,
        reminderMinutesBefore: Int = 30,
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
