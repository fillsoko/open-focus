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

Click **Start Focus** in the menu bar. Type your tasks and start.

- **Tab** — text field → time chips → next row
- **Enter** — text field → time chips → next row → start session (on row 5)
- **↑ ↓** — move between rows
- **← →** — pick time; number keys work too

Click **✓** in the notch to complete a task. **Stop Focus** in the menu bar to end early.

## Built with

- Swift 5.9 · SwiftUI · AppKit
- `NSPanel` overlay pinned above the built-in display's notch
- `SMAppService` for launch-at-login
- No third-party dependencies

## License

MIT
