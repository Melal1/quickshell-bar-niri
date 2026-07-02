import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../"

Item {
  id: root

  required property real sc
  required property var bar_win

  signal interactionStarted()
  signal interactionEnded()

  GRect {
    id: tray
    readonly property int max_w: 0.37 * Settings.hover_w
    body_color: Theme.c.black
    top_color: Theme.c.fg
    bottom_color: Theme.c.black2
    border_w: 3
    duration: 1500
    running: tray_hover.hovered
    Behavior on implicitWidth {
      NumberAnimation {
        duration:Motion.fast
        easing.type: Motion.std_ease
      }

    }

    Rectangle {
      anchors.centerIn: parent
      width: tray.width
      height: tray.height
      color: tray.body_color
      radius: tray.radius - 2 * root.sc
      opacity: !tray_hover.hovered ? 1 : 0
      Behavior on opacity {
        NumberAnimation { duration: Motion.std }
      }
      visible: opacity > 0
      Behavior on implicitWidth {
        NumberAnimation {
          duration:Motion.std
        }

      }
    }

    implicitWidth: Math.min(systray.implicitWidth + 13 * root.sc, max_w)
    implicitHeight: systray.implicitHeight + 7 * root.sc
    anchors.right: parent.right
    anchors.rightMargin: 15 * root.sc
    anchors.verticalCenter: parent.verticalCenter
    radius: 9 * root.sc
    clip: true

    HoverHandler {
      id: tray_hover
    }

    Flickable {
      anchors.fill: parent
      anchors.leftMargin: 4 * root.sc

      contentWidth: systray.implicitWidth
      contentHeight: parent.height
      flickableDirection: Flickable.HorizontalFlick

      Tray {
        id: systray
        sc: root.sc
        bar_win: root.bar_win

        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -3

        onMenu_opened: {
          root.interactionStarted()
        }

        onMenu_closed: {
          root.interactionEnded()
        }
      }
    }
  }
}
