#if canImport(XCTest) && (os(macOS) || os(iOS))
    import XCTest

    /// Bounded scrolling operations for revealing descendants in UI tests.
    extension XCUIElement {
        /// Swipes this container up until the child exists and is hittable.
        ///
        /// Runs on the main actor and checks the child before each swipe and
        /// after the final swipe. Zero or negative budgets check its current state
        /// without swiping. Choose the scrollable container that owns the child.
        /// Returns `false` when the swipe budget is exhausted; does not assert.
        ///
        /// - Parameters:
        ///   - child: The descendant to reveal within this container.
        ///   - maxAttempts: The maximum number of upward swipes to perform.
        /// - Returns: Whether the child exists and is hittable after the operation.
        @MainActor
        @discardableResult
        public func scrollUpUntilHittable(_ child: XCUIElement, maxAttempts: Int) -> Bool {
            revealElement(
                maxAttempts: maxAttempts,
                isHittable: { child.exists && child.isHittable },
                swipe: { self.swipeUp() })
        }

        /// Swipes this container down until the child exists and is hittable.
        ///
        /// Runs on the main actor and checks the child before each swipe and
        /// after the final swipe. Choose the scrollable container that owns the child.
        /// Zero or negative budgets check the current state without swiping.
        /// An exhausted budget returns `false` without recording an assertion.
        ///
        /// - Parameters:
        ///   - child: The descendant to reveal within this container.
        ///   - maxAttempts: The maximum number of downward swipes to perform.
        /// - Returns: Whether the child exists and is hittable after the operation.
        @MainActor
        @discardableResult
        public func scrollDownUntilHittable(_ child: XCUIElement, maxAttempts: Int) -> Bool {
            revealElement(
                maxAttempts: maxAttempts,
                isHittable: { child.exists && child.isHittable },
                swipe: { self.swipeDown() })
        }
    }

    @MainActor
    func revealElement(
        maxAttempts: Int, isHittable: () -> Bool, swipe: () -> Void
    ) -> Bool {
        for _ in 0..<max(0, maxAttempts) {
            if isHittable() { return true }
            swipe()
        }
        return isHittable()
    }
#endif
