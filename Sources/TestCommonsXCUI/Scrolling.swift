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
        /// Reveals a child using bounded vertical drags inside its owning scroll container.
        ///
        /// Resolves the smallest scroll view, table, or collection containing the child's
        /// accessibility identifier on every attempt, including after layout changes.
        /// Falls back to this element for menus that expose no scroll container.
        /// Gesture points remain within the window and above the software keyboard.
        /// Content above the viewport is revealed with a downward drag.
        ///
        /// - Parameters:
        ///   - child: The target with a nonempty, unique accessibility identifier.
        ///   - maxAttempts: The maximum number of drags; nonpositive values only check readiness.
        /// - Returns: Whether the child exists and is hittable. Does not record an assertion.
        @MainActor
        @discardableResult
        public func scrollVerticallyUntilHittable(_ child: XCUIElement, maxAttempts: Int) -> Bool {
            let app = XCUIApplication()
            for _ in 0..<max(0, maxAttempts) {
                if child.exists && child.isHittable { return true }
                guard !child.identifier.isEmpty else { return false }
                let containers = [XCUIElement.ElementType.scrollView, .table, .collectionView]
                    .flatMap {
                        self.descendants(matching: $0).containing(.any, identifier: child.identifier)
                            .allElementsBoundByIndex
                    }
                    .filter { $0.exists && !$0.frame.isEmpty }
                let container =
                    containers.min {
                        $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height
                    } ?? self
                let keyboard = app.keyboards.firstMatch
                guard
                    let drag = VerticalScrollDrag(
                        container: container.frame, window: app.windows.firstMatch.frame,
                        keyboard: keyboard.exists ? keyboard.frame : nil,
                        target: child.exists ? child.frame : nil
                    )
                else { return false }
                let origin = container.coordinate(withNormalizedOffset: .zero)
                origin.withOffset(CGVector(dx: drag.start.x, dy: drag.start.y)).press(
                    forDuration: VerticalScrollDrag.pressDuration,
                    thenDragTo: origin.withOffset(CGVector(dx: drag.end.x, dy: drag.end.y)),
                    withVelocity: .slow, thenHoldForDuration: VerticalScrollDrag.holdDuration)
            }
            return child.exists && child.isHittable
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
