import SwiftUI
import SwiftData
import UserNotifications

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: [SortDescriptor(\PlannerTask.scheduledDate), SortDescriptor(\PlannerTask.startHour)])
    private var allTasks: [PlannerTask]

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var showingAddSheet = false
    @State private var addSheetDefaultHour: Int?
    @State private var editingTask: PlannerTask?
    @State private var showingVoiceEntry = false
    @State private var showingDateJump = false
    @State private var notificationsDenied = false
    @State private var pendingRetime: PendingRetime?
    @State private var showingRetimeScopeOptions = false

    private struct PendingRetime {
        let task: PlannerTask
        let newStartHour: Int
        let newStartMinute: Int
        let newDurationMinutes: Int
    }

    private var tasksForSelectedDate: [PlannerTask] {
        allTasks.filter { Calendar.current.isDate($0.scheduledDate, inSameDayAs: selectedDate) }
    }

    private var isViewingToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var titleText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) { return "Today" }
        if calendar.isDateInTomorrow(selectedDate) { return "Tomorrow" }
        if calendar.isDateInYesterday(selectedDate) { return "Yesterday" }
        return selectedDate.formatted(.dateTime.weekday(.abbreviated).month().day())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if notificationsDenied {
                    notificationsDeniedBanner
                }
                content
            }
            .navigationTitle(titleText)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    HStack(spacing: 4) {
                        Button {
                            stepDate(by: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        Button {
                            stepDate(by: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                        Button {
                            showingDateJump = true
                        } label: {
                            Image(systemName: "calendar")
                        }
                    }
                }
                if !isViewingToday {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Today") {
                            selectedDate = Calendar.current.startOfDay(for: Date())
                        }
                    }
                }
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
                AddEditTaskView(defaultHour: addSheetDefaultHour, defaultDate: selectedDate)
            }
            .sheet(item: $editingTask) { task in
                AddEditTaskView(task: task)
            }
            .sheet(isPresented: $showingVoiceEntry) {
                VoiceEntryView(existingTasks: tasksForSelectedDate, targetDate: selectedDate)
            }
            .sheet(isPresented: $showingDateJump) {
                DateJumpView(selectedDate: $selectedDate)
            }
            .task {
                await refreshNotificationStatus()
                SeriesEditor.topUpAllSeries(context: modelContext)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task {
                        await refreshNotificationStatus()
                        SeriesEditor.topUpAllSeries(context: modelContext)
                    }
                }
            }
            .confirmationDialog(
                "Apply Time Change",
                isPresented: $showingRetimeScopeOptions,
                presenting: pendingRetime
            ) { pending in
                Button("This Occurrence Only") { applyRetime(pending, cascadeToFuture: false) }
                Button("This and Future Occurrences") { applyRetime(pending, cascadeToFuture: true) }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        contentBody
            .simultaneousGesture(daySwipeGesture)
    }

    /// A decisively-horizontal drag steps the day; near-vertical drags are left
    /// alone so they don't fight the grid's own vertical ScrollView.
    private var daySwipeGesture: some Gesture {
        DragGesture(minimumDistance: 40, coordinateSpace: .local)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical) * 1.5, abs(horizontal) > 60 else { return }
                stepDate(by: horizontal < 0 ? 1 : -1)
            }
    }

    @ViewBuilder
    private var contentBody: some View {
        if tasksForSelectedDate.isEmpty {
            ContentUnavailableView {
                Label("No Tasks Yet", systemImage: "calendar.day.timeline.left")
            } description: {
                Text(isViewingToday ? "Add a task to see it in today's hourly grid." : "No tasks scheduled for \(titleText).")
            } actions: {
                Button("Add Task") {
                    addSheetDefaultHour = nil
                    showingAddSheet = true
                }
            }
        } else {
            HourlyGridView(
                tasks: tasksForSelectedDate,
                isViewingToday: isViewingToday,
                onToggleComplete: toggleComplete,
                onEdit: { editingTask = $0 },
                onDelete: delete,
                onDeleteSeries: deleteSeries,
                onAddAtHour: { hour in
                    addSheetDefaultHour = hour
                    showingAddSheet = true
                },
                onRetime: retime
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

    private func stepDate(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
        }
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsDenied = settings.authorizationStatus == .denied
    }

    /// Persists immediately rather than leaving it to SwiftData's implicit
    /// autosave, whose timing isn't in our control (e.g. it fires on the app
    /// losing focus) — see the "Past crash" note in CLAUDE.md for why relying
    /// on it alone let a crash silently swallow unsaved changes.
    private func persist() {
        try? modelContext.save()
    }

    private func toggleComplete(_ task: PlannerTask) {
        task.isCompleted.toggle()
        if task.isCompleted {
            NotificationScheduler.cancelCheckIn(for: task)
        } else {
            NotificationScheduler.reschedule(for: task)
        }
        persist()
    }

    private func delete(_ task: PlannerTask) {
        NotificationScheduler.cancelAll(for: task)
        modelContext.delete(task)
        persist()
    }

    private func deleteSeries(_ task: PlannerTask) {
        guard let recurrenceParentId = task.recurrenceParentId else { return }
        SeriesEditor.deleteEntireSeries(recurrenceParentId: recurrenceParentId, context: modelContext)
        persist()
    }

    /// Applies a drag-to-move or drag-to-resize on the grid. A one-off task
    /// commits immediately; a recurring occurrence asks "this occurrence" vs
    /// "this and future", same choice the Add/Edit sheet's Save offers.
    private func retime(_ task: PlannerTask, newStartHour: Int, newStartMinute: Int, newDurationMinutes: Int) {
        guard newStartHour != task.startHour || newStartMinute != task.startMinute || newDurationMinutes != task.durationMinutes else { return }
        if task.recurrenceParentId != nil {
            pendingRetime = PendingRetime(task: task, newStartHour: newStartHour, newStartMinute: newStartMinute, newDurationMinutes: newDurationMinutes)
            showingRetimeScopeOptions = true
        } else {
            applyRetime(task, newStartHour: newStartHour, newStartMinute: newStartMinute, newDurationMinutes: newDurationMinutes)
        }
    }

    private func applyRetime(_ pending: PendingRetime, cascadeToFuture: Bool) {
        applyRetime(
            pending.task,
            newStartHour: pending.newStartHour,
            newStartMinute: pending.newStartMinute,
            newDurationMinutes: pending.newDurationMinutes,
            cascadeToFuture: cascadeToFuture
        )
    }

    private func applyRetime(_ task: PlannerTask, newStartHour: Int, newStartMinute: Int, newDurationMinutes: Int, cascadeToFuture: Bool = false) {
        task.startHour = newStartHour
        task.startMinute = newStartMinute
        task.durationMinutes = newDurationMinutes
        task.checkInSent = false
        NotificationScheduler.reschedule(for: task)

        if cascadeToFuture {
            SeriesEditor.applyEditToThisAndFuture(
                from: task,
                title: task.title,
                notes: task.notes,
                startHour: newStartHour,
                startMinute: newStartMinute,
                durationMinutes: newDurationMinutes,
                reminderMinutesBefore: task.reminderMinutesBefore,
                context: modelContext
            )
        }
        persist()
    }
}

private struct DateJumpView: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    @State private var tempDate: Date

    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        self._tempDate = State(initialValue: selectedDate.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            DatePicker("Date", selection: $tempDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle("Jump to Date")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Go") {
                            selectedDate = Calendar.current.startOfDay(for: tempDate)
                            dismiss()
                        }
                    }
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: PlannerTask.self, inMemory: true)
}
