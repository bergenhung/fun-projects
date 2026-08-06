import SwiftUI

struct HourlyGridView: View {
    let tasks: [PlannerTask]
    let onToggleComplete: (PlannerTask) -> Void
    let onEdit: (PlannerTask) -> Void
    let onDelete: (PlannerTask) -> Void
    let onAddAtHour: (Int) -> Void

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
                let target = min(max(Calendar.current.component(.hour, from: now), GridConfig.startHour), GridConfig.endHour - 1)
                proxy.scrollTo(target, anchor: .init(x: 0, y: 0.3))
            }
        }
        .onReceive(timer) { now = $0 }
    }

    private func hourRow(_ hour: Int) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(GridConfig.hourLabel(hour))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: GridConfig.hourGutterWidth, alignment: .trailing)
                .padding(.trailing, 6)
                .padding(.top, 4)

            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
                .padding(.top, 4)
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
                TaskBlockView(
                    task: layout.task,
                    onToggleComplete: { onToggleComplete(layout.task) },
                    onEdit: { onEdit(layout.task) },
                    onDelete: { onDelete(layout.task) }
                )
                .frame(width: columnWidth - 4, height: blockHeight(for: layout.task), alignment: .topLeading)
                .offset(
                    x: GridConfig.hourGutterWidth + 6 + CGFloat(layout.column) * columnWidth,
                    y: yOffset(for: layout.task) + 2
                )
            }
        }
        .allowsHitTesting(true)
    }

    private func blockHeight(for task: PlannerTask) -> CGFloat {
        max(CGFloat(task.durationMinutes) / 60 * GridConfig.hourHeight - 4, 28)
    }

    private func yOffset(for task: PlannerTask) -> CGFloat {
        CGFloat(task.startHour - GridConfig.startHour) * GridConfig.hourHeight
    }

    private func isCurrentHour(_ hour: Int) -> Bool {
        Calendar.current.isDateInToday(now) && Calendar.current.component(.hour, from: now) == hour
    }

    private var currentTimeOffset: CGFloat? {
        guard Calendar.current.isDateInToday(now) else { return nil }
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
