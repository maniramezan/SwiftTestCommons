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

The output size is `size` times `scale` pixels. The default scale of 1 keeps the pixel size
independent of the test device. It does not make pixels identical everywhere: fonts,
antialiasing, and OS versions can change them. Views backed by platform controls, such as
lists, scroll views, and text fields, render as placeholders offscreen.

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

Use ``HostedView/withHostedView(_:size:visible:scale:appearance:_:)`` to close the window
automatically, even when the closure throws. ``HostedView/init(_:fittingWidth:visible:scale:appearance:)``
sizes the window to the content's ideal height at a fixed width, and returns `nil` when the
content cannot be measured.

On iOS, SwiftUI builds a hosted hierarchy only in a test target that has a host
application. In a hostless package test bundle, ``HostedView/renderPNG()`` and
``ViewRendering/pngData(of:scale:)`` return `nil` rather than blank bytes, so a
comparison cannot pass by accident. Use the offscreen renderer there.

### Force an appearance

``HostedAppearance`` sets platform traits on the hosting hierarchy, so platform-backed
controls follow them as well as SwiftUI's environment. Use it for dark mode, right-to-left
layout, and Dynamic Type sizes. On macOS, AppKit has no Dynamic Type trait; apply
`.dynamicTypeSize(_:)` to the content instead.

```swift
import SwiftUI
import TestCommonsUI

@MainActor
func renderRightToLeftDark() -> Data? {
    let appearance = HostedAppearance(
        colorScheme: .dark, layoutDirection: .rightToLeft, dynamicTypeSize: .accessibility1)
    return HostedView.withHostedView(
        Label("Inbox", systemImage: "tray"), size: CGSize(width: 200, height: 60), scale: 2,
        appearance: appearance
    ) { hosted in
        hosted.waitForStableRender(timeout: .seconds(2)) ? hosted.renderPNG() : nil
    }
}
```

### Make renders comparable

Compare renders produced with the same scale, size, appearance, and environment. Pass a
fixed `scale` to ``HostedView/init(_:size:visible:scale:appearance:)`` or
``ViewRendering/pngData(of:scale:)`` when references are shared across machines; `nil`
uses the display's scale, which differs between devices.

Stable pixels do not prove that content arrived: an empty view is stable immediately.
Render a blank reference with the same settings and check
``HostedView/rendersDifferently(from:)`` when that distinction matters.

Byte equality fails on harmless encoder or antialiasing differences. ``RenderComparison``
decodes both images and counts differing pixels, with a per-channel tolerance and a
maximum differing fraction:

```swift
import Foundation
import TestCommonsUI

func matchesReference(_ render: Data, reference: Data) -> Bool {
    RenderComparison.matches(render, reference, channelTolerance: 2, maximumDifferingFraction: 0.001)
}
```

### Wait for stable frames

``HostedView/waitForStableRender(timeout:minimumFrames:requiredStableFrames:pollInterval:)``
pumps the main run loop until consecutive frames match. Frames are compared as raw pixels,
without PNG encoding. Animated views may never stabilize. Other main-actor tests can run while the loop is pumped, so serialize
suites that render, for example by nesting them in one `.serialized` suite.
