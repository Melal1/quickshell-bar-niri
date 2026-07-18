import QtQuick

Rectangle {
  id: toggle

  property bool on: false
  property color on_color: Theme.c.red
  signal toggled()

  width: 36
  height: 20
  radius: height / 2

  color: toggle.on ? toggle.on_color : Theme.c.bg
  border.width: 1
  border.color: toggle.on ? toggle.on_color : Theme.c.black2

  Behavior on color {
    ColorAnimation { duration: Motion.fast }
  }
  Behavior on border.color {
    ColorAnimation { duration: Motion.fast }
  }

  Rectangle {
    id: knob
    width: 14
    height: 14
    radius: width / 2
    color: Theme.c.fg
    anchors.verticalCenter: parent.verticalCenter
    x: toggle.on ? toggle.width - width - 3 : 3
    Behavior on x {
      NumberAnimation { duration: Motion.fast; easing.type: Motion.std_ease }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: toggle.toggled()
  }
}
