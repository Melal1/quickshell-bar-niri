import QtQuick

Item {
  id: root

  default property alias content: inner_rect.data

  required property color top_color
  required property color bottom_color
  required property color body_color
  property bool running: true
  property int duration: 3000

  property int radius: 0
  property int border_w: 1

  Rectangle {
    anchors.fill: parent
    radius: root.radius

    gradient: Gradient {
      GradientStop {
        position: 0.0
        color: root.top_color

        SequentialAnimation on color {
          running: root.running;
          loops: Animation.Infinite
          ColorAnimation {
            to: root.bottom_color;
            duration: root.duration;
            easing.type: Easing.Linear
          }
          ColorAnimation {
            to: root.top_color;
            duration: root.duration;
            easing.type: Easing.Linear
          }
        }
      }
      GradientStop {
        position: 1.0
        color: root.bottom_color

        SequentialAnimation on color {
          running: root.running;
          loops: Animation.Infinite
          ColorAnimation {
            to: root.top_color;
            duration: root.duration;
            easing.type: Easing.Linear
          }

          ColorAnimation {
            to: root.bottom_color;
            duration: root.duration;
            easing.type: Easing.Linear
          }
        }
      }
    }

    Rectangle {
      id: inner_rect
      anchors.fill: parent
      anchors.margins: root.border_w

      radius: Math.max(0, root.radius - root.border_w)

      color: root.body_color
    }
  }
}
