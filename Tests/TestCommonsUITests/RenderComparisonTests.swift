#if canImport(SwiftUI)
    import Foundation
    import SwiftUI
    import Testing
    import TestCommonsUI

    extension RenderingTests {
        @MainActor
        struct RenderComparisonTests {
            private let size = CGSize(width: 10, height: 10)

            @Test func identicalPixelsMatchAndDifferentPixelsDoNot() throws {
                let red = try #require(ViewRendering.pngData(rendering: Color.red, size: size))
                let blue = try #require(ViewRendering.pngData(rendering: Color.blue, size: size))
                #expect(RenderComparison.differingPixelFraction(between: red, and: red) == 0)
                #expect(RenderComparison.differingPixelFraction(between: red, and: blue) == 1)
                #expect(RenderComparison.matches(red, red))
                #expect(!RenderComparison.matches(red, blue))
                #expect(RenderComparison.matches(red, blue, channelTolerance: 255))
            }

            @Test func partialDifferencesAreMeasured() throws {
                let half = HStack(spacing: 0) {
                    Color.red
                    Color.blue
                }
                let red = try #require(ViewRendering.pngData(rendering: Color.red, size: size))
                let split = try #require(ViewRendering.pngData(rendering: half, size: size))
                let fraction = try #require(RenderComparison.differingPixelFraction(between: red, and: split))
                #expect(abs(fraction - 0.5) < 0.11)
                #expect(RenderComparison.matches(red, split, maximumDifferingFraction: 0.6))
                #expect(!RenderComparison.matches(red, split, maximumDifferingFraction: 0.4))
            }

            @Test func undecodableOrMismatchedImagesDoNotCompare() throws {
                let small = try #require(ViewRendering.pngData(rendering: Color.red, size: size))
                let large = try #require(ViewRendering.pngData(rendering: Color.red, size: size, scale: 2))
                #expect(RenderComparison.differingPixelFraction(between: small, and: large) == nil)
                #expect(RenderComparison.differingPixelFraction(between: Data([1, 2, 3]), and: small) == nil)
                #expect(!RenderComparison.matches(small, Data()))
            }
        }
    }
#endif
