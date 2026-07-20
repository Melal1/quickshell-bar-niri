import QtQuick

Item {
  id: root
  required property real level
  required property bool show_text
  property bool  inside        : true
  property bool  charging      : false
  property alias border_col    : body.border.color
  property alias border_width  : body.border.width
  property alias body_width    : body.implicitWidth
  property alias body_height   : body.implicitHeight
  property alias body_radius   : body.radius
  property alias body_color    : body.color
  property alias fill_col      : fill.color
  property alias tip_width     : tip.implicitWidth
  property alias tip_height    : tip.implicitHeight
  property alias tip_col       : tip.color
  property alias text_col      : text_lbl.color
  property alias text_content  : text_lbl.text
  property real  gap           : 0

  property bool _switch_to_bolt: false
  onChargingChanged: {
    if(!charging) root._switch_to_bolt = false

  }

  Timer {
    running : charging
    interval: 5000
    repeat: true
    onTriggered: root._switch_to_bolt = !root._switch_to_bolt
  }

  implicitWidth : inside
  ? body.implicitWidth + tip.implicitWidth
  : text_lbl.implicitWidth + gap + body.implicitWidth + tip.implicitWidth
  implicitHeight: Math.max(body.implicitHeight, text_lbl.implicitHeight)

  Rectangle {
    id: body
    border.color    : Theme.c.white //
    border.width    : 2 //
    implicitWidth   : 36 //
    implicitHeight  : 24 //
    radius          : 6 //
    color           : "#434343" //

    Rectangle {
      id: fill
      radius : 1
      anchors {
        top: parent.top
        left: parent.left
        bottom: parent.bottom
        topMargin: body.border.width
        bottomMargin: body.border.width
        leftMargin: body.border.width
      }
      readonly property real w_per : level * ( parent.width - 2 )
      width : Math.min(parent.width - body.border.width, w_per - body.border.width)
      color : Theme.c.blue //
      Behavior on width {
        NumberAnimation { duration:Motion.std }
      }

    }
  }

  Rectangle {
    id: tip
    anchors.left           : body.right
    anchors.verticalCenter : body.verticalCenter
    implicitWidth          : body.width / 8 //
    implicitHeight         : body.height / 3 //
    color                  : Theme.c.white //
    border {
      color                : Theme.c.bg
      width                : 1
    }
    radius:3
  }

  Text {
    id: text_lbl
    visible:root.show_text
    text                  : root.show_text ? Math.trunc( 100 * level )  : ""
    font.family           : Theme.clock_font
    color                 : Theme.c.fg //
    font.pixelSize        : 16
    font.weight           : 900
    font.letterSpacing    : 1.2
    opacity               : root._switch_to_bolt ? 0 : 1
    anchors.horizontalCenter: !inside ? undefined : body.horizontalCenter
    anchors.right         : inside ? undefined : body.left
    anchors.rightMargin   : inside ? undefined : root.gap
    anchors.verticalCenter:  body.verticalCenter
    Behavior on opacity {
      NumberAnimation { duration:Motion.std }
    }
  }

  GlyphIcon {
    id: bolt
    name: "sprout"
    color: Theme.c.white
    width:  body.implicitHeight * 0.85
    height: body.implicitHeight * 0.85
    anchors.horizontalCenter: body.horizontalCenter
    anchors.verticalCenter:  body.verticalCenter
    opacity: root._switch_to_bolt ? 1 : 0
    stroke: root._switch_to_bolt ? 3 : 1
    visible: opacity > 0
    Behavior on opacity {
      NumberAnimation { duration:Motion.std }
    }
    Behavior on stroke {
      NumberAnimation { duration:Motion.slow }
    }
  }

}
