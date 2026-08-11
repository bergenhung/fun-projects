import SwiftUI
import SwiftData
import UserNotifications

@main
struct PlannerApp: App {
    private let sharedModelContainer: ModelContainer?
    private let containerLoadError: String?
    private let notificationDelegate: PlannerNotificationDelegate?

    /// Without an explicit `url:`, SwiftData's default Mac store location
    /// (`~/Library/Application Support/default.store`) is shared by every
    /// unsandboxed SwiftData app on the machine — confirmed to collide with
    /// an unrelated app's store in practice (see CLAUDE.md). iOS doesn't need
    /// this: each app already gets its own sandboxed container.
    #if os(macOS)
    private static func plannerStoreURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = appSupport.appendingPathComponent("Planner", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("Planner.store")
    }
    #endif

    init() {
        let schema = Schema(versionedSchema: SchemaV2.self)
        #if os(macOS)
        let modelConfiguration = ModelConfiguration(schema: schema, url: Self.plannerStoreURL())
        #else
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        #endif

        do {
            let container = try ModelContainer(for: schema, migrationPlan: PlannerMigrationPlan.self, configurations: [modelConfiguration])

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
            containerLoadError = nil

            let delegate = PlannerNotificationDelegate(modelContainer: container)
            notificationDelegate = delegate
            UNUserNotificationCenter.current().delegate = delegate
            NotificationScheduler.registerCategories()
            NotificationScheduler.requestAuthorizationIfNeeded()
        } catch {
            // Not fatalError()-ing: a crash-looping app pushes users toward
            // "delete and reinstall," which is what actually destroys the
            // on-disk store (see CLAUDE.md). Surface the error instead.
            sharedModelContainer = nil
            containerLoadError = error.localizedDescription
            notificationDelegate = nil
        }
    }

    var body: some Scene {
        WindowGroup {
            if let sharedModelContainer {
                ContentView()
                    .modelContainer(sharedModelContainer)
            } else {
                DataLoadErrorView(message: containerLoadError ?? "Unknown error")
            }
        }
    }
}

private struct DataLoadErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("Couldn't Load Your Tasks")
                .font(.title2.bold())
            Text("Your existing data is most likely still on this device. Deleting and reinstalling the app is what would actually lose it — please don't do that. Instead, share the message below so the problem can be diagnosed.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Text(message)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .padding()
                .background(Color.gray.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
        }
        .padding()
    }
}
