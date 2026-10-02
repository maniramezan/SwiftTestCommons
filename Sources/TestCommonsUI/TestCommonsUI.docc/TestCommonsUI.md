# ``TestCommonsUI``

Explicitly owned SwiftUI hosting and rendered-frame observation for Apple-platform tests.

## Overview

Host a view with its required environment, render it, and call `close()` in a defer block.
Run suites that pump the main run loop serially. Stable pixels do not imply nonblank content;
compare against a caller-owned reference when that distinction matters.

```swift
import SwiftUI
import TestCommonsUI

@MainActor
func renderFixture() {
    let hosted = HostedView(Text("Ready"), size: CGSize(width: 200, height: 100))
    defer { hosted.close() }
    _ = hosted.waitForStableRender()
    _ = hosted.renderPNG()
}
```

## Topics

### Hosting and rendering

- ``HostedView``

### Caller-owned views

- ``RenderableView``
- ``ViewRendering``
