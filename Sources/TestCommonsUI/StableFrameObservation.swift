#if canImport(SwiftUI)
    import Foundation

    @MainActor
    func observeStableFrames(
        timeout: Duration, minimumFrames: Int, requiredStableFrames: Int,
        pollInterval: Duration, render: () -> Data?
    ) -> Bool {
        precondition(timeout >= .zero && pollInterval > .zero)
        precondition(minimumFrames > 0 && requiredStableFrames > 0)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        let interval = timeInterval(pollInterval)
        var previous: Data?
        var stable = 0
        var sampled = 0
        while clock.now < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(interval))
            let frame = render()
            stable = frame != nil && frame == previous ? stable + 1 : (frame == nil ? 0 : 1)
            previous = frame
            sampled += 1
            if sampled >= minimumFrames && stable >= requiredStableFrames {
                return true
            }
        }
        return false
    }

    func timeInterval(_ duration: Duration) -> TimeInterval {
        let components = duration.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
#endif
