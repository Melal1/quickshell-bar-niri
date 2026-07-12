# Cliphist.qml And Clipboard.qml Explanation

`Cliphist.qml` and `Clipboard.qml` work together to provide the clipboard
history surface for this Quickshell setup.

`Cliphist.qml` is the data layer. It talks to the external `cliphist`,
`wl-paste`, and `wl-copy` commands, keeps the clipboard history in memory, and
exposes it as QML properties.

`Clipboard.qml` is the UI layer. It shows the clipboard history inside a
`PillSurface`, lets the user search entries, copy an entry back to the clipboard,
delete individual entries, or wipe the full history with a hold action.

The important idea is this data flow:

```text
wl-paste --watch cliphist store
  -> Cliphist refresh debounce
  -> cliphist list
  -> Cliphist.parse_line(...)
  -> Cliphist.entries
  -> Clipboard.results
  -> ListView rows
```

When `Cliphist.entries` changes, `Clipboard.results` updates automatically
because it is a readonly QML property bound to the singleton data.

## File Structure

The clipboard feature is split into two files:

1. `Cliphist.qml`
2. `Clipboard.qml`

`Cliphist.qml` contains:

1. Singleton state.
2. Refresh, copy, remove, and wipe functions.
3. Clipboard list parsing.
4. Background `wl-paste` watcher.
5. `cliphist list`, `cliphist delete`, and `cliphist wipe` processes.

`Clipboard.qml` contains:

1. Imports and the `PillSurface` root.
2. UI state properties.
3. Search filtering.
4. Helper functions for focus, movement, activation, deletion, and wiping.
5. Open/result handlers.
6. Header, search box, wipe indicator, empty state, and result list UI.
7. Row delegate for each clipboard entry.

## Cliphist.qml

### Imports And Singleton

```qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root
```

`pragma Singleton` makes this file a global QML singleton. Other QML files can
refer to it directly as `Cliphist`.

`QtQuick` provides base QML types such as `Timer`.

`Quickshell` provides `Quickshell.execDetached(...)`.

`Quickshell.Io` provides `Process`, `SplitParser`, and `StdioCollector`.

Because this is a singleton, `Clipboard.qml` does not create or own the
clipboard backend. It simply binds to the shared state:

```qml
var all = Cliphist.entries
```

## Cliphist State

```qml
property var entries: []
readonly property int count: entries.length
property bool pending: false
property bool manage_store: true
property var delete_queue: []
```

`entries` is the parsed clipboard history.

Each entry has this shape:

```js
{
  id: "123",
  preview: "copied text",
  isImage: false,
  meta: "",
  label: "",
  sizeLabel: ""
}
```

`count` is the number of loaded entries. `Clipboard.qml` displays it in the
header:

```qml
root.results.length + " / " + Cliphist.count
```

Example:

```text
4 / 22
```

That means the current search has 4 visible matches out of 22 clipboard entries.

`pending` tracks whether a refresh was requested while another clipboard
operation was already running.

`manage_store` controls whether this singleton starts its own clipboard watcher:

```qml
property bool manage_store: true
```

If another service already runs this command:

```sh
wl-paste --watch cliphist store
```

then `manage_store` can be set to `false` to avoid running a second watcher.

`delete_queue` stores ids waiting to be deleted from `cliphist`.

## Refreshing History

```qml
function refresh() {
  if (list_proc.running || delete_proc.running || delete_queue.length) {
    pending = true
    return
  }

  list_proc.running = true
}
```

`refresh()` starts `cliphist list`, but only when it is safe.

It refuses to start a new list operation if:

- `cliphist list` is already running.
- `cliphist delete` is running.
- There are queued deletes still waiting.

Instead of losing that refresh request, it sets:

```qml
pending = true
```

Later, after the current list operation finishes, the pending refresh is run:

```qml
if (root.pending) {
  root.pending = false
  Qt.callLater(root.refresh)
}
```

This prevents overlapping commands while still making sure the UI catches up.

Example:

```text
1. User deletes entry 10.
2. A clipboard change happens immediately after.
3. refresh() sees that deletion is still in progress.
4. pending becomes true.
5. After the delete/list cycle finishes, refresh() runs again.
```

## Copying An Entry

```qml
function copy(entry) {
  if (!entry || !/^\d+$/.test(String(entry.id))) return
  Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "_", String(entry.id)])
}
```

`copy(entry)` copies a history item back into the active Wayland clipboard.

The entry id is validated first:

```qml
/^\d+$/.test(String(entry.id))
```

Only numeric ids are accepted.

Then the id is piped into:

```sh
cliphist decode | wl-copy
```

`cliphist decode` turns the stored history item back into its original clipboard
content. `wl-copy` writes that content into the current Wayland clipboard.

Example:

```text
entry.id = "42"

printf '42' | cliphist decode | wl-copy
```

This does not update the QML list directly. It changes the real clipboard, and
the watcher can refresh the history afterward if `cliphist store` reports a
change.

## Wiping History

```qml
function wipe() {
  entries = []
  wipe_proc.running = true
}
```

`wipe()` clears the UI immediately by setting:

```qml
entries = []
```

Then it starts:

```sh
cliphist wipe
```

The immediate clear makes the surface feel responsive. When the command exits,
the singleton refreshes from the real `cliphist` database:

```qml
Process {
  id: wipe_proc
  command: ["cliphist", "wipe"]
  onExited: root.refresh()
}
```

## Removing One Entry

```qml
function remove(entry) {
  if (!entry || !/^\d+$/.test(String(entry.id))) return

  var id = String(entry.id)
  var kept = []
  for (var i = 0; i < entries.length; i++) {
    if (entries[i].id !== id) kept.push(entries[i])
  }

  entries = kept
  delete_queue.push(id)
  pump_deletes()
}
```

`remove(entry)` deletes one clipboard item.

Like `copy`, it only accepts numeric ids.

The UI is updated optimistically:

```qml
entries = kept
```

That means the row disappears immediately before `cliphist delete` finishes.

Then the id is added to `delete_queue`, and `pump_deletes()` starts processing
the queue.

### pump_deletes

```qml
function pump_deletes() {
  if (delete_proc.running || delete_queue.length === 0) return

  var id = delete_queue.shift()
  delete_proc.command = ["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "_", id]
  delete_proc.running = true
}
```

`pump_deletes()` serializes delete operations.

Only one `cliphist delete` process runs at a time. If the user deletes several
items quickly, the ids wait in `delete_queue`.

When a delete process exits:

```qml
Process {
  id: delete_proc
  onExited: {
    if (root.delete_queue.length > 0) root.pump_deletes()
    else root.refresh()
  }
}
```

If more ids are queued, the next delete starts.

If the queue is empty, the singleton refreshes the full list from `cliphist`.

Example:

```text
delete_queue = ["10", "11", "12"]

delete 10
delete 11
delete 12
refresh list
```

## Parsing cliphist Output

```qml
function parse_line(line) {
  var tab = line.indexOf("\t")
  if (tab < 1) return null

  var id = line.substring(0, tab)
  if (!/^\d+$/.test(id)) return null

  var preview = line.substring(tab + 1)
```

`cliphist list` outputs one entry per line. Each valid line is expected to look
like this:

```text
123<TAB>preview text
```

The parser:

1. Finds the tab.
2. Extracts the id before the tab.
3. Rejects lines without a numeric id.
4. Uses everything after the tab as the preview.

### Binary And Image Entries

```qml
var binary = /^\[\[ binary data (.*) \]\]$/.exec(preview)
var is_image = false

if (binary !== null) {
  meta = binary[1]
  is_image = /\b(png|jpg|jpeg|gif|bmp|webp)\b/i.test(meta)
  label = is_image ? meta : "binary data"

  var split = /^(\S+ \S+) (.+)$/.exec(meta)
  if (split !== null) {
    size_label = split[1]
    label = split[2]
  }
}
```

`cliphist` represents binary content with a special preview string.

Example:

```text
[[ binary data 2.4 MiB image/png ]]
```

If the preview matches that format, `parse_line` extracts the metadata.

Then it checks whether the metadata contains an image-like file type:

```text
png, jpg, jpeg, gif, bmp, webp
```

If it is an image, the row is treated as an image entry. The UI shows an `IMG`
badge and uses the parsed label instead of the raw binary preview.

The size parsing expects metadata shaped like:

```text
2.4 MiB image/png
```

That becomes:

```text
sizeLabel = "2.4 MiB"
label = "image/png"
```

The returned object is:

```qml
return {
  id: id,
  preview: preview,
  isImage: is_image,
  meta: meta,
  label: label,
  sizeLabel: size_label
}
```

For normal text entries, `isImage` is false and `preview` is the text shown in
the clipboard surface.

## Background Store Watcher

```qml
Process {
  id: store_watch
  command: ["wl-paste", "--watch", "sh", "-c", "cliphist store; echo x"]
  running: root.manage_store
  stdout: SplitParser {
    onRead: refresh_debounce.restart()
  }
  onExited: {
    if (root.manage_store) store_respawn.restart()
  }
}
```

`store_watch` runs:

```sh
wl-paste --watch sh -c 'cliphist store; echo x'
```

Every time the Wayland clipboard changes:

1. `wl-paste` runs `cliphist store`.
2. The shell command prints `x`.
3. `SplitParser.onRead` sees output.
4. `refresh_debounce` restarts.

The printed `x` is just a small signal to QML that something changed.

If the watcher exits while `manage_store` is still true, it is restarted after
two seconds:

```qml
Timer {
  id: store_respawn
  interval: 2000
  onTriggered: store_watch.running = root.manage_store
}
```

## Refresh Debounce

```qml
Timer {
  id: refresh_debounce
  interval: 300
  onTriggered: root.refresh()
}
```

The debounce timer waits 300 ms before refreshing.

This avoids running `cliphist list` too aggressively if several clipboard events
arrive close together.

Example:

```text
clipboard event
clipboard event 100 ms later
clipboard event 200 ms later

Only one refresh runs after the last restart.
```

## Listing History

```qml
Process {
  id: list_proc
  command: ["cliphist", "list"]
  stdout: StdioCollector {
    onStreamFinished: {
      var lines = this.text.split("\n")
      var out = []

      for (var i = 0; i < lines.length; i++) {
        var entry = root.parse_line(lines[i])
        if (entry !== null) out.push(entry)
      }

      root.entries = out
```

`list_proc` runs:

```sh
cliphist list
```

`StdioCollector` waits until stdout is complete. Then the code splits the output
into lines, parses each line, and replaces `root.entries`.

Because `entries` is replaced as a whole, QML bindings depending on it update
cleanly.

## Startup Refresh

```qml
Component.onCompleted: refresh()
```

When the singleton is created, it immediately loads the current `cliphist`
history.

This means the clipboard surface can show existing history even before any new
clipboard event occurs.

## Clipboard.qml

`Clipboard.qml` is the visible clipboard manager surface.

It does not call `cliphist` directly. Instead, it reads from and sends actions to
the `Cliphist` singleton:

```text
Clipboard.qml
  reads:  Cliphist.entries, Cliphist.count
  calls:  Cliphist.refresh()
          Cliphist.copy(entry)
          Cliphist.remove(entry)
          Cliphist.wipe()
```

## Imports

```qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
```

`QtQuick` provides visual types such as `Item`, `Rectangle`, `Text`, `ListView`,
`MouseArea`, and `NumberAnimation`.

`QtQuick.Controls` provides `TextField`.

`pragma ComponentBehavior: Bound` makes component scoping stricter. This helps
the row delegate safely refer to its own required properties, such as
`clip_row.index`.

## Root Surface

```qml
PillSurface {
  id: root

  m_top: 16
  m_left: 18
  m_right: 18
  m_bottom: 16
```

The clipboard UI is built inside the same reusable `PillSurface` system used by
the launcher.

`PillSurface` provides:

- Shared pill-surface margins.
- The `open` property from the parent `Pill`.
- The derived `active` property.
- Fade behavior while the pill morph animation settles.
- The `request_close()` signal.

`Clipboard.qml` defines the content inside that surface. It does not create the
outer popup window by itself.

The margins match the launcher:

```qml
m_top: 16
m_left: 18
m_right: 18
m_bottom: 16
```

## Clipboard State

```qml
property string query: ""
property int selected_index: 0
property point last_pointer: Qt.point(-1, -1)
property real wipe_hold: 0
property bool wipe_fired: false
```

`query` is the current search text.

Example:

```text
query = "github"
```

Only clipboard entries containing `github` will be shown.

`selected_index` is the currently highlighted row in `root.results`.

Example:

```text
results = [entry A, entry B, entry C]
selected_index = 1
```

The selected row is `entry B`.

`last_pointer` stores the last global mouse position seen by a row. This keeps
mouse hover from fighting keyboard navigation.

`wipe_hold` is the wipe button hold progress.

Example:

```text
0.0 = not holding
0.5 = halfway held
1.0 = wipe completed
```

`wipe_fired` remembers whether the hold reached completion and already triggered
`Cliphist.wipe()`.

## Search Results

```qml
readonly property var results: {
  var all = Cliphist.entries
  var q = query.trim().toLowerCase()
  if (q.length === 0) return all

  var out = []
  for (var i = 0; i < all.length; i++) {
    var entry = all[i]
    var hay = entry.isImage
      ? (entry.label + " " + entry.sizeLabel)
      : entry.preview

    if (hay.toLowerCase().indexOf(q) !== -1) out.push(entry)
  }
  return out
}
```

`results` is the filtered list shown by the UI.

It depends on:

- `Cliphist.entries`: the full clipboard history.
- `query`: the typed search text.

Unlike `Launcher.qml`, this does not use fuzzy ranking. Clipboard search is a
simple case-insensitive substring search.

Example:

```text
query = "token"
preview = "API_TOKEN=abc123"
```

This entry is included because `api_token=abc123` contains `token`.

For image entries, the searchable text is:

```qml
entry.label + " " + entry.sizeLabel
```

For normal text entries, the searchable text is:

```qml
entry.preview
```

With an empty query, all entries are returned:

```qml
if (q.length === 0) return all
```

## Helper Functions

### focus_field

```qml
function focus_field() {
  search_field.forceActiveFocus()
}
```

This moves keyboard focus into the search field when the clipboard surface opens.

That lets the user type immediately.

### move

```qml
function move(delta) {
  if (results.length === 0) return

  selected_index = Math.max(0, Math.min(results.length - 1, selected_index + delta))
  clip_list.positionViewAtIndex(selected_index, ListView.Contain)
}
```

`move(delta)` changes the selected row.

Examples:

```qml
root.move(1)   // move down one row
root.move(-1)  // move up one row
```

The selected index is clamped so it never becomes invalid.

Example:

```text
results.length = 3
valid indexes = 0, 1, 2

selected_index = 2
move(1)
selected_index stays 2
```

`clip_list.positionViewAtIndex(..., ListView.Contain)` scrolls the list just
enough to keep the selected row visible.

### activate

```qml
function activate() {
  if (results.length === 0 || selected_index < 0 || selected_index >= results.length) return

  Cliphist.copy(results[selected_index])
  root.request_close()
}
```

`activate()` copies the selected history entry back into the clipboard.

It first checks that there is a valid selected result. This prevents errors if
the user presses Enter while there are no matches.

Then it calls:

```qml
Cliphist.copy(results[selected_index])
```

Finally it closes the clipboard surface:

```qml
root.request_close()
```

Example flow:

```text
1. Open clipboard.
2. Search "email".
3. Press Down to choose an entry.
4. Press Enter.
5. That entry becomes the active clipboard content.
6. The surface closes.
```

### remove_at

```qml
function remove_at(index) {
  if (index < 0 || index >= results.length) return
  Cliphist.remove(results[index])
}
```

`remove_at(index)` deletes one visible result.

The function receives an index into `root.results`, not directly into
`Cliphist.entries`.

That matters when searching.

Example:

```text
Cliphist.entries = [A, B, C, D]
query = "token"
results = [B, D]

remove_at(0) deletes B, not A.
```

### start_wipe And stop_wipe

```qml
function start_wipe() {
  wipe_fired = false
  wipe_drain.stop()
  wipe_fill.restart()
}
```

`start_wipe()` begins the hold-to-wipe animation.

It resets `wipe_fired`, stops any drain animation, and starts filling
`wipe_hold` from `0` to `1`.

```qml
function stop_wipe() {
  wipe_fill.stop()
  if (!wipe_fired && wipe_hold < 1) wipe_drain.restart()
}
```

`stop_wipe()` runs when the mouse is released or leaves the wipe button.

If the hold did not complete, the wipe is cancelled visually by draining
`wipe_hold` back to `0`.

## Open And Result Change Handlers

### onActiveChanged

```qml
onActiveChanged: {
  if (active) {
    query = ""
    search_field.text = ""
    selected_index = 0
    clip_list.contentY = 0
    Cliphist.refresh()
    Qt.callLater(root.focus_field)
  }
}
```

This runs when the clipboard surface opens.

It resets the surface:

- Clears the query.
- Clears the visible search text.
- Selects the first result.
- Scrolls to the top.
- Refreshes clipboard history.
- Focuses the search field on the next event-loop pass.

`Qt.callLater(root.focus_field)` is used because focus is more reliable after the
surface has opened and the `TextField` is ready.

Example behavior:

```text
1. Open clipboard.
2. Type "url".
3. Close clipboard.
4. Open clipboard again.
5. Search is empty, list is at the top, and the field is focused.
```

### onResultsChanged

```qml
onResultsChanged: {
  if (selected_index >= results.length) {
    selected_index = Math.max(0, results.length - 1)
  }
}
```

This protects against invalid selection indexes when the result list changes.

Example:

```text
Before typing:
results.length = 20
selected_index = 12

After typing a strict query:
results.length = 3
selected_index = 12 would be invalid

The handler clamps selected_index to 2.
```

If there are no results, the value becomes `0`.

That is still safe because `activate()` and `remove_at()` both check the result
length before using the index.

## Wipe Animation

```qml
NumberAnimation {
  id: wipe_fill
  target: root
  property: "wipe_hold"
  from: 0
  to: 1
  duration: Motion.heat
  onFinished: {
    root.wipe_fired = true
    Cliphist.wipe()
    wipe_drain.restart()
  }
}
```

`wipe_fill` animates `wipe_hold` from `0` to `1`.

The duration comes from:

```qml
Motion.heat
```

When the animation finishes:

1. `wipe_fired` becomes true.
2. `Cliphist.wipe()` clears clipboard history.
3. `wipe_drain` starts so the visual indicator returns to zero.

```qml
NumberAnimation {
  id: wipe_drain
  target: root
  property: "wipe_hold"
  to: 0
  duration: 180
}
```

`wipe_drain` animates the hold indicator back to `0`.

## Header UI

```qml
Item {
  id: header
  anchors.left: parent.left
  anchors.right: parent.right
  anchors.top: parent.top
  height: 46
```

The header is a 46-pixel-tall row at the top of the surface.

It contains:

- The title: `Clipboard`
- The count: `root.results.length + " / " + Cliphist.count`
- The wipe button

Example display:

```text
Clipboard                         6 / 31   W
```

The header uses theme values like `Theme.c.fg`, `Theme.c.black2`, and
`Theme.clock_font` so it matches the rest of the shell.

## Wipe Button

```qml
Rectangle {
  id: wipe_button
  width: 34
  height: 34
  radius: 17
  color: wipe_area.containsMouse || root.wipe_hold > 0 ? Theme.c.red : Theme.c.black
```

The wipe button is the round button on the right side of the header.

Its color changes to red when:

- The button is hovered.
- The hold animation is in progress.

The button contains a `Text` label:

```qml
text: "W"
```

The `MouseArea` drives the hold behavior:

```qml
MouseArea {
  id: wipe_area
  anchors.fill: parent
  hoverEnabled: true
  cursorShape: Qt.PointingHandCursor
  onPressed: root.start_wipe()
  onReleased: root.stop_wipe()
  onExited: root.stop_wipe()
}
```

Holding the button long enough wipes the history.

Releasing early cancels the wipe.

## Search Box UI

```qml
Rectangle {
  id: search_box
  anchors.top: header.bottom
  height: 44
  radius: 14
  color: Theme.c.black
  border.width: search_field.activeFocus ? 2 : 1
  border.color: search_field.activeFocus ? Theme.c.magenta : Theme.c.black2
```

The search box is a rounded rectangle under the header.

When the search field is focused:

- Border width becomes `2`.
- Border color becomes `Theme.c.magenta`.

When it is not focused:

- Border width is `1`.
- Border color is `Theme.c.black2`.

The border color is animated:

```qml
Behavior on border.color {
  ColorAnimation { duration: Motion.fast }
}
```

### TextField

```qml
TextField {
  id: search_field
  background: null
  placeholderText: "Search clipboard"
```

The `TextField` is the actual input. Its default control background is removed
with `background: null` because `search_box` already provides the visual
background.

When the text changes:

```qml
onTextChanged: {
  root.query = text
  root.selected_index = 0
  clip_list.contentY = 0
}
```

The clipboard surface:

- Copies the typed text into `root.query`.
- Selects the first result.
- Scrolls the list to the top.

Example:

```text
User types: "png"
root.query becomes "png"
root.results recalculates
selected_index becomes 0
```

## Keyboard Controls

The keyboard handlers live inside `search_field` because that is where focus is
while the clipboard surface is open.

```qml
Keys.onUpPressed: (event) => {
  root.move(-1)
  event.accepted = true
}
```

Up selects the previous row.

```qml
Keys.onDownPressed: (event) => {
  root.move(1)
  event.accepted = true
}
```

Down selects the next row.

```qml
Keys.onReturnPressed: (event) => {
  root.activate()
  event.accepted = true
}

Keys.onEnterPressed: (event) => {
  root.activate()
  event.accepted = true
}
```

Return and Enter both copy the selected entry.

```qml
Keys.onEscapePressed: (event) => {
  root.request_close()
  event.accepted = true
}
```

Escape closes the clipboard surface.

```qml
Keys.onPressed: (event) => {
  if (event.key === Qt.Key_X && (event.modifiers & Qt.ControlModifier) && search_field.selectedText.length === 0) {
    root.remove_at(root.selected_index)
    event.accepted = true
  }
}
```

Ctrl+X deletes the selected clipboard entry, but only when no text is selected in
the search field.

That condition matters because Ctrl+X normally cuts selected text from a text
field. If the user selected text in the search box, this handler leaves the
normal text-editing behavior alone.

Example keyboard flow:

```text
1. Open clipboard.
2. Type "code".
3. Press Down twice.
4. Press Enter.
5. The selected history item becomes the current clipboard content.
6. The surface closes.
```

## Separator And Wipe Progress

```qml
Rectangle {
  id: sep
  anchors.top: search_box.bottom
  anchors.topMargin: 14
  height: 1
  color: Theme.c.black2
  opacity: 0.45
```

The separator visually divides the search box from the result list.

Inside it is a red progress strip:

```qml
Rectangle {
  anchors.right: parent.right
  width: parent.width * root.wipe_hold
  visible: root.wipe_hold > 0
  color: Theme.c.red
}
```

As the user holds the wipe button, this strip grows from the right side.

Example:

```text
wipe_hold = 0.25
red strip width = 25% of separator width

wipe_hold = 1.0
red strip width = 100% of separator width
```

## Empty State

```qml
Text {
  anchors.centerIn: clip_list
  visible: root.results.length === 0
  text: root.query.length > 0 ? "No matches" : "History empty"
}
```

The empty-state text is centered inside the list area.

It shows:

```text
No matches
```

when the user typed a query and nothing matched.

It shows:

```text
History empty
```

when there are no clipboard entries.

## Clipboard List

```qml
ListView {
  id: clip_list
  anchors.top: sep.bottom
  anchors.bottom: parent.bottom
  clip: true
  spacing: 6
  boundsBehavior: Flickable.StopAtBounds
  model: root.results.length
```

`ListView` displays the current filtered results.

`model: root.results.length` means each row receives a numeric index. The row
uses that index to access the actual entry:

```qml
readonly property var entry: root.results[index]
```

`clip: true` prevents rows from drawing outside the list area.

`spacing: 6` adds vertical space between rows.

`boundsBehavior: Flickable.StopAtBounds` prevents overscroll bounce.

## Row Delegate

Each clipboard row is created by the `delegate`.

```qml
delegate: Item {
  id: clip_row
  required property int index

  width: clip_list.width
  height: 44
```

Each row is 44 pixels tall and as wide as the list.

`required property int index` is provided by the `ListView` model. The row uses
it to look up its clipboard entry.

### Row Properties

```qml
readonly property var entry: root.results[index]
readonly property bool selected: index === root.selected_index
readonly property string body: {
  if (!entry) return ""
  if (entry.isImage) return entry.label
  return entry.preview
}
```

`entry` is the clipboard history item represented by this row.

`selected` is true when this row matches `root.selected_index`.

`body` is the main text shown in the row.

For image entries, it uses:

```qml
entry.label
```

For text entries, it uses:

```qml
entry.preview
```

Example:

```text
Text entry body:
https://example.com

Image entry body:
image/png
```

### Row Background

```qml
Rectangle {
  anchors.fill: parent
  radius: 13
  color: clip_row.selected ? Theme.c.magenta : (row_area.containsMouse ? Theme.c.black : "transparent")
  border.width: clip_row.selected ? 0 : (row_area.containsMouse ? 1 : 0)
  border.color: Theme.c.black2
}
```

The row background has three visual states:

```text
Selected:
  magenta background, no border

Hovered:
  black background, thin border

Normal:
  transparent background, no border
```

The color is animated with `Motion.fast`.

### MouseArea

```qml
MouseArea {
  id: row_area
  anchors.fill: parent
  hoverEnabled: true
  cursorShape: Qt.PointingHandCursor
```

The `MouseArea` makes the row interactive.

On mouse movement:

```qml
onPositionChanged: (mouse) => {
  var global = row_area.mapToItem(null, mouse.x, mouse.y)
  if (global.x !== root.last_pointer.x || global.y !== root.last_pointer.y) {
    root.last_pointer = Qt.point(global.x, global.y)
    root.selected_index = clip_row.index
  }
}
```

This selects the row only when the pointer physically moved.

Why this matters:

```text
1. Mouse is resting over row 4.
2. User presses Down on the keyboard.
3. The list may scroll under the stationary pointer.
4. Without the last_pointer check, hover could steal selection back to row 4.
5. With the check, keyboard navigation stays in control until the mouse moves.
```

On click:

```qml
onClicked: {
  root.selected_index = clip_row.index
  root.activate()
}
```

Clicking a row selects it, copies it to the clipboard, and closes the surface.

### Type Badge

```qml
Rectangle {
  id: type_badge
  width: 28
  height: 24
  radius: 8
```

Each row has a small badge on the left.

The badge text is:

```qml
clip_row.entry && clip_row.entry.isImage ? "IMG" : "TXT"
```

So normal text entries show:

```text
TXT
```

Image entries show:

```text
IMG
```

When the row is selected, the badge uses a semi-transparent dark background so
it stays readable on the magenta selected row.

### Body Text

```qml
Text {
  anchors.left: type_badge.right
  anchors.right: meta.left
  text: clip_row.body
  maximumLineCount: 1
  elide: Text.ElideRight
  textFormat: Text.PlainText
}
```

The body text is the main clipboard preview.

It is forced to plain text:

```qml
textFormat: Text.PlainText
```

That prevents copied text that looks like rich text or markup from being
interpreted by QML.

Long previews are kept to one line and elided on the right.

Example:

```text
This is a very long clipboard entry that does not fit
```

may render as:

```text
This is a very long clipboard entry...
```

### Image Metadata

```qml
Text {
  id: meta
  width: text.length > 0 ? Math.min(95, implicitWidth) : 0
  text: clip_row.entry && clip_row.entry.isImage ? clip_row.entry.sizeLabel : ""
```

The metadata label appears on the right side of the row.

It is only used for image entries.

Example:

```text
2.4 MiB
```

The width is capped at 95 pixels so metadata does not steal too much space from
the main preview.

If there is no metadata text, the width becomes `0` and opacity becomes `0`.

### Remove Button

```qml
Text {
  id: remove_button
  anchors.right: parent.right
  width: 18
  text: row_area.containsMouse ? "x" : (clip_row.selected ? "↵" : "")
```

The right side of the row shows a small action hint.

When the row is hovered, it shows:

```text
x
```

Clicking it deletes the row:

```qml
MouseArea {
  anchors.fill: parent
  anchors.margins: -8
  enabled: row_area.containsMouse
  hoverEnabled: true
  cursorShape: Qt.PointingHandCursor
  onClicked: root.remove_at(clip_row.index)
}
```

When the row is selected but not hovered, it shows an enter-style glyph to hint
that pressing Enter will activate the row.

The click area has negative margins:

```qml
anchors.margins: -8
```

That makes the remove target easier to hit than the visible text alone.

## User Flows

### Copy From History

```text
1. Open the clipboard surface.
2. Cliphist.refresh() reloads history.
3. Type a search query if needed.
4. Use Up/Down or hover to select a row.
5. Press Enter or click the row.
6. Clipboard.qml calls Cliphist.copy(entry).
7. cliphist decode writes the selected content into wl-copy.
8. The surface closes.
```

### Delete One Entry

```text
1. Select or hover a row.
2. Press Ctrl+X, or click the row's x button.
3. Clipboard.qml calls Cliphist.remove(entry).
4. Cliphist removes the entry from the UI immediately.
5. The id is queued.
6. cliphist delete runs.
7. When all queued deletes finish, Cliphist.refresh() reloads the real list.
```

### Wipe History

```text
1. Press and hold the W button.
2. wipe_hold animates from 0 to 1.
3. The red separator fill grows.
4. Releasing early drains the indicator and cancels the wipe.
5. Holding to completion calls Cliphist.wipe().
6. The UI clears immediately.
7. cliphist wipe runs.
8. Cliphist.refresh() reloads the final empty list.
```

## Main Difference From Launcher.qml

`Launcher.qml` and `Clipboard.qml` share the same surface pattern:

- Both live inside `PillSurface`.
- Both reset state when opened.
- Both focus their search field with `Qt.callLater(...)`.
- Both use `selected_index`.
- Both support Up, Down, Enter, Escape, mouse hover, and click activation.
- Both use `last_pointer` to prevent stationary mouse hover from stealing
  keyboard selection.

The main difference is the data source and ranking:

```text
Launcher.qml:
DesktopEntries.applications
  -> Fuzzy.rank(...)
  -> launch app

Clipboard.qml:
Cliphist.entries
  -> substring filter
  -> copy history item
```

The launcher persists app usage in a JSON file.

The clipboard persists nothing itself. Persistence belongs to the external
`cliphist` database.

