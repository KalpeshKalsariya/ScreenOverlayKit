<div align="center">

# ScreenOverlayKit

A lightweight debug tool for iOS developers to instantly see which screen they're on while testing their app.

</div>

---

<div align="center">

https://github.com/user-attachments/assets/94611da2-581f-4ceb-96f1-ed5e4431c991

</div>


The overlay label updates automatically as the user moves from screen to screen — no manual calls needed. Tapping the label shows the full view-controller hierarchy path for the current screen (nav stack → tab → modal chain), with a one-tap copy button, and the label itself can be dragged to any edge of the screen.

## Features

- 📱 **Real-time screen name overlay** — floating pill label shows the active screen's name
- 🔄 **Auto-detection (UIKit)** — uses method swizzling on `viewDidAppear` / `viewDidDisappear`, no manual calls needed
- 🧩 **SwiftUI support** — a `.screenOverlayTrack("ScreenName")` view modifier tracks screens that live entirely inside SwiftUI navigation
- 👆 **Tap for full path** — tap the label to see the complete hierarchy (nav stack, tab bar, modal chain) for the current screen, with a copy-to-clipboard action
- 🧭 **Single-line console logging** — every screen change and path lookup is also printed to the Xcode console on one line, easy to search/filter
- 📊 **Analytics hook** — implement `ScreenOverlayEventLogger` to forward every screen view (and any custom event you log) to Firebase Analytics or any other backend
- 🫥 **Passthrough touches** — the overlay never blocks your app's own interactions; only the pill itself is interactive
- ⚡ **Simple setup** — call `ScreenOverlay.enable()` once inside your app's `#if DEBUG` block
- 🌗 **Dark & light mode support** — overlay automatically adapts to system appearance
- 🖐️ **Draggable overlay** — optionally drag the label anywhere on screen, snaps to the nearest edge
- 🔔 **Stays visible above alerts** — the overlay window renders above system alerts and action sheets, so it's never hidden behind them
- 🛡️ **Debug-only by usage** — wrap `ScreenOverlay.enable()` in `#if DEBUG` so it never runs in production
- 🌉 **Swift, SwiftUI & Objective-C** — `ScreenOverlay` is a plain `NSObject` subclass with explicit `@objc` entry points, so it's usable from all three

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

`ScreenOverlay.enable()` takes two optional parameters:

| Parameter | Default | Description |
|---|---|---|
| `draggable` | `false` | Lets you drag the overlay anywhere on screen; snaps to the nearest edge on release |
| `showTimeOnTrail` | `false` | Records how long each screen stayed on top, shown in the trail sheet and console/file exports |

ScreenOverlayKit works from **Swift (UIKit)**, **SwiftUI**, and **Objective-C** — pick the section below that matches your project.

### Swift — AppDelegate (UIKit)

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

### Swift — SceneDelegate (iOS 13+)

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

Prefer the plain `ScreenOverlay.enable()` call if you don't need dragging — both parameters are optional and default to `false`.

### SwiftUI

ScreenOverlayKit's automatic detection is UIKit-based (it swizzles `viewDidAppear` / `viewDidDisappear`), so it automatically sees the `UIHostingController` your SwiftUI content is wrapped in — that already covers a single-screen SwiftUI app. Screens navigated to purely within SwiftUI (`NavigationStack` destinations, `.sheet`, `.fullScreenCover`, tab selections, etc.) don't create a new `UIViewController`, so track each of those individually with the `.screenOverlayTrack(_:)` view modifier.

```swift
import SwiftUI
import ScreenOverlayKit

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .screenOverlayTrack("ContentView")
                .onAppear {
                    // .onAppear fires once the window scene exists, unlike App.init(),
                    // which can run before there's a scene for the overlay window to attach to.
                    #if DEBUG
                    ScreenOverlay.enable(draggable: true)
                    #endif
                }
        }
    }
}

struct ProfileView: View {
    var body: some View {
        Text("Profile")
            .screenOverlayTrack("ProfileView")
    }
}
```

If your app uses `UIApplicationDelegateAdaptor`, you can instead call `ScreenOverlay.enable()` from the adapted `AppDelegate`/`SceneDelegate` exactly as in the UIKit examples above.

### Objective-C

`ScreenOverlay` is a plain `NSObject` subclass with explicit `@objc` entry points, so it's fully usable from Objective-C. Swift's default parameter values don't exist in Objective-C, so a couple of explicit overloads are provided:

```objc
@import ScreenOverlayKit;

#if DEBUG
[ScreenOverlay enable];                                          // draggable: NO, showTimeOnTrail: NO
[ScreenOverlay enableWithDraggable:YES showTimeOnTrail:NO];       // customize both options
#endif

// Later:
[ScreenOverlay disable];
```

## Analytics / Event Logging (Firebase, etc.)

ScreenOverlayKit has **no dependency on Firebase or any analytics SDK**. Instead, it exposes a small `ScreenOverlayEventLogger` protocol — implement it and assign it to `ScreenOverlay.eventLogger` to forward every screen view (and any custom event you log) to whatever backend you use.

```swift
import ScreenOverlayKit
import FirebaseAnalytics

final class FirebaseScreenOverlayLogger: NSObject, ScreenOverlayEventLogger {
    func screenOverlayDidLogScreenView(_ screenName: String, previousScreenName: String?) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName
        ])
    }

    func screenOverlayDidLogEvent(_ name: String, parameters: [String: Any]?) {
        Analytics.logEvent(name, parameters: parameters)
    }
}

// Keep a strong reference somewhere (e.g. AppDelegate) — `eventLogger` is held weakly.
let screenOverlayLogger = FirebaseScreenOverlayLogger()

#if DEBUG
ScreenOverlay.enable()
ScreenOverlay.eventLogger = screenOverlayLogger
#endif
```

Every screen view recorded by ScreenOverlayKit — whether from automatic UIKit tracking or `.screenOverlayTrack(_:)` in SwiftUI — calls `screenOverlayDidLogScreenView(_:previousScreenName:)`. For anything else the user does (button taps, form submissions, feature usage), log it explicitly:

```swift
ScreenOverlay.logEvent(name: "checkout_button_tapped", parameters: ["cart_items": 3])
```

From Objective-C:

```objc
[ScreenOverlay logEventWithName:@"checkout_button_tapped" parameters:@{@"cart_items": @3}];
```

Because `eventLogger` is a plain protocol rather than a hard dependency, the exact same pattern works for Mixpanel, Amplitude, or an in-house logging pipeline — just implement the two methods and point them wherever you want.

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
| `ScreenOverlay` | Public entry point (`enable()` / `disable()` / `logEvent(name:parameters:)` / `eventLogger`) |
| `ScreenOverlayEventLogger` | Protocol you implement to forward screen views & custom events to Firebase or any analytics backend |
| `UIViewController+Swizzling` | Hooks into `viewDidAppear` & `viewDidDisappear` via Objective-C runtime swizzling |
| `View+ScreenOverlayTracking` | SwiftUI `.screenOverlayTrack(_:)` view modifier for screens with no backing `UIViewController` |
| `ViewControllerTracker` | Resolves the topmost visible VC from the window hierarchy; builds the full path on tap |
| `TrailLogger` | Records the current/previous session's screen trail and notifies `ScreenOverlay.eventLogger` |
| `OverlayManager` | Creates the `PassthroughWindow` above system alerts and drives the pill label's position/drag/tap behavior |
| `OverlayLabel` | The pill label itself — owns its light/dark-mode styling and padded-text layout |
| `PassthroughWindow` | Overrides `hitTest` so touches fall through to the app beneath, except on the pill itself |

### Folder Structure

```
Sources/ScreenOverlayKit
│
├── Public
│   ├── ScreenOverlay.swift              — enable()/disable()/logEvent()/eventLogger
│   └── ScreenOverlayEventLogger.swift   — analytics-forwarding protocol
│
├── Overlay
│   ├── OverlayManager.swift             — window lifecycle, dragging, positioning, tap handling
│   ├── OverlayLabel.swift               — the pill label's styling & sizing
│   └── PassthroughWindow.swift          — the UIWindow that lets touches fall through
│
├── Tracker
│   └── ViewControllerTracker.swift      — resolves the top-most VC, prints the hierarchy
│
├── Trail
│   ├── TrailEntry.swift                 — one recorded step in the screen trail
│   ├── TrailLogger.swift                — records/persists/exports the trail
│   └── TrailBottomSheet.swift           — the tap-to-view trail UI
│
├── Swizzling
│   └── UIViewController+Swizzling.swift — hooks viewDidAppear/viewDidDisappear
│
└── Extensions
    └── View+ScreenOverlayTracking.swift — SwiftUI `.screenOverlayTrack(_:)` modifier
```

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

For questions or feature requests, reach out at kalsariyakalpesh993@gmail.com or open an issue on GitHub.

## Author

Kalpesh Kalsariya — [github.com/KalpeshKalsariya](https://github.com/KalpeshKalsariya)
