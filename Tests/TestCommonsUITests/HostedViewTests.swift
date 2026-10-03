#if canImport(SwiftUI)
    import Foundation
    import SwiftUI
    import Testing
    import TestCommonsUI

    @MainActor
    @Suite(.serialized)
    struct HostedViewTests {
        @Test func hostedFramesRenderAndClose() throws {
            let size = CGSize(width: 40, height: 40)
            let blank = HostedView(Color.clear, size: size)
            defer { blank.close() }
            let reference = try #require(blank.renderPNG())
            let filled = HostedView(Color.red, size: size)
            defer { filled.close() }
            #expect(filled.rendersDifferently(from: reference))
            #expect(filled.waitForStableRender(timeout: 2, minimumFrames: 2, requiredStableFrames: 2))
            filled.close()
            filled.close()
            #expect(filled.renderPNG() == nil)
            #expect(!filled.waitForStableRender(timeout: 0))
        }

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
#endif
