import QtQuick

Item {
  id: root

  property real value: 0
  property bool disabled: false

  // The two merging colors for the normal volume bar
  property color active_col: "#8B8888"
  property color active_secondary_col: Qt.lighter(active_col, 1.6) // Defaults to a lighter version, but you can override!

  // The two merging colors for the overdrive bar (> 100%)
  property color overdride_col: "#BD6161"
  property color overdrive_secondary_col: Qt.lighter(overdride_col, 1.5)

  // Muted colors (these don't merge, they just go dark)
  property color muted_col: "#4A4A4A"
  property color disabled_overdrive_col: "#272727"

  property string icon: ""
  property real _anim_value: value

  Behavior on _anim_value {
    SmoothedAnimation {
      velocity: 2.5
      duration: 250
      easing.type: Easing.OutCirc
    }
  }

  Text {
    id: percentText
    width: 40
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    color: "white"
    font.bold: true
    font.family: "Liberation Sans"
    font.pixelSize: 16
    text: disabled ?"off":Math.round(root._anim_value * 100) + "%"
  }

  Text {
    id:icon_t
    width: 20
    anchors.right: parent.left
    anchors.verticalCenter: parent.verticalCenter
    color: "white"
    font.bold: true
    font.family: "Agave Nerd Font Propo"
    font.pixelSize: 20
    visible: icon !== ""
    text:icon
  }

  Rectangle {
    id: base
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.right: percentText.left
    anchors.rightMargin: 15
    anchors.leftMargin: 15
    height: parent.height / 5
    color: "#292828"
    radius: 50

    Rectangle {
      radius: parent.radius
      anchors { bottom: parent.bottom; left: parent.left; top: parent.top }
      width: root._anim_value > 1 ? parent.width : Math.min(parent.width, parent.width * root._anim_value)

      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: root.disabled ? root.muted_col : root.active_col }
        GradientStop {
          id: main_slosh
          position: 0.5
          // Uses your new custom secondary color!
          color: root.disabled ? root.muted_col : root.active_secondary_col
        }
        GradientStop { position: 1.0; color: root.disabled ? root.muted_col : root.active_col }
      }

      SequentialAnimation {
        running: !root.disabled
        loops: Animation.Infinite
        NumberAnimation { target: main_slosh; property: "position"; to: 0.0; duration: 2000; easing.type: Easing.InOutSine }
        NumberAnimation { target: main_slosh; property: "position"; to: 1.0; duration: 2000; easing.type: Easing.InOutSine }
      }
    }

    Rectangle {
      radius: base.radius
      anchors { bottom: base.bottom; left: base.left; top: base.top }
      width: root._anim_value < 1 ? 0 : Math.min(base.width, base.width * (root._anim_value - 1))

      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: root.disabled ? root.disabled_overdrive_col : root.overdride_col }
        GradientStop {
          id: red_slosh
          position: 0.5
          // Uses your new custom secondary overdrive color!
          color: root.disabled ? root.disabled_overdrive_col : root.overdrive_secondary_col
        }
        GradientStop { position: 1.0; color: root.disabled ? root.disabled_overdrive_col : root.overdride_col }
      }

      SequentialAnimation {
        running: !root.disabled && root._anim_value > 1
        loops: Animation.Infinite
        NumberAnimation { target: red_slosh; property: "position"; to: 0.0; duration: 1200; easing.type: Easing.InOutSine }
        NumberAnimation { target: red_slosh; property: "position"; to: 1.0; duration: 1200; easing.type: Easing.InOutSine }
      }
    }
  }
}
