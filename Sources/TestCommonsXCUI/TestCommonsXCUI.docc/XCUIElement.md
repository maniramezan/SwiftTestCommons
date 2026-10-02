# ``TestCommonsXCUI/XCUIAutomation/XCUIElement``

Bounded scrolling operations for revealing descendants in UI tests.

## Overview

Call these methods on the scrollable container that owns the element to reveal.
They run on the main actor and return whether the child exists and is hittable.
They do not record an XCTest assertion when the swipe budget is exhausted.

## Topics

### Revealing descendants

- ``scrollUpUntilHittable(_:maxAttempts:)``
- ``scrollDownUntilHittable(_:maxAttempts:)``
