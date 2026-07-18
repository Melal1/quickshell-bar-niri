# Bluetooth.qml Explanation

`Bluetooth.qml` is the Bluetooth management surface for this Quickshell setup. It shows the current adapter state, lists known and discovered devices, and lets the user scan, toggle the adapter, pair, connect / disconnect, trust, and unpair any device — all from the keyboard or the mouse.

The data flow is:

```text
Quickshell.Bluetooth
  -> root.adapter / root.devices
  -> root.devices_sorted
  -> ListView (device_list)
  -> dev_item delegate
```

`Quickshell.Bluetooth` is a live service exposed by Quickshell. The surface reads it on the fly — there is no caching or refresh button, the list updates as BlueZ updates its cache.

## File Structure

The file is split into these main parts:

1. Imports and the `PillSurface` root.
2. Live state properties (`adapter`, `devices`, `devices_sorted`, `discovering`).
3. Selection and unpair-hold state (`selected_index`, `unpair_hold_addr`, `unpair_hold_progress`).
4. Open / change handlers.
5. Helper functions (`move_selection`, `activate_selected`, `pair_selected`, `trust_selected`, `unpair_selected`, `start_unpair_hold`, `cancel_unpair_hold`, `meta_for`, `battery_level`, `activate_device`).
6. Timers (scan timer + unpair hold timer).
7. Header (title + adapter toggle).
8. Actions row (Scan + device count).
9. Divider, empty state, and the device `ListView`.
10. The row delegate with tile, name, meta, battery, pairing dot, trust button, unpair button, and pair button.

## Imports

```qml
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
```

- `QtQuick` — basic UI types (`Item`, `Rectangle`, `Text`, `ListView`, `Row`, `Column`, `Timer`).
- `Quickshell` — shell integration.
- `Quickshell.Io` — kept imported for forward-compatibility (the surface previously used `Process` and `StdioCollector` here, before switching to the native Bluetooth API).
- `Quickshell.Bluetooth` — the live Bluetooth service: `Bluetooth.defaultAdapter`, `Bluetooth.devices`, and the `BluetoothDeviceState` enum.

`pragma ComponentBehavior: Bound` makes QML component scoping strict, which keeps delegate code from reaching into parent scopes it did not declare.

## Root Surface

```qml
PillSurface {
  id: root

  focus: true

  m_top: 15
  m_left: 17
  m_right: 17
  m_bottom: 14
```

`PillSurface.qml` defines the shared behaviour for popup surfaces in this config:

- Fills its parent.
- Has margin properties (`m_top`, `m_left`, …).
- Exposes an `active` flag tied to `open`.
- Emits a `request_close()` signal that the host Pill listens to.
- Fades its content in and out while the pill morph animation runs.

`Bluetooth.qml` does not create its own window. It defines what is shown inside the existing pill system, sized to `Settings.bluetooth_w` x `Settings.bluetooth_h` (`460` x `560`).

`focus: true` is required so the surface can receive `Keys.onPressed` events. `onOpenChanged` calls `forceActiveFocus()` when the surface opens to grab the keyboard.

The margins give the content breathing room inside the pill body.

## Live Bluetooth State

```qml
readonly property var adapter:
  (typeof Bluetooth !== "undefined" && Bluetooth) ? Bluetooth.defaultAdapter : null

readonly property var devices:
  (typeof Bluetooth !== "undefined" && Bluetooth && Bluetooth.devices)
    ? Bluetooth.devices.values
    : []
```

These are read-only views into the live service:

- `adapter` is the system's default Bluetooth adapter. It has `enabled`, `discovering`, and other state.
- `devices` is an array of every Bluetooth device BlueZ knows about, paired or not, connected or not. Each device has `address`, `name`, `deviceName`, `connected`, `paired`, `trusted`, `battery`, `batteryAvailable`, `pairing`, `state`, and more.

The `typeof` guards make the file safe to load even if the Bluetooth service is unavailable (for example on a desktop with no Bluetooth hardware).

### devices_sorted

```qml
readonly property var devices_sorted: devices.slice().sort(function(a, b) {
  function rank(d) {
    if (!d) return 3;
    if (d.connected) return 0;
    if (d.paired) return 1;
    return (d.name && d.name.length) ? 2 : 3;
  }
  var r = rank(a) - rank(b);
  if (r !== 0) return r;
  return String((a && a.name) || "").localeCompare(String((b && b.name) || ""));
})
```

BlueZ hands the device cache out in arbitrary order. The surface re-sorts it so the most useful rows are always at the top:

```text
0 — connected devices
1 — paired but not connected
2 — named but unpaired (visible from a previous scan)
3 — nameless MAC addresses (least useful)
```

Within the same rank, devices are sorted alphabetically by name. The list is a `slice().sort(...)` so the underlying `Bluetooth.devices.values` array is not mutated.

Example:

```text
Bluetooth.devices.values = [mac AA:11, "Sony WH-1000XM4", "Pixel Buds"]
After sort:
  "Pixel Buds"        (connected)
  "Sony WH-1000XM4"   (paired)
  mac AA:11           (nameless)
```

### discovering

```qml
readonly property bool discovering: adapter ? adapter.discovering === true : false
```

Reflects whether the adapter is currently scanning. The header actions row reads this to show "Scanning…" instead of "Scan" while active.

## Selection And Unpair-Hold State

```qml
property int selected_index: 0

property string unpair_hold_addr: ""
property real unpair_hold_progress: 0
readonly property bool unpair_holding: unpair_hold_addr.length > 0

readonly property int unpair_hold_ms: 1000
```

- `selected_index` is the keyboard-highlighted device in the list.
- `unpair_hold_addr` is the MAC of the device whose unpair is currently being held. Empty when no hold is in progress.
- `unpair_hold_progress` is `0..1`; when it reaches `1` the unpair fires.
- `unpair_holding` is a convenience read-only flag (`true` while a hold is in progress).
- `unpair_hold_ms` is the total hold duration in milliseconds (`1000` — one second).

## Open And Change Handlers

```qml
onOpenChanged: {
  if (open) {
    selected_index = 0;
    root.forceActiveFocus();
  } else {
    scan_timer.stop();
    cancel_unpair_hold();
    if (adapter && adapter.discovering)
      adapter.discovering = false;
  }
}

onDevicesChanged: {
  selected_index = 0;
  if (unpair_hold_addr.length > 0) {
    var still_there = false;
    for (var i = 0; i < devices.length; i++) {
      if (devices[i] && devices[i].address === unpair_hold_addr) {
        still_there = true;
        break;
      }
    }
    if (!still_there)
      cancel_unpair_hold();
  }
}
```

When the surface opens, the selection resets to the first row and the surface grabs keyboard focus.

When it closes, any in-progress scan is stopped and any unpair hold is cancelled. The adapter's `discovering` flag is also turned off so a scan does not keep running after the user closes the surface.

`onDevicesChanged` resets the selection to the first row whenever the device list changes (for example when a new scan finds a new device). It also checks whether the device currently being held for unpair is still in the list — if it disappeared (e.g. the user used `bluetoothctl` externally), the hold is cancelled.

## Helper Functions

### move_selection

```qml
function move_selection(delta) {
  if (devices_sorted.length === 0)
    return;
  var next = selected_index + delta;
  if (next < 0) next = 0;
  if (next >= devices_sorted.length) next = devices_sorted.length - 1;
  if (next !== selected_index) {
    cancel_unpair_hold();
    selected_index = next;
    device_list.positionViewAtIndex(selected_index, ListView.Contain);
  }
}
```

Moves the keyboard selection by `delta` rows. `delta` is `+1` for down, `-1` for up.

The index is clamped to the valid range so it never goes below `0` or past the last device. If the selection actually changes, any in-progress unpair hold is cancelled (the hold is tied to a specific device, so changing targets aborts the confirmation). `device_list.positionViewAtIndex(selected_index, ListView.Contain)` scrolls the list just enough to keep the highlighted row in view.

### activate_selected

```qml
function activate_selected() {
  if (selected_index < 0 || selected_index >= devices_sorted.length)
    return;
  activate_device(devices_sorted[selected_index]);
}
```

Triggers the same action as clicking a row on the currently highlighted device. Returns silently if the index is out of range (which can happen if the list just emptied out).

### pair_selected

```qml
function pair_selected() {
  if (selected_index < 0 || selected_index >= devices_sorted.length)
    return;
  var d = devices_sorted[selected_index];
  if (d && typeof d.pair === "function")
    d.pair();
}
```

Calls the native `Quickshell.Bluetooth` `pair()` method on the selected device. **Only pairs** — does not trust or connect. For an already-paired device this is a no-op. The keyboard shortcut is Space.

### trust_selected

```qml
function trust_selected() {
  if (selected_index < 0 || selected_index >= devices_sorted.length)
    return;
  var d = devices_sorted[selected_index];
  if (d && d.paired && d.trusted !== undefined)
    d.trusted = !d.trusted;
}
```

Toggles the `trusted` property of the selected device. The property is writable on `BluetoothDevice` per the Quickshell docs, so this is a direct assignment — no shell command, no `Process`. The keyboard shortcut is `t`.

### unpair_selected

```qml
function unpair_selected() {
  if (selected_index < 0 || selected_index >= devices_sorted.length)
    return;
  var d = devices_sorted[selected_index];
  if (d && d.paired && typeof d.forget === "function")
    d.forget();
}
```

Calls the native `forget()` method on the selected device, which is the documented way to unpair a device in Quickshell. The device disappears from `Bluetooth.devices` within ~1s as BlueZ updates.

This is only called from the unpair-hold timer when `unpair_hold_progress` reaches `1` — never directly. Holding `u` for `unpair_hold_ms` (1 second) is the only way to trigger an unpair.

### start_unpair_hold

```qml
function start_unpair_hold() {
  if (unpair_holding)
    return;
  if (selected_index < 0 || selected_index >= devices_sorted.length)
    return;
  var d = devices_sorted[selected_index];
  if (!d || !d.paired)
    return;
  unpair_hold_addr = d.address;
  unpair_hold_progress = 0;
  unpair_hold_timer.restart();
}
```

Begins the hold-to-confirm countdown. Records the device's MAC so the hold stays tied to that device even if the user changes selection mid-hold (the `onDevicesChanged` handler will cancel the hold if the device vanishes from the list). Restarts the `unpair_hold_timer` which ticks every 33ms.

### cancel_unpair_hold

```qml
function cancel_unpair_hold() {
  unpair_hold_timer.stop();
  unpair_hold_addr = "";
  unpair_hold_progress = 0;
}
```

Stops the timer, clears the held MAC, and resets the progress to `0`. Called from:
- `Keys.onEscapePressed` — surface close
- `Keys.onReleased` for `u` — user let go of the unpair key before completion
- `onOpenChanged` when the surface closes
- `onDevicesChanged` when the held device disappears
- `move_selection` when the user changes selection
- All device row click handlers — any click cancels the hold
- All device button click handlers — trust / pair / unpair button clicks cancel the hold
- The unpair `MouseArea`'s `onReleased` and `onCanceled` — mouse equivalents of letting go

### meta_for

```qml
function meta_for(d) {
  if (!d) return "";
  var parts = [];
  if (d.connected) parts.push("connected");
  else if (d.paired) parts.push("paired");
  if (d.paired && d.trusted === true) parts.push("trusted");
  if (d.state !== undefined && typeof BluetoothDeviceState !== "undefined") {
    var st = BluetoothDeviceState.toString(d.state);
    if (st && st.length > 0 && parts.indexOf(st.toLowerCase()) === -1) parts.push(st.toLowerCase());
  }
  return parts.join(" · ");
}
```

Builds the secondary line for a device row. It joins:

- "connected" if the device is currently connected.
- "paired" if it is paired but not connected.
- "trusted" if the device is paired **and** `d.trusted === true`.
- The lowercase name of the current `BluetoothDeviceState` if it adds new info.

Example:

```text
Pixel Buds, connected, trusted, playing
Sony WH-1000XM4, paired, trusted
Random Speaker, paired
Unknown Speaker, paired, connecting
```

### battery_level

```qml
function battery_level(d) {
  if (!d || d.batteryAvailable !== true) return -1;
  var b = d.battery;
  if (b <= 0) return -1;
  if (b <= 1) b = b * 100;
  return Math.round(b);
}
```

Returns the device's battery as a percentage `0..100`, or `-1` if the device does not report a battery.

The first check uses the documented `batteryAvailable` property (true when the device reports a battery) instead of guarding against `undefined` / `null`. The `if (b <= 1) b = b * 100` branch handles the canonical `0.0..1.0` range from the docs; the rest of the function is defensive against stray `0..100` integer values.

### activate_device

```qml
function activate_device(d) {
  if (!d)
    return;
  if (d.connected) {
    if (typeof d.disconnect === "function")
      d.disconnect();
    return;
  }
  if (d.paired) {
    if (typeof d.connect === "function")
      d.connect();
    return;
  }
  if (typeof d.pair === "function")
    d.pair();
}
```

The click-dispatch function for **Enter** and row clicks. Behaviour depends on the device's state:

```text
connected  -> d.disconnect()
paired     -> d.connect()
unpaired   -> d.pair()
```

This is the "smart" activate. It does **not** trust or unpair — those have their own dedicated actions.

## Timers

```qml
Timer {
  id: scan_timer
  interval: 25000
  repeat: false
  onTriggered: if (root.adapter) root.adapter.discovering = false
}
```

`scan_timer` runs for 25 seconds. When it fires, it turns the adapter's `discovering` flag off, so a scan does not run forever.

```qml
Timer {
  id: unpair_hold_timer
  interval: 33
  repeat: true
  triggeredOnStart: true
  onTriggered: {
    if (unpair_hold_addr.length === 0) {
      stop();
      return;
    }
    var next = unpair_hold_progress + 33.0 / root.unpair_hold_ms;
    if (next >= 1) {
      unpair_hold_progress = 1;
      var addr = unpair_hold_addr;
      root.cancel_unpair_hold();
      if (selected_index >= 0 && selected_index < devices_sorted.length) {
        var d = devices_sorted[selected_index];
        if (d && d.paired && d.address === addr && typeof d.forget === "function")
          d.forget();
      }
    } else {
      unpair_hold_progress = next;
    }
  }
}
```

`unpair_hold_timer` drives the unpair hold progress. Every 33ms it advances `unpair_hold_progress` by `33 / unpair_hold_ms` (so 1000ms total hold). When progress reaches 1, the hold fires:

1. The held MAC is captured into a local.
2. The hold state is cleared (so a new hold can start fresh).
3. The current selected device is re-read from `devices_sorted` (it may have changed) and only unpairs if its address still matches the one we were holding.
4. `d.forget()` is called.

The re-check step is important — without it, the hold could fire `forget()` on a different device if the user navigated to a new one mid-hold. (The hold is also cancelled on selection change, so this is a belt-and-suspenders check.)

## Keyboard Controls

The surface is keyboard-first. The handlers live directly on the root `PillSurface`:

```qml
Keys.onEscapePressed: {
  cancel_unpair_hold();
  root.request_close();
}
```

Escape cancels any in-progress hold and emits `request_close`, which the host `Pill` is wired to call `pill.close_surface()`.

```qml
Keys.onPressed: (event) => {
  if (event.modifiers !== Qt.NoModifier || event.isAutoRepeat)
    return;

  if (event.key === Qt.Key_S || event.text === "s" || event.text === "S") { ... }
  if (event.text === "j" || event.text === "J" || event.key === Qt.Key_Down) { ... }
  if (event.text === "k" || event.text === "K" || event.key === Qt.Key_Up) { ... }
  if (event.key === Qt.Key_Space) { ... }
  if (event.key === Qt.Key_T || event.text === "t" || event.text === "T") { ... }
  if (event.text === "u" || event.text === "U") { ... }
  if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { ... }
}

Keys.onReleased: (event) => {
  if (event.isAutoRepeat)
    return;
  if (event.text === "u" || event.text === "U") {
    root.cancel_unpair_hold();
    event.accepted = true;
  }
}
```

The `onPressed` handler accepts only plain keystrokes (`Qt.NoModifier`) and ignores key autorepeat so a held key does not fly through the list.

Key map:

```text
s / S    Toggle scan (same as clicking the Scan label)
j / J    Move selection down
↓        Move selection down
k / K    Move selection up
↑        Move selection up
Space    Pair the selected device (d.pair, no trust, no connect)
t / T    Toggle trust on the selected device (only if paired)
u        Hold to unpair — release before 1s to cancel, hold to fire
Enter    Smart activate: disconnect / connect / pair based on state
Esc      Cancel any hold, close the surface
```

`event.accepted = true` tells QML the surface handled the key, so it does not continue bubbling to the global handler in `shell.qml`.

The `onReleased` handler exists only for `u` — every other key fires its action on press, but `u` needs to know when the user lets go so it can cancel the hold.

## Header

```qml
SurfaceHeader {
  id: header
  ...
  title: "Bluetooth"

  LinkToggle {
    anchors.right: parent.right
    ...
    on: root.adapter ? root.adapter.enabled === true : false
    onToggled: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
  }
}
```

A 24-pixel-tall row at the top of the surface. The title is "BLUETOOTH" (uppercase, letter-spaced) and the `LinkToggle` on the right flips the adapter's `enabled` flag.

## Actions Row

A 40-pixel-tall row directly below the header, separated by 12 pixels of breathing room.

Left side: a "Scan" / "Scanning…" pill button. The label is only visible while the adapter is enabled. While scanning, the border turns vermilion.

Right side: a "X devices" text in 16 pixels, only shown when there is at least one device in the list.

## Divider And Empty State

A single hairline divider between the actions row and the device list.

The empty state shows "Scanning…" while a scan is in progress, and "No devices found" otherwise. It is centered horizontally in the list area, 20 pixels below the divider.

## Device ListView

A vertical `ListView` filling the space between the divider and the surface bottom.

- `clip: true` keeps rows from drawing outside the list area.
- `spacing: 6` adds vertical space between rows.
- `boundsBehavior: Flickable.StopAtBounds` prevents overscroll bounce.
- `model: root.devices_sorted` is the sorted live list.
- `currentIndex: root.selected_index` keeps the ListView's own current index in sync with the keyboard selection.

The list is hidden entirely when there are no devices, so the empty-state text is what the user sees.

### Delegate

Each row is a `dev_item` that holds the device's data, a `dev_row` background rectangle, the icon tile, the name + meta column, and the right-side controls (pairing dot, battery, trust, unpair, pair).

```qml
delegate: Item {
  id: dev_item
  required property var modelData
  required property int index
  width: device_list.width

  readonly property bool is_connected: modelData ? modelData.connected === true : false
  readonly property bool is_paired: modelData ? modelData.paired === true : false
  readonly property bool is_trusted: modelData ? modelData.trusted === true : false
  readonly property string addr: (modelData && modelData.address) ? modelData.address : ""
  readonly property bool pairing: modelData ? modelData.pairing === true : false
  readonly property int battery: root.battery_level(modelData)
  readonly property bool selected: dev_item.index === root.selected_index
  readonly property bool unpairing_this: addr.length > 0 && root.unpair_hold_addr === addr
  readonly property real unpair_progress: dev_item.unpairing_this ? root.unpair_hold_progress : 0

  implicitHeight: dev_row.height
  ...
}
```

The delegate requires `modelData` (the device object) and `index` (its position in the sorted list).

- `is_connected` — drives the icon colour, name colour, and name weight.
- `is_paired` — controls whether the trust, unpair, and pair buttons show.
- `is_trusted` — drives the trust button's filled vs outlined state and text.
- `addr` — used to match `unpair_hold_addr` against this device.
- `pairing` — true while the device is being paired (driven by `d.pairing`, the native BluetoothDevice property).
- `battery` — percentage `0..100` or `-1` if unavailable.
- `selected` — true when this row matches the keyboard selection.
- `unpairing_this` — true if this specific device is the one being held for unpair.
- `unpair_progress` — `0..1` progress of the unpair hold, only nonzero for the held device.

The implicit height is just the row height — the previous "Pairing failed" line is gone, since the native `d.pair()` call doesn't return a failure status.

### Row Background

```qml
Rectangle {
  id: dev_row
  width: parent.width
  height: 62
  radius: 10
  color: dev_item.selected
    ? Qt.alpha(Theme.c.fg, 0.10)
    : (dev_area.containsMouse ? Qt.alpha(Theme.c.fg, 0.06) : "transparent")
  border.width: dev_item.selected ? 1 : 0
  border.color: Qt.alpha(Theme.c.red2, 0.5)
  ...
}
```

Three visual states:

```text
Selected    10% cream fill, 1px vermilion border
Hovered      6% cream fill, no border
Normal       transparent, no border
```

### Click

```qml
MouseArea {
  id: dev_area
  anchors.fill: parent
  hoverEnabled: true
  cursorShape: Qt.PointingHandCursor
  onClicked: {
    root.cancel_unpair_hold();
    root.selected_index = dev_item.index;
    root.activate_device(dev_item.modelData);
  }
}
```

Clicking anywhere on the row cancels any hold, sets the keyboard selection to this row, then triggers the smart activate. The row's `selected` property updates immediately, so the highlight follows the click.

### Icon Tile

```qml
Rectangle {
  id: dev_tile
  ...
  width: 40
  height: 40
  radius: 11
  color: Qt.alpha(Theme.c.bg, 0.6)
  border.width: 1
  border.color: Qt.alpha(Theme.c.fg, 0.15)

  GlyphIcon {
    anchors.centerIn: parent
    width: 22
    height: 22
    name: "bluetooth"
    color: dev_item.is_connected ? Theme.c.red2 : Theme.c.black2
    stroke: 1.7
  }
}
```

A 40x40 rounded square on the left edge of the row. The bluetooth glyph is 22x22 inside, lit vermilion when connected, dim when not.

### Name And Meta Column

```qml
Column {
  anchors.left: dev_tile.right
  anchors.leftMargin: 14
  anchors.right: dev_right.left
  anchors.rightMargin: 8
  anchors.verticalCenter: parent.verticalCenter
  spacing: 3

  Text {
    width: parent.width
    text: dev_item.modelData ? (dev_item.modelData.deviceName || dev_item.modelData.name || "Unknown") : "Unknown"
    color: dev_item.is_connected ? Theme.c.fg : Theme.c.white
    font.family: Theme.clock_font
    font.pixelSize: 20
    font.bold: dev_item.is_connected
    elide: Text.ElideRight
  }

  Text {
    width: parent.width
    visible: text.length > 0
    text: root.meta_for(dev_item.modelData)
    color: Theme.c.black2
    font.family: Theme.clock_font
    font.pixelSize: 16
    font.bold: true
    opacity: 0.8
    elide: Text.ElideRight
  }
}
```

A two-line column between the icon tile and the right-side controls. The meta line includes "trusted" when the device is paired and `d.trusted === true`.

### Right-Side Controls

```qml
Row {
  id: dev_right
  anchors.right: parent.right
  anchors.rightMargin: 10
  anchors.verticalCenter: parent.verticalCenter
  spacing: 6
  ...
}
```

Five slots, left to right, with 6-pixel spacing:

1. **Pairing dot** — a 7-pixel yellow circle with a slow `0.35 -> 1 -> 0.35` opacity breath driven by `Motion.pulse`. Only visible while `modelData.pairing === true` (native Quickshell state).
2. **Battery filament** — a `Filament` (see `Filament.qml`) showing the device's battery level as a horizontal vermilion fill. Only visible when connected and the device reports a battery.
3. **Trust button** — a pill button labelled "Trusted" (vermilion fill, vermilion text, vermilion border) or "Trust" (transparent fill, dim text, cream border). Only shown on paired devices. Clicking or pressing `t` flips `d.trusted`.
4. **Unpair button** — a pill button labelled "Unpair" / "Hold…". Only shown on paired devices. Mouse press-and-hold drives the unpair hold progress; the button shows a vermilion progress fill that grows from left to right. Release before 1s cancels, hold to 1s to fire.
5. **Pair button** — a pill button labelled "Pair". Only shown on devices that are neither paired nor currently being paired. Clicking calls `d.pair()` directly. The keyboard equivalent is Space.

The pair button's colour and border colour animate to a vermilion hover state.

#### Unpair Hold Progress Fill

```qml
Item {
  anchors.left: parent.left
  anchors.top: parent.top
  anchors.bottom: parent.bottom
  width: parent.width * dev_item.unpair_progress
  clip: true
  visible: dev_item.unpairing_this

  Rectangle {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: dev_item.unpairing_this
      ? (unpair_btn.width * dev_item.unpair_progress)
      : 0
    radius: 999
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: Qt.alpha(Theme.c.red, 0.55) }
      GradientStop { position: 1.0; color: Qt.alpha(Theme.c.red2, 0.55) }
    }
  }
}
```

While this specific device is being held for unpair, a vermilion gradient rectangle fills from the left, growing in width as `unpair_progress` advances from `0` to `1`. The button's text changes to "Hold…" so the user knows the action is in progress. The fill is clipped to the parent so it never spills past the pill shape.

#### Unpair MouseArea

```qml
MouseArea {
  id: unpair_area
  anchors.fill: parent
  hoverEnabled: true
  cursorShape: Qt.PointingHandCursor
  onPressed: {
    root.cancel_unpair_hold();
    root.selected_index = dev_item.index;
    root.start_unpair_hold();
  }
  onReleased: root.cancel_unpair_hold()
  onCanceled: root.cancel_unpair_hold()
}
```

The mouse-driven equivalent of the `u` keyboard shortcut. On press, the hold starts. On release (or cancel, e.g. when the cursor leaves the area in some setups), the hold is cancelled. The `unpair_hold_timer` ticks every 33ms while the hold is active; if it reaches 1, `d.forget()` fires.

## Full Example: Pairing A New Headphone

```text
1. User opens the Bluetooth surface from a keybind.
2. onOpenChanged resets selected_index to 0 and calls forceActiveFocus().
3. Surface grabs keyboard focus.
4. User presses 's' to start a scan.
5. Keys.onPressed flips adapter.discovering on and starts scan_timer.
6. Empty state shows "Scanning…".
7. A new device appears in devices_sorted.
8. onDevicesChanged resets selected_index to 0.
9. The ListView re-renders with the new device at the bottom.
10. User presses 'j' a few times to move selection to the new device.
11. Keys.onPressed calls move_selection(1) each time, which updates selected_index
    and scrolls the list to keep the highlight in view.
12. User presses Space.
13. Keys.onPressed calls pair_selected() -> d.pair() (native).
14. Quickshell's Bluetooth module triggers BlueZ to pair the device.
15. While in progress, d.pairing === true and the row shows a pulsing yellow dot.
16. Pairing completes. d.paired becomes true, d.pairing becomes false.
17. The ListView re-renders. The Pair button is replaced by Trust + Unpair buttons.
```

If the user wants the device to auto-reconnect, they press `t` to mark it trusted. If they want to disconnect later, they press Enter to smart-activate. If they want to remove the device, they hold `u` for one second.

## Full Example: Unpairing A Mouse

```text
1. Surface is open with a paired mouse visible.
2. User selects the mouse with the keyboard or clicks it.
3. The row's Unpair button is visible on the right.
4. User clicks and holds the Unpair button.
5. MouseArea.onPressed: cancel_unpair_hold, set selected_index, start_unpair_hold.
6. unpair_hold_timer starts ticking. unpair_hold_addr is set to the mouse's MAC.
7. unpair_hold_progress grows 0 -> 0.033 -> 0.066 -> ... -> 1 over 1 second.
8. The button's vermilion fill grows from left to right.
9. The button text reads "Hold…".
10. At progress == 1, unpair_hold_timer calls d.forget().
11. d.paired becomes false, the device disappears from Bluetooth.devices within ~1s.
12. onDevicesChanged runs, but unpair_hold_addr is empty so no extra cleanup.
13. The mouse row vanishes from the list.
```

If the user releases the mouse before 1 second, `onReleased` calls `cancel_unpair_hold`, which stops the timer and resets the progress. No unpair happens.

## Full Example: Trust Toggle

```text
1. Surface is open with a paired-but-not-trusted device visible.
2. The row's Trust button shows "Trust" (outlined, dim).
3. User clicks the Trust button (or presses 't').
4. d.trusted is set to true.
5. Quickshell propagates the change to BlueZ, which marks the device trusted.
6. The row re-renders: Trust button now shows "Trusted" (vermilion fill, vermilion text).
7. The meta line gains a "trusted" segment.
8. The device will now auto-reconnect when in range.
```

## Surface Lifecycle

```text
1. Pill.toggle_surface(Pill.Surfaces.Bluetooth) is called.
2. Pill sets active_surface = Bluetooth.
3. Pill binds the Bluetooth surface's `open` to `active_surface !== None`.
4. Bluetooth.onOpenChanged runs:
   - selected_index = 0
   - forceActiveFocus()
5. PillSurface animates opacity from 0 to 1 as the pill morphs.
6. While open, the surface reads live data from Quickshell.Bluetooth.
7. User presses Esc, or another keybind calls pill.close_surface().
8. Pill sets active_surface = None.
9. Bluetooth.onOpenChanged runs:
   - scan_timer.stop()
   - cancel_unpair_hold()
   - adapter.discovering = false
10. PillSurface animates opacity from 1 to 0.
```

## Important Identifiers

```text
root.adapter
  Live Bluetooth.defaultAdapter or null.

root.devices
  Array of every device BlueZ knows about.

root.devices_sorted
  Same array, sorted: connected first, paired second, named third, MACs last.

root.discovering
  Whether the adapter is currently scanning.

root.selected_index
  Index of the keyboard-highlighted row in root.devices_sorted.

root.unpair_hold_addr
  MAC of the device currently being held for unpair (or "" if none).

root.unpair_hold_progress
  0..1 progress of the unpair hold.

root.unpair_holding
  True while an unpair hold is in progress.

root.unpair_hold_ms
  Total hold duration in ms (1000).

move_selection(delta)
  Move the highlight by delta rows, clamped, with auto-scroll.

activate_selected()
  Run activate_device on the highlighted device (smart: disconnect/connect/pair).

pair_selected()
  Run d.pair() on the highlighted device (native, no trust, no connect).

trust_selected()
  Toggle d.trusted on the highlighted device (only if paired).

unpair_selected()
  Run d.forget() on the highlighted device. Only called from the unpair hold timer.

start_unpair_hold()
  Begin a 1-second hold for the highlighted paired device.

cancel_unpair_hold()
  Abort any in-progress hold.

meta_for(d)
  Build the secondary "connected · trusted · playing" line.

battery_level(d)
  Return percentage 0..100, or -1 if d.batteryAvailable is false.

activate_device(d)
  Smart activate: disconnect if connected, connect if paired, else pair.

scan_timer
  25s timer that turns adapter.discovering off automatically.

unpair_hold_timer
  33ms tick timer that drives unpair_hold_progress to 1 then fires d.forget().

device_list
  ListView of root.devices_sorted.

dev_item.selected
  Whether this row matches root.selected_index.

dev_item.is_paired / is_connected / is_trusted / pairing
  Pass-throughs of the device's native properties.

dev_item.unpairing_this
  True if this device is the one being held for unpair.

dev_item.unpair_progress
  0..1 progress of the hold for this specific device (0 if not held).
```

## Companion Files

- `LinkToggle.qml` — the on/off switch used in the header.
- `Filament.qml` — the battery level bar.
- `Settings.qml` — `bluetooth_w: 460` and `bluetooth_h: 560`.
- `Pill.qml` — registers `Bluetooth` in the `Surfaces` enum and the `surface_dim` map, and instantiates the surface.
- `shell.qml` — IPC handler that toggles the surface from external keybinds.

## Summary

`Bluetooth.qml` is reactive: the UI follows a small set of state properties and the live `Quickshell.Bluetooth` service. All device actions (pair, connect, disconnect, trust, unpair) use the native Quickshell API — no shell commands, no `Process`, no manual cache. The user can scan, toggle the adapter, navigate the device list with the keyboard or mouse, and pair / connect / disconnect / trust / unpair any device. The unpair action requires a one-second hold to confirm. The surface is themed through `Theme.c.*` and animated through `Motion.*` so it matches the rest of the pill system.
