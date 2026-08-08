import SwiftUI
import SwiftData
import UserNotifications

@main
struct PlannerApp: App {
    private let sharedModelContainer: ModelContainer
    private let notificationDelegate: PlannerNotificationDelegate

    init() {
        let schema = Schema([
            PlannerTask.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        if ProcessInfo.processInfo.arguments.contains("-seedSampleData") {
            let today = Calendar.current.startOfDay(for: Date())
            let rawHour = Calendar.current.component(.hour, from: Date())
            let hour = min(max(rawHour, GridConfig.startHour), GridConfig.endHour - 1)
            let secondHour = min(hour + 2, GridConfig.endHour - 1)
            let samples = [
                PlannerTask(title: "Standup", scheduledDate: today, startHour: hour, durationMinutes: 30),
                PlannerTask(title: "Write report", scheduledDate: today, startHour: hour, durationMinutes: 60),
                PlannerTask(title: "Gym", scheduledDate: today, startHour: secondHour, durationMinutes: 45, isCompleted: true),
            ]
            samples.forEach { container.mainContext.insert($0) }
        }

        sharedModelContainer = container
        notificationDelegate = PlannerNotificationDelegate(modelContainer: container)
        UNUserNotificationCenter.current().delegate = notificationDelegate
        NotificationScheduler.registerCategories()
        NotificationScheduler.requestAuthorizationIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
