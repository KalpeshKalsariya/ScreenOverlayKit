<div align="center">

# ScreenOverlayKit

A lightweight debug tool for iOS developers to instantly see which screen they're on while testing their app.

</div>

<div align="center">
https://github.com/user-attachments/assets/34d83c10-619f-4987-9721-42f0907ebf63
</div>

---

The overlay label updates automatically as the user moves from screen to screen — no manual calls needed. Tapping the label shows the full view-controller hierarchy path for the current screen (nav stack → tab → modal chain), with a one-tap copy button, and the label itself can be dragged to any edge of the screen.

## Features

- 📱 **Real-time screen name overlay** — floating pill label shows the active `UIViewController` class name
- 🔄 **Auto-detection** — uses method swizzling on `viewDidAppear` / `viewDidDisappear`, no manual calls needed
- 👆 **Tap for full path** — tap the label to see the complete hierarchy (nav stack, tab bar, modal chain) for the current screen, with a copy-to-clipboard action
- 🧭 **Single-line console logging** — every screen change and path lookup is also printed to the Xcode console on one line, easy to search/filter
- 🫥 **Passthrough touches** — the overlay never blocks your app's own interactions; only the pill itself is interactive
- ⚡ **Simple setup** — call `ScreenOverlay.enable()` once inside your app's `#if DEBUG` block
- 🌗 **Dark & light mode support** — overlay automatically adapts to system appearance
- 🖐️ **Draggable overlay** — optionally drag the label anywhere on screen, snaps to the nearest edge
- 🔔 **Stays visible above alerts** — the overlay window renders above system alerts and action sheets, so it's never hidden behind them
- 🛡️ **Debug-only by usage** — wrap `ScreenOverlay.enable()` in `#if DEBUG` so it never runs in production

## Requirements

| Minimum | |
|---|---|
| iOS | 13.0+ |
| Swift tools version | 6.3 (Swift 6 language mode) |
| Xcode | Toolchain with Swift 6.3 support |

## Installation

### Swift Package Manager (Recommended)

1. In Xcode, go to **File → Add Package Dependencies…**
2. Enter the repository URL:
   ```
   https://github.com/KalpeshKalsariya/ScreenOverlayKit
   ```
3. Select **Up to Next Major Version** starting from `1.0.0`
4. Add to your app target (not a framework target)

Or add it manually to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/KalpeshKalsariya/ScreenOverlayKit", from: "1.0.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["ScreenOverlayKit"]
    )
]
```

## Usage

> **Important:** ScreenOverlayKit is a debug tool. Always wrap `ScreenOverlay.enable()` in `#if DEBUG` in your app target. If you call it from a Release build, the overlay will appear for your users.

`ScreenOverlay.enable()` takes one optional parameter:

| Parameter | Default | Description |
|---|---|---|
| `draggable` | `false` | Lets you drag the overlay anywhere on screen; snaps to the nearest edge on release |

### AppDelegate (UIKit)

```swift
import ScreenOverlayKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        #if DEBUG
        ScreenOverlay.enable(draggable: true)
        #endif

        return true
    }
}
```

### SceneDelegate (iOS 13+)

```swift
import ScreenOverlayKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        #if DEBUG
        ScreenOverlay.enable(draggable: true)
        #endif
    }
}
```

Prefer the plain `ScreenOverlay.enable()` call if you don't need dragging — the parameter is optional and defaults to `false`.

> ⚠️ **Objective-C** — ScreenOverlayKit is a Swift-only package today (`ScreenOverlay` is a Swift `enum`, not exposed with `@objc`). Objective-C interop is not currently supported.

> ⚠️ **SwiftUI** — ScreenOverlayKit is UIKit-focused. SwiftUI screens are detected as their wrapping `UIHostingController<ContentView>`, and the label automatically strips that down to just `ContentView` — but native SwiftUI navigation (`NavigationStack`, `.sheet`, etc.) that doesn't go through UIKit view controllers isn't tracked.

## Draggable Overlay

By default the overlay is fixed at the top center, respecting the safe area. Pass `draggable: true` to let you drag it anywhere on screen. It snaps to the nearest edge when released.

```swift
#if DEBUG
ScreenOverlay.enable(draggable: true)
#endif
```

## Tap for Full Path

Tap the overlay label to see the complete hierarchy for whatever's currently visible — navigation stack, tab selection, and modal presentation chain — with a **Copy** button to grab it for a bug report or Slack message:

```
AppRootViewController
└─ UITabBarController
   └─ UINavigationController
      stack: HomeViewController → ProfileViewController
      └─ ProfileViewController
         (presents modally)
         └─ EditProfileViewController
```

The same path is also printed to the console as a single line, so you don't have to tap at all if you just want it in your logs:

```
🧭 ScreenOverlay path → AppRootViewController → UITabBarController → UINavigationController → ProfileViewController
```

## Dark & Light Mode

The overlay automatically adapts to the system appearance — no extra setup needed.

| Light Mode | Dark Mode |
|---|---|
| Dark background, white text | White background, dark text |

Make sure `UIUserInterfaceStyle` is not forced in your Info.plist, otherwise the system appearance change will have no effect.

## How It Works

| Component | Responsibility |
|---|---|
| `ScreenOverlay` | Public entry point (`enable()` / `disable()`) |
| `UIViewController+Swizzling` | Hooks into `viewDidAppear` & `viewDidDisappear` via Objective-C runtime swizzling |
| `ViewControllerTracker` | Resolves the topmost visible VC from the window hierarchy; builds the full path on tap |
| `OverlayWindow` | Creates a `UIWindow` above system alerts, hosting the floating pill label |
| `PassthroughWindow` | Overrides `hitTest` so touches fall through to the app beneath, except on the pill itself |

## Console Output

When active, ScreenOverlayKit prints to the Xcode console:

```
🔎 ScreenOverlayKit: scene manifest found, waiting for UIScene activation
🚀 ScreenOverlayKit enabled
📱 ScreenOverlay → HomeViewController  |  path: AppRootViewController → UINavigationController → HomeViewController

// After tapping the label:
🧭 ScreenOverlay path → AppRootViewController → UINavigationController → HomeViewController → ProfileViewController
```

## Disabling

```swift
ScreenOverlay.disable()
```

## License

MIT License. See [LICENSE](LICENSE) for details.

## Contact

For questions or feature requests, open an issue on GitHub.

## Author

Kalpesh Kalsariya — [github.com/KalpeshKalsariya](https://github.com/KalpeshKalsariya)
