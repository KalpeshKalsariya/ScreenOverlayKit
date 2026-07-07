<div align="center">

# ScreenOverlayKit

A lightweight debug tool for iOS developers to instantly see which screen they're on while testing their app.

</div>

---

<div align="center">

https://github.com/user-attachments/assets/94611da2-581f-4ceb-96f1-ed5e4431c991

</div>


The overlay label updates automatically as you move from screen to screen — no manual calls needed. Tapping the label prints the full view-controller hierarchy (nav stack → tab → modal chain) to the console, and the label can be dragged to any edge of the screen.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation (Swift Package Manager)](#installation-swift-package-manager)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Looking Up the Current Screen or Session, Without Any UI](#looking-up-the-current-screen-or-session-without-any-ui)
- [Draggable Overlay](#draggable-overlay)
- [Tap to Print the Full Hierarchy](#tap-to-print-the-full-hierarchy)
- [Dark & Light Mode](#dark--light-mode)
- [How It Works](#how-it-works)
- [Console Output](#console-output)
- [Disabling](#disabling)
- [License](#license)

## Features

- 📱 **Real-time screen name overlay** — floating pill label shows the active screen's name
- 🔄 **Auto-detection (UIKit)** — uses method swizzling on `viewDidAppear` / `viewDidDisappear`, no manual calls needed
- 🧩 **SwiftUI support** — a `.screenOverlayTrack("ScreenName")` view modifier tracks screens that live entirely inside SwiftUI navigation
- 🌳 **Full hierarchy on every screen change** — the complete hierarchy (nav stack, tab bar, modal chain) prints to the console automatically on every navigation; tap the label to print it on demand too
- 🧵 **Session history with full paths** — every screen visited during the current (and previous) session is recorded as a full breadcrumb path, queryable any time — no UI needed
- 🫥 **Passthrough touches** — the overlay never blocks your app's own interactions; only the pill itself is interactive
- ⚡ **Simple setup** — call `ScreenOverlay.enable()` once inside your app's `#if DEBUG` block
- 🌗 **Dark & light mode support** — overlay automatically adapts to system appearance
- 🖐️ **Draggable overlay** — optionally drag the label anywhere on screen, snaps to the nearest edge
- 🔔 **Stays visible above alerts** — the overlay window renders above system alerts and action sheets, so it's never hidden behind them
- 🌉 **Swift, SwiftUI & Objective-C** — `ScreenOverlay` is a plain `NSObject` subclass with explicit `@objc` entry points, so it's usable from all three

## Requirements

| Minimum | |
|---|---|
| iOS | 13.0+ |
| Swift tools version | 5.9 |
| Xcode | 15.0+ |

## Installation (Swift Package Manager)

**Option A — Xcode (recommended):**

1. In Xcode, go to **File → Add Package Dependencies…**
2. Paste the repository URL:
   ```
   https://github.com/KalpeshKalsariya/ScreenOverlayKit
   ```
3. For the version rule, choose **Up to Next Major Version**, starting from `1.0.0`
4. Add `ScreenOverlayKit` to your **app target** (not a framework/watch/extension target)
5. Click **Add Package** — Xcode fetches and links it automatically

**Option B — edit `Package.swift` by hand:**

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

Then run `swift package resolve` (or just build — Xcode/SPM resolves it automatically).

That's the whole install — no CocoaPods, no Carthage, no extra build phases, no `GoogleService-Info.plist`-style setup files. Once it's added, `import ScreenOverlayKit` works in any file in your app target.

ScreenOverlayKit targets Swift tools version 5.9 (Xcode 15.0+), so it doesn't require the latest Xcode release to add or build.

## Quick Start

The fastest way to see it working, in a UIKit app:

```swift
import ScreenOverlayKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        #if DEBUG
        ScreenOverlay.enable()
        #endif
        return true
    }
}
```

Build and run. You'll see a small pill label appear at the top of the screen showing the name of whatever screen is currently visible — it updates automatically as you navigate, no further code needed.

- Building a **SwiftUI** app, need **Objective-C**, or want the draggable/session-tracking options? See [Usage](#usage) below for the full walkthrough of each.

## Usage

> **Important:** ScreenOverlayKit is a debug tool. Always wrap `ScreenOverlay.enable()` in `#if DEBUG` in your app target. If you call it from a Release build, the overlay will appear for your users.

`ScreenOverlay.enable()` takes two optional parameters:

| Parameter | Default | Description |
|---|---|---|
| `draggable` | `false` | Lets you drag the overlay anywhere on screen; snaps to the nearest edge on release |
| `trackScreenDuration` | `false` | Records how long each screen stayed on top — printed to the console as the user navigates away, and stored alongside its session path (see `currentSessionPaths`) |

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
[ScreenOverlay enable];                                                // draggable: NO, trackScreenDuration: NO
[ScreenOverlay enableWithDraggable:YES trackScreenDuration:NO];        // customize both options
#endif

// Later:
[ScreenOverlay disable];
```

### Custom Tab Bars & Containers

ScreenOverlayKit's automatic detection can see through `UINavigationController` (`visibleViewController`) and `UITabBarController` (`selectedViewController`) on its own. If your app uses a **custom** tab bar or container view controller built with child view controller containment instead of `UITabBarController`, it's a dead end for that walk by default — the overlay, the tap-to-print hierarchy, and session recording would all report the container itself (e.g. `TabVC`) instead of whichever screen is actually visible inside it.

Conform your container to `ScreenOverlayContainerViewController` to fix that:

```swift
extension TabVC: ScreenOverlayContainerViewController {
    var screenOverlayVisibleChildViewController: UIViewController? {
        arrayNavigationVC.indices.contains(selectedIndex) ? arrayNavigationVC[selectedIndex] : nil
    }
}
```

That's the only change needed — once `TabVC` conforms, the label, hierarchy printout, `currentHierarchyPath()`, and session paths all resolve through it to whichever child is actually on screen.

## Looking Up the Current Screen or Session, Without Any UI

ScreenOverlayKit has no bottom-sheet UI to open — every one of these is a plain call you can make from anywhere in your code, at any time:

```swift
// The most recently tracked screen name (UIKit or SwiftUI) — nil until enable() has recorded one.
ScreenOverlay.currentScreenName

// A single-line breadcrumb of the live UIKit hierarchy, e.g.
// "AppRootViewController → UITabBarController → ProfileViewController"
ScreenOverlay.currentHierarchyPath()

// Every full path recorded so far in the current session, oldest first.
ScreenOverlay.currentSessionPaths

// Every full path recorded during the previous app session (persisted across launches).
ScreenOverlay.previousSessionPaths
```

From Objective-C:

```objc
NSString *screenName = [ScreenOverlay currentScreenName];
NSString *hierarchyPath = [ScreenOverlay currentHierarchyPath];
NSArray<NSString *> *currentSessionPaths = [ScreenOverlay currentSessionPaths];
```

`currentScreenName` reflects whatever the session last recorded, so it also picks up screens tracked manually via `.screenOverlayTrack(_:)` in SwiftUI. `currentHierarchyPath()` walks the live `UIViewController` hierarchy the same way `printHierarchy` does, so — like the rest of ScreenOverlayKit's automatic detection — it only sees UIKit containers, not SwiftUI-internal navigation. Session paths recorded from `.screenOverlayTrack(_:)` work around this by appending the SwiftUI screen name to the live UIKit path at the moment it appeared.

## Draggable Overlay

By default the overlay is fixed at the top center, respecting the safe area. Pass `draggable: true` to let you drag it anywhere on screen. It snaps to the nearest edge when released.

```swift
#if DEBUG
ScreenOverlay.enable(draggable: true)
#endif
```

## Tap to Print the Full Hierarchy

The full hierarchy — navigation stack, tab selection, and modal presentation chain — is printed to the Xcode console automatically on every screen change (see [Console Output](#console-output) below). Tapping the overlay label prints the exact same block on demand, without waiting for a navigation to trigger it — handy when you just want to check the current hierarchy without moving anywhere.

For a simple app — just a `UINavigationController` with one screen — it looks like this:

```
==========================
📡 ScreenOverlayKit Hierarchy
==========================

↳ UINavigationController
   Navigation Stack:
   • ViewController
   Visible:
   ↳ ViewController

==========================
```

For a deeper hierarchy — a tab bar, a nested navigation stack, and a presented modal — every level is printed the same way, just nested further:

```
==========================
📡 ScreenOverlayKit Hierarchy
==========================

↳ AppRootViewController
   Selected Tab:
   ↳ UITabBarController
      Navigation Stack:
      • HomeViewController
      • ProfileViewController
      Visible:
      ↳ ProfileViewController
         Presented:
         ↳ EditProfileViewController

==========================
```

If you want the current screen/hierarchy programmatically instead — without tapping anything — see [Looking Up the Current Screen or Session, Without Any UI](#looking-up-the-current-screen-or-session-without-any-ui) further up.

## Dark & Light Mode

The overlay automatically adapts to the system appearance — no extra setup needed.

| Light Mode | Dark Mode |
|---|---|
| Dark background, white text | White background, dark text |

Make sure `UIUserInterfaceStyle` is not forced in your Info.plist, otherwise the system appearance change will have no effect.

## How It Works

| Component | Responsibility |
|---|---|
| `ScreenOverlay` | Public entry point (`enable()` / `disable()` / session lookups) |
| `ScreenOverlayContainerViewController` | Protocol for custom tab bars/containers to expose their visible child to the hierarchy walk |
| `UIViewController+Swizzling` | Hooks into `viewDidAppear` & `viewDidDisappear` via Objective-C runtime swizzling |
| `View+ScreenOverlayTracking` | SwiftUI `.screenOverlayTrack(_:)` view modifier for screens with no backing `UIViewController` |
| `ViewControllerTracker` | Resolves the topmost visible VC from the window hierarchy; builds the hierarchy breadcrumb |
| `SessionRecorder` | Records the current/previous session's full screen paths |
| `SessionPathEntry` | One recorded screen visit: its full breadcrumb path, timestamp, and optional duration |
| `OverlayManager` | Creates the `PassthroughWindow` above system alerts and drives the pill label's position/drag/tap behavior |
| `OverlayLabel` | The pill label itself — owns its light/dark-mode styling and padded-text layout |
| `PassthroughWindow` | Overrides `hitTest` so touches fall through to the app beneath, except on the pill itself |

### Folder Structure

```
Sources/ScreenOverlayKit
│
├── Public
│   ├── ScreenOverlay.swift              — enable()/disable()/session lookups
│   └── ScreenOverlayContainerViewController.swift — protocol for custom tab bars/containers
│
├── Overlay
│   ├── OverlayManager.swift             — window lifecycle, dragging, positioning, tap handling
│   ├── OverlayLabel.swift               — the pill label's styling & sizing
│   └── PassthroughWindow.swift          — the UIWindow that lets touches fall through
│
├── Tracker
│   └── ViewControllerTracker.swift      — resolves the top-most VC, builds the hierarchy breadcrumb
│
├── Session
│   ├── SessionPathEntry.swift           — one recorded screen visit (full path, timestamp, duration)
│   └── SessionRecorder.swift            — records/persists the current & previous session's paths
│
├── Swizzling
│   └── UIViewController+Swizzling.swift — hooks viewDidAppear/viewDidDisappear
│
└── Extensions
    └── View+ScreenOverlayTracking.swift — SwiftUI `.screenOverlayTrack(_:)` modifier
```

## Console Output

Every line ScreenOverlayKit can print, grouped by when it happens — this is the complete list, not a trimmed sample.

**On `enable()` / `disable()`:**

```
🚀 ScreenOverlayKit enabled
🛑 ScreenOverlayKit disabled
```

**On every screen change (automatic — no setup beyond `enable()`):** the screen name, followed immediately by the full hierarchy — the same block you get from tapping the overlay label, printed automatically every time so you never have to tap just to see context:

```
📱 ScreenOverlay → ViewController
==========================
📡 ScreenOverlayKit Hierarchy
==========================

↳ UINavigationController
   Navigation Stack:
   • ViewController
   Visible:
   ↳ ViewController

==========================
```

See [Tap to Print the Full Hierarchy](#tap-to-print-the-full-hierarchy) above for what this looks like with a tab bar, nested navigation, and a presented modal.

**With `trackScreenDuration: true`, printed the moment the user navigates away from a screen** — including where they went:

```
⏱️ ScreenOverlay → HomeViewController stayed 4s -> ProfileViewController
```

**If something's misconfigured:**

```
❌ ScreenOverlayKit: No UIWindowScene found
```

This means `ScreenOverlay.enable()` ran before any `UIWindowScene` was connected — most commonly, calling it from a SwiftUI `App.init()` instead of `.onAppear` (see the [SwiftUI](#swiftui) section above), or too early in a custom `AppDelegate`/`SceneDelegate` flow. The overlay silently fails to appear when this happens; move the `enable()` call later in the launch sequence.

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
