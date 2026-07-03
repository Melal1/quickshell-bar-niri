# Quickshell2 Architecture Analysis

## 1. Executive Summary & Core Infrastructure
Quickshell2 is a highly customized, performance-focused desktop shell built using QML and the Quickshell framework. The design mandate is to deliver a smooth 60FPS experience without the overhead of constantly creating and destroying X11/Wayland surfaces.

**The Dual-Window Pattern (`shell.qml`)**
Instead of spawning individual windows per applet, the entire shell operates across two layers defined in `shell.qml`:
1.  **Reserve Layer:** A 1px-tall invisible zone at the top of the screen that pushes standard windows down.
2.  **Overlay Layer:** A full-screen transparent window that handles all rendering.

To prevent the transparent overlay from swallowing global mouse clicks, `shell.qml` calculates an `inputRegion` bounding box around the active pill surface and explicitly masks input. 

**State Management & IPC**
Global state is decoupled from the UI. Data fetching (e.g., system stats, notifications, clipboard) happens in independent `Singletons/` that the UI binds to reactively. Commands from Hyprland are routed through a central `IpcHandler` which triggers UI state changes (e.g., showing the audio mixer on volume change).

---

## 2. The Morphing Pill (`Pill.qml`)
Rather than distinct panels, the UI is centralized into a top-center "Pill." 

**Morphing Math**
The pill maintains a map of `surfaces` to geometry functions. When the active mode changes, it animates `targetWidth` and `targetHeight`. The active surface only begins to fade in when `morphCloseness` approaches 1.0, ensuring the geometry roughly matches the content before rendering.

**The "Ame" Focus Bead**
The visual soul of the pill is `Ame`—a glowing bead that glides between interactive elements. Surfaces expose an `ameForm` and `amePoint`. For example, in the launcher it docks to the text cursor; in the system monitor, it docks perfectly over a kanji glyph. 

---

## 3. Emphasized Surfaces: Launcher & Clipboard

The **Launcher (`Launcher.qml`)** and **Clipboard (`Clipboard.qml`)** represent the primary text-driven utilities in the shell. They share sophisticated input-handling logic.

### **The Application Launcher (`Launcher.qml`)**
The launcher acts as a search field over a ranked application list. It introduces complex ranking and state persistence:
*   **Fuzzy Ranking & Frequency:** The `allEntries` list is fed into a custom `Fuzzy.rank()` function (`lib/fuzzy.js`). Crucially, ranking isn't just string-matching. A `usageStore` (`FileView`) asynchronously reads/writes to `~/.local/state/ricelin/launcher-usage.json` to track how many times an app is launched, heavily biasing the fuzzy search towards frequently used apps.
*   **Keyboard vs. Mouse Heuristics:** A common UI bug occurs when keyboard-scrolling causes rows to slide under a stationary mouse cursor, re-triggering hover events and stealing focus. The launcher tracks `lastPointer` in window coordinates. It ignores hover events if the absolute mouse position hasn't actually moved, preserving keyboard dominance.

```qml
// Launcher.qml: Preventing hover-stealing during scroll
onPositionChanged: (m) => {
    var g = rowArea.mapToItem(null, m.x, m.y);
    if (g.x !== root.lastPointer.x || g.y !== root.lastPointer.y) {
        root.lastPointer = Qt.point(g.x, g.y); // Only update if physically moved
        root.selectedIndex = appRow.index;
    }
}
```

### **The Clipboard Manager (`Clipboard.qml`)**
The clipboard acts as a front-end to a background `cliphist` daemon (via the `Cliphist` singleton).
*   **Image Previews:** If a clipboard entry is an image (`entry.isImage`), the QML delegates switch layout to load a cached `entry.thumb` asynchronously into a rounded tile.
*   **Heat-Hold Wipe Mechanic:** Wiping the clipboard isn't a simple button click. It uses a custom `HeatHold` mechanic. Holding the "掃" (Sweep) button fills a `GradientStop` along the top divider bar. Releasing early cancels it; holding it to completion purges the history.

---

## 4. Notification Center & Connectivity (`Link.qml`)
`Link.qml` merges quick-toggles (Wi-Fi, Bluetooth) and notifications into an "INBOX".

*   **Subview Routing:** It acts as a micro-router with a `subview` property, allowing users to drill into a Wi-Fi or Bluetooth page without spawning a new surface.
*   **Notification Coalescing (`Singletons/Notifs.qml`):** The `Notifs` singleton intercepts the raw Quickshell `NotificationServer`. It aggressively coalesces notifications from the same app (generating a `count` badge) and surfaces `critical` alerts to the top. `Link.qml` binds to `Notifs.groups` to render the structured inbox.

---

## 5. Media & System Monitor (Complex Canvas Logic)
`Media.qml` and `SysmonSurface.qml` bypass standard QML primitives in favor of mathematically intense `Canvas` rendering.

*   **System Monitor (`SysmonSurface.qml`):** Hardware loads are drawn as 270-degree "flame dials." The rendering script calculates a perfect diagonal linear gradient across the stroke (` Theme.vermBurn` to `Theme.vermLit`) to simulate a rising flame relative to the CPU/GPU load. Polling the daemon is strictly gated to `Sysmon.open = active` to save battery.
*   **Media Surface (`Media.qml`):** The progress bar is a painted brush stroke. The `waveY(u)` function applies a damping sine wave math `(height / 2 - 2.6 * Math.sin(...) * Math.exp(...))` to the stroke's spine so it wavers wildly at the start and settles. The `Ame` bead docks directly to the head of this canvas stroke.

