#if canImport(XCTest) && (os(macOS) || os(iOS) || os(visionOS))
    import TestCommons
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
        ///   - velocity: The swipe speed. Fast swipes fling and can skip past a small target;
        ///     pass `.slow` for shorter steps.
        /// - Returns: Whether the child exists and is hittable after the operation.
        @MainActor
        @discardableResult
        public func scrollUpUntilHittable(
            _ child: XCUIElement, maxAttempts: Int, velocity: XCUIGestureVelocity = .default
        ) -> Bool {
            revealElement(
                maxAttempts: maxAttempts, isHittable: { child.isReady(within: self.frame) },
                swipe: { self.swipeUp(velocity: velocity) })
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
        ///   - velocity: The swipe speed. Fast swipes fling and can skip past a small target;
        ///     pass `.slow` for shorter steps.
        /// - Returns: Whether the child exists and is hittable after the operation.
        @MainActor
        @discardableResult
        public func scrollDownUntilHittable(
            _ child: XCUIElement, maxAttempts: Int, velocity: XCUIGestureVelocity = .default
        ) -> Bool {
            revealElement(
                maxAttempts: maxAttempts, isHittable: { child.isReady(within: self.frame) },
                swipe: { self.swipeDown(velocity: velocity) })
        }

        /// Swipes this container left, revealing content to the right, until the child is hittable.
        ///
        /// Checks the child before each swipe and after the final swipe. Zero or negative
        /// budgets check the current state without swiping. Does not record an assertion.
        ///
        /// - Parameters:
        ///   - child: The descendant to reveal within this container.
        ///   - maxAttempts: The maximum number of leftward swipes to perform.
        ///   - velocity: The swipe speed. Fast swipes fling and can skip past a small target;
        ///     pass `.slow` for shorter steps.
        /// - Returns: Whether the child exists and is hittable after the operation.
        @MainActor
        @discardableResult
        public func scrollLeftUntilHittable(
            _ child: XCUIElement, maxAttempts: Int, velocity: XCUIGestureVelocity = .default
        ) -> Bool {
            revealElement(
                maxAttempts: maxAttempts, isHittable: { child.isReady(within: self.frame) },
                swipe: { self.swipeLeft(velocity: velocity) })
        }

        /// Swipes this container right, revealing content to the left, until the child is hittable.
        ///
        /// Checks the child before each swipe and after the final swipe. Zero or negative
        /// budgets check the current state without swiping. Does not record an assertion.
        ///
        /// - Parameters:
        ///   - child: The descendant to reveal within this container.
        ///   - maxAttempts: The maximum number of rightward swipes to perform.
        ///   - velocity: The swipe speed. Fast swipes fling and can skip past a small target;
        ///     pass `.slow` for shorter steps.
        /// - Returns: Whether the child exists and is hittable after the operation.
        @MainActor
        @discardableResult
        public func scrollRightUntilHittable(
            _ child: XCUIElement, maxAttempts: Int, velocity: XCUIGestureVelocity = .default
        ) -> Bool {
            revealElement(
                maxAttempts: maxAttempts, isHittable: { child.isReady(within: self.frame) },
                swipe: { self.swipeRight(velocity: velocity) })
        }

        /// Reveals a child using bounded vertical drags inside its owning scroll container.
        ///
        /// Resolves the smallest scroll view, table, or collection containing the child's
        /// accessibility identifier on every attempt, including after layout changes, from one
        /// accessibility snapshot of this element. Falls back to this element for menus or
        /// unmaterialized lazy-list children. Use the owning scroll container as the receiver
        /// when the child may not exist yet. Gesture points remain within the window and above
        /// the software keyboard. Content above the viewport is revealed with a downward drag.
        ///
        /// - Parameters:
        ///   - child: The target with a nonempty, unique accessibility identifier.
        ///   - maxAttempts: The maximum number of drags; nonpositive values only check readiness.
        ///   - app: The application owning this element, for its window and keyboard frames.
        ///     Pass it when the app was launched by bundle identifier; nil uses the target app.
        /// - Returns: Whether the child exists and is hittable. Does not record an assertion.
        @MainActor
        @discardableResult
        public func scrollVerticallyUntilHittable(
            _ child: XCUIElement, maxAttempts: Int, in app: XCUIApplication? = nil
        ) -> Bool {
            revealByDragging(child, axis: .vertical, direction: .leftToRight, maxAttempts: maxAttempts, app: app)
        }

        /// Reveals a child using bounded horizontal drags inside its owning scroll container.
        ///
        /// Resolves the owning container like ``scrollVerticallyUntilHittable(_:maxAttempts:in:)``.
        /// Drags reveal content after the viewport in `direction`, or toward the target when its
        /// frame is known to lie beyond the other edge, such as a carousel's earlier pages.
        ///
        /// - Parameters:
        ///   - child: The target with a nonempty, unique accessibility identifier.
        ///   - maxAttempts: The maximum number of drags; nonpositive values only check readiness.
        ///   - direction: The content's reading direction; right-to-left reveals content to the left.
        ///   - app: The application owning this element, for its window and keyboard frames;
        ///     nil uses the target app.
        /// - Returns: Whether the child exists and is hittable. Does not record an assertion.
        @MainActor
        @discardableResult
        public func scrollHorizontallyUntilHittable(
            _ child: XCUIElement, maxAttempts: Int, direction: ReadingDirection = .leftToRight,
            in app: XCUIApplication? = nil
        ) -> Bool {
            revealByDragging(child, axis: .horizontal, direction: direction, maxAttempts: maxAttempts, app: app)
        }

        /// Whether this element exists, lies at least partly within `viewport`, and is hittable.
        ///
        /// Asking an element entirely outside the viewport for hittability records a test
        /// failure instead of returning false, so the frame is checked first.
        @MainActor
        private func isReady(within viewport: CGRect) -> Bool {
            exists && FrameGeometry.overlaps(frame, viewport) && isHittable
        }

        @MainActor
        private func revealByDragging(
            _ child: XCUIElement, axis: ScrollDrag.Axis, direction: ReadingDirection, maxAttempts: Int,
            app: XCUIApplication?
        ) -> Bool {
            let app = app ?? XCUIApplication()
            var identifier = ""
            var previous: [CGRect]?
            var reversed = false
            for _ in 0..<max(0, maxAttempts) {
                let window = app.windows.firstMatch.frame
                if child.isReady(within: window) { return true }
                if identifier.isEmpty && child.exists {
                    identifier = child.identifier
                }
                // One snapshot replaces a query and frame read per candidate container.
                let tree = (try? snapshot()).map(ElementNode.init)
                // Content that did not move after a drag has reached its end; drag back instead.
                let signature = tree?.frameSignature
                if let signature, signature == previous {
                    reversed.toggle()
                }
                previous = signature
                let origin = tree?.frame ?? frame
                let owner = tree?.owningScrollContainer(of: identifier)
                let container = owner?.container ?? origin
                let keyboard = app.keyboards.firstMatch
                guard
                    let drag = ScrollDrag(
                        axis: axis, container: container, window: window,
                        keyboard: keyboard.exists ? keyboard.frame : nil, target: owner?.target,
                        direction: direction, reversed: reversed)
                else { return false }
                let offset = CGVector(dx: container.minX - origin.minX, dy: container.minY - origin.minY)
                let base = coordinate(withNormalizedOffset: .zero)
                base.withOffset(CGVector(dx: offset.dx + drag.start.x, dy: offset.dy + drag.start.y)).press(
                    forDuration: ScrollDrag.pressDuration,
                    thenDragTo: base.withOffset(CGVector(dx: offset.dx + drag.end.x, dy: offset.dy + drag.end.y)),
                    withVelocity: .fast, thenHoldForDuration: ScrollDrag.holdDuration)
            }
            return child.isReady(within: app.windows.firstMatch.frame)
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
