<div align="center">

# ScreenOverlayKit

A lightweight debug tool for iOS developers to instantly see which screen they're on while testing their app — plus a separate, production-ready guard against screenshots, screen recording, and shoulder-surfing.

</div>

---

<div align="center">

https://github.com/user-attachments/assets/94611da2-581f-4ceb-96f1-ed5e4431c991

</div>


The overlay label updates automatically as you move from screen to screen — no manual calls needed. Tapping the label prints the full view-controller hierarchy (nav stack → tab → modal chain) to the console, and the label can be dragged to any edge of the screen.

ScreenOverlayKit also ships `ScreenCaptureGuard`, a separate, production-safe feature that detects screenshots, screen recording/mirroring, and app backgrounding, and automatically blurs any screen you mark as sensitive.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation (Swift Package Manager)](#installation-swift-package-manager)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Analytics and Firebase Logging](#analytics-and-firebase-logging)
- [Capture Protection](#capture-protection)
- [Draggable Overlay](#draggable-overlay)
- [Tap to Print the Full Hierarchy](#tap-to-print-the-full-hierarchy)
- [Dark & Light Mode](#dark--light-mode)
- [How It Works](#how-it-works)
- [Console Output](#console-output)
- [Disabling](#disabling)
- [License](#license)

## Features

**Debug overlay** (`ScreenOverlay`, wrap in `#if DEBUG`):
- 📱 **Real-time screen name overlay** — floating pill label shows the active screen's name
- 🔄 **Auto-detection (UIKit)** — uses method swizzling on `viewDidAppear` / `viewDidDisappear`, no manual calls needed
- 🧩 **SwiftUI support** — a `.screenOverlayTrack("ScreenName")` view modifier tracks screens that live entirely inside SwiftUI navigation
- 👆 **Tap to print the hierarchy** — tap the label to print the complete hierarchy (nav stack, tab bar, modal chain) to the console
- 🧵 **Session history with full paths** — every screen visited during the current (and previous) session is recorded as a full breadcrumb path, queryable any time — no UI needed
- 📊 **Analytics hook** — implement `ScreenOverlayEventLogger` to forward every screen view (and any custom event you log) to Firebase Analytics or any other backend
- 🫥 **Passthrough touches** — the overlay never blocks your app's own interactions; only the pill itself is interactive
- ⚡ **Simple setup** — call `ScreenOverlay.enable()` once inside your app's `#if DEBUG` block
- 🌗 **Dark & light mode support** — overlay automatically adapts to system appearance
- 🖐️ **Draggable overlay** — optionally drag the label anywhere on screen, snaps to the nearest edge
- 🔔 **Stays visible above alerts** — the overlay window renders above system alerts and action sheets, so it's never hidden behind them

**Capture protection** (`ScreenCaptureGuard`, production-ready — not debug-only):
- 📸 **Screenshot detection** — reacts after the fact (iOS has no API to block a screenshot before it's saved)
- 🔴 **Screen recording / mirroring detection** — reacts for the entire duration `UIScreen.isCaptured` is `true` (recording, AirPlay, external displays)
- 🕶️ **App Switcher protection** — blurs sensitive screens the instant the app resigns active, before the system snapshot is taken
- 🫧 **Blur sensitive screens only** — opt in per-screen with `markScreenAsSensitiveOverlay()` (UIKit) or `.sensitiveScreenOverlay()` (SwiftUI); everything else is left alone

**Both work from Swift, SwiftUI, and Objective-C** — `ScreenOverlay` and `ScreenCaptureGuard` are `NSObject` subclasses with explicit `@objc` entry points.

## Requirements

| Minimum | |
|---|---|
| iOS | 13.0+ |
| Swift tools version | 6.3 (Swift 6 language mode) |
| Xcode | Toolchain with Swift 6.3 support |

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

- Building a **SwiftUI** app, need **Objective-C**, or want the draggable/session/analytics options? See [Usage](#usage) below for the full walkthrough of each.
- Want to protect sensitive screens from screenshots and screen recording (works in production, not just debug builds)? See [Capture Protection](#capture-protection).

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

## Analytics and Firebase Logging

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

### Looking Up the Current Screen or Session, Without Any UI

ScreenOverlayKit has no bottom-sheet UI to open — every one of these is a plain call you can make from anywhere in your code, at any time, to grab context for a Firebase event:

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

```swift
Analytics.logEvent("checkout_started", parameters: [
    AnalyticsParameterScreenName: ScreenOverlay.currentScreenName ?? "Unknown",
    "hierarchy_path": ScreenOverlay.currentHierarchyPath()
])
```

From Objective-C:

```objc
NSString *screenName = [ScreenOverlay currentScreenName];
NSString *hierarchyPath = [ScreenOverlay currentHierarchyPath];
NSArray<NSString *> *currentSessionPaths = [ScreenOverlay currentSessionPaths];
```

`currentScreenName` reflects whatever the session last recorded, so it also picks up screens tracked manually via `.screenOverlayTrack(_:)` in SwiftUI. `currentHierarchyPath()` walks the live `UIViewController` hierarchy the same way `printHierarchy` does, so — like the rest of ScreenOverlayKit's automatic detection — it only sees UIKit containers, not SwiftUI-internal navigation. Session paths recorded from `.screenOverlayTrack(_:)` work around this by appending the SwiftUI screen name to the live UIKit path at the moment it appeared.

## Capture Protection

`ScreenCaptureGuard` is a **separate, production-ready** feature — unlike `ScreenOverlay`, it's not a debug tool and isn't meant to be wrapped in `#if DEBUG`. It detects screenshots, screen recording/mirroring, and app backgrounding, and automatically blurs any screen you've explicitly marked as sensitive.

> **Why per-screen, not the whole app?** Blurring every screen on every backgrounding is jarring and usually unnecessary. Mark only the screens that actually show sensitive data — a payment form, an ID card, a balance — the same way banking and health apps do it.

### Start Monitoring

Call this once, unconditionally, at launch:

```swift
import ScreenOverlayKit

// AppDelegate / SceneDelegate / SwiftUI App.init() — no #if DEBUG.
ScreenCaptureGuard.shared.startMonitoring()
```

From Objective-C:

```objc
[[ScreenCaptureGuard shared] startMonitoring];
```

### Mark a Screen as Sensitive

**UIKit:**

```swift
final class PaymentViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        markScreenAsSensitiveOverlay()
    }
}
```

**SwiftUI:**

```swift
struct CardNumberView: View {
    var body: some View {
        Text("4242 4242 4242 4242")
            .sensitiveScreenOverlay()
    }
}
```

**Objective-C:**

```objc
- (void)viewDidLoad {
    [super viewDidLoad];
    [self markScreenAsSensitiveOverlay];
}
```

### What Triggers the Blur

| Trigger | Behavior |
|---|---|
| App resigns active / App Switcher | Blurs instantly, before the system takes the snapshot — the only trigger that's fully preventable |
| Screen recording / mirroring (`UIScreen.isCaptured`) | Blurs for the entire duration the screen is being recorded or mirrored (AirPlay, external displays) |
| Screenshot taken | Briefly flashes the blur. iOS has no API to block or intercept a screenshot before it's saved — this only reacts after the fact |

### Reacting to Events (optional)

For anything beyond automatic blurring — an in-app warning, custom analytics, disabling a feature — adopt `ScreenCaptureGuardDelegate`:

```swift
final class SecurityHandler: NSObject, ScreenCaptureGuardDelegate {
    func screenCaptureGuardDidDetectScreenshot() {
        print("User took a screenshot")
    }

    func screenCaptureGuard(didChangeCaptureState isCaptured: Bool) {
        print(isCaptured ? "Recording/mirroring started" : "Recording/mirroring stopped")
    }
}

let securityHandler = SecurityHandler() // keep a strong reference — delegate is held weakly
ScreenCaptureGuard.shared.delegate = securityHandler
```

Both events are also automatically forwarded to `ScreenOverlay.eventLogger` (see [Analytics and Firebase Logging](#analytics-and-firebase-logging) above) as `"screenshot_taken"`, `"screen_recording_started"`, and `"screen_recording_ended"` — no extra wiring needed to get these into Firebase.

## Draggable Overlay

By default the overlay is fixed at the top center, respecting the safe area. Pass `draggable: true` to let you drag it anywhere on screen. It snaps to the nearest edge when released.

```swift
#if DEBUG
ScreenOverlay.enable(draggable: true)
#endif
```

## Tap to Print the Full Hierarchy

Tap the overlay label to print the complete hierarchy for whatever's currently visible — navigation stack, tab selection, and modal presentation chain — to the Xcode console.

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
| `ScreenOverlay` | Public entry point for the debug overlay (`enable()` / `disable()` / `logEvent(name:parameters:)` / `eventLogger` / session lookups) |
| `ScreenOverlayEventLogger` | Protocol you implement to forward screen views & custom events to Firebase or any analytics backend |
| `UIViewController+Swizzling` | Hooks into `viewDidAppear` & `viewDidDisappear` via Objective-C runtime swizzling |
| `View+ScreenOverlayTracking` | SwiftUI `.screenOverlayTrack(_:)` view modifier for screens with no backing `UIViewController` |
| `ViewControllerTracker` | Resolves the topmost visible VC from the window hierarchy; builds the hierarchy breadcrumb |
| `SessionRecorder` | Records the current/previous session's full screen paths and notifies `ScreenOverlay.eventLogger` |
| `SessionPathEntry` | One recorded screen visit: its full breadcrumb path, timestamp, and optional duration |
| `OverlayManager` | Creates the `PassthroughWindow` above system alerts and drives the pill label's position/drag/tap behavior |
| `OverlayLabel` | The pill label itself — owns its light/dark-mode styling and padded-text layout |
| `PassthroughWindow` | Overrides `hitTest` so touches fall through to the app beneath, except on the pill itself |
| `ScreenCaptureGuard` | Public entry point for capture protection (`startMonitoring()` / `stopMonitoring()` / `delegate` / `isBlurring`) — production-ready, independent of `ScreenOverlay` |
| `ScreenCaptureGuardDelegate` | Optional protocol notified of screenshot / recording / mirroring events |
| `SensitiveScreenRegistry` | Tracks every UIKit view marked sensitive and shows/hides its `BlurOverlayView` on command |
| `BlurOverlayView` | The `UIVisualEffectView` blur placed over a sensitive UIKit view |
| `UIViewController+SensitiveScreen` | `markScreenAsSensitiveOverlay()` / `unmarkScreenAsSensitiveOverlay()` for UIKit |
| `View+SensitiveScreenOverlay` | SwiftUI `.sensitiveScreenOverlay()` modifier, driven by `ScreenCaptureGuard`'s published `isBlurring` state |

### Folder Structure

```
Sources/ScreenOverlayKit
│
├── Public
│   ├── ScreenOverlay.swift              — enable()/disable()/logEvent()/eventLogger/session lookups
│   └── ScreenOverlayEventLogger.swift   — analytics-forwarding protocol
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
├── Security
│   ├── ScreenCaptureGuard.swift              — production entry point: startMonitoring()/delegate/isBlurring
│   ├── ScreenCaptureGuardDelegate.swift      — optional screenshot/recording notification protocol
│   ├── SensitiveScreenRegistry.swift         — tracks sensitive UIKit views, shows/hides their blur
│   ├── BlurOverlayView.swift                 — the UIVisualEffectView blur itself
│   ├── UIViewController+SensitiveScreen.swift — markScreenAsSensitiveOverlay() for UIKit
│   └── View+SensitiveScreenOverlay.swift     — .sensitiveScreenOverlay() modifier for SwiftUI
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

**On every screen change (automatic — no setup beyond `enable()`):**

```
📱 ScreenOverlay → HomeViewController
📱 ScreenOverlay → ProfileViewController
```

**With `trackScreenDuration: true`, printed the moment the user navigates away from a screen:**

```
⏱️ ScreenOverlay → HomeViewController stayed 4s
```

**After tapping the overlay label** — see [Tap to Print the Full Hierarchy](#tap-to-print-the-full-hierarchy) above for the full breakdown:

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

**From `ScreenOverlay.logEvent(name:parameters:)`:**

```
🔔 ScreenOverlayKit event → checkout_button_tapped ["cart_items": 3]
```

**From `ScreenCaptureGuard`, once `startMonitoring()` is running:**

```
📸 ScreenOverlayKit: Screenshot detected
🔴 ScreenOverlayKit: Screen recording/mirroring started
⏹️ ScreenOverlayKit: Screen recording/mirroring stopped
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
