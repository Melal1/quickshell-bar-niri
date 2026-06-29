pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property bool active: true
  property bool has_status: false
  property string text: ""

  FileView {
    id: file_v
    path: "/dev/shm/prayer_status"
    watchChanges: root.active
    onFileChanged: {
      file_v.reload();
    }
    onLoaded: {
      let content = file_v.text().trim();
      root.text = content;
      root.has_status = content !== "";
    }
    Component.onCompleted: {
      file_v.reload();
    }
  }
}
