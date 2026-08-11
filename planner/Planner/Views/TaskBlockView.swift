import SwiftUI

struct TaskBlockView: View {
    let task: PlannerTask
    /// True when the block is too short to fit the normal two-line layout
    /// (title + separate time line) without its content overflowing past the
    /// grid slot it's supposed to occupy. Below this, nothing in this view
    /// constrains/clips the content, so a tall two-line layout would silently
    /// render past its allotted height — reading as "misaligned" on the grid,
    /// most visible on 15/30-minute tasks. Below `twoLineMinHeight` we drop
    /// the separate time line and go single-line instead of shrinking further.
    let compact: Bool
    let onToggleComplete: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onDeleteSeries: (() -> Void)?

    /// Roughly the natural height of the two-line layout (padding + title
    /// line + spacing + time line) at the `.caption`/`.caption2` sizes below.
    static let twoLineMinHeight: CGFloat = 40

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
                    .lineLimit(compact ? 1 : 2)
                if compact {
                    Text(GridConfig.timeLabel(hour: task.startHour, minute: task.startMinute))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            if !compact {
                Text(GridConfig.timeLabel(hour: task.startHour, minute: task.startMinute))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
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
