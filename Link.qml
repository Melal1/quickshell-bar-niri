pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth

/**
* Connectivity hub + notification center. The top half shows Network
* (ethernet + wifi) and Bluetooth rows; below a separator sits the
* notification history (grouped or chronological). The rows own keyboard
* navigation; notifs are mouse/touch only.
*
* Clicking a row closes Link and opens the target surface on the Pill —
* `Network` or `Bluetooth` — through `pill.toggle_surface()`. The Pill's
* `toggle_surface` saves Link to `previous_surface` automatically, so pressing
* Esc on the target bounces the user back to Link.
*
* Keys:
*   j/k/↑/↓   — move between connectivity rows
*   g         — toggle grouped / chronological notif view
*   c (hold)  — hold-to-clear: the expanded group if one is open, else all notifs
*   Enter     — open the selected row's sub-surface
*   Esc       — cancel any in-flight hold, close surface
*
* Height: the surface's `dynamic_height` grows with the visible rows, the
* notif list content height, and the footer — capped at `Settings.link_max_h`.
* When capped, the notif ListView scrolls (mouse wheel).
*/
PillSurface {
  id: root

  m_top: 12
  m_left: 14
  m_right: 14
  m_bottom: 12
  clip:true

  focus: true

  readonly property var networking: (typeof Networking !== "undefined") ? Networking : null
  readonly property var raw_devices: (networking && networking.devices) ? networking.devices.values : []
  readonly property var wifi_dev: raw_devices.find(function(d) { return d && d.type === DeviceType.Wifi }) || null
  readonly property var wired_devs: raw_devices.filter(function(d) { return d && d.type === DeviceType.Wired })
  readonly property var primary_wired: wired_devs.find(function(d) { return d && d.hasLink }) || wired_devs[0] || null
  readonly property bool wifi_on: networking ? networking.wifiEnabled === true : false
  readonly property bool wifi_hardware_on: networking ? networking.wifiHardwareEnabled !== false : true
  readonly property var active_net: (wifi_dev && wifi_dev.networks)
  ? wifi_dev.networks.values.find(function(n) { return n && n.connected })
  : null
  readonly property var bt_adapter: (typeof Bluetooth !== "undefined" && Bluetooth) ? Bluetooth.defaultAdapter : null
  readonly property var bt_devices: (typeof Bluetooth !== "undefined" && Bluetooth && Bluetooth.devices)
  ? Bluetooth.devices.values
  : []
  readonly property int bt_connected_count: bt_devices.filter(function(d) { return d && d.connected; }).length
  readonly property var bt_connected_device: bt_devices.find(function(d) { return d && d.connected; }) || null

  readonly property bool network_has_ethernet: primary_wired && primary_wired.hasLink
  readonly property bool network_ethernet_connected: primary_wired && primary_wired.connected
  readonly property bool network_wifi_connected: wifi_on && active_net
  readonly property real network_signal: (active_net && typeof active_net.signalStrength === "number") ? active_net.signalStrength : 0

  function bt_battery(d) {
    if (!d || d.batteryAvailable !== true || !(d.battery > 0)) return -1;
    var b = d.battery;
    if (b <= 1) b = b * 100;
    return Math.round(b);
  }

  /**
  * Notification-center state. `grouped_view` switches between grouped and
  * chronological rendering of `NotificationsServer.history`.
  * `expanded_group` is the app name of the single currently-open group, or
  * "" when none is open.
  */
  property bool grouped_view: true
  property string expanded_group: ""
  property var current_time: Date.now()

  /**
  * Hold-to-confirm state for clear-all. Mirrors the BluetoothSurface unpair
  * pattern: a 33ms repeating timer advances `clear_hold_progress`; reaching 1
  * clears the expanded group (if one is open in grouped view) or all notifs
  * (otherwise). Releasing the key drains the bar back to 0 over 1s without
  * clearing.
  */
  property bool clear_holding: false
  property real clear_hold_progress: 0
  property bool clear_draining: false
  readonly property int clear_hold_ms: 1500

  function startClearHold() {
    if (clear_holding) return;
    if (NotificationsServer.history.length === 0) return;
    clear_holding = true;
    clear_hold_progress = 0;
    clear_hold_timer.restart();
  }

  function cancelClearHold() {
    clear_hold_timer.stop();
    clear_drain_anim.stop();
    clear_holding = false;
    clear_hold_progress = 0;
    clear_draining = false;
  }

  function drainClearHold() {
    if (!clear_holding || clear_draining) return;
    clear_hold_timer.stop();
    clear_draining = true;
    clear_drain_anim.from = clear_hold_progress;
    clear_drain_anim.to = 0;
    clear_drain_anim.start();
  }

  Timer {
    id: clear_hold_timer
    interval: 33
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!root.clear_holding) { stop(); return; }
      var next = root.clear_hold_progress + 33.0 / root.clear_hold_ms;
      if (next >= 1) {
        root.clear_hold_progress = 1;
        root.cancelClearHold();
        if (root.grouped_view && root.expanded_group.length > 0) {
          var g = null;
          var groups = NotificationsServer.groups;
          for (var i = 0; i < groups.length; i++) {
            if (groups[i].preview.app === root.expanded_group) { g = groups[i]; break; }
          }
          if (g) NotificationsServer.remove_group(g);
          root.expanded_group = "";
        } else {
          NotificationsServer.clear_all();
        }
      } else {
        root.clear_hold_progress = next;
      }
    }
  }

  NumberAnimation {
    id: clear_drain_anim
    duration: 1000
    easing.type: Easing.OutCubic
    onFinished: {
      root.clear_holding = false;
      root.clear_hold_progress = 0;
      root.clear_draining = false;
    }
  }

  Timer {
    interval: 30000
    running: root.open
    repeat: true
    onTriggered: root.current_time = Date.now()
  }

  /**
  * Row geometry and dynamic height. `row_h` is the fixed height each row
  * uses; `dynamic_height` is the total surface height Pill should morph to.
  * It now includes the header, the visible connectivity rows, a separator,
  * the notif region (growing with `contentHeight`, capped), and the footer.
  * The outer `Math.min` enforces `Settings.link_max_h` as the hard cap — past
  * that the notif ListView's own `clip` + `StopAtBounds` kicks in and the
  * list scrolls internally.
  */
  readonly property real row_h: 66
  readonly property real header_h: 24
  readonly property real row_spacing: 6
  readonly property real top_margin: 8
  readonly property real rows_empty_h: 20
  readonly property real sep_margin: 12
  readonly property real inbox_header_h: 22
  readonly property real footer_h: 24
  readonly property real notif_empty_h: 110

  readonly property bool net_row_visible: network_has_ethernet || (wifi_dev && wifi_hardware_on)
  readonly property bool bt_row_visible: bt_adapter

  readonly property real rows_height: {
    var h = 0;
    if (net_row_visible) h += row_h + row_spacing;
    if (bt_row_visible) h += row_h;
    if (!net_row_visible && !bt_row_visible) h += rows_empty_h;
    return h;
  }

  readonly property real notif_list_h: {
    if (NotificationsServer.history.length === 0) return notif_empty_h;
    var content = grouped_view ? grouped_list.contentHeight : chrono_list.contentHeight;
    var fixed = m_top + m_bottom + header_h + top_margin + rows_height
    + sep_margin + inbox_header_h + 4 + footer_h;
    return Math.min(content, Settings.link_max_h - fixed);
  }

  readonly property real dynamic_height: {
    var h = m_top + m_bottom + header_h + top_margin + rows_height;
    h += sep_margin + inbox_header_h + 4;
    h += notif_list_h;
    h += footer_h;
    return Math.min(h, Settings.link_max_h);
  }

  /**
  * Selection state. `main_selected` is 0 (network) or 1 (bluetooth). If the
  * selected row is hidden, `moveMain` pins to the visible row.
  */
  property int main_selected: 0

  onOpenChanged: {
    main_selected = 0;
    if (open) {
      root.forceActiveFocus();
      root.current_time = Date.now();
      NotificationsServer.suppress_popups = true;
      NotificationsServer.mark_all_seen();
      grouped_list.contentY = 0;
      chrono_list.contentY = 0;
    } else {
      NotificationsServer.suppress_popups = false;
      root.expanded_group = "";
      root.cancelClearHold();
    }
  }

  function activateMainRow() {
    if (main_selected === 0 && net_row_visible) {
      pill.toggle_surface(Pill.Surfaces.Network);
    } else if (main_selected === 1 && bt_row_visible) {
      pill.toggle_surface(Pill.Surfaces.Bluetooth);
    }
  }

  function moveMain(delta) {
    var next = main_selected + delta;
    next = Math.max(0, Math.min(1, next));
    if (next === 0 && !net_row_visible) next = 1;
    if (next === 1 && !bt_row_visible) next = 0;
    main_selected = next;
  }

  Keys.onEscapePressed: (event) => {
    event.accepted = true;
    root.cancelClearHold();
    root.request_close();
  }

  Keys.onPressed: (event) => {
    if (event.isAutoRepeat) return;

    if (event.modifiers === Qt.NoModifier && (event.text === "g" || event.text === "G")) {
      grouped_view = !grouped_view;
      event.accepted = true;
      return;
    }
    if (event.modifiers === Qt.NoModifier && (event.text === "c" || event.text === "C")
      && NotificationsServer.history.length > 0) {
      root.startClearHold();
      event.accepted = true;
      return;
    }
    if (event.text === "j" || event.text === "J" || event.key === Qt.Key_Down) {
      root.moveMain(1);
      event.accepted = true;
      return;
    }
    if (event.text === "k" || event.text === "K" || event.key === Qt.Key_Up) {
      root.moveMain(-1);
      event.accepted = true;
      return;
    }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.activateMainRow();
      event.accepted = true;
      return;
    }
  }

  Keys.onReleased: (event) => {
    if (event.isAutoRepeat) return;
    if (event.text === "c" || event.text === "C") {
      root.drainClearHold();
      event.accepted = true;
    }
  }

  SurfaceHeader {
    id: header
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    title: "Link"
  }

  Column {
    id: main_col
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: header.bottom
    anchors.topMargin: top_margin
    spacing: row_spacing

    /**
    * Network row. Visible when ethernet has a link or wifi device is present.
    * Title: ethernet device name (if connected) > wifi SSID (if connected) > "Network".
    * Left glyph: "ethernet" if ethernet has link, else "wifi".
    * Right indicator: WifiGlyph showing signal strength (hidden when ethernet is active).
    */
    Item {
      id: net_row
      visible: root.net_row_visible
      width: main_col.width
      height: root.row_h

      readonly property bool selected: root.main_selected === 0
      readonly property color tone_color: root.network_ethernet_connected || root.network_wifi_connected
      ? Theme.c.green2
      : (root.network_has_ethernet || root.wifi_on ? Theme.c.fg : Theme.c.black2)

      SelectableRowFrame {
        id: net_rect
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        frame_radius: 10
        selected: net_row.selected
        bar_left_margin: 0
        onClicked: {
          root.main_selected = 0;
          root.activateMainRow();
        }

        GlyphIcon {
          id: net_glyph
          anchors.left: parent.left
          anchors.leftMargin: 14
          anchors.verticalCenter: parent.verticalCenter
          width: 18
          height: 18
          name: root.network_has_ethernet ? "ethernet" : "wifi"
          color: net_row.tone_color
          stroke: 1.8
        }

        Text {
          id: net_title
          anchors.left: net_glyph.right
          anchors.leftMargin: 14
          anchors.right: net_indicator.left
          anchors.rightMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          text: root.network_ethernet_connected
          ? ((root.primary_wired && root.primary_wired.name) || "Ethernet")
          : (root.network_wifi_connected
            ? ((root.active_net && root.active_net.name) || "Wi-Fi")
            : "Network")
          color: Theme.c.white
          font.family: Theme.clock_font
          font.pixelSize: 20
          font.bold: true
          elide: Text.ElideRight
        }

        Item {
          id: net_indicator
          anchors.right: net_chev.left
          anchors.rightMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          width: net_glyph_icon.width
          height: net_glyph_icon.height
          visible: !root.network_ethernet_connected

          WifiGlyph {
            id: net_glyph_icon
            anchors.centerIn: parent
            width: 28
            height: 28
            level: root.network_wifi_connected ? root.network_signal : 0
            on: root.wifi_on
            color: root.network_wifi_connected ? Theme.c.green2 : Theme.c.fg
          }
        }

        Item {
          id: net_chev
          anchors.right: parent.right
          anchors.rightMargin: 14
          anchors.verticalCenter: parent.verticalCenter
          width: 16
          height: 16

          GlyphIcon {
            anchors.centerIn: parent
            width: 16
            height: 16
            name: "chevron-right"
            color: net_row.selected ? Theme.c.fg : Theme.c.black2
            stroke: 1.6
          }
        }

      }
    }

    /**
    * Bluetooth row. Visible when the BT adapter is present.
    * Title: connected device name (if any) > "Bluetooth".
    * Left glyph: "bluetooth".
    * Right indicator: Filament battery bar (visible only when connected and device reports battery).
    */
    Item {
      id: bt_row
      visible: root.bt_row_visible
      width: main_col.width
      height: root.row_h

      readonly property bool selected: root.main_selected === 1
      readonly property color tone_color: root.bt_connected_count > 0
      ? Theme.c.green2
      : (root.bt_adapter && root.bt_adapter.enabled ? Theme.c.fg : Theme.c.black2)

      SelectableRowFrame {
        id: bt_rect
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        frame_radius: 10
        selected: bt_row.selected
        bar_left_margin: 0
        onClicked: {
          root.main_selected = 1;
          root.activateMainRow();
        }

        GlyphIcon {
          id: bt_glyph
          anchors.left: parent.left
          anchors.leftMargin: 14
          anchors.verticalCenter: parent.verticalCenter
          width: 18
          height: 18
          name: "bluetooth"
          color: bt_row.tone_color
          stroke: 1.8
        }

        Text {
          id: bt_title
          anchors.left: bt_glyph.right
          anchors.leftMargin: 14
          anchors.right: bt_indicator.left
          anchors.rightMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          text: root.bt_connected_device
          ? (root.bt_connected_device.deviceName || root.bt_connected_device.name || "Bluetooth")
          : "Bluetooth"
          color: Theme.c.white
          font.family: Theme.clock_font
          font.pixelSize: 20
          font.bold: true
          elide: Text.ElideRight
        }

        Item {
          id: bt_indicator
          anchors.right: bt_chev.left
          anchors.rightMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          width: bt_filament.width
          height: bt_filament.height
          visible: root.bt_connected_device && root.bt_battery(root.bt_connected_device) >= 0

          Filament {
            id: bt_filament
            anchors.centerIn: parent
            level: {
              var lvl = root.bt_battery(root.bt_connected_device);
              return lvl >= 0 ? lvl / 100 : 0;
            }
          }
        }

        Item {
          id: bt_chev
          anchors.right: parent.right
          anchors.rightMargin: 14
          anchors.verticalCenter: parent.verticalCenter
          width: 16
          height: 16

          GlyphIcon {
            anchors.centerIn: parent
            width: 16
            height: 16
            name: "chevron-right"
            color: bt_row.selected ? Theme.c.fg : Theme.c.black2
            stroke: 1.6
          }
        }

      }
    }
  }

  Text {
    visible: !root.net_row_visible && !root.bt_row_visible
    anchors.top: header.bottom
    anchors.topMargin: 16
    anchors.horizontalCenter: parent.horizontalCenter
    text: "No transport available"
    color: Theme.c.black2
    font.family: Theme.clock_font
    font.pixelSize: 14
    font.bold: true
    opacity: 0.7
  }

  // ── Inbox section header (replaces separator) ──
  Item {
    id: inbox_header
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: main_col.bottom
    anchors.topMargin: root.sep_margin
    height: root.inbox_header_h

    // Row {
    //   anchors.left: parent.left
    //   anchors.leftMargin: 4
    //   anchors.verticalCenter: parent.verticalCenter
    //   spacing: 6
    //
    //   GlyphIcon {
    //     anchors.verticalCenter: parent.verticalCenter
    //     name: "inbox"
    //     color: Theme.c.white
    //     width: 16
    //     height: 16
    //     stroke: 1.5
    //   }
    //
    //   Text {
    //     anchors.verticalCenter: parent.verticalCenter
    //     text: "INBOX"
    //     color: Theme.c.white
    //     font.family: Theme.clock_font
    //     font.pixelSize: 16
    //     font.bold: true
    //     font.letterSpacing: 2.2
    //     opacity: 0.7
    //   }
    // }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin : 10
      anchors.left : parent.left
      text: ( NotificationsServer.history.length === 0 ? " " : "󱅫 " ) + "INBOX"
      color: Theme.c.white
      font.family: Theme.clock_font
      font.pixelSize: 16
      font.bold: true
      font.letterSpacing: 3
      opacity: NotificationsServer.history.length === 0 ? 0.3:0.8
    }
  }

  // ── Notif region ──
  Item {
    id: notif_area
    anchors.left: parent.left

    anchors.right: parent.right
    anchors.top: inbox_header.bottom
    anchors.topMargin: 4
    height: root.notif_list_h
    clip: true

    // Empty state: big inbox glyph + caption
    Column {
      anchors.centerIn: parent
      visible: NotificationsServer.history.length === 0
      spacing: 8
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: ""
        color: Theme.c.black2
        font.family: Theme.clock_font
        font.pixelSize: 64
        font.bold: true
        font.letterSpacing: 2.2
        opacity: 0.4
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "NO NOTIFICATIONS"
        color: Theme.c.black2
        font.family: Theme.clock_font
        font.pixelSize: 11
        font.bold: true
        font.letterSpacing: 2.2
        opacity: 0.7
      }
    }

    // Grouped view
    ListView {
      id: grouped_list
      anchors.fill: parent
      visible: root.grouped_view && NotificationsServer.history.length > 0
      model: root.grouped_view ? NotificationsServer.groups : []
      spacing: 5
      boundsBehavior: Flickable.StopAtBounds
      interactive: true

      remove: Transition {
        ParallelAnimation {
          NumberAnimation { property: "scale"; to: 0.8; duration: Motion.fast; easing.type: Easing.OutQuad }
          NumberAnimation { property: "opacity"; to: 0; duration: Motion.fast; easing.type: Easing.OutQuad }
        }
      }
      displaced: Transition {
        NumberAnimation { property: "y"; duration: Motion.std; easing.type: Motion.std_ease }
      }

      delegate: Item {
        id: group_col
        required property var modelData
        required property int index
        property bool collapsed: root.expanded_group !== modelData.preview.app
        width: grouped_list.width
        height: 44 + (items_col.visible ? items_col.implicitHeight : 0)

        // Group header — compact row with latest notif's image, app name,
        // count, preview text, and chevron. Sticks to the viewport top while
        // this group's items scroll under it (opaque bg, z:1). Corners go
        // square when pinned so cards can't peek through rounded arcs.
        Rectangle {
          id: group_header
          width: parent.width
          height: 44
          radius: group_header.y > 0 ? 0 : 8
          color: Theme.c.bg
          y: Math.max(0, Math.min(grouped_list.contentY - group_col.y, group_col.height - 44))
          z: 1

          // Hover tint overlay (keeps the base bg opaque for the sticky effect)
          Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: head_hover.containsMouse ? Qt.alpha(Theme.c.fg, 0.06) : "transparent"
            Behavior on color { ColorAnimation { duration: Motion.fast } }
          }

          MouseArea {
            id: head_hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var app = group_col.modelData.preview.app;
              root.expanded_group = (root.expanded_group === app) ? "" : app;
            }
          }

          // Latest notif's image tile
          Rectangle {
            id: head_tile
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 26
            radius: 7
            color: Theme.c.black
            border.width: 1
            border.color: Theme.c.black2

            Image {
              id: head_img
              anchors.fill: parent
              anchors.margins: group_col.modelData.preview.image ? 0 : 4
              source: NotificationsServer.icon_for(group_col.modelData.preview)
              sourceSize.width: 52
              sourceSize.height: 52
              fillMode: Image.PreserveAspectCrop
              smooth: true
              visible: source.toString().length > 0
            }

            Rectangle {
              anchors.centerIn: parent
              visible: !head_img.visible
              width: 6
              height: 6
              radius: 3
              color: Theme.c.fg
            }
          }

          // App name
          Text {
            id: head_name
            anchors.left: head_tile.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 140)
            text: group_col.modelData.preview.app
            color: Theme.c.black2
            font.family: Theme.clock_font
            font.pixelSize: 16
            font.bold: true
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.2
            elide: Text.ElideRight
          }

          // Count: "· N"
          Text {
            id: head_count
            anchors.left: head_name.right
            anchors.leftMargin: 5
            anchors.verticalCenter: parent.verticalCenter
            text: "· " + group_col.modelData.items.length
            color: Theme.c.black2
            font.family: Theme.clock_font
            font.pixelSize: 16
            opacity: 0.7
          }

          // Preview text (body or summary of the latest notif)
          Text {
            anchors.left: head_count.right
            anchors.leftMargin: 8
            anchors.right: head_chev.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: (group_col.modelData.preview.body && group_col.modelData.preview.body.length > 0)
            ? group_col.modelData.preview.body
            : group_col.modelData.preview.summary
            color: Theme.c.black2
            font.family: Theme.clock_font
            font.pixelSize: 14
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
            opacity: 0.6
          }

          // Expand/collapse chevron
          GlyphIcon {
            id: head_chev
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            name: group_col.collapsed ? "chevron-right" : "chevron-down"
            color: Theme.c.black2
            stroke: 1.8
            opacity: 0.7
          }
        }

        // Expanded items — only visible when not collapsed
        Column {
          id: items_col
          width: parent.width
          y: 44
          visible: !group_col.collapsed
          spacing: 4

          Behavior on opacity { NumberAnimation { duration: Motion.fast } }

          ListView {
            id: inner_list
            width: parent.width
            implicitHeight: contentHeight
            interactive: false
            model: group_col.modelData.items
            spacing: 4

            delegate: NotifCard {
              id: inner_card
              required property var modelData
              required property int index
              width: inner_list.width
              notif: modelData
              current_time: root.current_time

              SequentialAnimation {
                id: inner_remove_anim
                ParallelAnimation {
                  NumberAnimation { target: inner_card; property: "scale"; to: 0.8; duration: Motion.fast; easing.type: Easing.OutQuad }
                  NumberAnimation { target: inner_card; property: "opacity"; to: 0; duration: Motion.fast; easing.type: Easing.OutQuad }
                  NumberAnimation { target: inner_card; property: "implicitHeight"; to: 0; duration: Motion.fast; easing.type: Easing.OutQuad }
                }
                ScriptAction {
                  script: {
                    if (inner_card.notif) {
                      NotificationsServer.remove_notif(inner_card.notif);
                    }
                  }
                }
              }

              onDismissRequested: inner_remove_anim.start()
            }
          }
        }
      }
    }

    // Chronological view
    ListView {
      id: chrono_list
      anchors.fill: parent
      anchors.topMargin: 4
      visible: !root.grouped_view && NotificationsServer.history.length > 0
      model: !root.grouped_view ? NotificationsServer.history : []
      spacing: 4
      boundsBehavior: Flickable.StopAtBounds
      interactive: true

      add: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.std }
        NumberAnimation { property: "y"; from: -20; duration: Motion.std; easing.type: Motion.std_ease }
      }
      displaced: Transition {
        NumberAnimation { properties: "y"; duration: Motion.std; easing.type: Motion.std_ease }
      }

      delegate: SelectableRowFrame {
        id: chrono_frame
        width: chrono_list.width
        implicitHeight: chrono_card.implicitHeight
        selected: false
        selected_color: "transparent"
        hover_color: "transparent"
        normal_color: "transparent"
        bar_vertical_offset: -3
        required property var modelData
        required property int index

        NotifCard {
          id: chrono_card
          width: parent.width
          notif: chrono_frame.modelData
          current_time: root.current_time

          SequentialAnimation {
            id: chrono_remove_anim
            ParallelAnimation {
              NumberAnimation { target: chrono_card; property: "scale"; to: 0.8; duration: Motion.fast; easing.type: Easing.OutQuad }
              NumberAnimation { target: chrono_card; property: "opacity"; to: 0; duration: Motion.fast; easing.type: Easing.OutQuad }
              NumberAnimation { target: chrono_card; property: "implicitHeight"; to: 0; duration: Motion.fast; easing.type: Easing.OutQuad }
            }
            ScriptAction {
              script: {
                if (chrono_card.notif) {
                  NotificationsServer.remove_notif(chrono_card.notif);
                }
              }
            }
          }

          onDismissRequested: chrono_remove_anim.start()
        }
      }
    }
  }

  // ── Footer: tips + clear-all HoldBar ──
  Item {
    id: footer
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: notif_area.bottom
    anchors.topMargin: root.sep_margin
    height: root.footer_h

    Text {
      anchors.centerIn: parent
      visible: NotificationsServer.history.length > 0
      text: "g toggle  ·  c clear  ·  j/k move  ·  esc close"
      color: Theme.c.black2
      font.family: Theme.clock_font
      font.pixelSize: 15
      font.bold: true
      font.letterSpacing: 1.2
      opacity: root.clear_holding || root.clear_draining ? 0 : 0.6
      Behavior on opacity { NumberAnimation { duration: Motion.fast } }
    }

    HoldBar {
      id: clear_hold_bar
      anchors.fill: parent
      active: root.clear_holding || root.clear_draining
      progress: root.clear_hold_progress
      text: (root.clear_holding && !root.clear_draining) ? "Hold to clear all" : "Hold released"
      text_color: (root.clear_holding && !root.clear_draining) ? Theme.c.white : Theme.c.black2
      fill_start: Qt.alpha(Theme.c.red, 0.55)
      fill_end: Qt.alpha(Theme.c.red2, 0.55)
    }
  }
}
