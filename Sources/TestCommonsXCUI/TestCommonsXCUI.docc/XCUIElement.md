# ``TestCommonsXCUI/XCUIAutomation/XCUIElement``

Bounded scrolling operations for revealing descendants in UI tests.

## Overview

Call these methods on the scrollable container that owns the element to reveal, or on the
application for the drag-based helpers, which find the owning container themselves.
They run on the main actor and return whether the child exists and is hittable.
They do not record an XCTest assertion when the budget is exhausted.

## Topics

### Revealing descendants with swipes

- ``scrollUpUntilHittable(_:maxAttempts:velocity:)``
- ``scrollDownUntilHittable(_:maxAttempts:velocity:)``
- ``scrollLeftUntilHittable(_:maxAttempts:velocity:)``
- ``scrollRightUntilHittable(_:maxAttempts:velocity:)``

### Revealing descendants with drags

- ``scrollVerticallyUntilHittable(_:maxAttempts:in:)``
- ``scrollHorizontallyUntilHittable(_:maxAttempts:direction:in:)``
