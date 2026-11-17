#if canImport(ImageIO)
    import CoreGraphics
    import Foundation
    import ImageIO

    /// Compares rendered images by pixel instead of by encoded bytes.
    ///
    /// Byte equality fails on harmless encoder or antialiasing differences between machines.
    /// Decode both images, then count pixels whose channels differ by more than a tolerance.
    ///
    /// ## Topics
    /// - ``differingPixelFraction(between:and:channelTolerance:)``
    /// - ``matches(_:_:channelTolerance:maximumDifferingFraction:)``
    public enum RenderComparison {
        /// The fraction of pixels that differ between two encoded images.
        ///
        /// Both images are drawn into premultiplied 8-bit sRGB buffers before comparison, so
        /// different encodings of the same pixels compare equal.
        /// - Parameters:
        ///   - first: PNG or other ImageIO-readable bytes.
        ///   - second: The image to compare, at the same pixel size.
        ///   - channelTolerance: The largest per-channel difference that still counts as equal.
        /// - Returns: A value from 0 to 1, or nil when either image cannot be decoded or the
        ///   pixel sizes differ.
        public static func differingPixelFraction(
            between first: Data, and second: Data, channelTolerance: UInt8 = 0
        ) -> Double? {
            guard let first = rgbaPixels(first), let second = rgbaPixels(second),
                first.width == second.width, first.height == second.height
            else {
                return nil
            }
            let tolerance = Int(channelTolerance)
            var differing = 0
            first.bytes.withUnsafeBufferPointer { lhs in
                second.bytes.withUnsafeBufferPointer { rhs in
                    var index = 0
                    while index < lhs.count {
                        for channel in 0..<4
                        where abs(Int(lhs[index + channel]) - Int(rhs[index + channel])) > tolerance {
                            differing += 1
                            break
                        }
                        index += 4
                    }
                }
            }
            let total = first.width * first.height
            return total == 0 ? 0 : Double(differing) / Double(total)
        }

        /// Whether two encoded images match within the given tolerances.
        /// - Parameters:
        ///   - first: PNG or other ImageIO-readable bytes.
        ///   - second: The image to compare, at the same pixel size.
        ///   - channelTolerance: The largest per-channel difference that still counts as equal.
        ///   - maximumDifferingFraction: The largest fraction of differing pixels, from 0 to 1.
        /// - Returns: Whether both decode at one size and few enough pixels differ.
        public static func matches(
            _ first: Data, _ second: Data, channelTolerance: UInt8 = 0, maximumDifferingFraction: Double = 0
        ) -> Bool {
            precondition(maximumDifferingFraction >= 0 && maximumDifferingFraction <= 1)
            guard
                let fraction = differingPixelFraction(
                    between: first, and: second, channelTolerance: channelTolerance)
            else {
                return false
            }
            return fraction <= maximumDifferingFraction
        }

        private static func rgbaPixels(_ data: Data) -> (bytes: [UInt8], width: Int, height: Int)? {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
                let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
            else {
                return nil
            }
            let width = image.width
            let height = image.height
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
                guard
                    let context = CGContext(
                        data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                        bytesPerRow: width * 4, space: colorSpace,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
                else {
                    return false
                }
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
                return true
            }
            return drawn ? (bytes, width, height) : nil
        }
    }
#endif
