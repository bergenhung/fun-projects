import SwiftUI

struct HourlyGridView: View {
    let tasks: [PlannerTask]
    let isViewingToday: Bool
    let onToggleComplete: (PlannerTask) -> Void
    let onEdit: (PlannerTask) -> Void
    let onDelete: (PlannerTask) -> Void
    let onDeleteSeries: (PlannerTask) -> Void
    let onAddAtHour: (Int) -> Void
    let onRetime: (PlannerTask, Int, Int, Int) -> Void

    @State private var now = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private let hours = Array(GridConfig.startHour..<GridConfig.endHour)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        ForEach(hours, id: \.self) { hour in
                            hourRow(hour)
                                .id(hour)
                        }
                    }

                    taskLayer

                    if let indicatorOffset = currentTimeOffset {
                        currentTimeIndicator
                            .offset(y: indicatorOffset)
                    }
                }
            }
            .onAppear {
                proxy.scrollTo(initialScrollHour, anchor: .init(x: 0, y: 0.3))
            }
        }
        .onReceive(timer) { now = $0 }
    }

    private var initialScrollHour: Int {
        if isViewingToday {
            return min(max(Calendar.current.component(.hour, from: now), GridConfig.startHour), GridConfig.endHour - 1)
        }
        if let earliest = tasks.map(\.startHour).min() {
            return min(max(earliest, GridConfig.startHour), GridConfig.endHour - 1)
        }
        return GridConfig.startHour
    }

    private func hourRow(_ hour: Int) -> some View {
        // The divider line sits exactly at the row's top edge — that edge *is*
        // the hour boundary (rows are a zero-spacing VStack) — so it lines up
        // exactly with where task blocks are positioned. Only the label text is
        // nudged up to visually straddle the line, the way Apple/Google Calendar
        // draw hour labels; that offset is cosmetic and doesn't move the line.
        ZStack(alignment: .topLeading) {
            HStack(alignment: .top, spacing: 0) {
                Text(GridConfig.hourLabel(hour))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: GridConfig.hourGutterWidth, alignment: .trailing)
                    .padding(.trailing, 6)
                    .offset(y: -7)

                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }

            // Faint quarter-hour tick marks (:15/:30/:45) — a visual reference so
            // a task placed off the hour doesn't look like it's floating with no
            // relation to the clock. No labels; the hour line/label is enough.
            ForEach([15, 30, 45], id: \.self) { minute in
                Rectangle()
                    .fill(Color.gray.opacity(0.12))
                    .frame(height: 1)
                    .padding(.leading, GridConfig.hourGutterWidth + 6)
                    .offset(y: CGFloat(minute) / 60 * GridConfig.hourHeight)
            }
        }
        .frame(height: GridConfig.hourHeight, alignment: .top)
        .background(isCurrentHour(hour) ? Color.accentColor.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onAddAtHour(hour) }
    }

    private var taskLayer: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - GridConfig.hourGutterWidth - 12
            ForEach(TaskLayoutEngine.layout(for: tasks)) { layout in
                let columnWidth = availableWidth / CGFloat(layout.columnCount)
                DraggableTaskBlock(
                    task: layout.task,
                    width: columnWidth - 4,
                    baseHeight: blockHeight(for: layout.task),
                    onToggleComplete: { onToggleComplete(layout.task) },
                    onEdit: { onEdit(layout.task) },
                    onDelete: { onDelete(layout.task) },
                    onDeleteSeries: layout.task.recurrenceParentId != nil ? { onDeleteSeries(layout.task) } : nil,
                    onCommit: { newStartHour, newStartMinute, newDurationMinutes in
                        onRetime(layout.task, newStartHour, newStartMinute, newDurationMinutes)
                    }
                )
                .offset(
                    x: GridConfig.hourGutterWidth + 6 + CGFloat(layout.column) * columnWidth,
                    y: yOffset(for: layout.task)
                )
            }
        }
        .allowsHitTesting(true)
    }

    /// A small symmetric inset (not an asymmetric top/bottom fudge) so adjacent
    /// tasks don't visually touch, while keeping the block's vertical center —
    /// and therefore its top/bottom edges relative to `yOffset` — exactly where
    /// the duration math says they should be, matching the hour gridlines.
    private func blockHeight(for task: PlannerTask) -> CGFloat {
        max(CGFloat(task.durationMinutes) / 60 * GridConfig.hourHeight - 2, 28)
    }

    private func yOffset(for task: PlannerTask) -> CGFloat {
        CGFloat(task.startHour - GridConfig.startHour) * GridConfig.hourHeight
            + CGFloat(task.startMinute) / 60 * GridConfig.hourHeight
            + 1
    }

    private func isCurrentHour(_ hour: Int) -> Bool {
        isViewingToday && Calendar.current.isDateInToday(now) && Calendar.current.component(.hour, from: now) == hour
    }

    private var currentTimeOffset: CGFloat? {
        guard isViewingToday, Calendar.current.isDateInToday(now) else { return nil }
        let hour = Calendar.current.component(.hour, from: now)
        let minute = Calendar.current.component(.minute, from: now)
        guard hour >= GridConfig.startHour && hour < GridConfig.endHour else { return nil }
        return CGFloat(hour - GridConfig.startHour) * GridConfig.hourHeight + CGFloat(minute) / 60 * GridConfig.hourHeight
    }

    private var currentTimeIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            Rectangle()
                .fill(Color.red)
                .frame(height: 1.5)
        }
        .padding(.leading, GridConfig.hourGutterWidth - 4)
    }
}
