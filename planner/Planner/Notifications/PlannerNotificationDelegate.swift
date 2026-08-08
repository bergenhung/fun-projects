import Foundation
import UserNotifications
import SwiftData

/// Handles local notification delivery/actions so the completion check-in's
/// Yes/No buttons can update task state without opening the app. Delegate
/// callbacks can land on a background queue, so this uses its own ModelContext
/// rather than the UI's main-actor-bound one.
final class PlannerNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        markDelivered(notification.request.content)
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let content = response.notification.request.content
        markDelivered(content)
        if response.actionIdentifier == NotificationScheduler.checkInYesActionID {
            mutateTask(for: content) { $0.isCompleted = true }
        }
        completionHandler()
    }

    private func markDelivered(_ content: UNNotificationContent) {
        mutateTask(for: content) { $0.checkInSent = true }
    }

    private func mutateTask(for content: UNNotificationContent, _ update: (PlannerTask) -> Void) {
        guard content.categoryIdentifier == NotificationScheduler.checkInCategoryID,
              let idString = content.userInfo[NotificationScheduler.taskIDKey] as? String,
              let id = UUID(uuidString: idString) else { return }

        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<PlannerTask>(predicate: #Predicate { $0.id == id })
        guard let task = try? context.fetch(descriptor).first else { return }
        update(task)
        try? context.save()
    }
}
