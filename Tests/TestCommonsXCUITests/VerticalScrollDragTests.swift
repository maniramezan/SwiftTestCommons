#if os(macOS) || os(iOS)
    import Foundation
    import Testing

    @testable import TestCommonsXCUI

    struct VerticalScrollDragTests {
        private let window = CGRect(x: 0, y: 0, width: 956, height: 440)
        private let detail = CGRect(x: 462, y: 0, width: 494, height: 440)

        @Test
        func landscapeGesturesStayInTheDetailPane() throws {
            let drag = try #require(VerticalScrollDrag(container: detail, window: window, keyboard: nil, target: nil))
            #expect(drag.start.x + detail.minX == 709)
            #expect(drag.end.x + detail.minX == 709)
            #expect(drag.start.y > drag.end.y)
        }

        @Test
        func clipsOversizedContainersToWindowAndKeyboard() throws {
            let container = CGRect(x: 462, y: -100, width: 494, height: 1000)
            let keyboard = CGRect(x: 0, y: 250, width: 956, height: 190)
            let drag = try #require(
                VerticalScrollDrag(container: container, window: window, keyboard: keyboard, target: nil))
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
                VerticalScrollDrag(container: detail, window: window, keyboard: keyboard, target: nil))
            #expect(drag.start.y == 308)
        }

        @Test
        func targetAboveViewportReversesTheDrag() throws {
            let container = CGRect(x: 462, y: 100, width: 494, height: 340)
            let target = CGRect(x: 544, y: 51, width: 180, height: 24)
            let drag = try #require(
                VerticalScrollDrag(container: container, window: window, keyboard: nil, target: target))
            #expect(drag.start.y < drag.end.y)
        }

        @Test(arguments: [CGRect.zero, CGRect(x: 1000, y: 0, width: 100, height: 100)])
        func unavailableViewportHasNoGesture(container: CGRect) {
            #expect(VerticalScrollDrag(container: container, window: window, keyboard: nil, target: nil) == nil)
        }

        @Test
        func keyboardCoveringTheContainerHasNoGesture() {
            #expect(VerticalScrollDrag(container: detail, window: window, keyboard: window, target: nil) == nil)
        }
    }
#endif
