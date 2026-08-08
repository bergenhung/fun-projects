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
    @State private var duration: Int
    @State private var reminderOffset: Int

    init(task: PlannerTask? = nil, defaultHour: Int? = nil) {
        self.editingTask = task
        _title = State(initialValue: task?.title ?? "")
        _notes = State(initialValue: task?.notes ?? "")
        _date = State(initialValue: task?.scheduledDate ?? Calendar.current.startOfDay(for: Date()))

        let fallbackHour = min(max(Calendar.current.component(.hour, from: Date()), GridConfig.startHour), GridConfig.endHour - 1)
        _hour = State(initialValue: task?.startHour ?? defaultHour ?? fallbackHour)
        _duration = State(initialValue: task?.durationMinutes ?? 60)
        _reminderOffset = State(initialValue: task?.reminderMinutesBefore ?? 15)
    }

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

                if editingTask != nil {
                    Section {
                        Button("Delete Task", role: .destructive, action: delete)
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
                    Button("Save", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let scheduledDay = Calendar.current.startOfDay(for: date)

        if let editingTask {
            editingTask.title = trimmedTitle
            editingTask.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            editingTask.scheduledDate = scheduledDay
            editingTask.startHour = hour
            editingTask.durationMinutes = duration
            editingTask.reminderMinutesBefore = reminderOffset
            editingTask.checkInSent = false
            NotificationScheduler.reschedule(for: editingTask)
        } else {
            let newTask = PlannerTask(
                title: trimmedTitle,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                scheduledDate: scheduledDay,
                startHour: hour,
                durationMinutes: duration,
                reminderMinutesBefore: reminderOffset
            )
            modelContext.insert(newTask)
            NotificationScheduler.reschedule(for: newTask)
        }
        dismiss()
    }

    private func delete() {
        if let editingTask {
            NotificationScheduler.cancelAll(for: editingTask)
            modelContext.delete(editingTask)
        }
        dismiss()
    }
}
