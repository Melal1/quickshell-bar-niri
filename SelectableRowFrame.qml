import QtQuick

Item {
  id: root

  default property alias content: content_layer.data

  property bool selected: false
  property color selected_color: Qt.alpha(Theme.c.fg, 0.10)
  property color hover_color: Qt.alpha(Theme.c.fg, 0.06)
  property color normal_color: "transparent"
  property color bar_color: Theme.c.cyan2
  property real frame_border_width: 0
  property color frame_border_color: Theme.c.black2
  property real frame_radius: 10
  property real horizontal_margin: 0
  property bool show_selected_bar: true
  property int bar_left_margin: 2
  property real bar_vertical_offset: 0
  readonly property bool hovered: row_area.containsMouse

  signal clicked(var mouse)
  signal doubleClicked(var mouse)
  signal pointerMoved(var mouse)
  signal entered()
  signal exited()

  Rectangle {
    id: bg
    anchors.fill: parent
    anchors.leftMargin: root.horizontal_margin
    anchors.rightMargin: root.horizontal_margin
    radius: root.frame_radius
    color: root.selected ? root.selected_color : (row_area.containsMouse ? root.hover_color : root.normal_color)
    border.width: root.frame_border_width
    border.color: root.frame_border_color

    Behavior on color {
      ColorAnimation { duration: Motion.fast }
    }
  }

  MouseArea {
    id: row_area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: (mouse) => root.clicked(mouse)
    onDoubleClicked: (mouse) => root.doubleClicked(mouse)
    onPositionChanged: (mouse) => root.pointerMoved(mouse)
    onEntered: root.entered()
    onExited: root.exited()
  }

  Item {
    id: content_layer
    anchors.fill: parent
  }

  Rectangle {
    anchors.left: parent.left
    anchors.leftMargin: root.bar_left_margin
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: root.bar_vertical_offset
    width: 3
    height: parent.height * 0.55
    radius: width / 2
    color: root.bar_color
    opacity: root.show_selected_bar && root.selected ? 1 : 0

    Behavior on opacity {
      NumberAnimation { duration: Motion.fast }
    }
  }
}
