import QtQuick

/**
 * Small horizontal battery level bar. The track is a soft cream-alpha line;
 * the fill is a flat color that depends on the level: green at 80%+, cyan at
 * 50%+, yellow at 20%+, red below 20%. Used next to connected Bluetooth
 * devices that report battery (headphones, controllers, etc.).
 */
Item {
  id: root

  property real level: 0

  readonly property color fill_color:
    level >= 0.8 ? Theme.c.green
    : level >= 0.5 ? Theme.c.cyan
    : level >= 0.2 ? Theme.c.yellow
    : Theme.c.red

  implicitWidth: 22
  implicitHeight: 4

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    height: 3
    radius: height / 2
    color: Qt.alpha(Theme.c.fg, 0.13)
  }

  Rectangle {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: parent.width * Math.max(0, Math.min(1, root.level))
    radius: height / 2
    color: root.fill_color

    Behavior on color {
      ColorAnimation { duration: Motion.fast }
    }
  }
}
