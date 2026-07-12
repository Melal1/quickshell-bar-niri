pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property int current: 0
  property int maximum: 1
  readonly property real value: maximum > 0 ? current / maximum : 0
  readonly property int percent: Math.round(value * 100)
  property bool available: false
  readonly property string device_path: "/sys/class/backlight/" + Settings.backlight_device
  property bool current_loaded: false
  property bool max_loaded: false

  function refresh() {
    current_file.reload()
    max_file.reload()
  }

  function update_available() {
    available = current_loaded && max_loaded && maximum > 0
  }

  FileView {
    id: current_file
    path: root.device_path + "/brightness"
    blockLoading: true
    printErrors: false
    watchChanges: true

    onFileChanged: reload()

    onLoaded: {
      var parsed = parseInt(text().trim())
      if (!isNaN(parsed)) {
        root.current = parsed
        root.current_loaded = true
      }
      root.update_available()
    }
  }

  FileView {
    id: max_file
    path: root.device_path + "/max_brightness"
    blockLoading: true
    printErrors: false
    watchChanges: true

    onFileChanged: reload()

    onLoaded: {
      var parsed = parseInt(text().trim())
      if (!isNaN(parsed) && parsed > 0) {
        root.maximum = parsed
        root.max_loaded = true
      }
      root.update_available()
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
