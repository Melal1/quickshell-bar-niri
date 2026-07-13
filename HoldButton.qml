import QtQuick
import Quickshell.Widgets

Rectangle {
  id: root

  property color outer_color: Theme.c.magenta
  property color border_color: Theme.c.yellow
  property alias fill_gradient: fill_rect.gradient
  property alias border_w: root.border.width

  border.width: 3
  border.color: border_color
  color: outer_color
  radius: 10

  focus: true
  property bool is_holding: false
  property real _hold_progress: 0

  signal finished()

  onIs_holdingChanged: {
    if (is_holding) {
      drain_anim.stop();
      fill_anim.duration = 1500 * (1.0 - _hold_progress);
      fill_anim.start();
    } else {
      fill_anim.stop();
      drain_anim.duration = 1000 * _hold_progress;
      drain_anim.start();
    }
  }

  NumberAnimation {
    id: fill_anim
    target: root
    property: "_hold_progress"
    onFinished : {
      if (_hold_progress >= 1.0)
      root.finished();

    }
    to: 1.0
  }

  NumberAnimation {
    id: drain_anim
    target: root
    property: "_hold_progress"
    to: 0.0
  }

  ClippingRectangle {
    anchors.fill: parent
    anchors.margins: root.border.width
    radius: root.radius - root.border.width
    color: "transparent"

    Rectangle {
      id: fill_rect
      anchors {
        bottom: parent.bottom
        right: parent.right
        left: parent.left
      }

      height: root._hold_progress * parent.height

      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.lighter(Theme.c.cyan, 1.4) }
        GradientStop { position: 1.0; color: Theme.c.cyan }
      }
    }
  }
}
