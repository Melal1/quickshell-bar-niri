pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "lib/selection.js" as Selection

/**
* Bluetooth detail surface: scan with 25s auto-stop, adapter toggle, sorted
* live device list. Pairs via the native Quickshell Bluetooth API (d.pair,
* d.forget, d.trusted). Exposes moveSelection/activateSelected/pairSelected/
* trustSelected/unpairSelected/startUnpairHold/drainUnpairHold/cancelUnpairHold
* for keyboard input.
*
* Holds focus, manages the scan timer, register_filter notification suppression,
* and the hold-to-unpair progress.
*/
PillSurface {
  id: root

  m_top: 15
  m_left: 17
  m_right: 17
  m_bottom: 14

  readonly property var adapter: (typeof Bluetooth !== "undefined" && Bluetooth) ? Bluetooth.defaultAdapter : null
  readonly property var devices: (typeof Bluetooth !== "undefined" && Bluetooth && Bluetooth.devices) ? Bluetooth.devices.values : []

  /**
  * BlueZ hands the cache out in arbitrary order; sort connected first, then
  * paired, then named devices, nameless MACs last so a discovery scan doesn't
  * churn the useful rows around.
  */
  readonly property var devices_sorted: devices.slice().sort(function(a, b) {
      function rank(d) {
        if (!d) return 3;
        if (d.connected) return 0;
        if (d.paired) return 1;
        return (d.name && d.name.length) ? 2 : 3;
      }
      var r = rank(a) - rank(b);
      if (r !== 0) return r;
      return String((a && a.name) || "").localeCompare(String((b && b.name) || ""));
  })

  readonly property bool discovering: adapter ? adapter.discovering === true : false

  property int selected_index: 0

  /**
  * Hold-to-confirm state for the unpair action. `unpair_hold_addr` is the
  * MAC of the device whose unpair is currently being held. `unpair_hold_progress`
  * is 0..1; when it reaches 1 the unpair fires.
  */
  property string unpair_hold_addr: ""
  property real unpair_hold_progress: 0
  property bool unpair_draining: false
  readonly property bool unpair_holding: unpair_hold_addr.length > 0

  readonly property int unpair_hold_ms: 3000

  onOpenChanged: {
    NotificationsServer.set_filter_active("bluetooth", open);
    if (open) {
      selected_index = 0;
      root.forceActiveFocus();
    } else {
      scan_timer.stop();
      cancelUnpairHold();
      if (adapter && adapter.discovering)
      adapter.discovering = false;
    }
  }

  onDevicesChanged: {
    selected_index = 0;
    if (unpair_hold_addr.length > 0) {
      var still_there = false;
      for (var i = 0; i < devices.length; i++) {
        if (devices[i] && devices[i].address === unpair_hold_addr) {
          still_there = true;
          break;
        }
      }
      if (!still_there)
      cancelUnpairHold();
    }
  }

  Component.onCompleted: {
    NotificationsServer.register_filter("bluetooth",
      ["blueman", "blueberry", "bluez"]);
  }

  function moveSelection(delta) {
    if (devices_sorted.length === 0)
    return;
    var next = Selection.move(selected_index, delta, devices_sorted.length);
    if (next !== selected_index) {
      cancelUnpairHold();
      selected_index = next;
      device_list.positionViewAtIndex(selected_index, ListView.Contain);
    }
  }

  function activateSelected() {
    if (!Selection.valid(selected_index, devices_sorted.length))
    return;
    activateDevice(devices_sorted[selected_index]);
  }

  function pairSelected() {
    if (!Selection.valid(selected_index, devices_sorted.length))
    return;
    var d = devices_sorted[selected_index];
    if (!d || d.paired || typeof d.pair !== "function")
    return;
    d.pair();
  }

  function trustSelected() {
    if (!Selection.valid(selected_index, devices_sorted.length))
    return;
    var d = devices_sorted[selected_index];
    if (d && d.paired && d.trusted !== undefined)
    d.trusted = !d.trusted;
  }

  function unpairSelected() {
    if (!Selection.valid(selected_index, devices_sorted.length))
    return;
    var d = devices_sorted[selected_index];
    if (d && d.paired && typeof d.forget === "function")
    d.forget();
  }

  function startUnpairHold() {
    if (unpair_holding)
    return;
    if (!Selection.valid(selected_index, devices_sorted.length))
    return;
    var d = devices_sorted[selected_index];
    if (!d || !d.paired)
    return;
    unpair_hold_addr = d.address;
    unpair_hold_progress = 0;
    unpair_hold_timer.restart();
  }

  function cancelUnpairHold() {
    unpair_hold_timer.stop();
    unpair_drain_anim.stop();
    unpair_hold_addr = "";
    unpair_hold_progress = 0;
    unpair_draining = false;
  }

  function drainUnpairHold() {
    if (!unpair_holding || unpair_draining)
    return;
    unpair_hold_timer.stop();
    unpair_draining = true;
    unpair_drain_anim.from = unpair_hold_progress;
    unpair_drain_anim.to = 0;
    unpair_drain_anim.start();
  }

  function scanToggle() {
    if (!root.adapter) return;
    root.adapter.discovering = !root.adapter.discovering;
    if (root.adapter.discovering) scan_timer.restart();
    else scan_timer.stop();
  }

  focus: true
  Keys.onPressed: (event) => {
    if (event.modifiers !== Qt.NoModifier || event.isAutoRepeat)
    return;

    if (event.key === Qt.Key_S || event.text === "s" || event.text === "S") {
      if (!root.adapter)
      return;
      root.adapter.discovering = !root.adapter.discovering;
      if (root.adapter.discovering)
      scan_timer.restart();
      else
      scan_timer.stop();
      event.accepted = true;
      return;
    }

    if (event.text === "j" || event.text === "J" || event.key === Qt.Key_Down) {
      root.moveSelection(1);
      event.accepted = true;
      return;
    }

    if (event.text === "k" || event.text === "K" || event.key === Qt.Key_Up) {
      root.moveSelection(-1);
      event.accepted = true;
      return;
    }

    if (event.key === Qt.Key_Space) {
      root.pairSelected();
      event.accepted = true;
      return;
    }

    if (event.key === Qt.Key_T || event.text === "t" || event.text === "T") {
      root.trustSelected();
      event.accepted = true;
      return;
    }

    if (event.text === "u" || event.text === "U") {
      root.startUnpairHold();
      event.accepted = true;
      return;
    }

    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.activateSelected();
      event.accepted = true;
      return;
    }
  }

  Keys.onReleased: (event) => {
    if (event.isAutoRepeat)
    return;
    if (event.text === "u" || event.text === "U") {
      root.drainUnpairHold();
      event.accepted = true;
    }
  }

  Keys.onEscapePressed: (event) => {
    root.cancelUnpairHold();
    root.request_close();
    event.accepted = true;
  }

  function meta_for(d) {
    if (!d) return "";
    var parts = [];
    if (d.connected) parts.push("connected");
    else if (d.paired) parts.push("paired");
    if (d.paired && d.trusted === true) parts.push("trusted");
    if (d.state !== undefined && typeof BluetoothDeviceState !== "undefined") {
      var st = BluetoothDeviceState.toString(d.state);
      if (st && st.length > 0 && parts.indexOf(st.toLowerCase()) === -1) parts.push(st.toLowerCase());
    }
    return parts.join(" · ");
  }

  function battery_level(d) {
    if (!d || d.batteryAvailable !== true) return -1;
    var b = d.battery;
    if (b <= 0) return -1;
    if (b <= 1) b = b * 100;
    return Math.round(b);
  }

  /**
  * Click dispatch for a device row: disconnect when connected, connect when
  * paired, otherwise trigger d.pair() (native).
  */
  function activateDevice(d) {
    if (!d)
    return;
    if (d.connected) {
      if (typeof d.disconnect === "function")
      d.disconnect();
      return;
    }
    if (d.paired) {
      if (typeof d.connect === "function")
      d.connect();
      return;
    }
    if (typeof d.pair === "function")
    d.pair();
  }

  Timer {
    id: scan_timer
    interval: 25000
    repeat: false
    onTriggered: if (root.adapter) root.adapter.discovering = false
  }

  NumberAnimation {
    id: unpair_drain_anim
    duration: 1000
    easing.type: Easing.OutCubic
    onFinished: {
      unpair_hold_addr = "";
      unpair_hold_progress = 0;
      unpair_draining = false;
    }
  }

  /**
  * Drives the unpair hold progress. Every tick advances progress by the elapsed
  * fraction of the total hold window; when it reaches 1 the unpair fires and
  * the hold state clears.
  */
  Timer {
    id: unpair_hold_timer
    interval: 33
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (unpair_hold_addr.length === 0) {
        stop();
        return;
      }
      var next = unpair_hold_progress + 33.0 / root.unpair_hold_ms;
      if (next >= 1) {
        unpair_hold_progress = 1;
        var addr = unpair_hold_addr;
        root.cancelUnpairHold();
        if (Selection.valid(selected_index, devices_sorted.length)) {
          var d = devices_sorted[selected_index];
          if (d && d.paired && d.address === addr && typeof d.forget === "function")
          d.forget();
        }
      } else {
        unpair_hold_progress = next;
      }
    }
  }

  SurfaceHeader {
    id: header
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    title: "Bluetooth"

    LinkToggle {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      on_color: Theme.c.blue
      on: root.adapter ? root.adapter.enabled === true : false
      onToggled: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
    }
  }

  Item {
    id: actions_row
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: header.bottom
    anchors.topMargin: 12
    height: 40

    SurfaceActionPill {
      // visible: root.adapter ? root.adapter.enabled === true : false
      readonly property bool avil :root.adapter ? root.adapter.enabled === true : false
      id: scan_btn
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      // visible: root.adapter ? root.adapter.enabled === true : false
      opacity : avil ? 1 : 0.5
      active: root.discovering && avil
      height: 36
      font_size: 16
      horizontal_padding: 34
      text: root.discovering ? "Scanning…" : "Scan"
      onClicked: root.scanToggle()
    }

    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4
      visible: root.devices.length > 0

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.devices.length
        color: Theme.c.white
        font.family: Theme.clock_font
        font.pixelSize: 16
        font.bold: true
        opacity: 0.7
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "devices"
        color: Theme.c.black2
        font.family: Theme.clock_font
        font.pixelSize: 16
        font.bold: true
        opacity: 0.7
      }
    }
  }

  Rectangle {
    id: divider
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: actions_row.bottom
    anchors.topMargin: 12
    height: 1
    color: Qt.alpha(Theme.c.fg, 0.13)
  }

  Text {
    visible: root.devices.length === 0
    anchors.top: divider.bottom
    anchors.topMargin: 20
    anchors.horizontalCenter: parent.horizontalCenter
    text: root.discovering ? "Scanning…" : "No devices found"
    color: Theme.c.black2
    font.family: Theme.clock_font
    font.pixelSize: 16
    font.bold: true
    opacity: 0.7
  }

  ListView {
    id: device_list
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: divider.bottom
    anchors.topMargin: 10
    anchors.bottom: hold_row.top
    visible: root.devices.length > 0
    clip: true
    spacing: 6
    boundsBehavior: Flickable.StopAtBounds
    model: root.devices_sorted
    currentIndex: root.selected_index

    delegate: Item {
      id: dev_item
      required property var modelData
      required property int index
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: 6
      anchors.rightMargin: 6

      readonly property bool is_connected: modelData ? modelData.connected === true : false
      readonly property bool is_paired: modelData ? modelData.paired === true : false
      readonly property string addr: (modelData && modelData.address) ? modelData.address : ""
      readonly property bool pairing: modelData ? modelData.pairing === true : false
      readonly property int battery: root.battery_level(modelData)
      readonly property bool selected: dev_item.index === root.selected_index

      implicitHeight: dev_row.height

      SelectableRowFrame {
        id: dev_row
        width: parent.width
        height: 62
        selected: dev_item.selected
        frame_radius: 10
        onClicked: {
          root.cancelUnpairHold();
          root.selected_index = dev_item.index;
          root.activateDevice(dev_item.modelData);
        }

        Column {
          anchors.left: parent.left
          anchors.leftMargin: 14
          anchors.right: dev_right.left
          anchors.rightMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          spacing: 3

          Text {
            width: parent.width
            text: dev_item.modelData ? (dev_item.modelData.deviceName || dev_item.modelData.name || "Unknown") : "Unknown"
            color: dev_item.is_connected ? Theme.c.fg : Theme.c.white
            font.family: Theme.clock_font
            font.pixelSize: 20
            font.bold: dev_item.is_connected
            elide: Text.ElideRight
          }

          Text {
            width: parent.width
            visible: text.length > 0
            text: root.meta_for(dev_item.modelData)
            color: Theme.c.black2
            font.family: Theme.clock_font
            font.pixelSize: 16
            font.bold: true
            opacity: 0.8
            elide: Text.ElideRight
          }
        }

        Row {
          id: dev_right
          anchors.right: parent.right
          anchors.rightMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          spacing: 10

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: dev_item.pairing
            width: 7
            height: 7
            radius: width / 2
            color: Theme.c.yellow

            SequentialAnimation on opacity {
              running: dev_item.pairing
              loops: Animation.Infinite
              NumberAnimation { from: 0.35; to: 1; duration: Motion.pulse; easing.type: Easing.InOutSine }
              NumberAnimation { from: 1; to: 0.35; duration: Motion.pulse; easing.type: Easing.InOutSine }
            }
          }

          Filament {
            anchors.verticalCenter: parent.verticalCenter
            visible: dev_item.is_connected && dev_item.battery >= 0
            level: Math.max(0, dev_item.battery) / 100
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: dev_item.is_connected && dev_item.battery >= 0
            text: dev_item.battery + "%"
            color: Theme.c.black2
            font.family: Theme.clock_font
            font.pixelSize: 12
            font.bold: true
          }

          SurfaceActionPill {
            anchors.verticalCenter: parent.verticalCenter
            visible: !dev_item.is_paired && !dev_item.pairing
            height: 28
            text: "Pair"
            font_size: 13
            horizontal_padding: 20
            hover_color: Qt.alpha(Theme.c.fg, 0.06)
            inactive_border_color: Qt.alpha(Theme.c.fg, 0.15)
            inactive_text_color: Theme.c.black2
            hover_text_color: Theme.c.fg
            onClicked: {
              root.cancelUnpairHold();
              root.selected_index = dev_item.index;
              var md = dev_item.modelData;
              if (md && !md.paired && typeof md.pair === "function")
              md.pair();
            }
          }
        }

      }
    }
  }

  HoldBar {
    id: hold_row
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    active: root.unpair_holding || root.unpair_draining
    progress: root.unpair_hold_progress
    text: (root.unpair_holding && !root.unpair_draining) ? "Hold to unpair" : "Hold released"
    text_color: (root.unpair_holding && !root.unpair_draining) ? Theme.c.white : Theme.c.black2
    fill_start: Theme.c.cyan2
    fill_end: Theme.c.cyan2
  }
}
