import Foundation
import UserNotifications

enum NotificationScheduler {
    static let checkInCategoryID = "TASK_CHECKIN"
    static let checkInYesActionID = "CHECKIN_YES"
    static let checkInNoActionID = "CHECKIN_NO"
    static let taskIDKey = "taskID"

    static func registerCategories() {
        let yes = UNNotificationAction(identifier: checkInYesActionID, title: "Yes", options: [])
        let no = UNNotificationAction(identifier: checkInNoActionID, title: "No", options: [])
        let checkInCategory = UNNotificationCategory(
            identifier: checkInCategoryID,
            actions: [yes, no],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([checkInCategory])
    }

    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    /// A task's nominal start instant: `startHour`:`startMinute` on `scheduledDate`.
    static func startDate(for task: PlannerTask) -> Date? {
        Calendar.current.date(bySettingHour: task.startHour, minute: task.startMinute, second: 0, of: task.scheduledDate)
    }

    private static func reminderIdentifier(for task: PlannerTask) -> String {
        "reminder-\(task.id.uuidString)"
    }

    private static func checkInIdentifier(for task: PlannerTask) -> String {
        "checkin-\(task.id.uuidString)"
    }

    /// Cancels any existing reminder/check-in for this task and reschedules both
    /// from its current field values. Call after any create/edit that could move
    /// the task's time, and skip entirely once a task is completed.
    static func reschedule(for task: PlannerTask) {
        cancelAll(for: task)
        guard !task.isCompleted, let startDate = startDate(for: task) else { return }

        let reminderDate = startDate.addingTimeInterval(-Double(task.reminderMinutesBefore) * 60)
        if reminderDate > Date() {
            let content = UNMutableNotificationContent()
            content.title = task.title
            content.body = task.reminderMinutesBefore == 0
                ? "Starting now"
                : "Starts in \(task.reminderMinutesBefore) min"
            content.sound = .default
            schedule(identifier: reminderIdentifier(for: task), date: reminderDate, content: content)
        }

        let checkInDate = startDate.addingTimeInterval(Double(task.durationMinutes + 5) * 60)
        if checkInDate > Date() {
            let content = UNMutableNotificationContent()
            content.title = "Did you complete \"\(task.title)\"?"
            content.body = "Tap Yes or No."
            content.sound = .default
            content.categoryIdentifier = checkInCategoryID
            content.userInfo = [taskIDKey: task.id.uuidString]
            schedule(identifier: checkInIdentifier(for: task), date: checkInDate, content: content)
        }
    }

    static func cancelAll(for task: PlannerTask) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [reminderIdentifier(for: task), checkInIdentifier(for: task)]
        )
    }

    static func cancelCheckIn(for task: PlannerTask) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [checkInIdentifier(for: task)]
        )
    }

    private static func schedule(identifier: String, date: Date, content: UNNotificationContent) {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("NotificationScheduler: failed to schedule \(identifier): \(error)")
            }
        }
    }
}
