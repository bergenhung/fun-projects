import SwiftUI
import SwiftData

@main
struct PlannerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PlannerTask.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            if ProcessInfo.processInfo.arguments.contains("-seedSampleData") {
                let today = Calendar.current.startOfDay(for: Date())
                let currentHour = Calendar.current.component(.hour, from: Date())
                let samples = [
                    PlannerTask(title: "Standup", scheduledDate: today, startHour: currentHour, durationMinutes: 30),
                    PlannerTask(title: "Write report", scheduledDate: today, startHour: currentHour, durationMinutes: 60),
                    PlannerTask(title: "Gym", scheduledDate: today, startHour: currentHour + 2, durationMinutes: 45, isCompleted: true),
                ]
                samples.forEach { container.mainContext.insert($0) }
            }
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
