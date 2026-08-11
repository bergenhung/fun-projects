import SwiftUI

/// Wraps `TaskBlockView` with drag-to-move (grab the body, keeps duration) and
/// drag-to-resize (grab near the top or bottom edge, changes duration).
///
/// Uses a single `DragGesture` on the whole block rather than three separate
/// overlapping gesture recognizers on separate handle subviews — the previous
/// design was fragile (subtle z-order/hit-testing interactions between the
/// stacked handle views made bottom-edge resize unreliable in practice). A
/// single gesture that classifies itself by `value.startLocation` (the point
/// where the touch began, stable for the whole gesture) is the standard,
/// more robust pattern for this kind of "edge vs body" interaction.
///
/// Dragging only updates a local preview offset/height live; the actual
/// `startHour`/`startMinute`/`durationMinutes` change is reported once, via
/// `onCommit`, when the drag ends — so a single in-progress drag doesn't spam
/// SwiftData writes or reschedule notifications on every frame.
struct DraggableTaskBlock: View {
    let task: PlannerTask
    let width: CGFloat
    let baseHeight: CGFloat
    let onToggleComplete: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onDeleteSeries: (() -> Void)?
    let onCommit: (_ newStartHour: Int, _ newStartMinute: Int, _ newDurationMinutes: Int) -> Void

    private enum DragKind {
        case move, resizeTop, resizeBottom
    }

    @State private var activeDrag: DragKind?
    @State private var dragTranslation: CGFloat = 0

    private static let minDurationMinutes = 15
    private static let maxDurationMinutes = 480
    /// How close to the top/bottom edge (in points) a drag has to *start* to
    /// count as a resize instead of a move.
    private static let edgeGrabZone: CGFloat = 14

    private var minBlockHeight: CGFloat {
        CGFloat(Self.minDurationMinutes) / 60 * GridConfig.hourHeight - 4
    }

    var body: some View {
        TaskBlockView(
            task: task,
            onToggleComplete: onToggleComplete,
            onEdit: onEdit,
            onDelete: onDelete,
            onDeleteSeries: onDeleteSeries
        )
        .frame(width: width, height: previewHeight, alignment: .top)
        // `.highPriorityGesture` (not `.gesture`) because this whole view sits
        // inside HourlyGridView's ScrollView, whose own native vertical pan
        // gesture otherwise wins the vertical drag before ours ever fires —
        // dragging a block would just scroll the page instead of moving it.
        .highPriorityGesture(dragGesture)
        .offset(y: previewYOffset)
    }

    private var previewHeight: CGFloat {
        switch activeDrag {
        case .resizeBottom:
            return min(max(baseHeight + dragTranslation, minBlockHeight), maxHeight)
        case .resizeTop:
            return min(max(baseHeight - dragTranslation, minBlockHeight), maxHeight)
        case .move, .none:
            return baseHeight
        }
    }

    private var maxHeight: CGFloat {
        CGFloat(Self.maxDurationMinutes) / 60 * GridConfig.hourHeight
    }

    private var previewYOffset: CGFloat {
        switch activeDrag {
        case .move:
            return dragTranslation
        case .resizeTop:
            // Clamp so the top edge can't push height below the minimum.
            return min(dragTranslation, baseHeight - minBlockHeight)
        case .resizeBottom, .none:
            return 0
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .local)
            .onChanged { value in
                if activeDrag == nil {
                    activeDrag = kind(forStartY: value.startLocation.y)
                }
                dragTranslation = value.translation.height
            }
            .onEnded { value in
                if let kind = activeDrag {
                    commit(kind: kind, translation: value.translation.height)
                }
                activeDrag = nil
                dragTranslation = 0
            }
    }

    private func kind(forStartY y: CGFloat) -> DragKind {
        if y <= Self.edgeGrabZone { return .resizeTop }
        if y >= baseHeight - Self.edgeGrabZone { return .resizeBottom }
        return .move
    }

    /// Total minutes since midnight for the earliest/latest quarter-hour slot
    /// the grid displays.
    private var gridMinTotalMinutes: Int { GridConfig.startHour * 60 }
    private var gridMaxTotalMinutes: Int { (GridConfig.endHour - 1) * 60 + 45 }

    private func commit(kind: DragKind, translation: CGFloat) {
        let startTotalMinutes = task.startHour * 60 + task.startMinute

        switch kind {
        case .move:
            let minuteDelta = snappedMinutes(from: translation)
            guard minuteDelta != 0 else { return }
            let newTotal = min(max(startTotalMinutes + minuteDelta, gridMinTotalMinutes), gridMaxTotalMinutes)
            guard newTotal != startTotalMinutes else { return }
            onCommit(newTotal / 60, newTotal % 60, task.durationMinutes)

        case .resizeBottom:
            let minuteDelta = snappedMinutes(from: translation)
            guard minuteDelta != 0 else { return }
            let newDuration = min(max(task.durationMinutes + minuteDelta, Self.minDurationMinutes), Self.maxDurationMinutes)
            onCommit(task.startHour, task.startMinute, newDuration)

        case .resizeTop:
            // Dragging the top edge moves the start time (15-min snap, same as
            // resizeBottom) while keeping the end time fixed.
            let minuteDelta = snappedMinutes(from: translation)
            guard minuteDelta != 0 else { return }
            let newTotal = min(max(startTotalMinutes + minuteDelta, gridMinTotalMinutes), gridMaxTotalMinutes)
            let actualDelta = newTotal - startTotalMinutes
            guard actualDelta != 0 else { return }
            let newDuration = min(max(task.durationMinutes - actualDelta, Self.minDurationMinutes), Self.maxDurationMinutes)
            onCommit(newTotal / 60, newTotal % 60, newDuration)
        }
    }

    private func snappedMinutes(from translation: CGFloat) -> Int {
        let rawMinutes = translation / GridConfig.hourHeight * 60
        let step: CGFloat = 15
        return Int((rawMinutes / step).rounded()) * Int(step)
    }
}
