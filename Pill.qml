import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "PillComponent"
Item {
  id: pill

  required property var bar_win
  enum Modes {
    Rest,
    Hover,
    Osd,
    NotifPopup,
    None
  }

  enum Surfaces {
    None,
    NotifCenter,
    Launcher,
    Clipboard
  }

  property int active_surface: Pill.Surfaces.None
  readonly property bool notif_center_open: active_surface === Pill.Surfaces.NotifCenter
  readonly property bool launcher_open: active_surface === Pill.Surfaces.Launcher
  readonly property bool clipboard_open: active_surface === Pill.Surfaces.Clipboard
  readonly property bool is_surface: active_surface !== Pill.Surfaces.None
  property bool surface_opened_from_idle: false

  function toggle_surface(s) {
    if (active_surface === s) {
      close_surface();
    } else {
      if (!is_surface) {
        surface_opened_from_idle = !hovering && !_latched && !pinned;
      }
      active_surface = s;
    }
  }

  function close_surface() {
    active_surface = Pill.Surfaces.None;

    if (surface_opened_from_idle) {
      hovering = false;
      _latched = false;
      pinned = false;
      suppress_hover = true;
      _grace_timer.stop();
    }

    surface_opened_from_idle = false;
  }

  property bool suppress_hover: false

  property var modes_dim: ({
      [Pill.Modes.Rest]: [Settings.rest_w, Settings.rest_h,Settings.round_rad],
      [Pill.Modes.Hover]: [Settings.hover_w, Settings.hover_h,Settings.round_rad - 20 ],
      [Pill.Modes.Osd]: [Settings.osd_w, Settings.osd_h,Settings.round_rad],
      [Pill.Modes.NotifPopup]: [Settings.popup_w, pop_loader.item ? pop_loader.item.implicitHeight + 25 : Settings.rest_h,Settings.round_rad - 20 ],
      [Pill.Modes.None]: [0,0,0 ]
  })

  property var surface_dim: ({
      [Pill.Surfaces.NotifCenter]: [Settings.notifcenter_w, Settings.notifcenter_h, Settings.round_rad - 20],
      [Pill.Surfaces.Launcher]: [Settings.launcher_w, Settings.launcher_h, Settings.round_rad - 20],
      [Pill.Surfaces.Clipboard]: [Settings.clipboard_w, Settings.clipboard_h, Settings.round_rad - 20]
  })

  property bool hovering: false
  property bool pinned: false
  property bool osd: false
  property string osd_kind: "volume"
  property bool popup: NotificationsServer.popups.length > 0
  property bool _latched: false
  property bool brightness_ready: false
  property int current_brightness: Brightness.current
  property bool brightness_available: Brightness.available
  readonly property bool expanded: (hovering && !suppress_hover) || _latched || pinned

  function show_volume_osd() {
    osd_kind = "volume"
    osd = true
    _osd_timer.restart()
  }

  function show_brightness_osd() {
    osd_kind = "brightness"
    osd = true
    _osd_timer.restart()
  }

  onBrightness_availableChanged: {
    if (brightness_available) brightness_ready = true
  }

  onCurrent_brightnessChanged: {
    if (brightness_ready && Brightness.available) show_brightness_osd()
  }

  readonly property int mode: {
    if(is_surface) return Pill.Modes.None
    if (popup) return Pill.Modes.NotifPopup
    if (osd && !pinned) return Pill.Modes.Osd
    if (expanded) return Pill.Modes.Hover
    return Pill.Modes.Rest
  }

  readonly property var active_dim: (is_surface && !popup) ? surface_dim[active_surface] : modes_dim[mode]
  readonly property real target_w: active_dim[0]
  readonly property real target_h: active_dim[1]

  width: target_w
  height: target_h
  property int rad: active_dim[2]

  readonly property real morph_closeness: {
    const d = Math.max(Math.abs(width - target_w), Math.abs(height - target_h));
    return 1 - Math.min(1, d / (183));

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
      if (is_surface) close_surface();
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
    radius: pill.rad
    Behavior on radius {
      NumberAnimation { duration: Motion.std}
    }
    body_color: Theme.c.bg
    top_color: Theme.c.bg
    bottom_color: Theme.c.black2
    border_w: hover_mode || is_surface  ? 3 : osd_mode ? 2 : 1
    running: hover_mode || osd_mode || is_surface
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
    opacity: (hover_mode || pill.mode === Pill.Modes.Rest) ? 1 : 0

    Behavior on opacity {
      NumberAnimation { duration: Motion.fast; easing.type: Motion.std_ease }
    }

    Clock {
      id: clock
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top

      readonly property real rest_size: Settings.rest_h
      anchors.topMargin: (rest_size + (main.hover_mode ? rest_size * 0.2 : 0) - height) / 2
      anchors.horizontalCenterOffset: main.media_active && !main.hover_mode ? 12 : 0

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
      anchors.leftMargin: 37
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
        font.pixelSize: 15
      }

      Text {
        visible: AthanStatus.has_status
        text: "|"
        color: Theme.c.black2
        font.bold: true
        font.family: Theme.clock_font
        font.pixelSize: 15
      }

      Text {
        color: Theme.c.black2
        font.bold: true
        font.family: Theme.clock_font
        font.pixelSize: 15
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
      anchors.rightMargin: 25
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2
      layoutDirection: Qt.RightToLeft

      opacity: main.hover_mode ? 1 : 0
      visible: opacity > 0

      BuiltInTray {
        id: built_in_tray
        anchors.verticalCenter: parent.verticalCenter

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

        onLeftClicked: pill.toggle_surface(Pill.Surfaces.NotifCenter)
      }
    }
  }

  // Volume / brightness OSD
  Loader {
    anchors.fill: parent
    anchors.leftMargin: 50
    anchors.rightMargin: 25
    active: pill.mode === Pill.Modes.Osd
    opacity: pill.mode === Pill.Modes.Osd ? Math.pow(pill.morph_closeness, 1.2) : 0
    sourceComponent: Slider {
      readonly property bool brightness_osd: pill.osd_kind === "brightness"

      value: brightness_osd ? Brightness.value : Audio.volume
      disabled: brightness_osd ? !Brightness.available : Audio.is_muted
      active_col: brightness_osd ? Theme.c.yellow : "#8B8888"
      muted_col: brightness_osd ? Theme.c.black2 : "#4A4A4A"
      icon: brightness_osd ? "☀" : Audio.is_muted ? "󰖁"
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
    pill.show_volume_osd()
  }
  onCurrent_mutedChanged: {
    pill.show_volume_osd()
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
    anchors.topMargin: 20
    anchors.leftMargin: 27
    anchors.rightMargin: 27

    sourceComponent: Item {
      implicitHeight: popup_e.implicitHeight + 20

      readonly property var p: NotificationsServer.popups
      Popup {
        id: popup_e
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

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
    width: 10
    height: 10
    radius: 5
    color: Theme.c.red
    anchors.right: parent.right
    anchors.rightMargin: 27
    anchors.verticalCenter: parent.verticalCenter
    visible: pill.mode === Pill.Modes.Rest && NotificationsServer.unread && !NotificationsServer.dnd > 0 && !is_surface
    opacity: visible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Motion.fast } }
  }

  NotifCenterSurface {
    open: notif_center_open
    morph_closeness: pill.morph_closeness
  }

  Launcher {
    open: launcher_open
    morph_closeness: pill.morph_closeness
    onRequest_close: pill.close_surface()
  }

  Clipboard {
    open: clipboard_open
    morph_closeness: pill.morph_closeness
    onRequest_close: pill.close_surface()
  }
}
