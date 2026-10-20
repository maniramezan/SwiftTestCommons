#if os(macOS) || os(iOS)
    import Foundation

    struct VerticalScrollDrag {
        static let pressDuration: TimeInterval = 0.05
        static let holdDuration: TimeInterval = 0.1
        private static let startFraction: CGFloat = 0.7
        private static let endFraction: CGFloat = 0.2

        let start: CGPoint
        let end: CGPoint

        init?(container: CGRect, window: CGRect, keyboard: CGRect?, target: CGRect?) {
            var viewport = container.intersection(window)
            if let keyboard, viewport.intersects(keyboard) {
                viewport.size.height = max(0, keyboard.minY - viewport.minY)
            }
            guard !viewport.isNull && !viewport.isEmpty else { return nil }
            let x = viewport.midX - container.minX
            let upperY = viewport.minY - container.minY + viewport.height * Self.endFraction
            let lowerY = viewport.minY - container.minY + viewport.height * Self.startFraction
            let scrollDown = target.map { !$0.isEmpty && $0.midY < viewport.minY } ?? false
            start = CGPoint(x: x, y: scrollDown ? upperY : lowerY)
            end = CGPoint(x: x, y: scrollDown ? lowerY : upperY)
        }
    }
#endif
