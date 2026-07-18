pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Networking
import "lib/selection.js" as Selection

/**
* Network surface: WiFi list (scan, connect, password) and Ethernet devices.
* Owns focus, scan timer, password draft, and the connection-failed signal wiring.
*
* Preferred-link order: any connected wired device is surfaced above WiFi,
* mirroring the Main view's preference.
*/
PillSurface {
  id: root

  m_top: 15
  m_left: 17
  m_right: 17
  m_bottom: 14

  readonly property var networking: (typeof Networking !== "undefined") ? Networking : null
  readonly property var raw_devices: (networking && networking.devices) ? networking.devices.values : []
  readonly property var wifi_dev: raw_devices.find(function(d) { return d && d.type === DeviceType.Wifi }) || null
  readonly property var wired_devs: raw_devices.filter(function(d) { return d && d.type === DeviceType.Wired })

  readonly property var nets: (wifi_dev && wifi_dev.networks) ? wifi_dev.networks.values : []
  readonly property var nets_sorted: nets.slice().sort(function(a, b) {
      var ac = (a && a.connected) ? 1 : 0;
      var bc = (b && b.connected) ? 1 : 0;
      if (ac !== bc) return bc - ac;
      return ((b ? b.signalStrength : 0) || 0) - ((a ? a.signalStrength : 0) || 0);
  })
  readonly property var active_net: nets.find(function(n) { return n && n.connected }) || null
  readonly property var primary_wired: wired_devs.find(function(d) { return d && d.hasLink }) || wired_devs[0] || null

  /**
  * Combined "rows" list shown in the main ListView: each wired device first
  * (so Ethernet wins over WiFi when both are connected), then each WiFi
  * network. A null wired list still lets WiFi rows render alone.
  */
  readonly property var rows: {
    var out = [];
    for (var i = 0; i < wired_devs.length; i++) {
      if (wired_devs[i]) out.push({ kind: "wired", dev: wired_devs[i] });
    }
    for (var j = 0; j < nets_sorted.length; j++) {
      if (nets_sorted[j]) out.push({ kind: "wifi", net: nets_sorted[j] });
    }
    return out;
  }

  readonly property int wired_count: wired_devs.length
  readonly property int wifi_count: nets.length
  readonly property bool wifi_on: networking ? networking.wifiEnabled === true : false
  readonly property bool wifi_hardware_on: networking ? networking.wifiHardwareEnabled !== false : true
  readonly property bool scanning: wifi_dev ? wifi_dev.scannerEnabled === true : false

  property int selected_index: 0

  /**
  * SSID whose password is being asked for in the inline confirm row, plus the
  * password draft and the failure flag. `connecting` blocks the enter glyph
  * and spins a dot; `connectFailed` shows the "Connection failed" note.
  */
  property string expanded_ssid: ""
  property string pw_draft: ""
  property bool connecting: false
  property bool connect_failed: false

  function moveSelection(delta) {
    if (rows.length === 0) return;
    var next = Selection.move(selected_index, delta, rows.length);
    if (next !== selected_index) {
      selected_index = next;
      row_list.positionViewAtIndex(selected_index, ListView.Contain);
    }
  }

  function activateSelected() {
    if (!Selection.valid(selected_index, rows.length)) return;
    var r = rows[selected_index];
    if (!r) return;
    if (r.kind === "wired") activateWired(r.dev);
    else activateWifi(r.net);
  }

  function activateWired(dev) {
    if (!dev) return;
    if (dev.connected) {
      if (typeof dev.disconnect === "function") dev.disconnect();
      return;
    }
    if (typeof dev.connect === "function") dev.connect();
  }

  function activateWifi(net) {
    if (!net) return;
    if (net.connected) {
      if (typeof net.disconnect === "function") net.disconnect();
      return;
    }
    if (net.known) {
      if (typeof net.connect === "function") net.connect();
      return;
    }
    if (isSecured(net)) {
      connect_failed = false;
      pw_draft = "";
      expanded_ssid = net.name || "";
      return;
    }
    if (typeof net.connect === "function") net.connect();
  }

  function isSecured(net) {
    if (!net || net.security === undefined) return false;
    if (typeof WifiSecurityType !== "undefined" && typeof net.security === "number") {
      if (net.security === WifiSecurityType.None) return false;
      if (net.security === WifiSecurityType.Unknown) return false;
      if (net.security === WifiSecurityType.WpaPsk) return true;
      if (net.security === WifiSecurityType.Wpa2Psk) return true;
      if (net.security === WifiSecurityType.Sae) return true;
      if (net.security === WifiSecurityType.Wpa3SuiteB192) return true;
      if (net.security === WifiSecurityType.WpaEnterprise) return true;
    }
    var s = String(net.security);
    if (s === "" || s === "None" || s === "Unknown") return false;
    return true;
  }

  function scanToggle() {
    if (!wifi_dev) return;
    wifi_dev.scannerEnabled = !wifi_dev.scannerEnabled;
    if (wifi_dev.scannerEnabled) scan_timer.restart();
    else scan_timer.stop();
  }

  function cancelPassword() {
    expanded_ssid = "";
    pw_draft = "";
    connect_failed = false;
  }

  function connectWithPassword() {
    var ssid = expanded_ssid;
    var pw = pw_draft;
    if (!ssid.length || !pw.length) return;
    var net = nets.find(function(n) { return n && (n.name === ssid); });
    if (!net) return;
    connecting = true;
    connect_failed = false;
    if (typeof net.connectWithPsk === "function") {
      net.connectWithPsk(pw);
    } else if (typeof net.connect === "function") {
      net.connect();
    }
  }

  onOpenChanged: {
    if (open) {
      selected_index = 0;
      if (wifi_dev && wifi_on) wifi_dev.scannerEnabled = true;
      root.forceActiveFocus();
    } else {
      scan_timer.stop();
      if (wifi_dev) wifi_dev.scannerEnabled = false;
      cancelPassword();
    }
  }

  onWifi_onChanged: {
    if (wifi_dev) wifi_dev.scannerEnabled = wifi_on && open;
  }

  onExpanded_ssidChanged: if (pw_draft.length === 0) connect_failed = false

  Timer {
    id: scan_timer
    interval: 25000
    repeat: false
    onTriggered: if (root.wifi_dev) root.wifi_dev.scannerEnabled = false
  }

  /**
  * Catches `NoSecrets` and other failures from `connectWithPsk`. The signal
  * also fires for `connect()` on unknown secured networks, which we already
  * route through the password row, so the handler only needs to surface the
  * failure and clear the connecting flag.
  */
  Connections {
    target: root.networking
    function onConnectivityChanged() { }
  }

  function handleConnectionFailed(net, reason) {
    connecting = false;
    if (!net) return;
    var ssid = net.name || "";
    if (ssid === expanded_ssid) {
      connect_failed = true;
    }
  }

  focus: true
  Keys.onPressed: (event) => {
    if (event.isAutoRepeat) return;
    if (event.key === Qt.Key_S || event.text === "s" || event.text === "S") {
      root.scanToggle();
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
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (root.expanded_ssid.length > 0) {
        root.connectWithPassword();
      } else {
        root.activateSelected();
      }
      event.accepted = true;
      return;
    }
    if (event.key === Qt.Key_Escape) {
      if (root.expanded_ssid.length > 0) {
        root.cancelPassword();
        event.accepted = true;
        return;
      }
      root.request_close();
      event.accepted = true;
      return;
    }
  }

  Item {
    id: header_row
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: 24

    SurfaceHeader {
      id: head
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      title: "Network"

      LinkToggle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        on_color: Theme.c.blue
        on: root.wifi_on
        onToggled: {
          if (root.networking) root.networking.wifiEnabled = !root.networking.wifiEnabled;
        }
      }
    }
  }

  Item {
    id: actions_row
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: header_row.bottom
    anchors.topMargin: 6
    height: 36

    SurfaceActionPill {
      id: scan_btn
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      active: root.scanning
      height: 30
      font_size: 14
      horizontal_padding: 28
      text: root.scanning ? "Scanning…" : "Scan"
      onClicked: root.scanToggle()
    }

    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 6
      visible: root.rows.length > 0

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.rows.length
        color: Theme.c.white
        font.family: Theme.clock_font
        font.pixelSize: 14
        font.bold: true
        opacity: 0.7
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.wired_count > 0 ? "links" : "networks"
        color: Theme.c.black2
        font.family: Theme.clock_font
        font.pixelSize: 14
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
    anchors.topMargin: 8
    height: 1
    color: Qt.alpha(Theme.c.fg, 0.13)
  }

  Text {
    visible: root.rows.length === 0
    anchors.top: divider.bottom
    anchors.topMargin: 20
    anchors.horizontalCenter: parent.horizontalCenter
    text: root.scanning ? "Scanning…" : "No networks found"
    color: Theme.c.black2
    font.family: Theme.clock_font
    font.pixelSize: 14
    font.bold: true
    opacity: 0.7
  }

  ListView {
    id: row_list
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: divider.bottom
    anchors.topMargin: 8
    anchors.bottom: parent.bottom
    visible: root.rows.length > 0
    clip: true
    spacing: 4
    boundsBehavior: Flickable.StopAtBounds
    model: root.rows
    currentIndex: root.selected_index

    delegate: Item {
      id: row_item
      required property int index
      required property var modelData

      width: row_list.width
      height: row_inner.height + (row_item.expanded_pw ? (pw_block.height + (root.connect_failed ? 18 : 0)) : 0)

      readonly property bool is_wired: modelData ? modelData.kind === "wired" : false
      readonly property var wired: (is_wired && modelData) ? modelData.dev : null
      readonly property var net: (!is_wired && modelData) ? modelData.net : null
      readonly property bool is_connected: is_wired
      ? (wired ? wired.connected === true : false)
      : (net ? net.connected === true : false)
      readonly property bool is_known: !is_wired && net ? net.known === true : false
      readonly property bool secured: !is_wired && root.isSecured(net)
      readonly property int signal: (!is_wired && net) ? Math.round((net.signalStrength || 0) * 100) : 0
      readonly property bool selected: row_item.index === root.selected_index
      readonly property bool expanded_pw: !is_wired && root.expanded_ssid === (net && net.name)

      SelectableRowFrame {
        id: row_inner
        width: parent.width
        height: 60
        selected: row_item.selected
        frame_radius: 10
        onClicked: {
          root.selected_index = row_item.index;
          if (row_item.is_wired) root.activateWired(row_item.wired);
          else root.activateWifi(row_item.net);
        }

        // GlyphIcon {
        //   id: row_glyph
        //   anchors.left: parent.left
        //   anchors.leftMargin: 14
        //   anchors.verticalCenter: parent.verticalCenter
        //   width: 20
        //   height: 20
        //   name: row_item.is_wired ? "ethernet" : "wifi"
        //   color: row_item.is_connected
        //   ? Theme.c.green2
        //   : (row_item.selected ? Theme.c.fg : Theme.c.black2)
        //   stroke: 1.8
        // }

        Column {
          // anchors.left: row_glyph.right
          anchors.left: parent.left
          anchors.leftMargin: 12
          anchors.right: right_slot.left
          anchors.rightMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2

          Text {
            width: parent.width
            text: row_item.is_wired
            ? (row_item.wired && row_item.wired.name ? row_item.wired.name : "Wired")
            : (row_item.net && row_item.net.name ? row_item.net.name : "Hidden")
            color: row_item.is_connected ? Theme.c.fg : Theme.c.white
            font.family: Theme.clock_font
            font.pixelSize: 18
            font.bold: row_item.is_connected
            elide: Text.ElideRight
          }

          Text {
            width: parent.width
            visible: text.length > 0
            text: row_item.is_wired
            ? meta_wired(row_item.wired)
            : meta_wifi(row_item.net)
            color: Theme.c.black2
            font.family: Theme.clock_font
            font.pixelSize: 13
            font.bold: true
            opacity: 0.8
            elide: Text.ElideRight
          }
        }

        Item {
          id: right_slot
          anchors.right: parent.right
          anchors.rightMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          width: right_kids.width
          height: right_kids.height

          Row {
            id: right_kids
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            GlyphIcon {
              anchors.verticalCenter: parent.verticalCenter
              visible: !row_item.is_wired && row_item.secured
              width: 20
              height: 20
              name: "lock-outline"
              color: row_item.is_connected ? Theme.c.fg : Theme.c.black2
              stroke: 1.7
            }

            WifiGlyph {
              anchors.verticalCenter: parent.verticalCenter
              visible: !row_item.is_wired
              width: 28
              height: 28
              level: !row_item.is_wired && row_item.net ? (row_item.net.signalStrength || 0) : 0
              on: !row_item.is_wired && root.wifi_on
              color: row_item.is_connected ? Theme.c.green2 : Theme.c.fg
            }

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              visible: row_item.is_wired
              width: 36
              height: 20
              radius: 999
              color: row_item.is_connected
              ? (wired_toggle.containsMouse ? Qt.alpha(Theme.c.red, 0.85) : Theme.c.red)
              : (wired_toggle.containsMouse ? Qt.alpha(Theme.c.green, 0.85) : Theme.c.green)
              border.width: 1
              border.color: row_item.is_connected ? Theme.c.red2 : Theme.c.green2

              Text {
                anchors.centerIn: parent
                text: row_item.is_connected ? "Off" : "On"
                color: Theme.c.bg
                font.family: Theme.clock_font
                font.pixelSize: 10
                font.bold: true
              }

              MouseArea {
                id: wired_toggle
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.selected_index = row_item.index;
                  root.activateWired(row_item.wired);
                }
              }
            }
          }
        }

      }

      Item {
        id: pw_block
        visible: row_item.expanded_pw
        width: parent.width
        height: row_item.expanded_pw ? 44 : 0
        anchors.top: row_inner.bottom

        TextField {
          id: pw_field
          anchors.left: parent.left
          anchors.leftMargin: 14
          anchors.right: pw_row.left
          anchors.rightMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          background: null
          padding: 0
          color: Theme.c.fg
          font.family: Theme.clock_font
          font.pixelSize: 16
          echoMode: TextInput.Password
          placeholderText: "Password"
          placeholderTextColor: Theme.c.black2
          selectByMouse: true
          selectionColor: Theme.c.cyan
          text: root.pw_draft
          onTextEdited: root.pw_draft = text
          onAccepted: root.connectWithPassword()
          Component.onCompleted: if (row_item.expanded_pw) {
            text = root.pw_draft;
            cursorPosition = text.length;
            forceActiveFocus();
          }
          Connections {
            target: root
            function onExpanded_ssidChanged() {
              if (row_item.expanded_pw) {
                pw_field.text = root.pw_draft;
                pw_field.cursorPosition = pw_field.text.length;
                pw_field.forceActiveFocus();
              }
            }
          }
        }

        Row {
          id: pw_row
          anchors.right: parent.right
          anchors.rightMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          spacing: 8

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.connecting
            width: 7
            height: 7
            radius: width / 2
            color: Theme.c.yellow

            SequentialAnimation on opacity {
              running: root.connecting
              loops: Animation.Infinite
              NumberAnimation { from: 0.35; to: 1; duration: Motion.pulse; easing.type: Easing.InOutSine }
              NumberAnimation { from: 1; to: 0.35; duration: Motion.pulse; easing.type: Easing.InOutSine }
            }
          }

          GlyphIcon {
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            name: "return"
            color: pw_area.containsMouse ? Theme.c.fg : Theme.c.cyan2
            stroke: 1.8

            MouseArea {
              id: pw_area
              anchors.fill: parent
              anchors.margins: -6
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.connectWithPassword()
            }
          }
        }
      }

      Text {
        visible: row_item.expanded_pw && root.connect_failed
        anchors.top: pw_block.bottom
        anchors.left: parent.left
        anchors.leftMargin: 14
        text: "Connection failed"
        color: Theme.c.red2
        font.family: Theme.clock_font
        font.pixelSize: 12
        font.bold: true
      }
    }
  }

  function meta_wifi(net) {
    if (!net) return "";
    var parts = [];
    if (net.connected) parts.push("connected");
    else if (net.known) parts.push("saved");
    if (isSecured(net)) parts.push("secured");
    return parts.join(" · ");
  }

  function meta_wired(dev) {
    if (!dev) return "";
    var parts = [];
    if (dev.connected) parts.push("connected");
    else if (dev.hasLink) parts.push("link up");
    else parts.push("no link");
    if (dev.linkSpeed) parts.push(dev.linkSpeed + " Mb/s");
    return parts.join(" · ");
  }
}
