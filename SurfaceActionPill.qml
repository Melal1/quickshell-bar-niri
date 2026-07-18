import QtQuick

Rectangle {
  id: root

  property string text: ""
  property bool active: false
  property color active_color: Theme.c.cyan
  property color active_border_color: Theme.c.cyan2
  property color inactive_color: Theme.c.bg
  property color hover_color: Qt.alpha(Theme.c.white, 0.15)
  property color inactive_border_color: Qt.alpha(Theme.c.white, 0.15)
  property color hover_border_color: Theme.c.cyan2
  property color active_text_color: Theme.c.bg
  property color inactive_text_color: Theme.c.cyan2
  property color hover_text_color: inactive_text_color
  property string font_family: Theme.clock_font
  property int font_size: 14
  property int horizontal_padding: 28

  readonly property bool hovered: action_area.containsMouse

  signal clicked()

  height: 30
  width: label.implicitWidth + horizontal_padding
  radius: 999
  color: active ? active_color : (action_area.containsMouse ? hover_color : inactive_color)
  border.width: 1
  border.color: active ? active_border_color : (action_area.containsMouse ? hover_border_color : inactive_border_color)

  Behavior on width {
    NumberAnimation { duration: Motion.v_fast; easing.type: Motion.std_ease }
  }
  Behavior on color {
    ColorAnimation { duration: Motion.fast }
  }
  Behavior on border.color {
    ColorAnimation { duration: Motion.fast }
  }

  Text {
    id: label
    anchors.centerIn: parent
    text: root.text
    color: root.active ? root.active_text_color : (action_area.containsMouse ? root.hover_text_color : root.inactive_text_color)
    font.family: root.font_family
    font.pixelSize: root.font_size
    font.bold: true

    Behavior on color {
      ColorAnimation { duration: Motion.fast }
    }
  }

  MouseArea {
    id: action_area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
