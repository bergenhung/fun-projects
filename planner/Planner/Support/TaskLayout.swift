import Foundation

struct TaskLayout: Identifiable {
    let task: PlannerTask
    let column: Int
    let columnCount: Int

    var id: UUID { task.id }
}

/// Assigns side-by-side columns to tasks whose hour ranges overlap, using the
/// standard interval-graph-coloring approach used by calendar day views.
enum TaskLayoutEngine {
    static func layout(for tasks: [PlannerTask]) -> [TaskLayout] {
        let sorted = tasks.sorted {
            if $0.startHour != $1.startHour { return $0.startHour < $1.startHour }
            return $0.durationMinutes < $1.durationMinutes
        }

        func startMinutes(_ t: PlannerTask) -> Int { t.startHour * 60 }
        func endMinutes(_ t: PlannerTask) -> Int { t.startHour * 60 + max(t.durationMinutes, 1) }

        var clusters: [[PlannerTask]] = []
        var currentCluster: [PlannerTask] = []
        var clusterEnd = Int.min

        for task in sorted {
            if currentCluster.isEmpty || startMinutes(task) < clusterEnd {
                currentCluster.append(task)
                clusterEnd = max(clusterEnd, endMinutes(task))
            } else {
                clusters.append(currentCluster)
                currentCluster = [task]
                clusterEnd = endMinutes(task)
            }
        }
        if !currentCluster.isEmpty { clusters.append(currentCluster) }

        var result: [TaskLayout] = []
        for cluster in clusters {
            var columnEndTimes: [Int] = []
            var assignments: [(PlannerTask, Int)] = []
            for task in cluster {
                var placed = false
                for idx in columnEndTimes.indices {
                    if startMinutes(task) >= columnEndTimes[idx] {
                        columnEndTimes[idx] = endMinutes(task)
                        assignments.append((task, idx))
                        placed = true
                        break
                    }
                }
                if !placed {
                    columnEndTimes.append(endMinutes(task))
                    assignments.append((task, columnEndTimes.count - 1))
                }
            }
            let columnCount = columnEndTimes.count
            for (task, col) in assignments {
                result.append(TaskLayout(task: task, column: col, columnCount: columnCount))
            }
        }
        return result
    }
}
