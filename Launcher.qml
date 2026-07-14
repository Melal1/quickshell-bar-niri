pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "lib/calc.js" as Calc
import "lib/fuzzy.js" as Fuzzy

PillSurface {
  id: root

  m_top: 15
  m_left: 17
  m_right: 17
  m_bottom: 14

  property string query: ""
  property int selected_index: 0
  property var usage: ({})
  property var web_shortcuts: []
  property point last_pointer: Qt.point(-1, -1)
  property bool calc_mode: false
  property bool web_prompt_mode: false
  property var web_prompt_entry: null

  readonly property string usage_file: Quickshell.env("HOME") + "/.config/quickshell/launcher-usage.json"
  readonly property string web_shortcuts_file: Quickshell.env("HOME") + "/.config/quickshell/launcher-web-shortcuts.json"
  readonly property string calc_input: calc_mode ? query : ""
  readonly property var calc_result: calc_mode ? Calc.evaluate(calc_input) : ({ ok: false, display: "", detail: "", copy: "" })
  readonly property string surface_title: root.calc_mode ? "Calc" : (root.web_prompt_mode && root.web_prompt_entry ? root.web_prompt_entry.name : "Apps")
  readonly property string surface_detail: root.calc_mode ? "Enter copies" : (root.web_prompt_mode ? "Enter opens" : root.results.length + " / " + root.total_count)
  readonly property var all_entries: {
    var src = DesktopEntries.applications.values;
    var out = [];
    for (var i = 0; i < src.length; i++) {
      if (src[i] && !src[i].noDisplay) {
        out.push(src[i]);
      }
    }

    for (var j = 0; j < root.web_shortcuts.length; j++) {
      var shortcut = root.web_shortcuts[j];
      if (shortcut && shortcut.name && shortcut.url && !shortcut.noDisplay) {
        out.push(root.make_web_entry(shortcut));
      }
    }

    return out;
  }
  readonly property int total_count: all_entries.length
  readonly property var results: calc_mode || web_prompt_mode ? [] : Fuzzy.rank(all_entries, query, usage)

  function default_web_shortcuts() {
    return [
      {
        id: "web:nixpkgs",
        name: "nixpkgs",
        genericName: "Search Nix Packages",
        keywords: ["nix", "nixos", "package", "packages"],
        icon: "nix-snowflake",
        url: "https://search.nixos.org/packages?query={query}"
      }
    ];
  }

  function make_web_entry(shortcut) {
    return {
      id: shortcut.id || ("web:" + shortcut.name.toLowerCase().replace(/\s+/g, "-")),
      name: shortcut.name,
      genericName: shortcut.genericName || "Web shortcut",
      keywords: shortcut.keywords || [],
      icon: shortcut.icon || "web-browser",
      isWebShortcut: true,
      url: shortcut.url
    };
  }

  function load_web_shortcuts() {
    var raw = web_shortcuts_store.text();
    if (!raw || raw.length === 0) {
      root.web_shortcuts = default_web_shortcuts();
      web_shortcuts_store.setText(JSON.stringify(root.web_shortcuts, null, 2));
      return;
    }

    try {
      var parsed = JSON.parse(raw);
      root.web_shortcuts = parsed instanceof Array ? parsed : default_web_shortcuts();
    } catch (e) {
      root.web_shortcuts = default_web_shortcuts();
    }
  }

  function web_url(entry, text) {
    var encoded = encodeURIComponent(text);
    if (entry.url.indexOf("{query}") !== -1) {
      return entry.url.split("{query}").join(encoded);
    }

    return entry.url + (entry.url.indexOf("?") === -1 ? "?q=" : "&q=") + encoded;
  }

  function move(delta) {
    if (calc_mode || web_prompt_mode || results.length === 0) {
      return;
    }

    selected_index = Math.max(0, Math.min(results.length - 1, selected_index + delta));
    app_list.positionViewAtIndex(selected_index, ListView.Contain);
  }

  function activate() {
    if (calc_mode) {
      if (calc_result.ok && calc_result.copy.length > 0) {
        Quickshell.execDetached(["wl-copy", calc_result.copy]);
      }
      return;
    }

    if (web_prompt_mode) {
      if (web_prompt_entry && query.trim().length > 0) {
        if (web_prompt_entry.id) {
          root.usage[web_prompt_entry.id] = (root.usage[web_prompt_entry.id] || 0) + 1;
          usage_store.setText(JSON.stringify(root.usage));
        }
        var url = web_url(web_prompt_entry, query.trim());
        Quickshell.execDetached(["xdg-open", url]);
        root.request_close();
      }
      return;
    }

    if (results.length === 0 || selected_index < 0 || selected_index >= results.length) {
      return;
    }

    var entry = results[selected_index];
    if (!entry) {
      return;
    }

    if (entry.isWebShortcut) {
      web_prompt_entry = entry;
      web_prompt_mode = true;
      query = "";
      search_field.text = "";
      search_field.forceActiveFocus();
      return;
    }

    if (entry.id) {
      root.usage[entry.id] = (root.usage[entry.id] || 0) + 1;
      usage_store.setText(JSON.stringify(root.usage));
    }

    entry.execute();
    root.request_close();
  }

  onActiveChanged: {
    if (active) {
      query = "";
      search_field.text = "";
      calc_mode = false;
      web_prompt_mode = false;
      web_prompt_entry = null;
      selected_index = 0;
      app_list.contentY = 0;
      Qt.callLater(function() {
        search_field.forceActiveFocus();
      });
    }
  }

  onResultsChanged: {
    if (!calc_mode && !web_prompt_mode && selected_index >= results.length) {
      selected_index = 0;
    }
  }

  FileView {
    id: usage_store
    path: root.usage_file
    blockLoading: true
    atomicWrites: true
    printErrors: false
  }

  FileView {
    id: web_shortcuts_store
    path: root.web_shortcuts_file
    blockLoading: true
    atomicWrites: true
    printErrors: false
  }

  Component.onCompleted: {
    var raw = usage_store.text();
    try {
      root.usage = raw && raw.length ? JSON.parse(raw) : ({});
    } catch (e) {
      root.usage = ({});
    }

    root.load_web_shortcuts();
  }

  SurfaceHeader {
    id: header
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    title: root.surface_title
    detail: root.surface_detail
  }

  Rectangle {
    id: search_box
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: header.bottom
    anchors.topMargin: 12
    height: 50
    radius: 13
    color: Theme.c.black
    border.width: search_field.activeFocus ? 2 : 1
    border.color: search_field.activeFocus ? Theme.c.cyan : Theme.c.black2

    Behavior on border.color {
      ColorAnimation { duration: Motion.fast }
    }

    Text {
      id: search_icon
      anchors.left: parent.left
      anchors.leftMargin: 14
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: -3
      text: root.calc_mode ? "=" : (root.web_prompt_mode ? "?" : "⌕")
      color: Theme.c.black2
      font.family: Theme.clock_font
      font.pixelSize: 24
      font.bold: true
    }

    TextField {
      id: search_field
      anchors.left: search_icon.right
      anchors.leftMargin: 10
      anchors.right: parent.right
      anchors.rightMargin: 14
      anchors.verticalCenter: parent.verticalCenter
      height: parent.height - 10
      background: null
      padding: 0
      color: Theme.c.fg
      selectedTextColor: Theme.c.bg
      selectionColor: Theme.c.yellow
      placeholderText: root.web_prompt_mode && root.web_prompt_entry ? "Query for " + root.web_prompt_entry.name : "Search apps"
      placeholderTextColor: Theme.c.black2
      font.family: Theme.clock_font
      font.pixelSize: 21

      onTextChanged: {
        if (!root.calc_mode && text.charAt(0) === "=") {
          root.calc_mode = true;
          root.web_prompt_mode = false;
          root.web_prompt_entry = null;
          search_field.text = text.substring(1);
          return;
        }

        root.query = text;
        root.selected_index = 0;
        app_list.contentY = 0;
      }

      Keys.onUpPressed: (event) => {
        root.move(-1);
        event.accepted = true;
      }
      Keys.onDownPressed: (event) => {
        root.move(1);
        event.accepted = true;
      }
      Keys.onPressed: (event) => {
        if (!root.calc_mode && !root.web_prompt_mode && search_field.text.length === 0 && event.text === "=") {
          root.calc_mode = true;
          event.accepted = true;
        } else if (root.calc_mode && search_field.text.length === 0 && event.key === Qt.Key_Backspace) {
          root.calc_mode = false;
          event.accepted = true;
        } else if (root.web_prompt_mode && search_field.text.length === 0 && event.key === Qt.Key_Backspace) {
          root.web_prompt_mode = false;
          root.web_prompt_entry = null;
          event.accepted = true;
        } else if (event.modifiers === Qt.ControlModifier && (event.key === Qt.Key_P || event.key === Qt.Key_K)) {
          root.move(-1);
          event.accepted = true;
        } else if (event.modifiers === Qt.ControlModifier && (event.key === Qt.Key_N || event.key === Qt.Key_J)) {
          root.move(1);
          event.accepted = true;
        }
      }
      Keys.onReturnPressed: (event) => {
        root.activate();
        event.accepted = true;
      }
      Keys.onEnterPressed: (event) => {
        root.activate();
        event.accepted = true;
      }
      Keys.onEscapePressed: (event) => {
        if (root.web_prompt_mode) {
          root.web_prompt_mode = false;
          root.web_prompt_entry = null;
          root.query = "";
          search_field.text = "";
        } else {
          root.request_close();
        }
        event.accepted = true;
      }
    }
  }

  Rectangle {
    id: sep
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: search_box.bottom
    anchors.topMargin: 12
    height: 1
    color: Theme.c.black2
    opacity: 0.45
  }

  Text {
    anchors.centerIn: app_list
    visible: !root.calc_mode && !root.web_prompt_mode && root.results.length === 0
    text: root.query.length > 0 ? "No matches" : "No apps found"
    color: Theme.c.black2
    font.family: Theme.clock_font
    font.pixelSize: 18
    font.bold: true
  }

  Item {
    id: calc_panel
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: sep.bottom
    anchors.topMargin: 10
    anchors.bottom: parent.bottom
    visible: root.calc_mode || root.web_prompt_mode

    Rectangle {
      id: calc_card
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: 156
      radius: 13
      color: Theme.c.black
      border.width: 1
      border.color: root.calc_mode && root.calc_result.ok ? Theme.c.cyan : Theme.c.black2

      Behavior on border.color {
        ColorAnimation { duration: Motion.fast }
      }

      Text {
        id: calc_value
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.top: parent.top
        anchors.topMargin: 18
        text: root.calc_mode ? root.calc_result.display : "Search " + (root.web_prompt_entry ? root.web_prompt_entry.name : "")
        color: root.calc_mode && !root.calc_result.ok ? Theme.c.black2 : Theme.c.fg
        font.family: Theme.clock_font
        font.pixelSize: 24
        font.bold: true
        wrapMode: Text.Wrap
        maximumLineCount: 3
        elide: Text.ElideRight
      }

      Text {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.top: calc_value.bottom
        anchors.topMargin: 12
        text: root.calc_mode ? root.calc_result.detail : (root.web_prompt_entry ? root.web_prompt_entry.genericName : "")
        color: Theme.c.black2
        font.family: Theme.clock_font
        font.pixelSize: 17
        font.bold: true
        elide: Text.ElideRight
      }
    }
  }

  ListView {
    id: app_list
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: sep.bottom
    anchors.topMargin: 10
    anchors.bottom: parent.bottom
    clip: true
    spacing: 6
    boundsBehavior: Flickable.StopAtBounds
    visible: !root.calc_mode && !root.web_prompt_mode
    model: root.results.length

    delegate: Item {
      id: app_row
      required property int index

      width: app_list.width
      height: 60

      readonly property var entry: root.results[index]
      readonly property bool selected: index === root.selected_index
      readonly property string secondary: {
        if (!entry) return "";
        if (entry.genericName && entry.genericName.length > 0) return entry.genericName;
        return "";
      }

      Rectangle {
        anchors.fill: parent
        radius: 13
        color: app_row.selected ? Theme.c.black: "transparent"
        border.width: app_row.selected ? 0 : (row_area.containsMouse ? 1 : 0)
        border.color: Theme.c.black2

        Behavior on color {
          ColorAnimation { duration: Motion.fast }
        }
      }

      MouseArea {
        id: row_area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPositionChanged: (mouse) => {
          var global = row_area.mapToItem(null, mouse.x, mouse.y);
          if (global.x !== root.last_pointer.x || global.y !== root.last_pointer.y) {
            root.last_pointer = Qt.point(global.x, global.y);
            root.selected_index = app_row.index;
          }
        }
        onClicked: {
          root.selected_index = app_row.index;
          root.activate();
        }
      }

      Rectangle {
        id: icon_bg
        anchors.left: parent.left
        anchors.leftMargin: 11
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        height: 36
        radius: 8
        color: app_row.selected ? Theme.c.black2 : Theme.c.black
        opacity: app_row.selected ? 0.35 : 1
      }

      Image {
        id: app_icon
        anchors.centerIn: icon_bg
        width: 31
        height: 31
        sourceSize.width: 46
        sourceSize.height: 46
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        source: app_row.entry && app_row.entry.icon ? Quickshell.iconPath(app_row.entry.icon, true) : ""
      }

      Text {
        id: app_name
        anchors.left: icon_bg.right
        anchors.leftMargin: 12
        anchors.right: app_meta.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: app_row.entry ? app_row.entry.name : ""
        color:  Theme.c.fg
        font.family: Theme.clock_font
        font.pixelSize: 21
        font.bold: app_row.selected
        elide: Text.ElideRight
      }

      Text {
        id: app_meta
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(130, implicitWidth)
        text: app_row.secondary
        color: app_row.selected ?  Theme.c.fg:Theme.c.black2
        opacity: app_row.secondary.length > 0 ? 0.85 : 0
        font.family: Theme.clock_font
        font.pixelSize: 16
        font.bold: app_row.selected
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
      }
    }
  }
}
