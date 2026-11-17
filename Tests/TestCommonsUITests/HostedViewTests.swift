#if HOSTING_APPKIT || HOSTING_UIKIT
    import Foundation
    import SwiftUI
    import Testing
    import TestCommonsUI

    extension RenderingTests {
        @MainActor
        struct HostedViewTests {
            private struct TestFailure: Error {}

            #if HOSTING_APPKIT
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

                @Test func appearanceOverridesReachTheRenderedPixels() throws {
                    let size = CGSize(width: 40, height: 20)
                    let light = HostedView(
                        Color.primary, size: size, scale: 1, appearance: HostedAppearance(colorScheme: .light))
                    defer { light.close() }
                    let dark = HostedView(
                        Color.primary, size: size, scale: 1, appearance: HostedAppearance(colorScheme: .dark))
                    defer { dark.close() }
                    #expect(dark.rendersDifferently(from: try #require(light.renderPNG())))

                    let stripes = HStack(spacing: 0) {
                        Color.red
                        Color.blue
                    }
                    let leftToRight = HostedView(
                        stripes, size: size, scale: 1, appearance: HostedAppearance(layoutDirection: .leftToRight))
                    defer { leftToRight.close() }
                    let rightToLeft = HostedView(
                        stripes, size: size, scale: 1,
                        appearance: HostedAppearance(layoutDirection: .rightToLeft, dynamicTypeSize: .large))
                    defer { rightToLeft.close() }
                    #expect(rightToLeft.rendersDifferently(from: try #require(leftToRight.renderPNG())))
                }

                @Test func fittingWidthUsesTheIdealHeight() throws {
                    let hosted = try #require(
                        HostedView(Color.red.frame(height: 30), fittingWidth: 50, scale: 1))
                    defer { hosted.close() }
                    #expect(hosted.window.frame.size == CGSize(width: 50, height: 30))
                    #expect(HostedView(Color.red.frame(height: 0), fittingWidth: 50) == nil)
                }

                @Test func scopedHostingClosesAfterTheBody() throws {
                    let size = CGSize(width: 20, height: 20)
                    let hosted = HostedView.withHostedView(Color.red, size: size, scale: 1) { hosted in
                        #expect(hosted.renderPNG() != nil)
                        return hosted
                    }
                    #expect(hosted.renderPNG() == nil)
                    #expect(throws: TestFailure.self) {
                        try HostedView.withHostedView(Color.red, size: size) { _ in throw TestFailure() }
                    }
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
