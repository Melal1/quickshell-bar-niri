import QtQuick
import Quickshell.Services.Notifications
import "../"

Rectangle {
  id: root

  signal leftClicked()

  anchors.verticalCenter: parent.verticalCenter
  width: 36
  height: 35
  // color: notif_hover.containsMouse ? Theme.c.black : "transparent"
  color:"transparent"

  Behavior on color { ColorAnimation { duration: Motion.fast } }

  Text {
    id: icon_text
    anchors.centerIn: parent
    text:""
    color: Theme.c.fg
    font.pixelSize: 16

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
    property real inset: 10
    property real diagonal: (parent.width - 2.2 * inset) * 1.414
    x: inset
    y: inset - height / 2
    width: NotificationsServer.dnd ? diagonal : 0
    height: 3
    radius: 2
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
  // Rectangle {
  //   width: 18
  //   height: 18
  //   radius: 10
  //   color: Theme.c.red
  //   anchors.top: parent.top
  //   anchors.right: parent.right
  //   anchors {
  //     rightMargin:3
  //     topMargin: 3
  //
  //   }
  //   visible: NotificationsServer.unread > 0
  //
  //   Text {
  //     anchors.centerIn: parent
  //     anchors.verticalCenterOffset: 2
  //     text: NotificationsServer.unread > 9 ? "9+" : NotificationsServer.unread
  //     color: Theme.c.bg
  //     font.pixelSize: 12
  //     font.bold: true
  //   }
  // }

  MouseArea {
    id: notif_hover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked:  {
      NotificationsServer.dnd = !NotificationsServer.dnd
      jiggle.restart()
    }
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    // onContainsMouseChanged:{
    //   if(containsMouse && !NotificationsServer.dnd)
    //   jiggle.restart()
    // }
  }
}
