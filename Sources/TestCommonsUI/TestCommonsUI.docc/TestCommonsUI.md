# ``TestCommonsUI``

Explicitly owned SwiftUI hosting and rendered-frame observation for Apple-platform tests.

## Overview

Render SwiftUI content offscreen in any test bundle, or host it in a real window when
platform-backed controls must behave as they do in an app. Stable pixels do not imply
nonblank content; compare against a caller-owned reference when that distinction matters.

```swift
import SwiftUI
import TestCommonsUI

@MainActor
func renderFixture() -> Data? {
    ViewRendering.pngData(rendering: Text("Ready"), size: CGSize(width: 200, height: 100))
}
```

## Topics

### Guide

- <doc:RenderingSwiftUIViews>

### Hosting and rendering

- ``HostedView``

### Caller-owned views

- ``RenderableView``
- ``ViewRendering``
