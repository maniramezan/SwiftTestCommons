#if canImport(SwiftUI)
    import Foundation
    import SwiftUI
    import Testing
    import TestCommonsUI

    extension RenderingTests {
        @MainActor
        struct HostedViewTests {
            #if canImport(AppKit)
                @Test func hostedFramesRenderAndClose() throws {
                    let size = CGSize(width: 40, height: 40)
                    let blank = HostedView(Color.clear, size: size)
                    defer { blank.close() }
                    let reference = try #require(blank.renderPNG())
                    let filled = HostedView(Color.red, size: size)
                    defer { filled.close() }
                    #expect(filled.rendersDifferently(from: reference))
                    #expect(
                        filled.waitForStableRender(
                            timeout: .seconds(2), minimumFrames: 2, requiredStableFrames: 2))
                    filled.close()
                    filled.close()
                    #expect(filled.renderPNG() == nil)
                    #expect(!filled.waitForStableRender(timeout: .zero))
                }

                @Test(arguments: [1.0, 2.0])
                func fixedScaleSetsPixelSize(scale: CGFloat) throws {
                    let hosted = HostedView(Color.red, size: CGSize(width: 30, height: 20), scale: scale)
                    defer { hosted.close() }
                    let png = try #require(hosted.renderPNG())
                    #expect(pngPixelSize(png) == CGSize(width: 30 * scale, height: 20 * scale))
                }
            #else
                // Package tests on iOS run without a host app, where SwiftUI never builds a
                // hosted hierarchy. Renders must report that instead of returning blank bytes.
                @Test func hostlessRendersAreUnavailable() {
                    let hosted = HostedView(Color.red, size: CGSize(width: 40, height: 40), scale: 1)
                    defer { hosted.close() }
                    #expect(hosted.renderPNG() == nil)
                    #expect(!hosted.rendersDifferently(from: Data()))
                    #expect(!hosted.waitForStableRender(timeout: .milliseconds(100)))
                }
            #endif
        }
    }
#endif
