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
    Launcher,
    Clipboard,
    Power,
    Bluetooth,
    Link,
    Network
  }

  property int active_surface: Pill.Surfaces.None
  readonly property bool launcher_open: active_surface === Pill.Surfaces.Launcher
  readonly property bool clipboard_open: active_surface === Pill.Surfaces.Clipboard
  readonly property bool power_open: active_surface === Pill.Surfaces.Power
  readonly property bool bluetooth_open: active_surface === Pill.Surfaces.Bluetooth
  readonly property bool link_open: active_surface === Pill.Surfaces.Link
  readonly property bool network_open: active_surface === Pill.Surfaces.Network
  readonly property bool is_surface: active_surface !== Pill.Surfaces.None
  /**
  * True when the surface was opened while the pill was NOT pinned (hold mode
  * off). On close, this decides whether Esc returns to rest (flag true) or
  * stays in hover/hold mode (flag false). Set in `toggle_surface` when no
  * surface was already up; cleared in `close_surface` only on a full close
  * (not when returning to a parent surface).
  */
  property bool surface_opened_from_idle: false

  /**
  * The surface that was open immediately before the current one. Saved when
  * `toggle_surface` opens a new surface while another is already up, and
  * consumed by `close_surface(restore_previous = true)` (called from each
  * surface's Esc handler) to bounce the user back to the parent surface —
  * e.g. closing Network returns to Link. Cleared whenever a surface is
  * fully closed (e.g. clicking outside the pill, or Esc with no parent).
  */
  property int previous_surface: Pill.Surfaces.None

  function toggle_surface(s) {
    if (active_surface === s) {
      close_surface();
    } else {
      if (!is_surface) {
        surface_opened_from_idle = !pinned;
        previous_surface = Pill.Surfaces.None;
      } else {
        previous_surface = active_surface;
      }
      active_surface = s;
    }
  }

  function close_surface(restore_previous) {
    if (restore_previous === undefined) restore_previous = false;
    var return_to = restore_previous && previous_surface !== Pill.Surfaces.None ? previous_surface : Pill.Surfaces.None;

    active_surface = return_to;
    previous_surface = Pill.Surfaces.None;

    if (return_to === Pill.Surfaces.None && surface_opened_from_idle) {
      hovering = false;
      _latched = false;
      pinned = false;
      suppress_hover = true;
      _grace_timer.stop();
    }

    if (return_to === Pill.Surfaces.None) {
      surface_opened_from_idle = false;
    }
  }

  property bool suppress_hover: false

  property var modes_dim: ({
      [Pill.Modes.Rest]: [Settings.rest_w, Settings.rest_h,Settings.round_rad],
      [Pill.Modes.Hover]: [Settings.hover_w, Settings.hover_h,Settings.round_rad - 20 ],
      [Pill.Modes.Osd]: [Settings.osd_w, Settings.osd_h,Settings.round_rad],
      [Pill.Modes.NotifPopup]: [Settings.popup_w, pop_loader.item ? pop_loader.item.implicitHeight + 25 : Settings.rest_h,Settings.round_rad - 20 ],
      [Pill.Modes.None]: [0,0,0]
  })

  function surface_dim_for(s) {
    if (s === Pill.Surfaces.None) return [0, 0, 0];
    if (s === Pill.Surfaces.Launcher) return [Settings.launcher_w, Settings.launcher_h, Settings.round_rad - 20];
    if (s === Pill.Surfaces.Clipboard) return [Settings.clipboard_w, Settings.clipboard_h, Settings.round_rad - 20];
    if (s === Pill.Surfaces.Power) return [power_loader.item ? power_loader.item.implicitWidth + 100 : 350, Settings.power_menu_h, Settings.round_rad - 20];
    if (s === Pill.Surfaces.Bluetooth) return [Settings.bluetooth_w, Settings.bluetooth_h, Settings.round_rad - 20];
    if (s === Pill.Surfaces.Link) return [Settings.link_w, link ? link.dynamic_height + 10 : 240, Settings.round_rad - 20];
    if (s === Pill.Surfaces.Network) return [Settings.network_w, Settings.network_h, Settings.round_rad - 20];
    return [0, 0, 0];
  }

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

  readonly property var active_dim: (is_surface ) ? surface_dim_for(active_surface) : modes_dim[mode]
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
    readonly property bool notif_on_surface:  is_surface && popup
    anchors.fill: parent
    radius: pill.rad
    Behavior on radius {
      NumberAnimation { duration: Motion.std}

    }
    duration: notif_on_surface ? 1500 : 3000
    body_color: Qt.alpha(Theme.c.bg, Settings.surface_opacity)
    top_color:notif_on_surface? Qt.alpha(Theme.c.red2 , Settings.surface_opacity): Qt.alpha(Theme.c.bg,Settings.surface_opacity)
    bottom_color: notif_on_surface  ? Qt.alpha(Theme.c.red,Settings.surface_opacity) : Qt.alpha(Theme.c.black,Settings.surface_opacity)

    border_w: notif_on_surface ? 5 :hover_mode || is_surface  ? 3 : osd_mode ? 2 : 1
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
        onLeftClicked: pill.toggle_surface(Pill.Surfaces.Link)
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset:3
      }
      BatteryGlyph {
        id: battery_glyph
        show_text:true
        anchors.verticalCenter: parent.verticalCenter
        visible: Battery.available
        charging:Battery.charging
        level: Battery.level
        opacity: main.hover_mode ? 1 : 0
        ColorPulse {
          target_property : "fill_col"
          active: Battery.charging
          default_color:Theme.c.blue
          step_duration:3000
          sequence: [
          Theme.c.blue,
          Theme.c.green
          ]
        }

        scale: main.hover_mode ? 1 : 0.5
        Behavior on opacity {
          NumberAnimation { duration: Motion.fast; easing.type: Motion.std_ease }
        }
        Behavior on scale {
          NumberAnimation { duration: Motion.fast; easing.type: Motion.std_ease }
        }
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
      active_col: brightness_osd ? Theme.c.yellow : Theme.c.blue
      muted_col: Theme.c.black2
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
    active:  popup
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
        onOpenLink: pill.toggle_surface(Pill.Surfaces.Link)
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
  Loader {
    id: power_loader
    anchors.fill:parent
    active:power_open
    sourceComponent: Power {
      open:parent.active
      morph_closeness: pill.morph_closeness
      onRequest_close: pill.close_surface()
    }

  }

  BluetoothSurface {
    open: bluetooth_open
    morph_closeness: pill.morph_closeness
    onRequest_close: pill.close_surface(true)
  }

  Link {
    id: link
    open: link_open
    morph_closeness: pill.morph_closeness
    onRequest_close: pill.close_surface()
  }

  NetworkSurface {
    open: network_open
    morph_closeness: pill.morph_closeness
    onRequest_close: pill.close_surface(true)
  }
}
