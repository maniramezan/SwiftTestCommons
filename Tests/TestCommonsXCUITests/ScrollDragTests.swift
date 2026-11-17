#if os(macOS) || os(iOS) || os(visionOS)
    import Foundation
    import TestCommons
    import Testing

    @testable import TestCommonsXCUI

    struct ScrollDragTests {
        private let window = CGRect(x: 0, y: 0, width: 956, height: 440)
        private let detail = CGRect(x: 462, y: 0, width: 494, height: 440)

        @Test
        func landscapeGesturesStayInTheDetailPane() throws {
            let drag = try #require(ScrollDrag(container: detail, window: window, keyboard: nil, target: nil))
            #expect(drag.start.x + detail.minX == 709)
            #expect(drag.end.x + detail.minX == 709)
            #expect(drag.start.y > drag.end.y)
        }

        @Test
        func clipsOversizedContainersToWindowAndKeyboard() throws {
            let container = CGRect(x: 462, y: -100, width: 494, height: 1000)
            let keyboard = CGRect(x: 0, y: 250, width: 956, height: 190)
            let drag = try #require(
                ScrollDrag(container: container, window: window, keyboard: keyboard, target: nil))
            for point in [drag.start, drag.end] {
                let absolute = CGPoint(x: point.x + container.minX, y: point.y + container.minY)
                #expect(window.contains(absolute))
                #expect(absolute.y < keyboard.minY)
                #expect(absolute.x > container.minX)
            }
        }

        @Test
        func keyboardInAnotherPaneDoesNotClipTheViewport() throws {
            let keyboard = CGRect(x: 0, y: 100, width: 400, height: 340)
            let drag = try #require(
                ScrollDrag(container: detail, window: window, keyboard: keyboard, target: nil))
            #expect(drag.start.y == 352)
        }

        @Test(arguments: [ScrollDrag.Axis.vertical, .horizontal])
        func eachDragStepsLessThanOneViewport(axis: ScrollDrag.Axis) throws {
            let drag = try #require(
                ScrollDrag(axis: axis, container: detail, window: window, keyboard: nil, target: nil))
            let step = axis == .vertical ? abs(drag.start.y - drag.end.y) : abs(drag.start.x - drag.end.x)
            let extent = axis == .vertical ? detail.height : detail.width
            #expect(step > extent / 2)
            #expect(step < extent * 0.7)
        }

        @Test
        func targetAboveViewportReversesTheDrag() throws {
            let container = CGRect(x: 462, y: 100, width: 494, height: 340)
            let target = CGRect(x: 544, y: 51, width: 180, height: 24)
            let drag = try #require(
                ScrollDrag(container: container, window: window, keyboard: nil, target: target))
            #expect(drag.start.y < drag.end.y)
        }

        @Test(arguments: [CGRect.zero, CGRect(x: 1000, y: 0, width: 100, height: 100)])
        func unavailableViewportHasNoGesture(container: CGRect) {
            #expect(ScrollDrag(container: container, window: window, keyboard: nil, target: nil) == nil)
        }

        @Test
        func keyboardCoveringTheContainerHasNoGesture() {
            #expect(ScrollDrag(container: detail, window: window, keyboard: window, target: nil) == nil)
        }

        @Test(arguments: [ReadingDirection.leftToRight, .rightToLeft])
        func horizontalDragsRevealContentAfterTheViewport(direction: ReadingDirection) throws {
            let drag = try #require(
                ScrollDrag(
                    axis: .horizontal, container: detail, window: window, keyboard: nil, target: nil,
                    direction: direction))
            #expect(drag.start.y == drag.end.y)
            #expect(drag.start.y + detail.minY == detail.midY)
            #expect((drag.start.x > drag.end.x) == (direction == .leftToRight))
        }

        @Test
        func horizontalDragsMoveTowardAKnownTarget() throws {
            let container = CGRect(x: 100, y: 0, width: 400, height: 200)
            let wide = CGRect(x: 0, y: 0, width: 1000, height: 440)
            let left = CGRect(x: 10, y: 50, width: 40, height: 40)
            let right = CGRect(x: 600, y: 50, width: 40, height: 40)
            let towardLeft = try #require(
                ScrollDrag(
                    axis: .horizontal, container: container, window: wide, keyboard: nil, target: left,
                    direction: .leftToRight))
            #expect(towardLeft.start.x < towardLeft.end.x)
            let towardRight = try #require(
                ScrollDrag(
                    axis: .horizontal, container: container, window: wide, keyboard: nil, target: right,
                    direction: .rightToLeft))
            #expect(towardRight.start.x > towardRight.end.x)
        }

        @Test(arguments: [ScrollDrag.Axis.vertical, .horizontal])
        func reversingFlipsThePlannedDrag(axis: ScrollDrag.Axis) throws {
            let forward = try #require(
                ScrollDrag(axis: axis, container: detail, window: window, keyboard: nil, target: nil))
            let back = try #require(
                ScrollDrag(axis: axis, container: detail, window: window, keyboard: nil, target: nil, reversed: true))
            #expect(back.start == forward.end)
            #expect(back.end == forward.start)
        }

        @Test
        func aTargetBeyondTheViewportOverridesReversal() throws {
            let container = CGRect(x: 120, y: 0, width: 282, height: 874)
            let tall = CGRect(x: 0, y: 0, width: 402, height: 874)
            let above = CGRect(x: 237, y: -412, width: 47, height: 22)
            let below = CGRect(x: 237, y: 1200, width: 47, height: 22)
            let up = try #require(
                ScrollDrag(container: container, window: tall, keyboard: nil, target: above, reversed: true))
            #expect(up.start.y < up.end.y)
            let down = try #require(
                ScrollDrag(container: container, window: tall, keyboard: nil, target: below, reversed: true))
            #expect(down.start.y > down.end.y)
            let left = try #require(
                ScrollDrag(
                    axis: .horizontal, container: container, window: tall, keyboard: nil,
                    target: CGRect(x: -300, y: 10, width: 40, height: 40), reversed: true))
            #expect(left.start.x < left.end.x)
        }
    }
#endif
