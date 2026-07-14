# ESC Exit Surface Flow

## Overview

ESC exits surfaces through two paths, both ending at `pill.close_surface()` in `Pill.qml`.

---

## 1. Global Catch-All — `shell.qml:65-69`

A `FocusScope` wraps the entire shell window. When **any** surface is open (`pill.is_surface` is true), it grabs focus and handles ESC directly:

```qml
FocusScope {
  anchors.fill: parent
  focus: pill.is_surface
  Keys.onEscapePressed: pill.close_surface()
}
```

This is the **primary, top-level** handler — catches ESC regardless of which surface is showing.

---

## 2. Per-Surface Handlers via `request_close()` Signal

Individual surfaces have their **own** `Keys.onEscapePressed` inside internal focus scopes, which emit the `request_close()` signal defined in `PillSurface.qml:20`.

| File              | Line | What it does                                                        |
| ----------------- | ---- | ------------------------------------------------------------------- |
| `Launcher.qml`    | 331  | If in `web_prompt_mode`, exits that mode first; otherwise `request_close()` |
| `Clipboard.qml`   | 318  | Calls `request_close()` directly                                    |
| `Tray.qml`        | 257  | Sets `menu.open = false` (closes tray menu, not a Pill surface)     |
| `Popup.qml`       | 340  | Exits `reply_mode` on notification popup                            |

These `request_close()` signals are wired in `Pill.qml:489-495`:

```qml
Launcher {  onRequest_close: pill.close_surface() }
Clipboard { onRequest_close: pill.close_surface() }
```

---

## 3. The Close Logic — `Pill.qml:44-56`

```qml
function close_surface() {
    active_surface = Pill.Surfaces.None;  // ← exits the surface
    if (surface_opened_from_idle) {       // reset hover/latch state
        hovering = false;
        _latched = false;
        pinned = false;
        suppress_hover = true;
        _grace_timer.stop();
    }
    surface_opened_from_idle = false;
}
```

Setting `active_surface = Pill.Surfaces.None` makes `is_surface` false, which causes the surface's `open` binding to become false → triggers the fade-out animation in `PillSurface`.

---

## Summary

ESC is caught either by the **global FocusScope** in `shell.qml` or by the **surface's own focused widget** (search field, list, etc.). Both paths call `pill.close_surface()` which sets `active_surface` to `None`.
