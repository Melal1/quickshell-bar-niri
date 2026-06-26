import QtQuick
import Quickshell
import Quickshell.Io

// Atomic prayer status display.
// Set `active: true` to start watching the file; false to stop.

Text {
  id: root
  property bool active: false

  readonly property bool hasStatus: fileView.text().trim() !== ""

  text: fileView.text().trim()
  color: Theme.c.black2
  font.bold: true
  font.family: Theme.clock_font
  font.pixelSize: 15

  FileView {
    id: fileView
    path: "/dev/shm/prayer_status"
    watchChanges: root.active
    onFileChanged: this.reload()
  }
}
