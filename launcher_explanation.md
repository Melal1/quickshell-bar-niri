# Launcher.qml Explanation

`Launcher.qml` is the application launcher surface for this Quickshell setup.
It shows installed desktop applications, lets the user search them with fuzzy
matching, supports keyboard and mouse selection, launches the selected app, and
stores usage counts so frequently used apps appear higher.

The important idea is this data flow:

```text
DesktopEntries.applications
  -> root.all_entries
  -> Fuzzy.rank(root.all_entries, root.query, root.usage)
  -> root.results
  -> ListView rows
```

When the user types, `root.query` changes. Because `root.results` is a readonly
property bound to `Fuzzy.rank(...)`, the list updates automatically.

## File Structure

The file is split into these main parts:

1. Imports and the `PillSurface` root.
2. Launcher state properties.
3. App collection and ranking.
4. Helper functions for focus, movement, and activation.
5. Usage persistence through `FileView`.
6. Header, search box, empty state, and app list UI.
7. Row delegate for each app result.

## Imports

```qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "lib/fuzzy.js" as Fuzzy
```

`QtQuick` provides basic UI types like `Item`, `Rectangle`, `Text`, `Image`, and
`ListView`.

`QtQuick.Controls` provides `TextField`.

`Quickshell` provides shell integration, including desktop application entries
through `DesktopEntries`.

`Quickshell.Io` provides `FileView`, which this launcher uses to read and write
the usage JSON file.

`lib/fuzzy.js` is imported as `Fuzzy`. The launcher calls `Fuzzy.rank(...)` to
sort and filter apps.

`pragma ComponentBehavior: Bound` makes QML component scoping stricter. In this
file, that helps delegate code safely refer to the properties it explicitly owns,
such as `app_row.index`.

## Root Surface

```qml
PillSurface {
  id: root

  m_top: 16
  m_left: 18
  m_right: 18
  m_bottom: 16
```

The launcher is built inside a custom `PillSurface` component. `PillSurface.qml`
defines common behavior for popup-like surfaces in this config:

- It fills its parent.
- It has margin properties such as `m_top` and `m_left`.
- It exposes `active`, which is tied to `open`.
- It has a `request_close()` signal.
- It fades content in and out while the pill morph animation runs.

So `Launcher.qml` does not create the outer window by itself. It defines the
content that appears inside the existing pill surface system.

The margins here give the launcher content breathing room inside the pill:

```qml
m_top: 16
m_left: 18
m_right: 18
m_bottom: 16
```

## State Properties

```qml
property string query: ""
property int selected_index: 0
property var usage: ({})
property point last_pointer: Qt.point(-1, -1)
```

These properties hold the launcher's runtime state.

`query` is the current search text.

Example:

```qml
query: "fire"
```

This would make `root.results` contain apps matching `"fire"`, such as
`Firefox`.

`selected_index` is the currently highlighted row in `root.results`.

Example:

```text
results = [Firefox, Files, Foot]
selected_index = 1
```

In that case, the selected app is `Files`.

`usage` is a JavaScript object that tracks how many times each app was launched.
It is saved to disk.

Example:

```json
{
  "firefox.desktop": 12,
  "org.wezfurlong.wezterm.desktop": 5,
  "code.desktop": 2
}
```

`last_pointer` stores the last mouse position seen by a row. This prevents the
mouse hover code from fighting keyboard navigation when the pointer has not
actually moved.

## App Data

```qml
readonly property string usage_file:
  Quickshell.env("HOME") + "/.config/quickshell/launcher-usage.json"
```

`usage_file` is the path where usage counts are stored.

For user `melal`, the file resolves to:

```text
/home/melal/.config/quickshell/launcher-usage.json
```

### all_entries

```qml
readonly property var all_entries: {
  var src = DesktopEntries.applications.values;
  var out = [];
  for (var i = 0; i < src.length; i++) {
    if (src[i] && !src[i].noDisplay) {
      out.push(src[i]);
    }
  }
  return out;
}
```

`DesktopEntries.applications.values` comes from Quickshell. It contains desktop
application entries, usually read from `.desktop` files.

The launcher filters out entries with `noDisplay`.

Example:

```text
Keep:
Firefox
Files
Terminal

Ignore:
Hidden helper apps where noDisplay is true
```

This means the launcher avoids showing internal utilities that are not meant to
appear in normal app menus.

### total_count

```qml
readonly property int total_count: all_entries.length
```

This is the total number of visible applications before search filtering.

It is displayed in the header as the right side of this text:

```qml
root.results.length + " / " + root.total_count
```

Example:

```text
7 / 143
```

That means the current search has 7 matches out of 143 visible apps.

### results

```qml
readonly property var results: Fuzzy.rank(all_entries, query, usage)
```

`results` is the current list shown by the launcher.

It depends on three values:

- `all_entries`: the full visible app list.
- `query`: the text typed by the user.
- `usage`: launch counts used for sorting.

Because this is a QML binding, changing `query` automatically recalculates
`results`.

Example:

```text
query = ""
```

With an empty query, `Fuzzy.rank` sorts apps mostly by usage count, then by name.
Frequently launched apps appear first.

Example:

```text
query = "term"
```

With a search query, `Fuzzy.rank` only returns matching apps and sorts better
matches first.

## How Fuzzy Ranking Works

The ranking logic lives in `lib/fuzzy.js`.

It builds searchable text from:

- `entry.name`
- `entry.genericName`
- `entry.keywords`

The score levels are:

```text
0 = app name starts with the query
1 = query appears somewhere in name/genericName/keywords
2 = query is a subsequence of one of those fields
99 = no match
```

Lower score is better.

Example:

```text
Query: "fire"

Firefox
  name starts with "fire"
  score 0

LibreWolf Web Browser
  keyword or generic name may contain "fire" only if provided by the desktop entry
  score depends on its metadata

Files
  "fire" is not found
  score 99, hidden from results
```

Subsequence matching means the letters only need to appear in order, not
necessarily next to each other.

Example:

```text
Query: "ff"
Candidate: "Firefox"

f i r e f o x
^       ^

"ff" matches as a subsequence, so it can still appear.
```

If two apps have the same fuzzy score, usage count breaks the tie. If usage is
also the same, app name is used alphabetically.

Example:

```text
Query: "term"

App        Score  Usage
Terminal   0      2
Terminator 0      8
Foot       99     5
```

The result order is:

```text
Terminator
Terminal
```

`Foot` is not included because it does not match the query.

## Helper Functions

### focus_field

```qml
function focus_field() {
  search_field.forceActiveFocus();
}
```

This moves keyboard focus into the search field. It is called when the launcher
opens so the user can type immediately.

### move

```qml
function move(delta) {
  if (results.length === 0) {
    return;
  }

  selected_index = Math.max(0, Math.min(results.length - 1, selected_index + delta));
  app_list.positionViewAtIndex(selected_index, ListView.Contain);
}
```

`move(delta)` changes the selected row.

Examples:

```qml
root.move(1)   // move down one row
root.move(-1)  // move up one row
```

The selected index is clamped so it never goes below `0` or above the last result.

Example:

```text
results.length = 5
valid indexes = 0, 1, 2, 3, 4

selected_index = 4
move(1)
selected_index stays 4
```

`app_list.positionViewAtIndex(..., ListView.Contain)` scrolls the list just
enough to keep the selected row visible.

### activate

```qml
function activate() {
  if (results.length === 0 || selected_index < 0 || selected_index >= results.length) {
    return;
  }

  var entry = results[selected_index];
  if (!entry) {
    return;
  }

  if (entry.id) {
    root.usage[entry.id] = (root.usage[entry.id] || 0) + 1;
    usage_store.setText(JSON.stringify(root.usage));
  }

  entry.execute();
  root.request_close();
}
```

`activate()` launches the selected app.

It first checks that there is a valid result. This prevents crashes if the user
presses Enter while there are no matches.

Then it updates usage:

```qml
root.usage[entry.id] = (root.usage[entry.id] || 0) + 1;
```

Example:

```text
Before:
usage["firefox.desktop"] = 3

After launching Firefox:
usage["firefox.desktop"] = 4
```

Then it saves the JSON:

```qml
usage_store.setText(JSON.stringify(root.usage));
```

Finally, it launches the app and asks the surface to close:

```qml
entry.execute();
root.request_close();
```

## Open And Result Change Handlers

### onActiveChanged

```qml
onActiveChanged: {
  if (active) {
    query = "";
    search_field.text = "";
    selected_index = 0;
    app_list.contentY = 0;
    Qt.callLater(root.focus_field);
  }
}
```

This runs when the launcher becomes active.

It resets the launcher to a clean state:

- Clears the query.
- Clears the visible search text.
- Selects the first result.
- Scrolls the app list to the top.
- Focuses the search field on the next event-loop pass.

`Qt.callLater(root.focus_field)` is used because focus is more reliable after the
surface has finished opening and the `TextField` is ready.

Example behavior:

```text
1. Open launcher.
2. Type "fire".
3. Launch Firefox.
4. Open launcher again.
5. Search field is empty again, and focus is already inside it.
```

### onResultsChanged

```qml
onResultsChanged: {
  if (selected_index >= results.length) {
    selected_index = 0;
  }
}
```

This protects against invalid selection indexes when the result list changes.

Example:

```text
Before typing:
results.length = 20
selected_index = 10

After typing a strict query:
results.length = 2
selected_index = 10 would be invalid

The handler resets selected_index to 0.
```

## Usage Persistence

```qml
FileView {
  id: usage_store
  path: root.usage_file
  blockLoading: true
  atomicWrites: true
  printErrors: false
}
```

`FileView` connects QML to the usage JSON file.

`path` points to `~/.config/quickshell/launcher-usage.json`.

`blockLoading: true` makes the file contents available immediately when possible.
That matters because `Component.onCompleted` reads the file right away.

`atomicWrites: true` writes safely by replacing the file atomically, reducing the
chance of leaving a corrupted JSON file if writing is interrupted.

`printErrors: false` avoids noisy logs if the file does not exist yet.

The file is loaded here:

```qml
Component.onCompleted: {
  var raw = usage_store.text();
  try {
    root.usage = raw && raw.length ? JSON.parse(raw) : ({});
  } catch (e) {
    root.usage = ({});
  }
}
```

If the file exists and contains valid JSON, it becomes `root.usage`.

If the file is missing, empty, or invalid, usage falls back to an empty object.

Example:

```text
launcher-usage.json contains:
{"firefox.desktop":12}

After startup:
root.usage = { "firefox.desktop": 12 }
```

Bad JSON example:

```text
launcher-usage.json contains:
not valid json

After startup:
root.usage = {}
```

## Header UI

```qml
Item {
  id: header
  anchors.left: parent.left
  anchors.right: parent.right
  anchors.top: parent.top
  height: 46
```

The header is a 46-pixel-tall row at the top of the launcher.

It contains the title:

```qml
text: "Apps"
```

And the result count:

```qml
text: root.results.length + " / " + root.total_count
```

Example display:

```text
Apps                                      12 / 143
```

The header uses theme values like `Theme.c.fg`, `Theme.c.black2`, and
`Theme.clock_font` so it matches the rest of the shell.

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

The search box is a rounded rectangle below the header.

When the search field is focused:

- Border width becomes `2`.
- Border color becomes `Theme.c.magenta`.

When it is not focused:

- Border width is `1`.
- Border color is `Theme.c.black2`.

This behavior makes keyboard focus visible.

The border color is animated:

```qml
Behavior on border.color {
  ColorAnimation { duration: Motion.fast }
}
```

### Search Icon

```qml
Text {
  id: search_icon
  text: "⌕"
}
```

This is a text-based search icon placed on the left side of the box.

### TextField

```qml
TextField {
  id: search_field
  background: null
  placeholderText: "Search apps"
```

The `TextField` is the actual input. Its default control background is removed
with `background: null` because the surrounding `search_box` already provides
the visual background.

When the text changes:

```qml
onTextChanged: {
  root.query = text;
  root.selected_index = 0;
  app_list.contentY = 0;
}
```

The launcher:

- Copies the typed text into `root.query`.
- Selects the first result.
- Scrolls to the top.

Example:

```text
User types: "fox"
root.query becomes "fox"
root.results recalculates
selected_index becomes 0
```

## Keyboard Controls

The keyboard handlers live inside `search_field` because that is where focus is
while the launcher is open.

```qml
Keys.onUpPressed: (event) => {
  root.move(-1);
  event.accepted = true;
}
```

Up selects the previous row.

```qml
Keys.onDownPressed: (event) => {
  root.move(1);
  event.accepted = true;
}
```

Down selects the next row.

```qml
Keys.onReturnPressed: (event) => {
  root.activate();
  event.accepted = true;
}

Keys.onEnterPressed: (event) => {
  root.activate();
  event.accepted = true;
}
```

Return and Enter both launch the selected app.

```qml
Keys.onEscapePressed: (event) => {
  root.request_close();
  event.accepted = true;
}
```

Escape closes the launcher without launching anything.

`event.accepted = true` tells QML that the launcher handled the key event, so it
should not continue bubbling elsewhere.

Example keyboard flow:

```text
1. Open launcher.
2. Type "term".
3. Press Down twice.
4. Press Enter.
5. The selected terminal app launches.
6. The launcher closes.
```

## Separator And Empty State

```qml
Rectangle {
  id: sep
  anchors.top: search_box.bottom
  anchors.topMargin: 14
  height: 1
  color: Theme.c.black2
  opacity: 0.45
}
```

The separator visually divides the search box from the result list.

The empty-state text is centered inside the list area:

```qml
Text {
  anchors.centerIn: app_list
  visible: root.results.length === 0
  text: root.query.length > 0 ? "No matches" : "No apps found"
}
```

It shows:

```text
No matches
```

when the user typed something but nothing matched.

It shows:

```text
No apps found
```

when there are no visible desktop entries at all.

## App List

```qml
ListView {
  id: app_list
  anchors.top: sep.bottom
  anchors.bottom: parent.bottom
  clip: true
  spacing: 6
  boundsBehavior: Flickable.StopAtBounds
  model: root.results.length
```

`ListView` displays the current results.

`model: root.results.length` means each row is represented by a numeric index.
The delegate uses that index to access the real app entry:

```qml
readonly property var entry: root.results[index]
```

`clip: true` prevents rows from drawing outside the list area.

`spacing: 6` adds vertical space between rows.

`boundsBehavior: Flickable.StopAtBounds` prevents overscroll bounce.

## Row Delegate

Each result row is created by the `delegate`.

```qml
delegate: Item {
  id: app_row
  required property int index

  width: app_list.width
  height: 46
```

Each row is 46 pixels tall and as wide as the list.

`required property int index` is provided by the `ListView` model. The row uses
it to look up its app entry.

### Row Properties

```qml
readonly property var entry: root.results[index]
readonly property bool selected: index === root.selected_index
readonly property string secondary: {
  if (!entry) return "";
  if (entry.genericName && entry.genericName.length > 0) return entry.genericName;
  return "";
}
```

`entry` is the desktop app represented by this row.

`selected` is true when this row matches `root.selected_index`.

`secondary` is extra text shown on the right side of the row. Currently it uses
`entry.genericName` if available.

Example:

```text
app_name: Firefox
app_meta: Web Browser
```

If there is no generic name, `app_meta` becomes invisible through opacity.

### Row Background

```qml
Rectangle {
  anchors.fill: parent
  radius: 13
  color: app_row.selected
    ? Theme.c.magenta
    : (row_area.containsMouse ? Theme.c.black : "transparent")
  border.width: app_row.selected ? 0 : (row_area.containsMouse ? 1 : 0)
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

The `MouseArea` makes rows interactive.

On mouse movement:

```qml
onPositionChanged: (mouse) => {
  var global = row_area.mapToItem(null, mouse.x, mouse.y);
  if (global.x !== root.last_pointer.x || global.y !== root.last_pointer.y) {
    root.last_pointer = Qt.point(global.x, global.y);
    root.selected_index = app_row.index;
  }
}
```

This selects the row only when the pointer really moved.

Why this matters:

```text
1. Mouse is resting over row 3.
2. User presses Down on the keyboard.
3. Without the last_pointer check, hover handling could immediately force
   selection back to row 3.
4. With the check, keyboard navigation is not overridden unless the mouse moves.
```

On click:

```qml
onClicked: {
  root.selected_index = app_row.index;
  root.activate();
}
```

Clicking a row selects it and launches it.

### Icon Background And Icon

```qml
Rectangle {
  id: icon_bg
  width: 28
  height: 28
  radius: 8
  color: app_row.selected
    ? Qt.rgba(0.06, 0.06, 0.07, 0.35)
    : Theme.c.black
}
```

The icon sits inside a small rounded rectangle.

When the row is selected, the icon background becomes semi-transparent dark so
it still works on the magenta selected row.

```qml
Image {
  id: app_icon
  anchors.centerIn: icon_bg
  width: 23
  height: 23
  sourceSize.width: 46
  sourceSize.height: 46
  fillMode: Image.PreserveAspectFit
  asynchronous: true
  smooth: true
  source: app_row.entry && app_row.entry.icon
    ? Quickshell.iconPath(app_row.entry.icon, true)
    : ""
}
```

The image source uses the app's desktop icon name and asks Quickshell to resolve
it to an icon path.

Example:

```text
entry.icon = "firefox"
Quickshell.iconPath("firefox", true)
```

`asynchronous: true` keeps icon loading from blocking the UI.

`fillMode: Image.PreserveAspectFit` keeps the icon from stretching.

### App Name

```qml
Text {
  id: app_name
  text: app_row.entry ? app_row.entry.name : ""
  color: app_row.selected ? Theme.c.bg : Theme.c.fg
  font.bold: app_row.selected
  elide: Text.ElideRight
}
```

This is the main app label.

When selected, the text switches to `Theme.c.bg` for contrast against the
magenta row background.

`elide: Text.ElideRight` prevents long app names from overflowing.

Example:

```text
Very Long Application Name That Does Not Fit
```

may render as:

```text
Very Long Application Name...
```

### App Metadata

```qml
Text {
  id: app_meta
  width: Math.min(130, implicitWidth)
  text: app_row.secondary
  color: app_row.selected ? Theme.c.bg : Theme.c.black2
  opacity: app_row.secondary.length > 0 ? 0.85 : 0
  horizontalAlignment: Text.AlignRight
  elide: Text.ElideRight
}
```

This is the secondary label on the right.

It shows `entry.genericName`, such as:

```text
Web Browser
Text Editor
Terminal Emulator
```

The width is capped at 130 pixels so metadata does not steal too much space from
the app name.

If there is no metadata, opacity is set to `0`.

## Full Example: Typing And Launching Firefox

```text
1. Launcher opens.
2. onActiveChanged clears the query and focuses search_field.
3. User types "fire".
4. search_field.onTextChanged sets root.query = "fire".
5. root.results recalculates with Fuzzy.rank(...).
6. ListView redraws using the new result count.
7. selected_index is reset to 0.
8. User presses Enter.
9. root.activate() reads root.results[0].
10. Usage count for that app id increases by 1.
11. usage_store writes launcher-usage.json.
12. entry.execute() launches Firefox.
13. root.request_close() closes the launcher.
```

## Full Example: Mouse Launch

```text
1. User opens the launcher.
2. User moves the mouse over the "Files" row.
3. row_area.onPositionChanged updates root.selected_index.
4. The row background becomes magenta.
5. User clicks the row.
6. onClicked sets selected_index again and calls root.activate().
7. Files launches and the launcher closes.
```

## Full Example: Usage-Based Sorting

Assume the usage file contains:

```json
{
  "firefox.desktop": 10,
  "code.desktop": 4,
  "org.gnome.Nautilus.desktop": 1
}
```

When the query is empty, apps with higher usage appear earlier.

Example order:

```text
Firefox
Visual Studio Code
Files
Other apps alphabetically...
```

If the user launches Files several times, its count increases and it can move up
the default list the next time the launcher opens.

## Important Identifiers

```text
root.query
  Current search text.

root.selected_index
  Index of the highlighted item in root.results.

root.usage
  App launch counts loaded from launcher-usage.json.

root.all_entries
  Visible desktop apps from Quickshell.

root.results
  Ranked and filtered apps shown in the ListView.

usage_store
  FileView used to read and write launcher-usage.json.

search_field
  TextField that receives keyboard input.

app_list
  ListView that displays search results.

app_row.entry
  Desktop entry for a single row.

app_row.selected
  Whether the row is currently highlighted.
```

## Summary

`Launcher.qml` is reactive: the UI follows a small set of state properties.
Typing changes `root.query`, which updates `root.results`, which updates the
`ListView`. Moving the selection changes `root.selected_index`, which updates row
highlighting. Launching an app updates `root.usage`, writes it to disk, executes
the desktop entry, and closes the surface.

The result is a compact app launcher with:

- Fuzzy app search.
- Keyboard navigation.
- Mouse hover and click support.
- Usage-based sorting.
- Persistent launch history.
- Themed styling through `Theme` and `Motion`.
