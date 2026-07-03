import QtQuick
import Quickshell.Services.Notifications
import "../"

Rectangle {
  id: root
  required property real sc
  signal leftClicked()

  anchors.verticalCenter: parent.verticalCenter
  width: 28 * root.sc
  height: 28 * root.sc
  radius: 14 * root.sc
  // color: notif_hover.containsMouse ? Theme.c.black : "transparent"
  color:"transparent"
  clip: true

  Behavior on color { ColorAnimation { duration: Motion.fast } }

  Text {
    id: icon_text
    anchors.centerIn: parent
    text:""
    color: Theme.c.fg
    font.pixelSize: 14 * root.sc

    SequentialAnimation {
      id: jiggle
      NumberAnimation { target: icon_text; property: "rotation"; to: -30; duration: 150 }
      NumberAnimation { target: icon_text; property: "rotation"; to: 30; duration: 150 }
      NumberAnimation { target: icon_text; property: "rotation"; to: -12; duration: 90 }
      NumberAnimation { target: icon_text; property: "rotation"; to: 12; duration: 90 }
      NumberAnimation { target: icon_text; property: "rotation"; to: 0; duration: 50 }
    }
  }

  // DND diagonal strikethrough
  Rectangle {
    id: dnd_line
    property real inset: 6 * root.sc
    property real diagonal: (parent.width - 2.2 * inset) * 1.414
    x: inset
    y: inset - height / 2
    width: NotificationsServer.dnd ? diagonal : 0
    height: 3 * root.sc
    radius: 1 * root.sc
    color: Theme.c.red
    rotation: 45
    transformOrigin: Item.Left
    border.width: 0.5
    border.color: Theme.c.bg

    Behavior on width {
      NumberAnimation { duration: Motion.fast; easing.type: Easing.InOutQuad }
    }
  }

  // Unread badge
  Rectangle {
    width: 12 * root.sc
    height: 12 * root.sc
    radius: 6 * root.sc
    color: Theme.c.red
    anchors.top: parent.top
    anchors.right: parent.right
    visible: NotificationsServer.unread > 0

    Text {
      anchors.centerIn: parent
      text: NotificationsServer.unread > 9 ? "9+" : NotificationsServer.unread
      color: Theme.c.bg
      font.pixelSize: 8 * root.sc
      font.bold: true
    }
  }

  MouseArea {
    id: notif_hover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: function(mouse) {
      if (mouse.button === Qt.LeftButton)
      root.leftClicked()
      else {
        NotificationsServer.dnd = !NotificationsServer.dnd
        jiggle.restart()
      }
    }
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    // onContainsMouseChanged:{
    //   if(containsMouse && !NotificationsServer.dnd)
    //   jiggle.restart()
    // }
  }
}
