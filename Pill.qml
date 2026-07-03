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
    Osd,
    NotifPopup
  }

  enum Surfaces {
    None,
    NotifCenter
  }

  property int active_surface: Pill.Surfaces.None
  readonly property bool notif_center_open: active_surface === Pill.Surfaces.NotifCenter
  readonly property bool is_surface: active_surface !== Pill.Surfaces.None

  function toggle_surface(s) {
    if (active_surface === s) {
      active_surface = Pill.Surfaces.None;
    } else {
      active_surface = s;
    }
  }

  property bool exiting_surface: false
  onIs_surfaceChanged: {
    if (!is_surface) {
      exiting_surface = true;
    }
  }
  onMorph_closenessChanged: {
    if (morph_closeness > 0.95 && exiting_surface) {
      exiting_surface = false;
    }
  }

  property bool suppress_hover: false

  property var modes_dim: ({
      [Pill.Modes.Rest]: [Settings.rest_w, Settings.rest_h,Settings.round_rad],
      [Pill.Modes.Hover]: [Settings.hover_w, Settings.hover_h,Settings.round_rad - 20 ],
      [Pill.Modes.Osd]: [Settings.osd_w, Settings.osd_h,Settings.round_rad],
      [Pill.Modes.NotifPopup]: [Settings.popup_w, pop_loader.item ? pop_loader.item.implicitHeight + 15 * sc : Settings.rest_h,Settings.round_rad - 20 ]
  })

  property var surface_dim: ({
      [Pill.Surfaces.NotifCenter]: [Settings.notifcenter_w, Settings.notifcenter_h, Settings.round_rad - 20]
  })

  property bool hovering: false
  property bool pinned: false
  property bool osd: false
  property bool popup: NotificationsServer.popups.length > 0
  property bool _latched: false
  readonly property bool expanded: (hovering && !suppress_hover) || _latched || pinned

  readonly property int mode: {
    if (popup) return Pill.Modes.NotifPopup
    if (osd && !pinned) return Pill.Modes.Osd
    if (expanded) return Pill.Modes.Hover
    return Pill.Modes.Rest
  }

  readonly property var active_dim: (is_surface && !popup) ? surface_dim[active_surface] : modes_dim[mode]
  readonly property real target_w: active_dim[0] * sc
  readonly property real target_h: active_dim[1] * sc

  width: target_w
  height: target_h

  readonly property real morph_closeness: {
    const d = Math.max(Math.abs(width - target_w), Math.abs(height - target_h));
    return 1 - Math.min(1, d / (110 * sc));

  }

  Behavior on width {
    NumberAnimation {
      duration: Motion.morph
      easing.type: Motion.custom
      easing.bezierCurve: Motion.morph_curve
    }
  }
  Behavior on height {
    NumberAnimation {
      duration: Motion.morph
      easing.type: Motion.custom
      easing.bezierCurve: Motion.morph_curve
    }
  }

  MouseArea {
    anchors.fill: parent
    onClicked: {
      if (is_surface) active_surface = Pill.Surfaces.None;
      else pill.pinned = !pill.pinned;
    }
    z: -1
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
    radius: pill.modes_dim[pill.mode][2] * pill.sc
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
    opacity: (hover_mode || pill.mode === Pill.Modes.Rest) && !is_surface ? (pill.exiting_surface ? Math.pow(pill.morph_closeness, 1.3) : 1) : 0

    Behavior on opacity {
      NumberAnimation { duration: Motion.fast; easing.type: Motion.std_ease }
    }

    Clock {
      id: clock
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top

      readonly property real rest_size: Settings.rest_h * pill.sc
      anchors.topMargin: (rest_size + (main.hover_mode ? rest_size * 0.2 : 0) - height) / 2
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
          easing.bezierCurve: Motion.morph_curve
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
      opacity: main.hover_mode ? Math.pow(pill.morph_closeness, 1.3) : 0
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
      opacity: main.hover_mode ? 0 : pill.morph_closeness
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

    // ── System Tray and Notif Btn (hover mode only)
    Row {
      anchors.right: parent.right
      anchors.rightMargin: 15 * pill.sc
      anchors.verticalCenter: parent.verticalCenter
      spacing: 1 * pill.sc
      layoutDirection: Qt.RightToLeft

      opacity: main.hover_mode ? (pill.exiting_surface ? Math.pow(pill.morph_closeness, 1.3) : 1) : 0
      visible: opacity > 0

      BuiltInTray {
        id: built_in_tray
        anchors.verticalCenter: parent.verticalCenter
        sc: pill.sc
        bar_win: pill.bar_win

        onInteraction_started: {
          main.last_pinned_state = pill.pinned
          if (!pill.pinned) {
            pill.pinned = true
          }
        }
        onInteraction_ended: {
          pill.pinned = main.last_pinned_state
          pill._latched = true
          _grace_timer.restart()
        }
      }

      NotifButton {
        id: notif_btn
        sc: pill.sc
        onLeftClicked: pill.toggle_surface(Pill.Surfaces.NotifCenter)
      }
    }
  }

  // Volume Osd
  Loader {
    anchors.fill: parent
    anchors.leftMargin: 30 * pill.sc
    anchors.rightMargin: 15 * pill.sc
    active: pill.mode === Pill.Modes.Osd
    opacity: pill.mode === Pill.Modes.Osd ? Math.pow(pill.morph_closeness, 1.2) : 0
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
      if (pill.morph_closeness < 0.95) {
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

  property real current_volume: Audio.volume
  property bool current_muted: Audio.is_muted

  onCurrent_volumeChanged: {
    pill.osd = true
    _osd_timer.restart()
  }
  onCurrent_mutedChanged: {
    pill.osd = true
    _osd_timer.restart()
  }

  Loader {
    readonly property bool on:pill.mode === Pill.Modes.NotifPopup

    id:pop_loader
    visible: opacity > 0.01
    opacity: on ? Math.pow(pill.morph_closeness, 1.3)  : 0
    active: popup
    Behavior on opacity {
      NumberAnimation {
        duration: Motion.v_fast
      }
    }
    anchors.fill: parent
    anchors.topMargin: 12 * pill.sc
    anchors.leftMargin: 16 * pill.sc
    anchors.rightMargin: 16 * pill.sc

    sourceComponent: Item {
      implicitHeight: popup_e.implicitHeight  / pill.sc

      readonly property var p: NotificationsServer.popups
      Popup {
        id: popup_e
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        sc:pill.sc
        notif: p[p.length-1]
        onClose_popup: {
          console.log("Popup dot clicked! Suppressing hover and clearing latch.")
          pill.suppress_hover = true
          pill._latched = false
          _grace_timer.stop()
        }
      }
      Text {
        anchors {
          bottom: parent.bottom
          right: parent.right
          rightMargin: 10
          bottomMargin:10
        }
        font.pixelSize: 13
        font.bold:true
        color:Theme.c.fg
        text: (  p.length - 1 ) + "+"
        visible: opacity > 0
        opacity:p.length > 1 ? 1 : 0
        Behavior on opacity{
          NumberAnimation{ duration: Motion.fast }
        }

      }
    }
  }

  // Unread dot in Rest mode
  Rectangle {
    width: 6 * pill.sc
    height: 6 * pill.sc
    radius: 3 * pill.sc
    color: Theme.c.red
    anchors.right: parent.right
    anchors.rightMargin: 16 * pill.sc
    anchors.verticalCenter: parent.verticalCenter
    visible: pill.mode === Pill.Modes.Rest && NotificationsServer.unread && !NotificationsServer.dnd > 0 && !is_surface
    opacity: visible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Motion.fast } }
  }

  NotifCenterSurface {
    open: notif_center_open
    s: pill.sc
    morph_closeness: pill.morph_closeness
  }
}
