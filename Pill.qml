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

  GRect {
    anchors.fill: parent
    radius: Settings.round_rad * sc
    body_color: Theme.c.bg
    top_color: Theme.c.black2
    bottom_color: Theme.c.white
    border_w: 1
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

    opacity: hover_mode|| pill.mode === Pill.Modes.Rest ? 1 : 0

    Behavior on opacity {
      NumberAnimation { duration: Motion.fast; easing.type: Motion.std_ease }
    }

    Clock {
      id: clock
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top

      readonly property real restSize: Settings.rest_h * pill.sc
      anchors.topMargin: (restSize + (main.hover_mode ? restSize * 0.2 : 0) - height) / 2
      anchors.horizontalCenterOffset: main.media_active ? 7 * pill.sc : 0

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

    Visullizer {
      id : vis
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: -1
      anchors.left: parent.left
      anchors.leftMargin: 25 * pill.sc
      playing: main.playing
      paused: main.paused
      color: Theme.c.fg
      opacity: (main.hover_mode || !main.media_active) ? 0 : 1
      visible: opacity > 0
      Behavior on opacity { NumberAnimation { duration: main.hover_mode ? Motion.slow : Motion.fast } }
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: clock.bottom
      anchors.topMargin: clock.height * (clock.scale - 1) + 5
      spacing: 10

      opacity: main.hover_mode ? Math.pow(pill.morphCloseness, 1.2) : 0
      scale: main.hover_mode ? 1 : 0.5
      visible: opacity > 0

      Behavior on scale {
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
    interval: 500
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
    interval: 3000
    onTriggered: pill.osd = false
  }
  Timer {
    id: _media_paused_timer
    interval: 5000
    onTriggered: main._hide_paused = true
  }

}
