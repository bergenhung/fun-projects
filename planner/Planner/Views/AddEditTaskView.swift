import SwiftUI
import SwiftData

struct AddEditTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let editingTask: PlannerTask?

    @State private var title: String
    @State private var notes: String
    @State private var date: Date
    @State private var hour: Int
    @State private var minute: Int
    @State private var duration: Int
    @State private var reminderOffset: Int

    @State private var repeatKind: RepeatKind = .never
    @State private var customDays: Set<Weekday> = []
    @State private var hasEndDate = false
    @State private var endDate = Date()

    @State private var showingDeleteOptions = false
    @State private var showingSaveScopeOptions = false

    private enum RepeatKind: Hashable {
        case never, daily, weekdays, weekly, custom
    }

    init(task: PlannerTask? = nil, defaultHour: Int? = nil, defaultDate: Date? = nil) {
        self.editingTask = task
        _title = State(initialValue: task?.title ?? "")
        _notes = State(initialValue: task?.notes ?? "")
        _date = State(initialValue: task?.scheduledDate ?? defaultDate ?? Calendar.current.startOfDay(for: Date()))

        let fallbackHour = min(max(Calendar.current.component(.hour, from: Date()), GridConfig.startHour), GridConfig.endHour - 1)
        _hour = State(initialValue: task?.startHour ?? defaultHour ?? fallbackHour)
        _minute = State(initialValue: task?.startMinute ?? 0)
        _duration = State(initialValue: task?.durationMinutes ?? 60)
        _reminderOffset = State(initialValue: task?.reminderMinutesBefore ?? 15)
    }

    private var isSeriesOccurrence: Bool { editingTask?.recurrenceParentId != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("When") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("Hour", selection: $hour) {
                        ForEach(GridConfig.startHour..<GridConfig.endHour, id: \.self) { h in
                            Text(GridConfig.hourLabel(h)).tag(h)
                        }
                    }
                    Picker("Minute", selection: $minute) {
                        ForEach(GridConfig.minuteOptions, id: \.self) { m in
                            Text(String(format: ":%02d", m)).tag(m)
                        }
                    }
                    Picker("Duration", selection: $duration) {
                        ForEach(GridConfig.durationOptions, id: \.self) { minutes in
                            Text(GridConfig.durationLabel(minutes)).tag(minutes)
                        }
                    }
                }

                Section("Reminder") {
                    Picker("Remind me", selection: $reminderOffset) {
                        ForEach(GridConfig.reminderOptions, id: \.self) { minutes in
                            Text(GridConfig.reminderLabel(minutes)).tag(minutes)
                        }
                    }
                }

                if editingTask == nil {
                    repeatSection
                } else if isSeriesOccurrence {
                    Section {
                        Label("Part of a repeating series", systemImage: "repeat")
                            .foregroundStyle(.secondary)
                    }
                }

                if editingTask != nil {
                    Section {
                        Button("Delete Task", role: .destructive) {
                            if isSeriesOccurrence {
                                showingDeleteOptions = true
                            } else {
                                delete(scope: .justThis)
                            }
                        }
                    }
                }
            }
            .navigationTitle(editingTask == nil ? "New Task" : "Edit Task")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if isSeriesOccurrence {
                            showingSaveScopeOptions = true
                        } else {
                            save(scope: .justThis)
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog(
                "Delete Repeating Task",
                isPresented: $showingDeleteOptions,
                titleVisibility: .visible
            ) {
                Button("Delete This Occurrence", role: .destructive) { delete(scope: .justThis) }
                Button("Delete This and Future Occurrences", role: .destructive) { delete(scope: .thisAndFuture) }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "Save Changes",
                isPresented: $showingSaveScopeOptions,
                titleVisibility: .visible
            ) {
                Button("This Occurrence Only") { save(scope: .justThis) }
                Button("This and Future Occurrences") { save(scope: .thisAndFuture) }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var repeatSection: some View {
        Section {
            Picker("Repeat", selection: $repeatKind) {
                Text("Never").tag(RepeatKind.never)
                Text("Daily").tag(RepeatKind.daily)
                Text("Weekdays").tag(RepeatKind.weekdays)
                Text("Weekly").tag(RepeatKind.weekly)
                Text("Custom").tag(RepeatKind.custom)
            }

            if repeatKind == .custom {
                WeekdaySelector(selection: $customDays)
            }

            if repeatKind != .never {
                Toggle("End Date", isOn: $hasEndDate)
                if hasEndDate {
                    DatePicker("Ends", selection: $endDate, in: date..., displayedComponents: .date)
                }
            }
        } header: {
            Text("Repeat")
        } footer: {
            if repeatKind != .never {
                Text("Creates occurrences up to \(RecurrenceEngine.materializationWindowDays) days ahead\(hasEndDate ? " or until the end date" : ""). Each day can be completed independently.")
            }
        }
    }

    private var recurrenceRule: RecurrenceRule? {
        let frequency: RecurrenceFrequency?
        switch repeatKind {
        case .never: frequency = nil
        case .daily: frequency = .daily
        case .weekdays: frequency = .weekdays
        case .weekly: frequency = .weekly
        case .custom: frequency = customDays.isEmpty ? nil : .custom(days: Array(customDays).sorted { $0.rawValue < $1.rawValue })
        }
        guard let frequency else { return nil }
        return RecurrenceRule(frequency: frequency, endDate: hasEndDate ? Calendar.current.startOfDay(for: endDate) : nil)
    }

    private enum SaveScope {
        case justThis, thisAndFuture
    }

    private func save(scope: SaveScope) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotesOrNil = trimmedNotes.isEmpty ? nil : trimmedNotes
        let scheduledDay = Calendar.current.startOfDay(for: date)

        if let editingTask {
            editingTask.title = trimmedTitle
            editingTask.notes = trimmedNotesOrNil
            editingTask.scheduledDate = scheduledDay
            editingTask.startHour = hour
            editingTask.startMinute = minute
            editingTask.durationMinutes = duration
            editingTask.reminderMinutesBefore = reminderOffset
            editingTask.checkInSent = false
            NotificationScheduler.reschedule(for: editingTask)

            if scope == .thisAndFuture {
                SeriesEditor.applyEditToThisAndFuture(
                    from: editingTask,
                    title: trimmedTitle,
                    notes: trimmedNotesOrNil,
                    startHour: hour,
                    startMinute: minute,
                    durationMinutes: duration,
                    reminderMinutesBefore: reminderOffset,
                    context: modelContext
                )
            }
        } else if let rule = recurrenceRule {
            let recurrenceParentId = UUID()
            let horizonEnd = Calendar.current.date(byAdding: .day, value: RecurrenceEngine.notificationHorizonDays, to: Calendar.current.startOfDay(for: Date()))!
            for occurrenceDate in RecurrenceEngine.occurrenceDates(startingAt: scheduledDay, rule: rule) {
                let occurrence = PlannerTask(
                    title: trimmedTitle,
                    notes: trimmedNotesOrNil,
                    scheduledDate: occurrenceDate,
                    startHour: hour,
                    startMinute: minute,
                    durationMinutes: duration,
                    reminderMinutesBefore: reminderOffset,
                    recurrenceParentId: recurrenceParentId,
                    recurrenceRule: rule
                )
                modelContext.insert(occurrence)
                if occurrenceDate <= horizonEnd {
                    NotificationScheduler.reschedule(for: occurrence)
                }
            }
        } else {
            let newTask = PlannerTask(
                title: trimmedTitle,
                notes: trimmedNotesOrNil,
                scheduledDate: scheduledDay,
                startHour: hour,
                startMinute: minute,
                durationMinutes: duration,
                reminderMinutesBefore: reminderOffset
            )
            modelContext.insert(newTask)
            NotificationScheduler.reschedule(for: newTask)
        }
        // Save immediately rather than relying solely on SwiftData's implicit
        // autosave — see the "Past crash" note in CLAUDE.md.
        try? modelContext.save()
        dismiss()
    }

    private func delete(scope: SaveScope) {
        guard let editingTask else {
            dismiss()
            return
        }
        switch scope {
        case .justThis:
            NotificationScheduler.cancelAll(for: editingTask)
            modelContext.delete(editingTask)
        case .thisAndFuture:
            SeriesEditor.deleteThisAndFuture(from: editingTask, context: modelContext)
        }
        try? modelContext.save()
        dismiss()
    }
}

private struct WeekdaySelector: View {
    @Binding var selection: Set<Weekday>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.allCases) { day in
                let isSelected = selection.contains(day)
                Button {
                    if isSelected {
                        selection.remove(day)
                    } else {
                        selection.insert(day)
                    }
                } label: {
                    Text(day.shortLabel)
                        .font(.caption.bold())
                        .frame(width: 28, height: 28)
                        .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
