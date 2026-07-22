<div align="center">
<pre>
 ██████╗ ██████╗ ███████╗███╗   ██╗███████╗ ██████╗  ██████╗██╗   ██╗███████╗
██╔═══██╗██╔══██╗██╔════╝████╗  ██║██╔════╝██╔═══██╗██╔════╝██║   ██║██╔════╝
██║   ██║██████╔╝█████╗  ██╔██╗ ██║█████╗  ██║   ██║██║     ██║   ██║███████╗
██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║██╔══╝  ██║   ██║██║     ██║   ██║╚════██║
╚██████╔╝██║     ███████╗██║ ╚████║██║     ╚██████╔╝╚██████╗╚██████╔╝███████║
 ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝╚═╝      ╚═════╝  ╚═════╝ ╚═════╝ ╚══════╝
</pre>

**Focus on the Big 5 things that matter today.**

![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift&logoColor=white)
![Platform](https://img.shields.io/badge/macOS-13%2B-lightgrey?logo=apple&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-native-blue)
![License](https://img.shields.io/badge/license-MIT-black)

<img src="assets/icon-hero.png" width="180" alt="OpenFocus icon">

</div>

---

A tiny macOS focus timer that lives inside your notch. Enter up to 5 tasks, hit start, and the notch takes over — current task, countdown, nothing else. Click it to complete. Confetti.

<div align="center">

<img src="assets/screenshots/input-filled.png" alt="Input mode with 5 tasks" width="900">

<sub>Input mode — Big 5 for the day</sub>

<img src="assets/screenshots/active.png" alt="Active timer under the notch" width="900">

<sub>Active mode — current task + countdown, in the notch</sub>

</div>

## Install

**Download the DMG** from the [latest release](https://github.com/fillsoko/open-focus/releases/latest), drag `OpenFocus.app` to `Applications`, launch.

Or build from source:

```bash
git clone https://github.com/fillsoko/open-focus.git
cd open-focus
./scripts/build_app.sh   # produces dist/OpenFocus.app
```

Requires Xcode command-line tools.

## Use

- **Start Focus** in the menu bar → drop-down opens under your notch.
- Type up to 5 tasks. `Tab` into the time chips, `← →` to pick `5 / 10 / 15 / 30 / 60`, or just type a number (`1` → `10`, `1` `5` → `15`).
- `↑ ↓` in text fields jump between rows.
- `⌘ ↩` to start. The notch becomes your timer.
- **Click the notch** to complete the current task. Confetti falls at your cursor.
- **Stop Focus** in the menu bar to end early.
- **Launch at Login** and **Check for Updates…** in the menu bar.

## Built with

- Swift 5.9 · SwiftUI · AppKit
- `NSPanel` overlay pinned to the built-in display's notch
- `SMAppService` for launch-at-login
- No third-party dependencies

## License

MIT
