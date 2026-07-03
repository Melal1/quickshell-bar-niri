import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Item {
  id: root
  required property real sc
  required property var notif
  required property bool live
  readonly property bool _is_crit: notif.urgency === NotificationUrgency.Critical
  readonly property var acts: notif.actions ? notif.actions.filter(function(a) { return a.text.length > 0; }) : []

  HoverHandler{
    id:hov
    onHoveredChanged :{
      if(hovered)
      {
        console.log("hovering on noti")
        expire_t.stop()
      }
      else{
        expire_t.restart()
        console.log("hovering loss on noti")
      }

    }

  }

  onNotifChanged: {
    if(!hov.hovered)
    expire_t.restart()
  }

  Timer {
    id: expire_t
    interval: root._is_crit ? 20000 : 4000;
    onTriggered: {
      let p = NotificationsServer.popups
      console.log("Running cleaner")
      for(let i = 0 ; i < p.length ; i++) {
        NotificationsServer.remove_popup(p[i])
      }
    }
  }

  implicitHeight: Math.max(icon_tile.height, col.implicitHeight)

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.openCenter()
  }

  Rectangle {
    id: icon_tile
    anchors.left: parent.left
    anchors.top: parent.top
    width: 28 * root.sc
    height: 28 * root.sc
    radius: 9 * root.sc
    color: Theme.c.black
    border.width: 1
    border.color: Theme.c.black2

    Image {
      id: toast_img
      anchors.fill: parent
      anchors.margins: root.notif.image ? 0 : 6 * root.sc
      source: NotificationsServer.icon_for(root.notif)
      sourceSize.width: 56
      sourceSize.height: 56
      fillMode: Image.PreserveAspectCrop
      smooth: true
      visible: source.toString().length > 0
    }

    Rectangle {
      anchors.centerIn: parent
      visible: !toast_img.visible
      width: 7 * root.sc
      height: 7 * root.sc
      radius: 2 * root.sc
      rotation: 45
      color: root._is_crit ? Theme.c.red2 : Theme.c.red
    }
  }

  Row {
    id: dots
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: 4 * root.sc
    spacing: 6 * root.sc

    Rectangle {
      width: 10 * root.sc
      height: 10 * root.sc
      radius: 5 * root.sc
      color: yellow_area.containsMouse ? Theme.c.yellow2 : Theme.c.yellow

      Behavior on color {
        ColorAnimation { duration: Motion.fast }
      }

      MouseArea {
        id: yellow_area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          expire_t.stop()
          let p = NotificationsServer.popups
          for(let i = 0 ; i < p.length ; i++) {
            NotificationsServer.remove_popup(p[i])
          }
        }
      }
    }

    Rectangle {
      width: 10 * root.sc
      height: 10 * root.sc
      radius: 5 * root.sc
      color: red_area.containsMouse ? Theme.c.red2 : Theme.c.red

      Behavior on color {
        ColorAnimation { duration: Motion.fast }
      }

      MouseArea {
        id: red_area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (typeof root.notif.dismiss === "function") {
            root.notif.dismiss()
          }
          expire_t.stop()
          let p = NotificationsServer.popups
          for(let i = 0 ; i < p.length ; i++) {
            NotificationsServer.remove_popup(p[i])
          }
        }
      }
    }
  }

  Column {
    id: col
    anchors.left: icon_tile.right
    anchors.leftMargin: 10 * root.sc
    anchors.right: dots.left
    anchors.rightMargin: 8 * root.sc
    anchors.top: parent.top
    spacing: 3 * root.sc

    Text {
      width: parent.width
      text: (root.notif.appName && root.notif.appName.length) ? root.notif.appName : "System"
      color: Theme.c.white2
      font.family: Theme.clock_font
      font.pixelSize: 8.5 * root.sc
      font.weight: Font.DemiBold
      font.capitalization: Font.AllUppercase
      font.letterSpacing: 1.4 * root.sc
      elide: Text.ElideRight
    }

    Row {
      width: parent.width
      spacing: 5 * root.sc

      Item {
        visible: root._is_crit
        anchors.verticalCenter: parent.verticalCenter
        width: 8 * root.sc
        height: 8 * root.sc

        Rectangle {
          anchors.centerIn: parent
          width: 8 * root.sc
          height: 8 * root.sc
          radius: 999
          color: Theme.c.red
          opacity: 0.3
        }
        Rectangle {
          anchors.centerIn: parent
          width: 4 * root.sc
          height: 4 * root.sc
          radius: 999
          color: Theme.c.red
        }
      }

      Text {
        width: parent.width - (root._is_crit ? 13 * root.sc : 0)
        text: root.notif.summary
        color: Theme.c.white
        font.family: Theme.clock_font
        font.pixelSize: 11.5 * root.sc
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
      font.pixelSize: 10.5 * root.sc
      wrapMode: Text.Wrap
      maximumLineCount: 2
      elide: Text.ElideRight
      textFormat: Text.PlainText
    }

    Row {
      visible: root.acts.length > 0
      spacing: 6 * root.sc
      topPadding: 4 * root.sc

      Repeater {
        model: root.acts

        Rectangle {
          id: act_pill
          required property var modelData
          required property int index

          height: 20 * root.sc
          width: act_text.implicitWidth + 18 * root.sc
          radius: 999
          color: Theme.c.black
          border.width: 1
          border.color: Theme.c.black2

          Text {
            id: act_text
            anchors.centerIn: parent
            text: act_pill.modelData.text