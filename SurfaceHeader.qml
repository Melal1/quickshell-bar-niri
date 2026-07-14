import QtQuick

Item {
  id: head

  property string title: ""
  property string detail: ""
  property color title_color: Theme.c.black2
  property color detail_color: Theme.c.black2
  property string font_family: Theme.clock_font

  width: parent ? parent.width : 0
  height: 24

  Text {
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    text: head.title
    color: head.title_color
    font.family: head.font_family
    font.pixelSize: 13
    font.bold: true
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 1.6
    elide: Text.ElideRight
    width: Math.max(0, parent.width - action_slot.width - detail_text.width - 18)
  }

  Text {
    id: detail_text
    anchors.right: action_slot.left
    anchors.rightMargin: action_slot.width > 0 ? 10 : 0
    anchors.verticalCenter: parent.verticalCenter
    text: head.detail
    color: head.detail_color
    font.family: head.font_family
    font.pixelSize: 13
    font.bold: true
    opacity: text.length > 0 ? 0.9 : 0
    horizontalAlignment: Text.AlignRight
  }

  Item {
    id: action_slot
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: childrenRect.width
    height: parent.height
  }
}
