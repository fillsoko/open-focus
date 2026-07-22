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

A tiny macOS focus timer that lives inside your notch. Enter up to 5 tasks, hit start, and the notch takes over — current task, countdown, nothing else. Click it to complete. Confetti.

## Install

```bash
git clone https://github.com/fillsoko/open-focus.git
cd open-focus
./run.sh
```

Requires Xcode command-line tools.

## Use

- **Start Focus** in the menu bar → drop-down opens under your notch.
- Type up to 5 tasks. `Tab` into the time chips, `← →` to pick `5 / 10 / 15 / 30 / 60`.
- `⌘ ↩` to start. The notch becomes your timer.
- **Click the notch** to complete the current task.
- **Stop Focus** in the menu bar to end early.

## Built with

- Swift 5.9 · SwiftUI · AppKit
- `NSPanel` overlay pinned to the built-in display's notch
- No third-party dependencies

## License

MIT
