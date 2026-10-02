# Synchronizing UI interactions

Wait for the state an interaction requires and reveal elements within a bounded swipe budget.

## Overview

### Wait for readiness

An element can exist before its underlying feature is ready. Use
``waitForEnabled(_:timeout:named:file:line:)`` when the next action requires an enabled
control. Enabled state does not guarantee that the control is hittable; scrolling
or another application-specific condition may also be necessary.

```swift
import XCTest
import TestCommonsXCUI

@MainActor
func submitWhenReady(in app: XCUIApplication) {
    let submit = app.buttons["submit"]
    guard TestCommonsXCUI.waitForEnabled(submit, timeout: 5) else { return }
    submit.tap()
}
```

``waitForExistence(_:timeout:named:file:line:)`` checks hierarchy membership only.
``waitForValue(_:on:timeout:named:file:line:)`` compares an exact accessibility value;
``waitForValueContaining(_:on:timeout:named:file:line:)`` compares a literal substring.
Both string comparisons are case-sensitive and require existence within the same
timeout budget. They observe `value`, not `label`.

Each wait records an XCTest failure on timeout and returns a discardable `Bool`.
Use the returned flag to stop an interaction that requires a successful wait.
Ignoring it still reports the assertion failure but allows subsequent code to run.
Pass a nonnegative timeout in seconds; the package supplies no application-specific default.

### Preserve failure locations in adapters

Helpers default to `#filePath` and `#line` at the immediate call site. A local wrapper
should accept and forward both values so failures point to the test rather than the wrapper.

```swift
import XCTest
import TestCommonsXCUI

@MainActor
@discardableResult
func waitForReady(
    _ element: XCUIElement,
    file: StaticString = #filePath,
    line: UInt = #line
) -> Bool {
    TestCommonsXCUI.waitForEnabled(element, timeout: 5, file: file, line: line)
}
```

Qualifying a wait with `TestCommonsXCUI` also avoids ambiguity while local helpers
with the same names are being replaced.

### Reveal a child within a scrollable container

Scroll the container that owns the child. The scrolling helpers check existence
and hittability before each swipe and after the final swipe.

```swift
import XCTest
import TestCommonsXCUI

@MainActor
func revealAndTap(_ child: XCUIElement, in container: XCUIElement) {
    let revealed = container.scrollUpUntilHittable(child, maxAttempts: 8)
    XCTAssertTrue(revealed, "Expected the child to become hittable")
    guard revealed else { return }
    child.tap()
}
```

Use ``/TestCommonsXCUI/XCUIAutomation/XCUIElement/scrollDownUntilHittable(_:maxAttempts:)`` for content above the
viewport. A zero or negative budget checks the current state without swiping.
Unlike the wait helpers, scrolling returns `false` on exhaustion without recording
an assertion. Assert the returned flag when revealing the element is required.

### Check frame order

Import `TestCommons` to obtain `ReadingDirection`, and use
``XCTAssertReadingOrder(first:second:direction:_:rowTolerance:file:line:)`` with
frames in the same coordinate space. The assertion checks valid geometry, row
alignment, and strict horizontal-center order, and reports both frames on failure.
Its row tolerance is exclusive; equal horizontal centers fail in either direction.

```swift
import XCTest
import TestCommons
import TestCommonsXCUI

@MainActor
func checkHorizontalOrder(_ first: XCUIElement, _ second: XCUIElement) {
    guard TestCommonsXCUI.waitForExistence(first, timeout: 5) else { return }
    guard TestCommonsXCUI.waitForExistence(second, timeout: 5) else { return }
    XCTAssertReadingOrder(
        first: first.frame, second: second.frame,
        direction: .leftToRight, "Item order", rowTolerance: 1.5
    )
}
```
