# Configuring UI test launches

Launch the app in a known locale, layout direction, and text size, and capture what went wrong.

## Overview

### Set locale, direction, and text size

Configure an unlaunched `XCUIApplication`, then launch it. Each helper removes earlier
arguments of the same kind and keeps your app-specific flags, so a shared setup can be
overridden per test.

```swift
import TestCommons
import TestCommonsXCUI
import XCTest

@MainActor
func launchMirroredLargeText() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-UITesting"]
    configureLocale(of: app, language: "fa", locale: "fa_IR")
    configureLayoutDirection(of: app, .rightToLeft)
    configureContentSizeCategory(of: app, "UICTContentSizeCategoryAccessibilityXL")
    app.launch()
    return app
}
```

``configureLayoutDirection(of:_:)`` mirrors the layout without translating the app, which
checks right-to-left support before strings are localized. ``configureContentSizeCategory(of:_:)``
takes a `UIContentSizeCategory` raw value and is available on iOS, tvOS, and visionOS.

### Replace text in a field

``replaceText(in:with:caretOffset:timeout:named:file:line:)`` taps at the end of a plain
field, deletes its contents, types the replacement, and waits for the field to report it.
A value equal to the field's placeholder counts as empty, both before typing and when the
replacement is empty. One delete key is typed per Unicode scalar, so text with combining
marks or zero-width joiners is cleared completely. Secure fields do not expose their
contents and need your own strategy.

### Choose one element and record diagnostics

``uniqueHittableElement(in:file:line:)`` returns the single hittable match of a query and
records a failure when more than one is visible, which catches ambiguous identifiers early.
``attachDiagnostics(of:to:named:lifetime:)`` attaches a screenshot and the accessibility
hierarchy to the test; pass `.deleteOnSuccess` to keep them only for failures.

```swift
import TestCommonsXCUI
import XCTest

final class CheckoutUITests: XCTestCase {
    @MainActor
    func testPayButtonIsUnique() {
        let app = XCUIApplication()
        app.launch()
        attachDiagnostics(of: app, to: self, named: "Checkout", lifetime: .deleteOnSuccess)
        let pay = uniqueHittableElement(in: app.buttons.matching(identifier: "pay"))
        XCTAssertNotNil(pay)
    }
}
```
