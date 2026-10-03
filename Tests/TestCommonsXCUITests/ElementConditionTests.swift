#if os(macOS) || os(iOS)
    import Foundation
    import Testing

    @testable import TestCommonsXCUI

    struct ElementConditionTests {
        @Test(arguments: [true, false], [true, false])
        func hittabilityRequiresExistence(exists: Bool, hittable: Bool) {
            let attributes: NSDictionary = ["exists": exists, "isHittable": hittable]
            #expect(ElementCondition.hittable.predicate.evaluate(with: attributes) == (exists && hittable))
            #expect(ElementCondition.absent.predicate.evaluate(with: attributes) == !exists)
        }

        @Test func labelsAreLiteralAndRequireExistence() {
            let label = "Ready %@ 'status'"
            let attributes: NSDictionary = ["exists": true, "label": label]
            #expect(ElementCondition.label(label).predicate.evaluate(with: attributes))
            #expect(ElementCondition.labelContaining("%@").predicate.evaluate(with: attributes))
            #expect(!ElementCondition.label("ready %@ 'status'").predicate.evaluate(with: attributes))
            #expect(!ElementCondition.label(label).predicate.evaluate(with: ["exists": false, "label": label]))
        }

        @Test(arguments: [true, false], [true, false])
        func enabledRequiresExistenceAndReadiness(exists: Bool, enabled: Bool) {
            let attributes: NSDictionary = ["exists": exists, "isEnabled": enabled]
            #expect(ElementCondition.enabled.predicate.evaluate(with: attributes) == (exists && enabled))
        }

        @Test(arguments: [true, false])
        func matchingValuesRequireExistence(exists: Bool) {
            let attributes: NSDictionary = ["exists": exists, "value": "ready"]
            #expect(ElementCondition.value("ready").predicate.evaluate(with: attributes) == exists)
            #expect(ElementCondition.valueContaining("ead").predicate.evaluate(with: attributes) == exists)
            #expect(ElementCondition.value("ead").predicate.evaluate(with: attributes) == false)
            #expect(ElementCondition.valueContaining("READY").predicate.evaluate(with: attributes) == false)
        }

        @Test
        func specialCharactersAreLiteralPredicateArguments() {
            let text = "it's 100% %@ ready"
            let attributes: NSDictionary = ["exists": true, "value": text]
            #expect(ElementCondition.value(text).predicate.evaluate(with: attributes))
            #expect(ElementCondition.valueContaining("100% %@").predicate.evaluate(with: attributes))
        }

        @Test(arguments: [
            (ElementCondition.enabled, "exist and become enabled"),
            (.hittable, "exist and become hittable"),
            (.absent, "disappear"),
            (.label("Done"), "exist with label equal to 'Done'"),
            (.labelContaining("Do"), "exist with label containing 'Do'"),
            (.value("1"), "exist with value equal to '1'"),
            (.valueContaining("1"), "exist with value containing '1'"),
        ])
        func failureDescriptionsNameTheCondition(condition: ElementCondition, description: String) {
            #expect(condition.description == description)
        }

        @Test
        func missingValuesDoNotMatch() {
            let attributes: NSDictionary = ["exists": true, "value": NSNull()]
            #expect(ElementCondition.value("").predicate.evaluate(with: attributes) == false)
            #expect(ElementCondition.valueContaining("ready").predicate.evaluate(with: attributes) == false)
        }
    }

#endif
