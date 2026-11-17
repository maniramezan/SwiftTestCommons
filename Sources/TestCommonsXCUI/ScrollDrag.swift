#if os(macOS) || os(iOS) || os(visionOS)
    import Foundation
    import TestCommons

    /// A drag gesture, relative to its container's origin, that scrolls one viewport step.
    struct ScrollDrag {
        enum Axis {
            case vertical
            case horizontal
        }

        static let pressDuration: TimeInterval = 0.05
        // Holding at the end stops momentum, so drags can move fast without flinging.
        static let holdDuration: TimeInterval = 0.1
        // Each step covers 65% of the viewport: long enough to cut gestures, and short
        // enough that any target under a third of the viewport is fully shown at some step.
        private static let startFraction: CGFloat = 0.8
        private static let endFraction: CGFloat = 0.15

        let start: CGPoint
        let end: CGPoint

        /// Plans a drag within the visible part of `container`, above any keyboard.
        ///
        /// Vertical drags reveal content below unless the target lies above the viewport.
        /// Horizontal drags reveal content after the viewport in `direction` unless the
        /// target lies on the other side. `reversed` flips the default drag, for when content
        /// stopped moving because the scroll reached its end; a target beyond the viewport
        /// always decides the direction.
        init?(
            axis: Axis = .vertical, container: CGRect, window: CGRect, keyboard: CGRect?, target: CGRect?,
            direction: ReadingDirection = .leftToRight, reversed: Bool = false
        ) {
            var viewport = container.intersection(window)
            if let keyboard, viewport.intersects(keyboard) {
                viewport.size.height = max(0, keyboard.minY - viewport.minY)
            }
            guard !viewport.isNull && !viewport.isEmpty else { return nil }
            let target = target.flatMap { $0.isEmpty ? nil : $0 }
            switch axis {
            case .vertical:
                let x = viewport.midX - container.minX
                let upperY = viewport.minY - container.minY + viewport.height * Self.endFraction
                let lowerY = viewport.minY - container.minY + viewport.height * Self.startFraction
                let revealAbove: Bool
                if let target, target.midY < viewport.minY {
                    revealAbove = true
                } else if let target, target.midY > viewport.maxY {
                    revealAbove = false
                } else {
                    revealAbove = reversed
                }
                start = CGPoint(x: x, y: revealAbove ? upperY : lowerY)
                end = CGPoint(x: x, y: revealAbove ? lowerY : upperY)
            case .horizontal:
                let y = viewport.midY - container.minY
                let leftX = viewport.minX - container.minX + viewport.width * Self.endFraction
                let rightX = viewport.minX - container.minX + viewport.width * Self.startFraction
                let revealLeft: Bool
                if let target, target.midX < viewport.minX {
                    revealLeft = true
                } else if let target, target.midX > viewport.maxX {
                    revealLeft = false
                } else {
                    revealLeft = (direction == .rightToLeft) != reversed
                }
                start = CGPoint(x: revealLeft ? leftX : rightX, y: y)
                end = CGPoint(x: revealLeft ? rightX : leftX, y: y)
            }
        }
    }
#endif
