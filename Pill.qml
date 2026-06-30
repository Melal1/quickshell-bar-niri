import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "PillComponent"
Item {
  id: pill
  required property real sc
  required property var bar_win
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

  readonly property real morph_clossnes: {
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

  MouseArea {
    anchors.fill: parent
    onClicked: pill.pinned = !pill.pinned
    z: -1 // Put it below other clickable items
  }

  onHoveringChanged: {
    if (hovering) {
      _latched = true
      _grace_timer.stop()
    } else {
      _grace_timer.restart()
    }
  }

  GRect {
    id:body
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
    border_w: hover_mode  ? 1.8 * pill.sc : osd_mode ? 1.2 * pill.sc : 1
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

    readonly property bool media_active: built_in_media.media_active
    property bool last_pinned_state: false
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
      color:Theme.c.fg

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

    BuiltInMedia {
      id: built_in_media
      anchors.fill: parent
      sc: pill.sc
      playing: main.playing
      paused: main.paused
      opacity: main.hover_mode ? Math.pow(pill.morph_clossnes, 1.3) : 0
      visible: opacity > 0
    }

    Visullizer {
      id: vis
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: -1
      anchors.left: parent.left
      anchors.leftMargin: 22 * pill.sc
      playing: main.playing
      paused: main.paused
      color: Audio.is_muted ? Theme.c.red2 : Theme.c.yellow
      opacity: main.hover_mode ? 0 : pill.morph_clossnes
      visible: opacity > 0 && !main.hover_mode && main.media_active
      
      Behavior on opacity { 
        NumberAnimation { duration: Motion.slow; easing.type: Motion.std_ease } 
      }
      
      amp: Audio.volume

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
        font.pixelSize: Math.round(9 * pill.sc)
      }

      Text {
        visible: AthanStatus.has_status
        text: "|"
        color: Theme.c.black2
        font.bold: true
        font.family: Theme.clock_font
        font.pixelSize: Math.round(9 * pill.sc)
      }

      Text {
        color: Theme.c.black2
        font.bold: true
        font.family: Theme.clock_font
        font.pixelSize: Math.round(9 * pill.sc)
        text: AthanStatus.text

        Binding {
          target: AthanStatus
          property: "active"
          value: main.hover_mode
        }
        ColorPulse {
          active: PrayersAlert.prayer_upcoming
          default_color:Theme.c.black2
          step_duration:1000
          sequence: [
          Theme.c.fg,
          Theme.c.black2
          ]

        }
      }

    }

    // ── System Tray (hover mode only)
    BuiltInTray {
      anchors.fill: parent
      sc: pill.sc
      bar_win: pill.bar_win
      opacity: (main.hover_mode && SystemTray.items.values.length > 0) ? Math.pow(pill.morph_clossnes, 1.3) : 0
      visible: opacity > 0

      onInteractionStarted: {
        main.last_pinned_state = pill.pinned
        if (!pill.pinned) {
          pill.pinned = true
        }
      }
      onInteractionEnded: {
        pill.pinned = main.last_pinned_state
        pill._latched = true
        _grace_timer.restart()
      }
    }
  }

  // Volume Osd

  Loader {
    anchors.fill: parent
    anchors.leftMargin: 30 * pill.sc
    anchors.rightMargin: 15 * pill.sc
    active: pill.mode === Pill.Modes.Osd
    opacity: pill.mode === Pill.Modes.Osd ? Math.pow(pill.morph_clossnes, 1.2) : 0
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
      if (pill.morph_clossnes < 0.95) {
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
