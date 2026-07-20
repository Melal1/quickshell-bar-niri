import QtQuick

/**
* Individual notification card shown in the Link surface's notif region.
* Shows icon, app name eyebrow, summary, body, action pills, timestamp, and
* dismiss button. Slides in on creation and scales down on dismiss with
* animation. Action pills invoke the notif's action and dismiss the card.
*/
Item {
  id: card

  property var notif
  property var current_time: Date.now()

  implicitHeight: card_body.implicitHeight + 7
  clip: true

  signal dismissRequested()

  function dismiss() {
    dismissRequested();
  }

  Rectangle {
    id: card_body
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    implicitHeight: card_content.implicitHeight + 40
    radius: 17
    color: card_hover.containsMouse ? Theme.c.black : Theme.c.bg
    border.width: 2
    border.color: Theme.c.black2

    Behavior on color {
      ColorAnimation { duration: Motion.fast }
    }

    MouseArea {
      id: card_hover
      anchors.fill: parent
      hoverEnabled: true
    }

    Row {
      id: card_content
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 12
      spacing: 13

      // Icon
      Rectangle {
        id: icon_tile
        width: 43
        height: 43
        radius: 13
        color: Theme.c.black

        Image {
          id: icon_img
          anchors.fill: parent
          anchors.margins: card.notif && card.notif.image ? 0 : 8
          source: card.notif ? NotificationsServer.icon_for(card.notif) : ""
          sourceSize.width: 52
          sourceSize.height: 52
          fillMode: Image.PreserveAspectCrop
          smooth: true
          visible: source.toString().length > 0
        }

        Rectangle {
          anchors.centerIn: parent
          visible: !icon_img.visible
          width: 10
          height: 10
          radius: 5
          color: Theme.c.fg
        }
      }

      // Text content
      Column {
        width: parent.width - icon_tile.width - 12 - 27
        spacing: 3

        Text {
          width: parent.width
          text: (card.notif && card.notif.app) ? card.notif.app : "System"
          color: Theme.c.black2
          font.pixelSize: 13
          font.bold: true
          font.capitalization: Font.AllUppercase
          font.letterSpacing: 2
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          text: (card.notif && card.notif.summary) ? card.notif.summary : ""
          color: Theme.c.fg
          font.pixelSize: 18
          font.bold: true
          maximumLineCount: 1
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          visible: card.notif && card.notif.body && card.notif.body.length > 0
          text: (card.notif && card.notif.body) ? card.notif.body : ""
          color: Theme.c.black2
          font.pixelSize: 17
          wrapMode: Text.Wrap
          maximumLineCount: 2
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }

        Row {
          id: actions_row
          visible: card_hover.containsMouse && card.notif && card.notif.actions && card.notif.actions.length > 0
          spacing: 10
          topPadding: 3
          height: visible ? implicitHeight : 0

          Behavior on height { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutQuad } }

          Repeater {
            model: card.notif ? (card.notif.actions || []) : []

            Rectangle {
              id: act_pill
              required property var modelData

              height: 33
              width: act_text.implicitWidth + 23
              radius: 999
              color: Theme.c.black
              border.width: 1
              border.color: Theme.c.black2

              Text {
                id: act_text
                anchors.centerIn: parent
                text: act_pill.modelData.text
                color: act_ar.containsMouse ? Theme.c.white : Theme.c.black2
                font.pixelSize: 17
                font.bold: true
              }

              MouseArea {
                id: act_ar
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  act_pill.modelData.invoke()
                  card.dismiss()
                }
              }
            }
          }
        }
      }

      // Dismiss button
      Rectangle {
        id: dismiss_dot
        width: 12
        height: 12
        radius: 6
        color: x_area.containsMouse ? Theme.c.red2 : Theme.c.red

        Behavior on color {
          ColorAnimation { duration: Motion.fast }
        }

        MouseArea {
          id: x_area
          anchors.fill: parent
          anchors.margins: -7
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: card.dismiss()
        }
      }
    }

    // Age stamp — bottom-right of the card body
    Text {
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.rightMargin: 12
      anchors.bottomMargin: 7
      readonly property int age: {
        if (!card.notif || !card.notif.ts) return -1;
        let diff = Math.max(0, current_time - card.notif.ts);
        return Math.floor(diff / 60000);
      }
      text: age < 0 ? "" : age < 1 ? "now" : age < 60 ? age + "m" : Math.floor(age / 60) + "h"
      color: Theme.c.black2
      font.pixelSize: 12
      opacity: 0.7
    }
  }
}
