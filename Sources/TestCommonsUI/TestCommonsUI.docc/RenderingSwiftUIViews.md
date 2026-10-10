# Rendering SwiftUI views

Choose an offscreen or hosted renderer, make renders comparable, and wait for stable frames.

## Overview

### Render offscreen without a window

``ViewRendering/pngData(rendering:size:scale:)`` uses SwiftUI's `ImageRenderer`. It needs
no window or host application, so it works in package test bundles on every platform.
Supply the environment the view needs, because no app scene provides it.

```swift
import SwiftUI
import Testing
import TestCommonsUI

@MainActor
@Test func badgeRendersContent() throws {
    let size = CGSize(width: 80, height: 24)
    let blank = try #require(ViewRendering.pngData(rendering: Color.clear, size: size))
    let badge = try #require(
        ViewRendering.pngData(rendering: Text("New").environment(\.locale, Locale(identifier: "en_US")), size: size)
    )
    #expect(badge != blank)
}
```

The output size is `size` times `scale` pixels. The default scale of 1 keeps bytes
independent of the test device. Views backed by platform controls, such as lists,
scroll views, and text fields, render as placeholders offscreen.

### Host a view in a window

``HostedView`` places the view in a real `NSWindow` or `UIWindow`, so platform-backed
controls, lazy containers, and layout passes behave as they do in an app. Call
``HostedView/close()`` when finished, normally in `defer`.

```swift
import SwiftUI
import TestCommonsUI

@MainActor
func renderHostedList() -> Data? {
    let hosted = HostedView(List(0..<3, id: \.self) { Text("Row \($0)") }, size: CGSize(width: 200, height: 200), scale: 2)
    defer { hosted.close() }
    guard hosted.waitForStableRender(timeout: .seconds(2)) else {
        return nil
    }
    return hosted.renderPNG()
}
```

On iOS, SwiftUI builds a hosted hierarchy only in a test target that has a host
application. In a hostless package test bundle, ``HostedView/renderPNG()`` and
``ViewRendering/pngData(of:scale:)`` return `nil` rather than blank bytes, so a
comparison cannot pass by accident. Use the offscreen renderer there.

### Make renders comparable

Compare renders produced with the same scale, size, appearance, and environment. Pass a
fixed `scale` to ``HostedView/init(_:size:visible:scale:)`` or
``ViewRendering/pngData(of:scale:)`` when references are shared across machines; `nil`
uses the display's scale, which differs between devices.

Stable pixels do not prove that content arrived: an empty view is stable immediately.
Render a blank reference with the same settings and check
``HostedView/rendersDifferently(from:)`` when that distinction matters.

### Wait for stable frames

``HostedView/waitForStableRender(timeout:minimumFrames:requiredStableFrames:pollInterval:)``
pumps the main run loop until consecutive frames match. Animated views may never
stabilize. Other main-actor tests can run while the loop is pumped, so serialize
suites that render, for example by nesting them in one `.serialized` suite.
