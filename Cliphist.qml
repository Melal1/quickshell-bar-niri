pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property var entries: []
  readonly property int count: entries.length
  property bool pending: false

  // Set this false if you already run `wl-paste --watch cliphist store` elsewhere.
  property bool manage_store: true

  function refresh() {
    if (list_proc.running || delete_proc.running || delete_queue.length) {
      pending = true
      return
    }

    list_proc.running = true
  }

  function copy(entry) {
    if (!entry || !/^\d+$/.test(String(entry.id))) return
    Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "_", String(entry.id)])
  }

  function wipe() {
    entries = []
    wipe_proc.running = true
  }

  property var delete_queue: []

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

  function pump_deletes() {
    if (delete_proc.running || delete_queue.length === 0) return

    var id = delete_queue.shift()
    delete_proc.command = ["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "_", id]
    delete_proc.running = true
  }

  function parse_line(line) {
    var tab = line.indexOf("\t")
    if (tab < 1) return null

    var id = line.substring(0, tab)
    if (!/^\d+$/.test(id)) return null

    var preview = line.substring(tab + 1)
    var meta = ""
    var label = ""
    var size_label = ""
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

    return {
      id: id,
      preview: preview,
      isImage: is_image,
      meta: meta,
      label: label,
      sizeLabel: size_label
    }
  }

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

  Timer {
    id: store_respawn
    interval: 2000
    onTriggered: store_watch.running = root.manage_store
  }

  Timer {
    id: refresh_debounce
    interval: 300
    onTriggered: root.refresh()
  }

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

        if (root.pending) {
          root.pending = false
          Qt.callLater(root.refresh)
        }
      }
    }
  }

  Process {
    id: delete_proc
    onExited: {
      if (root.delete_queue.length > 0) root.pump_deletes()
      else root.refresh()
    }
  }

  Process {
    id: wipe_proc
    command: ["cliphist", "wipe"]
    onExited: root.refresh()
  }

  Component.onCompleted: refresh()
}
