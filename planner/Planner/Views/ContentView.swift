import SwiftUI
import SwiftData
import UserNotifications

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var tasks: [PlannerTask]

    @State private var showingAddSheet = false
    @State private var addSheetDefaultHour: Int?
    @State private var editingTask: PlannerTask?
    @State private var showingVoiceEntry = false
    @State private var notificationsDenied = false

    init() {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let startOfNextDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        _tasks = Query(
            filter: #Predicate<PlannerTask> { $0.scheduledDate >= startOfDay && $0.scheduledDate < startOfNextDay },
            sort: \PlannerTask.startHour
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if notificationsDenied {
                    notificationsDeniedBanner
                }
                content
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        addSheetDefaultHour = nil
                        showingAddSheet = true
                    } label: {
                        Label("Add Task", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingVoiceEntry = true
                    } label: {
                        Label("Add by Voice", systemImage: "mic")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddEditTaskView(defaultHour: addSheetDefaultHour)
            }
            .sheet(item: $editingTask) { task in
                AddEditTaskView(task: task)
            }
            .sheet(isPresented: $showingVoiceEntry) {
                VoiceEntryView(existingTasks: tasks)
            }
            .task { await refreshNotificationStatus() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await refreshNotificationStatus() }
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if tasks.isEmpty {
            ContentUnavailableView {
                Label("No Tasks Yet", systemImage: "calendar.day.timeline.left")
            } description: {
                Text("Add a task to see it in today's hourly grid.")
            } actions: {
                Button("Add Task") {
                    addSheetDefaultHour = nil
                    showingAddSheet = true
                }
            }
        } else {
            HourlyGridView(
                tasks: tasks,
                onToggleComplete: toggleComplete,
                onEdit: { editingTask = $0 },
                onDelete: delete,
                onAddAtHour: { hour in
                    addSheetDefaultHour = hour
                    showingAddSheet = true
                }
            )
        }
    }

    private var notificationsDeniedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .foregroundStyle(.orange)
            Text("Notifications are off, so reminders and check-ins won't appear.")
                .font(.footnote)
            Spacer()
            #if os(iOS)
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.footnote.bold())
            #endif
        }
        .padding(10)
        .background(Color.orange.opacity(0.12))
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsDenied = settings.authorizationStatus == .denied
    }

    private func toggleComplete(_ task: PlannerTask) {
        task.isCompleted.toggle()
        if task.isCompleted {
            NotificationScheduler.cancelCheckIn(for: task)
        } else {
            NotificationScheduler.reschedule(for: task)
        }
    }

    private func delete(_ task: PlannerTask) {
        NotificationScheduler.cancelAll(for: task)
        modelContext.delete(task)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: PlannerTask.self, inMemory: true)
}
