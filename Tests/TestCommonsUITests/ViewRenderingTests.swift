#if canImport(SwiftUI)
    import Foundation
    import SwiftUI
    import Testing
    import TestCommonsUI

    extension RenderingTests {
        @MainActor
        struct ViewRenderingTests {
            @Test func callerOwnedViewsRenderAndStabilize() throws {
                let hosted = HostedView(Color.blue, size: CGSize(width: 24, height: 24))
                defer { hosted.close() }
                #if canImport(AppKit)
                    let view: RenderableView = hosted.hosting
                #else
                    let view: RenderableView = hosted.hosting.view
                #endif
                #expect(ViewRendering.pngData(of: view) != nil)
                #expect(ViewRendering.waitForStableRender(view, timeout: 2, minimumFrames: 2, requiredStableFrames: 2))
                #expect(!ViewRendering.waitForStableRender(view, timeout: 0))
            }
        }
    }
#endif
