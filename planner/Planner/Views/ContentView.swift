import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [PlannerTask]

    @State private var showingAddSheet = false
    @State private var addSheetDefaultHour: Int?
    @State private var editingTask: PlannerTask?

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
            Group {
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
            }
            .sheet(isPresented: $showingAddSheet) {
                AddEditTaskView(defaultHour: addSheetDefaultHour)
            }
            .sheet(item: $editingTask) { task in
                AddEditTaskView(task: task)
            }
        }
    }

    private func toggleComplete(_ task: PlannerTask) {
        task.isCompleted.toggle()
    }

    private func delete(_ task: PlannerTask) {
        modelContext.delete(task)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: PlannerTask.self, inMemory: true)
}
