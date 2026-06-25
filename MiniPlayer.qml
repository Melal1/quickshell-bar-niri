import Quickshell
import QtQuick

Item {
  Image {
    id: albumCover
    readonly property string unk: "./Assests/UnkownTrack.jpg"

    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left

    width: 48; height: 48
    source: Player.player ? Player.player.trackArtUrl === "" ? unk : Player.player.
    trackArtUrl : unk
    fillMode: Image.PreserveAspectCrop
  }
  Rectangle {
    anchors.centerIn:albumCover
    anchors.left: parent.left
    width:60; height: 60
    color:"transparent"
    border.width: 5
    border.color:"#101010"
    radius: 17
  }

  Column {
    id:info
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: albumCover.right
    anchors.leftMargin: 6
    anchors.verticalCenterOffset: 3
    width: 140

    Text {
      id:title
      text: Player.player ? Player.player.trackTitle !== "" ? Player.player.trackTitle :
      "No Title" : "Nothing Here"
      font.bold:true
      color: "white"
      font.pixelSize: 10
      elide: Text.ElideRight
      width: parent.width

    }

    Row {
      spacing: 1
      Visullizer {
        playing: Player.player ? Player.player.isPlaying : false
        color: "red"
        amp: Audio.volume
        scale:0.6
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -2
        clip: true
        width: playing ?  implicitWidth : 0

        Behavior on width {
          NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

      }

      Text {
        text: Player.player ? Player.player.trackArtist !== "" ? Player.player.trackArtist : "" : "but chickens"
        font.pixelSize: 8
        font.bold: true
        color: "gray"
        elide: Text.ElideRight
        width: 110
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}
