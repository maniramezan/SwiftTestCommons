# ``TestCommonsXCUI``

XCTest assertions and bounded interactions for UI test targets.

## Overview

Link this product into XCTest UI targets. Use the core `TestCommons` product for
geometry, recorders, and isolated storage in other targets, including shipping tools.
This product supports iOS 18 and macOS 15 or later with Swift 6 language mode.

Wait and scroll helpers run on the main actor. They accept caller-controlled timeout
or swipe budgets. Assertion helpers forward the caller's source location by default.
Keep application launch configuration and accessibility identifiers in your own target.

## Topics

### Guide

- <doc:SynchronizingUIInteractions>

### Element state assertions

- ``waitForExistence(_:timeout:file:line:)``
- ``waitForEnabled(_:timeout:file:line:)``
- ``waitForValue(_:on:timeout:file:line:)``
- ``waitForValueContaining(_:on:timeout:file:line:)``

### Layout assertions

- ``XCTAssertReadingOrder(first:second:direction:_:rowTolerance:file:line:)``

### Bounded scrolling

- ``TestCommonsXCUI/XCUIAutomation``
