#if canImport(XCTest) && (os(macOS) || os(iOS))
    import XCTest

    enum ElementCondition {
        case enabled
        case hittable
        case absent
        case label(String)
        case labelContaining(String)
        case value(String)
        case valueContaining(String)

        var predicate: NSPredicate {
            switch self {
            case .hittable:
                NSPredicate(format: "exists == true AND isHittable == true")
            case .absent:
                NSPredicate(format: "exists == false")
            case .label(let value):
                NSPredicate(format: "exists == true AND label == %@", value)
            case .labelContaining(let value):
                NSPredicate(format: "exists == true AND label CONTAINS %@", value)
            case .enabled:
                NSPredicate(format: "exists == true AND isEnabled == true")
            case .value(let value):
                NSPredicate(format: "exists == true AND value == %@", value)
            case .valueContaining(let value):
                NSPredicate(format: "exists == true AND value CONTAINS %@", value)
            }
        }

        var description: String {
            switch self {
            case .enabled: "exist and become enabled"
            case .hittable: "exist and become hittable"
            case .absent: "disappear"
            case .label(let value): "exist with label equal to '\(value)'"
            case .labelContaining(let value): "exist with label containing '\(value)'"
            case .value(let value): "exist with value equal to '\(value)'"
            case .valueContaining(let value): "exist with value containing '\(value)'"
            }
        }
    }
#endif
