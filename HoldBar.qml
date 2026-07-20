import QtQuick

/**
 * Hold-to-confirm progress bar. A text label sits on the left and a pill-shaped
 * track on the right fills from 0..1 as `progress` advances. The component
 * fades itself in when `active` becomes true and out when it goes false, so
 * callers can drive show/hide through a single boolean.
 *
 * The fill gradient and text color are properties — callers typically use
 * vermilion for destructive confirmations and any color for neutral progress
 * (e.g. the scan-active state of the bluetooth panel).
 */
Item {
  id: root

  property real progress: 0
  property bool active: false
  property string text: ""
  property color text_color: Theme.c.red2
  property color fill_start: Qt.alpha(Theme.c.red, 0.55)
  property color fill_end: Qt.alpha(Theme.c.red2, 0.55)

  implicitHeight: 24

  opacity: active ? 1 : 0
  visible: opacity > 0
  Behavior on opacity { NumberAnimation { duration: Motion.fast } }

  Text {
    id: hold_text
    anchors.left: parent.left
    anchors.leftMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    text: root.text
    color: root.text_color
    font.family: Theme.clock_font
    font.pixelSize: 13
    font.bold: true

    Behavior on color {
      ColorAnimation { duration: Motion.fast }
    }
  }

  Rectangle {
    id: hold_track
    anchors.left: hold_text.right
    anchors.leftMargin: 12
    anchors.right: parent.right
    anchors.rightMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    height: 6
    radius: height / 2
    color: Qt.alpha(Theme.c.fg, 0.13)
    clip: true

    Rectangle {
      id: hold_fill
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: parent.width * Math.max(0, Math.min(1, root.progress))
      radius: 999
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: root.fill_start }
        GradientStop { position: 1.0; color: root.fill_end }
      }
    }
  }
}
