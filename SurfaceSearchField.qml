import QtQuick
import QtQuick.Controls

TextField {
  id: root

  property color accent_color: Theme.c.cyan
  property color bg_color: Theme.c.black
  property color border_color: Theme.c.black2
  property color placeholder_color: Theme.c.black2
  property string font_family: Theme.clock_font
  property bool framed: true

  signal moveRequested(int delta)
  signal acceptRequested()
  signal escapeRequested()

  height: 50
  background: Rectangle {
    visible: root.framed
    radius: 13
    color: root.bg_color
    border.width: root.activeFocus ? 2 : 1
    border.color: root.activeFocus ? root.accent_color : root.border_color

    Behavior on border.color {
      ColorAnimation { duration: Motion.fast }
    }
  }
  color: Theme.c.fg
  selectedTextColor: Theme.c.bg
  selectionColor: accent_color
  placeholderTextColor: placeholder_color
  font.family: font_family
  font.pixelSize: 21

  Keys.onUpPressed: (event) => {
    root.moveRequested(-1);
    event.accepted = true;
  }
  Keys.onDownPressed: (event) => {
    root.moveRequested(1);
    event.accepted = true;
  }
  Keys.onReturnPressed: (event) => {
    root.acceptRequested();
    event.accepted = true;
  }
  Keys.onEnterPressed: (event) => {
    root.acceptRequested();
    event.accepted = true;
  }
  Keys.onEscapePressed: (event) => {
    root.escapeRequested();
    event.accepted = true;
  }
}
