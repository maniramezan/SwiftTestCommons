#if canImport(XCTest) && (os(macOS) || os(iOS) || os(tvOS) || os(visionOS))
    /// Removes every occurrence of each key and its value, then appends the new pairs in order.
    ///
    /// A trailing key without a value is removed. Unrelated flags keep their positions.
    func replacingLaunchArguments(_ arguments: [String], with pairs: [(key: String, value: String)]) -> [String] {
        var arguments = arguments
        for (key, _) in pairs {
            while let index = arguments.firstIndex(of: key) {
                arguments.remove(at: index)
                if index < arguments.count {
                    arguments.remove(at: index)
                }
            }
        }
        return arguments + pairs.flatMap { [$0.key, $0.value] }
    }
#endif
