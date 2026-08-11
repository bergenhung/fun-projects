import SwiftUI

struct TaskBlockView: View {
    let task: PlannerTask
    let onToggleComplete: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onDeleteSeries: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                if task.recurrenceParentId != nil {
                    Image(systemName: "repeat")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                Text(task.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .lineLimit(2)
            }
            Text(GridConfig.timeLabel(hour: task.startHour, minute: task.startMinute))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(task.isCompleted ? Color.gray.opacity(0.25) : Color.accentColor.opacity(0.25))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(task.isCompleted ? Color.gray : Color.accentColor, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggleComplete)
        .contextMenu {
            Button(task.isCompleted ? "Mark Incomplete" : "Mark Complete", systemImage: "checkmark.circle") {
                onToggleComplete()
            }
            Button("Edit", systemImage: "pencil", action: onEdit)
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            if let onDeleteSeries {
                Button("Delete Entire Series", systemImage: "trash.slash", role: .destructive, action: onDeleteSeries)
            }
        }
    }
}
