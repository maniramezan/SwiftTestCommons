#if canImport(SwiftUI)
    import Foundation

    @MainActor
    func observeStableFrames(
        timeout: TimeInterval, minimumFrames: Int, requiredStableFrames: Int,
        pollInterval: TimeInterval, render: () -> Data?
    ) -> Bool {
        precondition(timeout.isFinite && timeout >= 0 && pollInterval.isFinite && pollInterval > 0)
        precondition(minimumFrames > 0 && requiredStableFrames > 0)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(timeout))
        var previous: Data?
        var stable = 0
        var sampled = 0
        while clock.now < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(pollInterval))
            let frame = render()
            stable = frame != nil && frame == previous ? stable + 1 : (frame == nil ? 0 : 1)
            previous = frame
            sampled += 1
            if sampled >= minimumFrames && stable >= requiredStableFrames { return true }
        }
        return false
    }
#endif
