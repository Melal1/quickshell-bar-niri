# Clipboard And Cliphist Explanation

`Clipboard.qml` is the clipboard manager surface for this Quickshell setup.
It shows clipboard history from `Cliphist.qml`, lets the user search and filter
entries, previews the selected item, and can copy, delete, refresh, or wipe the
history.

`Cliphist.qml` is the backend singleton. It talks to the external `cliphist`,
`wl-paste`, and `wl-copy` commands and exposes parsed clipboard entries to QML.

The important idea is this data flow:

```text
wl-paste --watch sh -c 'cliphist store; echo x'
  -> Cliphist.refresh()
  -> cliphist list
  -> Cliphist.parse_line(...)
  -> Cliphist.entries
  -> Clipboard.results
  -> ListView rows and preview panel
```

When the clipboard history changes, `Cliphist.entries` changes. Because
`Clipboard.results` is a readonly property bound to `Cliphist.entries`, the UI
updates automatically.

## File Structure

The clipboard feature is split into these main parts:

1. `Cliphist.qml`
2. `Clipboard.qml`

`Cliphist.qml` contains:

1. Singleton state.
2. Refresh, copy, remove, and wipe functions.
3. `cliphist list` parsing.
4. A background `wl-paste` watcher.
5. Processes for `cliphist list`, `cliphist delete`, and `cliphist wipe`.

`Clipboard.qml` contains:

1. Imports and the `PillSurface` root.
2. Clipboard UI state.
3. Search and type filtering.
4. Helpers for titles, subtitles, text previews, image previews, selection, copy,
   and delete.
5. Open and result-change handlers.
6. Header, search box, filter combo, list panel, and preview panel.
7. Action buttons for copy, delete, refresh, and wipe.

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

`pragma Singleton` makes `Cliphist` available as shared state. `Clipboard.qml`
does not create its own backend; it reads and calls the singleton directly:

```qml
var all = Cliphist.entries;
Cliphist.copy(root.selected_item);
```

`QtQuick` provides base QML types such as `Timer`.

`Quickshell` provides `Quickshell.execDetached(...)`, used for copy actions.

`Quickshell.Io` provides `Process`, `SplitParser`, and `StdioCollector`, used
to run external commands and collect their output.

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

`count` is the number of loaded entries. `Clipboard.qml` displays it alongside
the filtered count:

```qml
root.results.length + " / " + Cliphist.count
```

Example:

```text
4 / 22
```

That means the current search and filter show 4 entries out of 22 total
clipboard entries.

`pending` remembers that a refresh was requested while another clipboard command
was already running.

`manage_store` controls whether this singleton starts its own clipboard watcher:

```qml
property bool manage_store: true
```

If another service already runs `wl-paste --watch cliphist store`, set this to
`false` to avoid duplicate watchers.

`delete_queue` stores entry ids waiting to be deleted. Deletes are serialized so
multiple quick delete actions do not overlap.

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

`refresh()` starts `cliphist list` when no list or delete operation is already in
progress.

If the backend is busy, it sets `pending` instead. After the current operation
finishes, the pending refresh runs on the next event-loop pass:

```qml
if (root.pending) {
  root.pending = false
  Qt.callLater(root.refresh)
}
```

This keeps process calls from overlapping while still making sure the visible
history catches up.

## Copying An Entry

```qml
function copy(entry) {
  if (!entry || !/^\d+$/.test(String(entry.id))) return
  Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "_", String(entry.id)])
}
```

`copy(entry)` restores a history entry to the current Wayland clipboard.

The id is validated first. Only numeric `cliphist` ids are accepted.

Then the id is piped through:

```sh
cliphist decode | wl-copy
```

`cliphist decode` reconstructs the original clipboard content, and `wl-copy`
writes it into the active clipboard.

## Removing And Wiping

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

`remove(entry)` updates the UI immediately by removing the entry from
`Cliphist.entries`, then queues the real `cliphist delete` command.

`pump_deletes()` runs one delete process at a time:

```qml
delete_proc.command = ["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "_", id]
delete_proc.running = true
```

When the queue is empty, `Cliphist.refresh()` reloads the real database.

`wipe()` clears the visible entries immediately and runs:

```sh
cliphist wipe
```

After the wipe process exits, the singleton refreshes again.

## Parsing cliphist Output

```qml
function parse_line(line) {
  var tab = line.indexOf("\t")
  if (tab < 1) return null

  var id = line.substring(0, tab)
  if (!/^\d+$/.test(id)) return null

  var preview = line.substring(tab + 1)
  ...
}
```

`cliphist list` outputs one entry per line. Each valid line starts with a numeric
id, then a tab, then a preview.

Example:

```text
42    copied text
```

The parser returns `null` for malformed lines. That keeps broken output from
reaching the UI.

Binary entries are detected from `cliphist` preview text:

```qml
var binary = /^\[\[ binary data (.*) \]\]$/.exec(preview)
```

If the metadata looks like an image format, the entry gets:

```js
isImage: true
```

`Clipboard.qml` uses that flag for the Images filter and the `IMG` badge.

## Clipboard.qml

### Imports And Surface

```qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PillSurface {
  id: root
```

`Clipboard.qml` is rendered inside `PillSurface`, the same surface system used by
the launcher. The file defines the content inside the pill; it does not create
the outer shell window.

`QtQuick.Controls` provides `TextField`, `ComboBox`, `ScrollBar`, and `TextArea`.

`QtQuick.Layouts` provides `RowLayout` and `ColumnLayout` for the two-panel
clipboard layout.

## Clipboard State

```qml
property string query: ""
property int selected_index: 0
property int filter_index: 0
property string image_preview_source: ""
property string image_preview_path: ""
property string image_preview_id: ""
property int image_preview_token: 0
property bool image_preview_loading: false
property bool image_preview_pending: false
```

`query` is the current search text.

`selected_index` is the highlighted row in `root.results`.

`filter_index` follows the filter combo:

```text
0 = All
1 = Text
2 = Images
```

The image preview properties track decoded temporary files for selected image
entries. `cliphist list` only exposes metadata for images, so `Clipboard.qml`
decodes the selected image before an `Image` item can display it.

## Results

```qml
readonly property var results: {
  var out = [];
  var q = root.query.trim().toLowerCase();
  var all = Cliphist.entries;
  ...
  return out;
}
```

`results` is the list displayed by `ListView`.

It depends on:

- `Cliphist.entries`
- `root.query`
- `root.filter_index`

The filter first checks type:

```qml
if (root.filter_index === 1 && isBinary) continue;
if (root.filter_index === 2 && !isImage) continue;
```

Then it searches across the preview and metadata:

```qml
var haystack = [
  entry.preview || "",
  entry.label || "",
  entry.meta || "",
  entry.sizeLabel || ""
].join(" ").toLowerCase();
```

Text search is simple substring matching. Unlike `Launcher.qml`, the clipboard
does not use fuzzy ranking because clipboard entries are already ordered by
recency from `cliphist`.

## Selected Item

```qml
readonly property var selected_item:
  selected_index >= 0 && selected_index < results.length ? results[selected_index] : null
```

`selected_item` is the entry shown in the preview panel and used by the action
buttons.

The bounds check prevents invalid access when a search or filter change makes
the result list shorter.

## Helper Functions

### icon_text

```qml
function icon_text(entry) {
  if (!entry) return "T";
  if (entry.isImage) return "IMG";
  if (entry.meta && entry.meta.length > 0) return "BIN";
  return "T";
}
```

This returns the short badge shown on rows and in the preview header.

### title

```qml
function title(entry) {
  if (!entry) return "";
  if (entry.isImage) return entry.label && entry.label.length > 0 ? entry.label : "Image";
  if (entry.meta && entry.meta.length > 0) return entry.label && entry.label.length > 0 ? entry.label : "Binary data";

  var text = String(entry.preview || "").replace(/\s+/g, " ").trim();
  return text.length > 0 ? text : "Empty text";
}
```

Text entries use a compact one-line version of `entry.preview`.

Image and binary entries use parsed metadata from `Cliphist.parse_line(...)`.

### preview

```qml
function preview(entry) {
  if (!entry) return "";
  if (entry.isImage) return "";
  if (entry.meta && entry.meta.length > 0) {
    var label = entry.isImage ? "Image clipboard item" : "Binary clipboard item";
    return label + "\n\n" + entry.meta;
  }

  return String(entry.preview || "");
}
```

Text entries show their preview directly.

Image entries return an empty text preview because they are handled by the image
preview process.

Non-image binary entries cannot be displayed as raw content in this UI, so the
preview panel shows their metadata.

### Previews (Image and Text)

```qml
function update_image_preview() {
  image_preview_source = "";
  image_preview_path = "";
  image_preview_id = "";
  image_preview_loading = false;

  var entry = root.selected_item;
  if (!entry || !entry.isImage || !/^\d+$/.test(String(entry.id))) return;

  image_preview_token += 1;
  image_preview_id = String(entry.id);
  image_preview_path = "/tmp/quickshell-cliphist-preview-" + image_preview_id;
  image_preview_loading = true;
  image_preview_proc.command = ["sh", "-c", "...", "_", image_preview_id, image_preview_path];
  image_preview_proc.running = true;
}
```

Image previews are generated on demand for the selected row.

The command decodes the selected `cliphist` id into a file under `/tmp`. It uses
a unique `.tmp` file while decoding, then moves that into the stable preview path
for the selected id. It only prints the path back to QML if the file exists and is non-empty.
That prevents zero-byte or failed decodes from being handed to the Qt `Image`
item.

The process output is collected here:

```qml
Process {
  id: image_preview_proc
  stdout: StdioCollector {
    onStreamFinished: {
      var path = this.text.trim();
      root.image_preview_loading = false;

      if (path.length > 0 && root.selected_item && root.selected_item.isImage && String(root.selected_item.id) === root.image_preview_id && path === root.image_preview_path) {
        root.image_preview_source = "file://" + path;
      }
    }
  }
}
```

The id and path checks make sure an older decode result does not replace the
preview after the user has selected a different row.

Preview decoding is requested from three places:

- When `selected_index` changes.
- When `results` changes.
- When `Cliphist.entries` changes.

The last trigger matters because a refresh can replace the selected entry object
without changing `selected_index`. Without that hook, the first selected image
could wait until the user manually hit Refresh before decoding.

The decode request is debounced through a short `Timer`, and if a decode process
is already running, `image_preview_pending` records that another preview should
start afterward.

## Selection And Actions

```qml
function move_selection(delta) {
  if (root.results.length === 0) return;
  select_item(Math.max(0, Math.min(root.results.length - 1, selected_index + delta)));
}
```

Selection is clamped between the first and last result.

```qml
function copy_selected() {
  if (!root.selected_item) return;
  Cliphist.copy(root.selected_item);
  root.request_close();
}
```

Copying delegates to `Cliphist.copy(...)` and then closes the surface.

```qml
function remove_selected() {
  if (!root.selected_item) return;
  Cliphist.remove(root.selected_item);
}
```

Deleting delegates to `Cliphist.remove(...)`. The singleton removes the entry
from the visible list immediately and then runs the backend delete.

## Open And Result Handlers

```qml
onActiveChanged: {
  if (active) {
    reset_view();
    Cliphist.refresh();
    Qt.callLater(function() { search_field.forceActiveFocus(); });
  }
}
```

When the clipboard surface opens, it clears the search, scrolls to the top,
refreshes history, and focuses the search field.

```qml
onResultsChanged: {
  if (selected_index >= results.length) {
    selected_index = 0;
  }
}
```

When filtering changes the result length, this keeps the selected index valid.

Image preview refreshes are triggered when the selected index changes and after
the result list changes:

```qml
onSelected_indexChanged: update_image_preview()
```

## User Interaction

Keyboard behavior:

- `Up` / `Down`: move selection.
- `Ctrl-P` / `Ctrl-K`: move selection up.
- `Ctrl-N` / `Ctrl-J`: move selection down.
- `Enter`: copy the selected entry back to the clipboard and close.
- `Delete`: delete the selected entry from history.
- `Escape`: close the surface.

Mouse behavior:

- Click a row to select it.
- Double-click a row to copy it and close.
- Use the action buttons to copy, delete, refresh, or wipe.

## UI Layout

The visible surface has three main areas:

1. Header row with back button, search field, and filter combo.
2. Count row showing filtered count and total `Cliphist.count`.
3. Content row with the history list on the left and preview/actions on the
   right.

The older recent-related panel has been removed. The right side is now dedicated
to the selected item preview and clipboard actions.

The action buttons are explicitly height-constrained to 38 pixels:

```qml
Layout.preferredHeight: 38
Layout.minimumHeight: 38
Layout.maximumHeight: 38
```

That keeps Copy, Delete, Refresh, and Wipe as a compact footer instead of letting
them stretch into the preview area.

## Dependencies

This feature expects these external commands to exist:

```sh
cliphist
wl-paste
wl-copy
```

Without them, the QML surface can still load, but the backend cannot store,
list, restore, or mutate clipboard history.

## Recent UI Improvements

Recent updates have improved the clipboard behavior and UI:
- **Full Text Previews**: Instead of relying on `cliphist list`'s truncated previews, `Clipboard.qml` now dynamically fetches the full text of an item using `cliphist decode` via a background process (`text_preview_proc`).
- **Clean Animations**: The closing animation no longer leaves items sticking out of the shrinking surface. This was achieved by adding `clip: true` to the root `ColumnLayout` and setting a very fast fade out (`Motion.v_fast`) in `PillSurface.qml` when closing.
- **Robust Keyboard Shortcuts**: Keyboard shortcuts like `Ctrl-J` and `Ctrl-K` now use bitwise AND (`event.modifiers & Qt.ControlModifier`) instead of strict equality, ensuring they still work if `NumLock` or `CapsLock` is active.
- **Refined Preview Layout**: The repetitive icon and title header above the text/image preview area was removed to give more space to the actual content.
- **Improved Readability**: Font sizes across the entire clipboard UI were increased by 4 pixels.
