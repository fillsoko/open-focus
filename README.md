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

</div>

---

A tiny macOS focus timer that lives inside your notch. Enter up to 5 tasks, hit start, and the notch takes over — current task, countdown, nothing else. Click the ✓ to complete. Confetti cannon fires from your cursor.

<div align="center">

<img src="assets/screenshots/input-filled.png" alt="Input mode with 5 tasks" width="900">

<sub>Input mode — Big 5 for the day</sub>

<img src="assets/screenshots/active.png" alt="Active timer under the notch" width="900">

<sub>Active mode — current task + countdown, in the notch</sub>

<img src="assets/screenshots/confetti.png" alt="Confetti cannon from cursor" width="900">

<sub>Done — confetti cannon fires from your cursor</sub>

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

- **Start Focus** in the menu bar → drop-down opens under your notch. Row 1 is auto-focused.
- **Type**, then **Tab** or `→` (at end of text) to jump to time chips. `← →` cycle `5 / 10 / 15 / 30 / 60`, or just type a number (`1` → `10`, then `5` → `15`).
- **Enter in text** → time chip of same row.
  **Enter on time chip** → confirms and moves to next row.
  **Enter on row 5 time chip** → starts the session.
- **↑ ↓** move between rows in text or time.
- The currently focused time selection **pulses** so you always know where you are.
- Click **✓** in the notch to complete — a **confetti cannon fires from your cursor for 2.5 seconds**, following you if you move.
- **Stop Focus** in the menu bar to end early. **Launch at Login** and **Check for Updates…** live there too.

## Built with

- Swift 5.9 · SwiftUI · AppKit
- `NSPanel` overlay pinned above the built-in display's notch
- `SMAppService` for launch-at-login
- No third-party dependencies

## License

MIT
