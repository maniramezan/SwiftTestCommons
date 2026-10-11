#if canImport(SwiftUI)
    import Foundation
    import ImageIO

    /// Returns the pixel dimensions encoded in PNG bytes, or nil for undecodable data.
    func pngPixelSize(_ data: Data) -> CGSize? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }
        return CGSize(width: image.width, height: image.height)
    }
#endif
