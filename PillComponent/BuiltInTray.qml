import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../"

Item {
  id: root

  required property var bar_win

  signal interaction_started()
  signal interaction_ended()
  readonly property bool has_items: SystemTray.items.values.length > 0
  visible: has_items

  implicitWidth: tray.implicitWidth
  implicitHeight: tray.implicitHeight

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
      radius: tray.radius - 3.33
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

    implicitWidth: Math.min(systray.implicitWidth + 21.67, max_w)
    implicitHeight: systray.implicitHeight + 11.67
    anchors.fill: parent
    radius: 15
    clip: true

    HoverHandler {
      id: tray_hover
    }

    Flickable {
      anchors.fill: parent
      anchors.leftMargin: 6.67

      contentWidth: systray.implicitWidth
      contentHeight: parent.height
      flickableDirection: Flickable.HorizontalFlick

      Tray {
        id: systray

        bar_win: root.bar_win

        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -3

        onMenu_opened: {
          root.interaction_started()
        }

        onMenu_closed: {
          root.interaction_ended()
        }
      }
    }
  }
}
