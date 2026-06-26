import QtQuick
import Quickshell

Item {
  id: pill
  required property real sc
  enum Modes {
    Rest,
    Hover,
    Osd
  }

  property bool hovering: false
  property bool pinned: false
  property bool osd: false
  property bool _latched: false
  readonly property bool expanded: hovering || _latched || pinned

  readonly property int mode: {
    if (osd && !pinned) return Pill.Modes.Osd
    if (expanded) return Pill.Modes.Hover
    return Pill.Modes.Rest
  }

  readonly property real target_w: Settings.modes_dim[mode][0] * sc
  readonly property real target_h: Settings.modes_dim[mode][1] * sc

  width: target_w
  height: target_h

  readonly property real morphCloseness: {
    const d = Math.max(Math.abs(width - target_w), Math.abs(height - target_h));
    return 1 - Math.min(1, d / (110 * sc));

  }

  Behavior on width {
    NumberAnimation {
      duration: Motion.morph
      easing.type: Motion.custom
      easing.bezierCurve: Motion.morphCurve
    }
  }
  Behavior on height {
    NumberAnimation {
      duration: Motion.morph
      easing.type: Motion.custom
      easing.bezierCurve: Motion.morphCurve
    }
  }

  TapHandler { onTapped: pill.pinned = !pill.pinned }

  onHoveringChanged: {
    if (hovering) {
      _latched = true
      _grace_timer.stop()
    } else {
      _grace_timer.restart()
    }
  }

  GRect {
    readonly property bool hover_mode : pill.mode === Pill.Modes.Hover
    readonly property bool osd_mode : pill.mode === Pill.Modes.Osd
    anchors.fill: parent
    radius: hover_mode ? ( Settings.round_rad - 20 )* sc : Settings.round_rad * sc
    Behavior on radius {
      NumberAnimation { duration: Motion.std}
    }
    body_color: Theme.c.bg
    top_color: Theme.c.bg
    bottom_color: Theme.c.black2
    border_w: hover_mode  ? 3 : osd_mode ? 2 : 1
    running: hover_mode || osd_mode
  }

  // ============================================================
  //  main section — shared between Rest and Hover.
  //  Clock morphs in place; extras fade in/out per mode.
  // ============================================================
  Item {
    id: main
    anchors.fill: parent
    readonly property bool hover_mode : pill.mode === Pill.Modes.Hover
    readonly property bool playing : Player.status === Player.Modes.Playing
    readonly property bool paused :Player.status === Player.Modes.Paused

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

    opacity: hover_mode || pill.mode === Pill.Modes.Rest ? 1 : 0

    Behavior on opacity {
      NumberAnimation { duration: Motion.fast; easing.type: Motion.std_ease }
    }

    Clock {
      id: clock
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top

      readonly property real restSize: Settings.rest_h * pill.sc
      anchors.topMargin: (restSize + (main.hover_mode ? restSize * 0.2 : 0) - height) / 2
      anchors.horizontalCenterOffset: main.media_active && !main.hover_mode ? 7 * pill.sc : 0

      Behavior on anchors.horizontalCenterOffset {
        NumberAnimation { duration: Motion.std; easing.type: Motion.std_ease }
      }

      scale: main.hover_mode ? 2.0 : 1.0
      transformOrigin: Item.Top

      Behavior on scale {
        NumberAnimation {
          duration: Motion.morph
          easing.type: Motion.custom
          easing.bezierCurve: Motion.morphCurve
        }
      }
      Behavior on anchors.topMargin {
        NumberAnimation { duration: Motion.slow; easing.type: Motion.std_ease }
      }
    }

    Item {

      opacity : main.hover_mode ? Math.pow(pill.morphCloseness,1.3) : 0
      visible: opacity > 0

      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: -1
      anchors.left: parent.left
      Image {
        id: cover
        anchors.verticalCenter: parent.verticalCenter
        height: Settings.hover_h * pill.sc * 0.55
        width: height
        readonly property string unk: "./Assests/UnkownTrack.jpg"
        anchors.left: parent.left
        anchors.leftMargin: 15 * pill.sc
        source: Player.player ? Player.player.desktopEntry === "mpd-mpris" ||Player.player.trackArtUrl === ""  ? unk : Player.player.
        trackArtUrl : unk
        fillMode: Image.PreserveAspectCrop
      }

      Rectangle {
        anchors.centerIn:cover
        width:cover.width +10;
        height: cover.width + 10
        color:"transparent"
        border.width: 5
        border.color:Theme.c.bg
        radius: width / 4

      }

      Column {
        id:info
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: cover.right
        anchors.leftMargin: 10
        anchors.verticalCenterOffset: 6
        width: 180

        Text {
          id:title
          text: Player.player ? Player.player.trackTitle !== "" ? Player.player.trackTitle :
          "No Title" : "Nothing Here"
          font.bold:true
          color: Theme.c.fg
          font.pixelSize: 16
          elide: Text.ElideRight
          width: parent.width

        }

        Row {
          spacing: 1
          Visullizer {
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -5
            playing: main.playing
            paused: main.paused
            scale:0.6
            color: Audio.is_muted ?Theme.c.red2 :Theme.c.yellow
            clip: true
            width: main.media_active ?  implicitWidth : 0
            amp:1.2
            SequentialAnimation on color {
              loops: Animation.Infinite // Loops forever
              running: main.playing

              ColorAnimation { to: Theme.c.green2; duration: 3000 }
              ColorAnimation { to: Theme.c.cyan; duration: 3000 }
              ColorAnimation { to: Theme.c.yellow; duration: 3000 } // Go back to start
            }
            Behavior on width {
              NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }

          }

          Text {
            text: Player.player ? Player.player.trackArtist !== "" ? Player.player.trackArtist : "" : "but chickens"
            font.pixelSize: 13
            font.bold: true
            color: Theme.c.black2
            elide: Text.ElideRight
            width: 110
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -3
          }
        }
      }
    }

    Visullizer {
      id : vis
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: -1
      anchors.left: parent.left
      anchors.leftMargin: 25 * pill.sc
      playing: main.playing
      paused: main.paused
      color: Audio.is_muted ?Theme.c.red2 :Theme.c.yellow
      opacity: main.hover_mode  ? 0 : pill.morphCloseness
      visible: opacity > 0 && !main.hover_mode && main.media_active
      Behavior on opacity { NumberAnimation { duration: Motion.slow; easing.type:Motion.std_ease  } }
      amp:Audio.volume
      SequentialAnimation on color {
        loops: Animation.Infinite
        running: main.playing && !Audio.is_muted

        ColorAnimation { to: Theme.c.green2; duration: 3000 }
        ColorAnimation { to: Theme.c.cyan; duration: 3000 }
        ColorAnimation { to: Theme.c.yellow; duration: 3000 }
      }
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: clock.bottom
      anchors.topMargin: clock.height * (clock.scale - 1) + 5
      spacing: 10

      opacity: main.hover_mode ? 1 : 0
      scale: main.hover_mode ? 1 : 0.5
      visible: opacity > 0

      Behavior on scale {
        NumberAnimation { duration: Motion.fast; easing.type: Motion.std_ease }
      }
      Behavior on opacity {
        NumberAnimation { duration: Motion.fast; easing.type: Motion.std_ease }
      }

      Text {
        text: Qt.formatDateTime(Time.date, "ddd MMM dd")
        color: Theme.c.black2
        font.bold: true
        font.family: Theme.clock_font
        font.pixelSize: 15
      }

      Text {
        visible: athan.hasStatus
        text: "|"
        color: Theme.c.black2
        font.bold: true
        font.family: Theme.clock_font
        font.pixelSize: 15
      }

      AthanStatus {
        id: athan
        active: main.hover_mode
      }
    }
  }
  // Volume Osd
  Loader {
    anchors.fill: parent
    anchors.leftMargin: 30 * pill.sc
    anchors.rightMargin: 15 * pill.sc
    active: pill.mode === Pill.Modes.Osd
    opacity: pill.mode === Pill.Modes.Osd ? Math.pow(pill.morphCloseness, 1.2) : 0
    sourceComponent: Slider {
      value: Audio.volume
      disabled: Audio.is_muted
      icon: Audio.is_muted ? "󰖁"
      : Audio.volume < 0.33 ? "󰕿"
      : Audio.volume < 0.66 ? "󰖀"
      : "󰕾"
    }
  }

  Timer {
    id: _grace_timer
    interval: 1000
    onTriggered: {
      if (pill.morphCloseness < 0.95) {
        _grace_timer.restart()
        return
      }
      pill._latched = false
    }
  }

  Timer {
    id: _osd_timer
    interval: 1500
    onTriggered: pill.osd = false
  }
  Timer {
    id: _media_paused_timer
    interval: 10000
    onTriggered: main._hide_paused = true
  }

  Connections {
    target: Audio.audio
    function onVolumeChanged() {
      pill.osd = true
      _osd_timer.restart()
    }

    function onMutedChanged(params) {
      onVolumeChanged();
    }
  }

}
