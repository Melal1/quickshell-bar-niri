import QtQuick
import Quickshell
import "../"

Item {
  id: root

  required property bool playing
  required property bool paused

  property bool _hide_paused: false
  readonly property bool media_active: (playing || paused) && !_hide_paused

  onPausedChanged: {
    if (paused) {
      _media_paused_timer.restart()
    } else {
      _media_paused_timer.stop()
      _hide_paused = false
    }
  }

  Timer {
    id: _media_paused_timer
    interval: 10000
    onTriggered: root._hide_paused = true
  }

  Timer {
    id: _position_update_timer
    interval: 500
    running: root.playing && controls_col.visible
    repeat: true
    onTriggered: {
      if (Player.player) Player.player.positionChanged()
    }
  }

  Item {
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: -1
    anchors.left: parent.left

    Image {
      id: cover
      anchors.verticalCenter: parent.verticalCenter
      height: Settings.hover_h * 0.6
      width: height
      readonly property string unk: "../Assests/UnkownTrack.jpg"
      anchors.left: parent.left
      anchors.leftMargin: 25
      source: {
        if (!Player.player) return unk;
        if (Settings.ignore_mpd_mpris_art && Player.player.desktopEntry === "mpd-mpris") return unk;
        if (Player.player.trackArtUrl === "") return unk;
        return Player.player.trackArtUrl;
      }
      fillMode: Image.PreserveAspectCrop
    }

    Rectangle {
      anchors.centerIn: cover
      width: cover.width + 10
      height: cover.width + 10
      color: "transparent"
      border.width: 5
      border.color: Theme.c.bg
      radius: width / 5
    }

    Item {
      id: info_container
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: cover.right
      anchors.leftMargin: 10
      anchors.verticalCenterOffset: 6
      width: 180
      height: 46

      HoverHandler {
        id: info_hover
      }

      Column {
        id: info
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        opacity: info_hover.hovered ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 200 } }
        visible: opacity > 0

        Marquee {
          id: title
          active: info.visible
          text: Player.player ? Player.player.trackTitle !== "" ? Player.player.trackTitle : "No Title" : "Nothing Here"
          font.bold: true
          color: Theme.c.fg
          font.pixelSize: 16
          width: parent.width
        }

        Row {
          spacing: 1

          Visullizer {
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -5
            playing: root.playing
            paused: root.paused
            scale: 0.6
            color: Audio.is_muted ? Theme.c.red2 : Theme.c.yellow
            clip: true
            width: root.media_active ? implicitWidth : 0
            amp: 1.2

            SequentialAnimation on color {
              loops: Animation.Infinite
              running: root.playing
              ColorAnimation { to: Theme.c.green2; duration: 3000 }
              ColorAnimation { to: Theme.c.cyan; duration: 3000 }
              ColorAnimation { to: Theme.c.yellow; duration: 3000 }
            }
            Behavior on width {
              NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }
          }

          Marquee {
            active: info.visible
            text: Player.player ? Player.player.trackArtist !== "" ? Player.player.trackArtist : "" : "but chickens"
            font.pixelSize: 13
            font.bold: true
            color: Theme.c.black2
            width: 110
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -3
          }
        }
      }

      Column {
        id: controls_col
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset:-3.67
        width: parent.width
        opacity: info.opacity > 0.3 ? 0 :1
        Behavior on opacity { NumberAnimation { duration: 200 } }
        visible: opacity > 0
        spacing: 5

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: 23.33

          Text {
            readonly property bool active: (Player.player && Player.player.canGoPrevious)
            text: "󰒮"
            font.family: "Agave Nerd Font Propo"
            font.pixelSize: 28
            color: active ? Theme.c.fg : Theme.c.black2
            MouseArea {
              anchors.fill: parent
              cursorShape:parent.active ?Qt.PointingHandCursor : Qt.ArrowCursor
              enabled:parent.active

              onClicked: {
                if (parent.active) Player.player.previous()
              }
            }
          }
          Rectangle {
            width: 40
            height: 36
            radius: 4
            color: Theme.c.black
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -3

            Text {
              readonly property bool active : Player.player  && (Player.player.canPlay || Player.player.canPause || Player.player.canTogglePlaying)
              id: play_text
              text: root.playing ? "󰏤" : "󰐊"
              anchors.centerIn: parent
              anchors.verticalCenterOffset: -0.33
              font.family: "Agave Nerd Font Propo"
              font.pixelSize: 32
              color:  active ? Theme.c.fg : Theme.c.black2
            }
            MouseArea {
              anchors.fill: parent
              enabled: play_text.active
              cursorShape: play_text.active ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: {
                if (play_text.active) {
                  Player.player.togglePlaying()
                } else if (Player.player) {
                  if (root.playing && Player.player.canPause) Player.player.pause()
                  else if (!root.playing && Player.player.canPlay) Player.player.play()
                }
              }
            }
          }
          Text {
            readonly property bool active :(Player.player && Player.player.canGoNext)
            text: "󰒭"
            font.family: "Agave Nerd Font Propo"
            font.pixelSize: 28
            color: active  ? Theme.c.fg : Theme.c.black2
            MouseArea {
              anchors.fill: parent
              enabled:parent.active
              cursorShape: parent.active ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: {
                if (parent.active) Player.player.next()
              }
            }
          }
        }

        Rectangle {
          width: parent.width
          anchors.horizontalCenter: parent.horizontalCenter
          height: 6
          radius: 3
          color: Theme.c.black

          Rectangle {
            id: progress_fill
            clip: true
            anchors {
              bottom:parent.bottom
              top:parent.top
              left:parent.left
            }
            radius: parent.radius
            color: Theme.c.fg

            ColorPulse{
              id:color_anim
              active: controls_col.visible || info.visible
              step_duration: progress_fill.len > 0 ? 500 + (2000 * progress_fill.prog) : 1000
              default_color: Theme.c.fg
              sequence : [
              Theme.c.magenta,
              Theme.c.yellow,
              Theme.c.fg
              ]

            }
            property real pos: 0
            property real len: 0
            property bool supported: false
            readonly property real prog: pos / len

            Behavior on width {
              NumberAnimation { duration: 100 }
            }

            // Continuous visual shine
            // Rectangle {
            //   height: parent.height
            //   width: 40
            //   radius: parent.radius
            //   gradient: Gradient {
            //     orientation: Gradient.Horizontal
            //     GradientStop { position: 0.0; color: "transparent" }
            //     GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.45) }
            //     GradientStop { position: 1.0; color: "transparent" }
            //   }
            //
            //   property real anim_prog: 0
            //   x: -width + (parent.width + width) * anim_prog
            //
            //   NumberAnimation on anim_prog {
            //     from: 0; to: 1
            //     duration: {
            //       let ratio = progress_fill.len > 0 ? (progress_fill.pos / progress_fill.len) : 0;
            //       return 2500 - (1700 * ratio);
            //     }
            //     loops: Animation.Infinite
            //     running: root.playing && progress_fill.width > 0
            //   }
            // }

            Connections {
              target: Player.player
              function onPositionChanged() {
                if (Player.player) {
                  progress_fill.pos = Player.player.position;
                  progress_fill.len = Player.player.length;
                  progress_fill.supported = Player.player.positionSupported;
                }
              }
              function onTrackTitleChanged() {
                if (Player.player) {
                  progress_fill.pos = 0;
                  progress_fill.len = Player.player.length;
                }
              }
            }

            width: {
              if (!supported || len === 0) return 0;
              return Math.min(parent.width, parent.width * prog);
            }
          }

          MouseArea {
            anchors.fill: parent
            anchors.topMargin: -5
            anchors.bottomMargin: -5
            cursorShape: Qt.PointingHandCursor
            onClicked: (mouse) => {
              if (Player.player && Player.player.canSeek && Player.player.length > 0) {
                let progress = mouse.x / width;
                let targetTime = progress * Player.player.length;
                let offset = targetTime - Player.player.position;
                Player.player.seek(offset);
              }
            }
          }
        }
      }
    }
  }

}
