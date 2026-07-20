import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Item {
  id: root

  required property var notif
  readonly property bool _is_crit: notif.urgency === NotificationUrgency.Critical
  readonly property var acts: notif.actions ? notif.actions.filter(function(a) { return a.text.length > 0; }) : []
  property bool reply_mode: false
  signal close_popup()
  signal openLink()

  HoverHandler {
    onHoveredChanged :{
      if(hovered)
      expire_t.stop()
      else
      expire_t.restart()
    }
  }

  function clean_up(clicked,no_l) {
    if (clicked) root.close_popup()
    expire_t.stop()
    let p = NotificationsServer.popups
    let end = p.length - ( no_l?1: 0 )
    for(let i = 0 ; i < end  ; i++) {
      NotificationsServer.remove_popup(p[i])
    }
  }
  Timer {
    id: expire_t
    interval: root._is_crit ? 20000 : 4000;
    onTriggered: {
      root.clean_up(false)
    }
  }

  onNotifChanged: {
    expire_t.restart()
  }

  implicitHeight: Math.max(icon_tile.height, col.implicitHeight)

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: (mouse) => {
      if (mouse.button === Qt.RightButton) {
        root.openLink()
        root.clean_up(true)
      } else {
        root.clean_up(true)
      }
    }
  }

  Rectangle {
    id: icon_tile
    anchors.left:parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: 47
    height: 47
    radius: 15
    color: Theme.c.black
    border.width: 1
    border.color: Theme.c.black2

    Image {
      id: popup_img
      anchors.fill: parent
      anchors.margins: root.notif.image ? 0 : 10
      source: NotificationsServer.icon_for(root.notif)
      sourceSize.width: 56
      sourceSize.height: 56
      fillMode: Image.PreserveAspectCrop
      smooth: true
      visible: source.toString().length > 0
    }

    Rectangle {
      anchors.centerIn: parent
      visible: !popup_img.visible
      width: 12
      height: 12
      radius: 3
      rotation: 45
      color: root._is_crit ? Theme.c.red2 : Theme.c.cyan
    }
  }

  Row {
    id: dots
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: 7
    spacing: 10

    Rectangle {
      width: 17
      height: 17
      radius: 8
      color: yellow_ar.containsMouse ? Theme.c.yellow2 : Theme.c.yellow

      Behavior on color {
        ColorAnimation { duration: Motion.fast }
      }

      MouseArea {
        id: yellow_ar
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          root.clean_up(true)
        }
      }
    }

    Rectangle {
      width: 17
      height: 17
      radius: 8
      color: red_ar.containsMouse ? Theme.c.red2 : Theme.c.red

      Behavior on color {
        ColorAnimation { duration: Motion.fast }
      }

      MouseArea {
        id: red_ar
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          let dismissAction = root.notif.dismiss
          Qt.callLater(function() {
              if (typeof dismissAction === "function") {
                dismissAction()
              }
          })
          root.clean_up(true,true)
        }
      }
    }
  }

  Column {
    id: col
    anchors.left: icon_tile.right
    anchors.leftMargin: 17
    anchors.right: dots.left
    anchors.rightMargin: 13
    anchors.top: parent.top
    spacing: 5

    Text {
      width: parent.width
      text: (root.notif.appName && root.notif.appName.length) ? root.notif.appName : "System"
      color: Theme.c.white2
      font.family: Theme.clock_font
      font.pixelSize: 14
      font.weight: Font.DemiBold
      font.capitalization: Font.AllUppercase
      font.letterSpacing: 2
      elide: Text.ElideRight
    }

    Row {
      width: parent.width
      spacing: 8

      Item {
        visible: root._is_crit
        anchors.verticalCenter: parent.verticalCenter
        width: 13
        height: 13

        Rectangle {
          anchors.centerIn: parent
          width: 13
          height: 13
          radius: 999
          color: Theme.c.red
          opacity: 0.3
        }
        Rectangle {
          anchors.centerIn: parent
          width: 7
          height: 7
          radius: 999
          color: Theme.c.red
        }
      }

      Text {
        width: parent.width - (root._is_crit ? 22 : 0)
        text: root.notif.summary
        color: Theme.c.white
        font.family: Theme.clock_font
        font.pixelSize: 19
        font.weight: Font.DemiBold
        maximumLineCount: 1
        elide: Text.ElideRight
      }
    }

    Text {
      width: parent.width
      visible: root.notif.body.length > 0
      text: root.notif.body
      color: Theme.c.white2
      font.family: Theme.clock_font
      font.pixelSize: 18
      wrapMode: Text.Wrap
      maximumLineCount: 2
      elide: Text.ElideRight
      textFormat: Text.PlainText
    }

    Item {
      visible: root.acts.length > 0 || root.notif.hasInlineReply
      width: parent.width
      height: root.reply_mode ? 47 : Math.max(acts_row.implicitHeight,  root.notif.hasInlineReply
        ? 40 : 0)
      Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }

      Row {
        id: acts_row
        spacing: 10
        topPadding: 7
        opacity: root.reply_mode ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Motion.fast } }

        Repeater {
          model: root.acts

          Rectangle {
            id: act_pill
            required property var modelData
            required property int index

            height: 33
            width: act_text.implicitWidth + 30
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
              font.weight: Font.DemiBold
            }

            MouseArea {
              id: act_ar
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                let action = act_pill.modelData
                root.clean_up(true,true)
                action.invoke()
              }
            }
          }
        }
      }

      Rectangle {
        id: reply_pill
        visible: root.notif.hasInlineReply

        y: acts_row.topPadding
        x: root.reply_mode ? 0 : (acts_row.width > 0 ? acts_row.width + acts_row.spacing : 0)

        height: root.reply_mode ? 40 : 33
        width: root.reply_mode ? parent.width : reply_text.implicitWidth + 30
        radius: root.reply_mode ? 7 : 20
        color: Theme.c.black
        border.width: 1
        border.color: Theme.c.black2
        clip: true

        Behavior on x { NumberAnimation { duration:Motion.fast } }
        Behavior on width { NumberAnimation {
            duration: Motion.morph
            easing.type: Motion.custom
            easing.bezierCurve: Motion.morph_curve
          } }
        Behavior on height { NumberAnimation {

            duration: Motion.morph
            easing.type: Motion.custom
            easing.bezierCurve: Motion.morph_curve
          } }
        Behavior on radius { NumberAnimation {
            duration: Motion.morph
            easing.type: Motion.custom
            easing.bezierCurve: Motion.morph_curve
          } }

        Text {
          id: reply_text
          anchors.centerIn: parent
          text: "Reply"
          color: reply_ar.containsMouse ? Theme.c.white : Theme.c.black2
          font.pixelSize: 17
          font.weight: Font.DemiBold
          opacity: root.reply_mode ? 0 : 1
          visible: opacity > 0
          Behavior on opacity { NumberAnimation { duration: Motion.v_fast} }
        }

        TextInput {
          id: reply_input
          anchors.fill: parent
          anchors.margins: 10
          color: Theme.c.white
          font.pixelSize: 17
          font.family: Theme.clock_font
          verticalAlignment: TextInput.AlignVCenter
          opacity: root.reply_mode ? 1 : 0
          visible: opacity > 0
          Behavior on opacity { NumberAnimation {  duration: Motion.v_fast ; easing.type: Motion.std_ease} }

          onActiveFocusChanged: {
            if (activeFocus) {
              expire_t.stop()
            } else {
              expire_t.restart()
              root.reply_mode = false
              text = ""
            }
          }

          Keys.onEscapePressed: {
            root.reply_mode = false
            text = ""
          }

          Text {
            anchors.fill: parent
            visible: !reply_input.text && !reply_input.activeFocus
            text: root.notif.inlineReplyPlaceholder || "Reply..."
            color: Theme.c.white2
            font.pixelSize: 17
            font.family: Theme.clock_font
            verticalAlignment: Text.AlignVCenter
          }

          onAccepted: {
            if (text.length > 0) {
              root.notif.sendInlineReply(text)
              root.clean_up(true, true)
            }
          }
        }

        MouseArea {
          id: reply_ar
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          visible: !root.reply_mode
          onClicked: {
            root.reply_mode = true
            reply_input.forceActiveFocus()
          }
        }
      }
    }
  }
}
