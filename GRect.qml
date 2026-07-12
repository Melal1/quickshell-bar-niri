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

  // Use internal properties to allow smooth transitions when top/bottom colors change
  property color _anim_top: top_color
  property color _anim_bottom: bottom_color

  Behavior on _anim_top { ColorAnimation { duration: 400; easing.type: Easing.InOutQuad } }
  Behavior on _anim_bottom { ColorAnimation { duration: 400; easing.type: Easing.InOutQuad } }

  // Base gradient
  Rectangle {
    anchors.fill: parent
    radius: root.radius

    gradient: Gradient {
      GradientStop { position: 0.0; color: root._anim_top }
      GradientStop { position: 1.0; color: root._anim_bottom }
    }

    // Overlay gradient for the pulse effect
    Rectangle {
      anchors.fill: parent
      radius: root.radius
      opacity: 0

      gradient: Gradient {
        GradientStop { position: 0.0; color: root._anim_bottom }
        GradientStop { position: 1.0; color: root._anim_top }
      }

      SequentialAnimation on opacity {
        running: root.running
        loops: Animation.Infinite
        NumberAnimation { to: 1.0; duration: root.duration; easing.type: Easing.Linear }
        NumberAnimation { to: 0.0; duration: root.duration; easing.type: Easing.Linear }
      }
    }

    // Inner cutout
    Rectangle {
      id: inner_rect
      anchors.fill: parent
      anchors.margins: root.border_w
      radius: Math.max(0, root.radius - root.border_w)
      color: root.body_color
    }
  }
}
