#if canImport(XCTest) && (os(macOS) || os(iOS) || os(tvOS) || os(visionOS))
    import XCTest

    enum ElementCondition {
        case enabled
        case hittable
        case selected
        case focused
        case absent
        case label(String)
        case labelContaining(String)
        case value(String)
        case valueContaining(String)
        case emptyValue(placeholder: String?)

        var predicate: NSPredicate {
            switch self {
            case .hittable:
                NSPredicate(format: "exists == true AND isHittable == true")
            case .selected:
                NSPredicate(format: "exists == true AND isSelected == true")
            case .focused:
                NSPredicate(format: "exists == true AND hasFocus == true")
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
            case .emptyValue(let placeholder):
                // Cleared fields commonly report their placeholder as their value.
                NSPredicate(format: "exists == true AND (value == '' OR value == %@)", placeholder ?? "")
            }
        }

        var description: String {
            switch self {
            case .enabled: "exist and become enabled"
            case .hittable: "exist and become hittable"
            case .selected: "exist and become selected"
            case .focused: "exist and gain focus"
            case .absent: "disappear"
            case .label(let value): "exist with label equal to '\(value)'"
            case .labelContaining(let value): "exist with label containing '\(value)'"
            case .value(let value): "exist with value equal to '\(value)'"
            case .valueContaining(let value): "exist with value containing '\(value)'"
            case .emptyValue: "exist with an empty value"
            }
        }

        /// Matches a query whose `count` equals `count`.
        static func queryCount(_ count: Int) -> NSPredicate {
            NSPredicate(format: "count == %d", count)
        }
    }
#endif
