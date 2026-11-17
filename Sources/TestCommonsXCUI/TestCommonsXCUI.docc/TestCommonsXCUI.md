# ``TestCommonsXCUI``

XCTest assertions and bounded interactions for UI test targets.

## Overview

Link this product into XCTest UI targets. Use the core `TestCommons` product for
geometry, recorders, and isolated storage in other targets, including shipping tools.
This product supports iOS and Mac Catalyst 18, macOS 15, and visionOS 2 or later with Swift 6
language mode. On tvOS 18, waits, assertions, and launch configuration are available; gesture
helpers are not, because tvOS UI tests navigate with the remote.

Wait and scroll helpers run on the main actor. They accept caller-controlled timeout
or swipe budgets. Assertion helpers forward the caller's source location by default.
Keep application launch configuration and accessibility identifiers in your own target.

## Topics

### Guides

- <doc:SynchronizingUIInteractions>
- <doc:ConfiguringUITestLaunches>

### Element state assertions

- ``waitForExistence(_:timeout:named:file:line:)``
- ``waitForEnabled(_:timeout:named:file:line:)``
- ``waitForValue(_:on:timeout:named:file:line:)``
- ``waitForValueContaining(_:on:timeout:named:file:line:)``
- ``waitForSelection(_:timeout:named:file:line:)``
- ``waitForFocus(_:timeout:named:file:line:)``
- ``waitForCount(_:of:timeout:named:file:line:)``

### Interaction readiness

- ``waitForHittability(_:timeout:named:file:line:)``
- ``waitForAbsence(_:timeout:named:file:line:)``
- ``waitForLabel(_:on:timeout:named:file:line:)``
- ``waitForLabelContaining(_:on:timeout:named:file:line:)``

### Layout assertions

- ``XCTAssertReadingOrder(first:second:direction:_:rowTolerance:file:line:)``
- ``XCTAssertReadingOrder(_:direction:_:rowTolerance:file:line:)``

### Bounded scrolling

- ``TestCommonsXCUI/XCUIAutomation``

### Launch configuration

- ``configureLocale(of:language:locale:)``
- ``configureLayoutDirection(of:_:)``
- ``configureContentSizeCategory(of:_:)``

### Automation support

- ``attachDiagnostics(of:to:named:lifetime:)``
- ``uniqueHittableElement(in:file:line:)``
- ``replaceText(in:with:caretOffset:timeout:named:file:line:)``
