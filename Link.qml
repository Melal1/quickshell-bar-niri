pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth

/**
* Connectivity hub: a small overview of Network (ethernet + wifi) and
* Bluetooth. Clicking a row closes Link and opens the target surface on the
* Pill — `Network` or `Bluetooth` — through `pill.toggle_surface()`. The
* Pill's `toggle_surface` saves Link to `previous_surface` automatically, so
* pressing Esc on the target bounces the user back to Link.
*
* The Network row collapses ethernet and wifi into a single line: ethernet
* takes priority when connected (so the row shows the ethernet device name
* with the ethernet glyph), wifi shows through when ethernet is absent, and
* the "Network" detail view inside the standalone Network surface still
* lists both transports separately.
*
* Height: the surface's `dynamic_height` is computed from the visible rows
* plus the header and margins, so the Pill morphs to fit whatever content is
* actually present. If a row's visibility flips mid-open (e.g. an ethernet
* cable is plugged in), the Pill animates to the new height.
*/
PillSurface {
  id: root

  m_top: 12
  m_left: 14
  m_right: 14
  m_bottom: 12

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
    if (!d || d.batteryAvailable !== true) return -1;
    var b = d.battery;
    if (b <= 0) return -1;
    if (b <= 1) b = b * 100;
    return Math.round(b);
  }

  /**
  * Row geometry and dynamic height. `row_h` is the fixed height each row
  * uses; `dynamic_height` is the total surface height Pill should morph to,
  * computed from the header, visible rows, and margins. When a row's
  * visibility flips mid-open, `dynamic_height` recomputes and the Pill
  * animates to the new value.
  */
  readonly property real row_h: 66
  readonly property real header_h: 24
  readonly property real row_spacing: 6
  readonly property real top_margin: 8
  readonly property real empty_state_h: 20

  readonly property bool net_row_visible: network_has_ethernet || (wifi_dev && wifi_hardware_on)
  readonly property bool bt_row_visible: bt_adapter

  readonly property real dynamic_height: {
    var h = m_top + m_bottom;
    h += header_h;
    h += top_margin;
    if (net_row_visible) h += row_h + row_spacing;
    if (bt_row_visible) h += row_h;
    if (!net_row_visible && !bt_row_visible) h += empty_state_h;
    return h;
  }

  /**
  * Selection state. `main_selected` is 0 (network) or 1 (bluetooth). If the
  * selected row is hidden, `moveMain` skips to the next visible row.
  */
  property int main_selected: 0

  onOpenChanged: {
    main_selected = 0;
    if (open) {
      root.forceActiveFocus();
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
    if (next < 0) next = 0;
    if (next > 1) next = 1;
    // Skip hidden rows: if the target row is hidden, walk forward/backward.
    if (next === 0 && !net_row_visible && bt_row_visible) next = 1;
    if (next === 1 && !bt_row_visible && net_row_visible) next = 0;
    if (next !== main_selected) {
      main_selected = next;
    }
  }

  Keys.onEscapePressed: (event) => {
    event.accepted = true;
    root.request_close();
  }

  Keys.onPressed: (event) => {
    if (event.isAutoRepeat) return;
    if (event.text === "j" || event.text === "J" || event.key === Qt.Key_Down) {
      moveMain(1);
      event.accepted = true;
      return;
    }
    if (event.text === "k" || event.text === "K" || event.key === Qt.Key_Up) {
      moveMain(-1);
      event.accepted = true;
      return;
    }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      activateMainRow();
      event.accepted = true;
      return;
    }
  }

  SurfaceHeader {
    id: header
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    title: "Connectivity"
  }

  Column {
    id: main_col
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: header.bottom
    anchors.topMargin: top_margin
    anchors.bottom: parent.bottom
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
}

