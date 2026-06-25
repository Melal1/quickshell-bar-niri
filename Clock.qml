import Quickshell
import QtQuick
import Quickshell.Io

Item {
  id:root
  required property real s
  required property bool is_hovering
  Text {
    id: time_text

    text:Qt.formatDateTime(clock.date, "hh:mm AP")
    color:"#D7D7D7"
    font.bold: true
    font.family: "Liberation Sans"
    font.pixelSize: 24
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    readonly property real size : Consts.rest_h * s
    anchors.topMargin: (size + (is_hovering ? size * 0.2 : 0 )  - height) / 2
    scale: is_hovering ? 2.0 : 1.0
    transformOrigin: Item.Top

    Behavior on scale {
      NumberAnimation {
        duration: Motion.morph
        easing.type: Motion.custom
        easing.bezierCurve: Motion.morphCurve
      }
    }

    Behavior on anchors.topMargin {
      NumberAnimation {
        duration: Motion.slow
        easing.type: Motion.std_ease
      }
    }

    SystemClock {
      id: clock
      precision: SystemClock.Minutes
    }
  }
  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: time_text.bottom
    anchors.topMargin:time_text.height * (time_text.scale -1 )+ 5
    spacing: 10
    id: date_athan_row
    readonly property int font_size : 15

    opacity: is_hovering ? 1 : 0
    scale: is_hovering ? 1 : 0.5

    Behavior on opacity {
      NumberAnimation {
        duration: Motion.fast
        easing.type: Motion.std_ease
      }
    }
    Behavior on scale {
      NumberAnimation {
        duration: Motion.fast
        easing.type: Motion.std_ease
      }
    }
    Text {
      text:Qt.formatDateTime(clock.date, "ddd MMM dd")
      color:"gray"
      font.bold: true
      font.family: "Liberation Sans"
      font.pixelSize: date_athan_row.font_size

    }
    Text {
      visible: ath.on
      text:"|"
      color:"gray"
      font.bold: true
      font.family: "Liberation Sans"
      font.pixelSize: date_athan_row.font_size
    }
    Text {
      visible: ath.on
      text: ath.text()
      color:"gray"
      font.bold: true
      font.family: "Liberation Sans"
      font.pixelSize: date_athan_row.font_size

    }
    FileView {
      id:ath
      property bool on: this.text().trim() !== ""
      path:"/dev/shm/prayer_status"
      onFileChanged: this.reload()
      watchChanges:is_hovering
    }

  }

}
