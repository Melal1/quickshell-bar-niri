pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io

PillSurface {
  id: root

  m_top: 18
  m_left: 20
  m_right: 20
  m_bottom: 18

  property string query: ""
  property int selected_index: 0
  property int filter_index: 0
  property string font_family: Theme.clock_font
  property color panel_color: Qt.rgba(1, 1, 1, 0.035)
  property color border_color: Qt.rgba(1, 1, 1, 0.08)
  property color selected_color: Theme.c.magenta
  property color secondary_text: Theme.c.black2
  property string image_preview_source: ""
  property string image_preview_path: ""
  property string image_preview_id: ""
  property int image_preview_token: 0
  property bool image_preview_loading: false
  property bool image_preview_pending: false

  property string text_preview_content: ""
  property string text_preview_id: ""
  property bool text_preview_pending: false

  readonly property var results: {
    var out = [];
    var q = root.query.trim().toLowerCase();
    var all = Cliphist.entries;

    for (var i = 0; i < all.length; i++) {
      var entry = all[i];
      if (!entry) continue;

      var isImage = !!entry.isImage;
      var isBinary = entry.meta && entry.meta.length > 0;

      if (root.filter_index === 1 && isBinary) continue;
      if (root.filter_index === 2 && !isImage) continue;

      var haystack = [
      entry.preview || "",
      entry.label || "",
      entry.meta || "",
      entry.sizeLabel || ""
      ].join(" ").toLowerCase();

      if (q.length === 0 || haystack.indexOf(q) !== -1) {
        out.push(entry);
      }
    }

    return out;
  }

  readonly property var selected_item: selected_index >= 0 && selected_index < results.length ? results[selected_index] : null

  function icon_text(entry) {
    if (!entry) return "T";
    if (entry.isImage) return "IMG"; if (entry.meta && entry.meta.length > 0) return "BIN"; return "T"; }
  function title(entry) {
    if (!entry) return "";
    if (entry.isImage) return entry.label && entry.label.length > 0 ? entry.label : "Image";
    if (entry.meta && entry.meta.length > 0) return entry.label && entry.label.length > 0 ? entry.label : "Binary data";

    var text = String(entry.preview || "").replace(/\s+/g, " ").trim();
    return text.length > 0 ? text : "Empty text";
  }

  function subtitle(entry) {
    if (!entry) return "";

    var parts = [];
    if (entry.sizeLabel && entry.sizeLabel.length > 0) parts.push(entry.sizeLabel);
    if (entry.meta && entry.meta.length > 0 && entry.meta !== entry.sizeLabel) parts.push(entry.meta);
    parts.push("#" + entry.id);
    return parts.join("  ");
  }

  function preview(entry) {
    if (!entry) return "";
    if (entry.isImage) return "";
    if (entry.meta && entry.meta.length > 0) {
      var label = entry.isImage ? "Image clipboard item" : "Binary clipboard item";
      return label + "\n\n" + entry.meta;
    }

    return String(entry.preview || "");
  }

  function request_preview() {
    preview_debounce.restart();
  }

  function update_text_preview() {
    if (text_preview_proc.running) {
      text_preview_pending = true;
      return;
    }

    text_preview_content = "";
    text_preview_id = "";
    text_preview_pending = false;

    var entry = root.selected_item;
    if (!entry || entry.isImage || (entry.meta && entry.meta.length > 0) || !/^\d+$/.test(String(entry.id))) return;

    text_preview_id = String(entry.id);
    text_preview_proc.command = ["sh", "-c", "printf '%s' \"$1\" | cliphist decode", "_", text_preview_id];
    text_preview_proc.running = true;
  }

  function update_image_preview() {
    if (image_preview_proc.running) {
      image_preview_pending = true;
      return;
    }

    image_preview_source = "";
    image_preview_path = "";
    image_preview_id = "";
    image_preview_loading = false;
    image_preview_pending = false;

    var entry = root.selected_item;
    if (!entry || !entry.isImage || !/^\d+$/.test(String(entry.id))) return;

    image_preview_token += 1;
    image_preview_id = String(entry.id);
    image_preview_path = "/tmp/quickshell-cliphist-preview-" + image_preview_id;
    image_preview_loading = true;
    image_preview_proc.command = ["sh", "-c", "tmp=\"$2.$3.tmp\"; if printf '%s' \"$1\" | cliphist decode > \"$tmp\" && [ -s \"$tmp\" ]; then mv \"$tmp\" \"$2\"; printf '%s\n' \"$2\"; else rm -f \"$tmp\"; fi", "_", image_preview_id, image_preview_path, String(image_preview_token)];
    image_preview_proc.running = true;
  }

  function select_item(index) {
    if (index < 0 || index >= root.results.length) return;
    selected_index = index;
    item_list.currentIndex = index;
    item_list.positionViewAtIndex(index, ListView.Contain);
  }

  function move_selection(delta) {
    if (root.results.length === 0) return;
    select_item(Math.max(0, Math.min(root.results.length - 1, selected_index + delta)));
  }

  function copy_selected() {
    if (!root.selected_item) return;
    Cliphist.copy(root.selected_item);
    root.request_close();
  }

  function remove_selected() {
    if (!root.selected_item) return;
    Cliphist.remove(root.selected_item);
  }

  function reset_view() {
    query = "";
    search_field.text = "";
    selected_index = 0;
    item_list.contentY = 0;
  }

  onActiveChanged: {
    if (active) {
      reset_view();
      Cliphist.refresh();
      Qt.callLater(function() {
          search_field.forceActiveFocus();
          root.request_preview();
      });
    }
  }

  onResultsChanged: {
    if (selected_index >= results.length) {
      selected_index = 0;
    }
    Qt.callLater(root.request_preview);
  }

  onSelected_indexChanged: request_preview()

  Process {
    id: image_preview_proc
    stdout: StdioCollector {
      onStreamFinished: {
        var path = this.text.trim();
        root.image_preview_loading = false;

        if (path.length > 0 && root.selected_item && root.selected_item.isImage && String(root.selected_item.id) === root.image_preview_id && path === root.image_preview_path) {
          root.image_preview_source = "file://" + path + "?v=" + root.image_preview_token;
        }
      }
    }
    onExited: {
      root.image_preview_loading = false;
      if (root.image_preview_pending) {
        Qt.callLater(root.update_image_preview);
      }
    }
  }

  Process {
    id: text_preview_proc
    stdout: StdioCollector {
      onStreamFinished: {
        var txt = this.text;
        if (root.selected_item && !root.selected_item.isImage && String(root.selected_item.id) === root.text_preview_id) {
          root.text_preview_content = txt;
        }
      }
    }
    onExited: {
      if (root.text_preview_pending) {
        Qt.callLater(root.update_text_preview);
      }
    }
  }

  Timer {
    id: preview_debounce
    interval: 20
    repeat: false
    onTriggered: {
      root.update_image_preview();
      root.update_text_preview();
    }
  }

  Connections {
    target: Cliphist
    function onEntriesChanged() {
      Qt.callLater(root.request_preview);
    }
  }

  ColumnLayout {
    anchors.fill: parent
    clip: true
    spacing: 14

    RowLayout {
      id: header_row
      Layout.fillWidth: true
      Layout.preferredHeight: 66
      spacing: 12

      TextField {
        id: search_field
        Layout.fillWidth: true
        Layout.preferredHeight: 50
        background: Rectangle {
          radius: 13
          color: Theme.c.black
          border.width: search_field.activeFocus ? 2 : 1
          border.color: search_field.activeFocus ? root.selected_color : root.border_color

          Behavior on border.color {
            ColorAnimation { duration: Motion.fast }
          }
        }
        leftPadding: 14
        rightPadding: 14
        color: Theme.c.fg
        selectedTextColor: Theme.c.bg
        selectionColor: root.selected_color
        placeholderText: "Search clipboard history"
        placeholderTextColor: root.secondary_text
        font.family: root.font_family
        font.pixelSize: 23

        onTextChanged: {
          root.query = text;
          root.selected_index = 0;
          item_list.contentY = 0;
        }

        Keys.onUpPressed: (event) => {
          root.move_selection(-1);
          event.accepted = true;
        }
        Keys.onDownPressed: (event) => {
          root.move_selection(1);
          event.accepted = true;
        }
        Keys.onPressed: (event) => {
          if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_P || event.key === Qt.Key_K)) {
            root.move_selection(-1);
            event.accepted = true;
          } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_N || event.key === Qt.Key_J)) {
            root.move_selection(1);
            event.accepted = true;
          } else if (event.key === Qt.Key_Delete) {
            root.remove_selected();
            event.accepted = true;
          }
        }
        Keys.onReturnPressed: (event) => {
          root.copy_selected();
          event.accepted = true;
        }
        Keys.onEnterPressed: (event) => {
          root.copy_selected();
          event.accepted = true;
        }
        Keys.onEscapePressed: (event) => {
          root.request_close();
          event.accepted = true;
        }
      }

      ComboBox {
        id: filter_combo
        Layout.preferredWidth: 96
        Layout.preferredHeight: 50
        model: ["All", "Text", "Images"]
        font.family: root.font_family
        font.pixelSize: 18
        font.bold:true
        onActivated: root.filter_index = currentIndex

        background: Rectangle {
          radius: 13
          color: Theme.c.black
          border.width: 1
          border.color: root.border_color
        }

        contentItem: Text {
          leftPadding: 12
          rightPadding: 26
          verticalAlignment: Text.AlignVCenter
          text: filter_combo.displayText
          color: Theme.c.fg
          font: filter_combo.font
          elide: Text.ElideRight
        }

        indicator: Text {
          anchors.right: parent.right
          anchors.rightMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          text: "v"
          color: root.secondary_text
          font.family: root.font_family
          font.pixelSize: 16
          font.bold: true
        }
      }
    }

    ColumnLayout {
      id: sub_header
      Layout.fillWidth: true
      spacing: 9

      RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Text {
          text: String(root.results.length)
          color: root.selected_color
          font.family: root.font_family
          font.pixelSize: 22
          font.bold: true
        }

        Text {
          text: "Items"
          color: Theme.c.fg
          font.family: root.font_family
          font.pixelSize: 22
          font.bold: true
        }

        Item { Layout.fillWidth: true }

        Text {
          text: root.results.length + " / " + Cliphist.count
          color: root.secondary_text
          font.family: root.font_family
          font.pixelSize: 16
          font.bold: true
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: root.border_color
      }
    }

    RowLayout {
      id: content_row
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: 14

      Rectangle {
        id: list_panel
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        radius: 16
        color: root.panel_color
        border.width: 1
        border.color: root.border_color

        Text {
          anchors.centerIn: parent
          visible: root.results.length === 0
          text: root.query.length > 0 ? "No matches" : "Clipboard history is empty"
          color: root.secondary_text
          font.family: root.font_family
          font.pixelSize: 18
          font.bold: true
        }

        ListView {
          id: item_list
          anchors.fill: parent
          anchors.margins: 8
          clip: true
          spacing: 7
          model: root.results.length
          currentIndex: root.selected_index
          boundsBehavior: Flickable.StopAtBounds

          ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
          }

          delegate: Item {
            id: item_row
            required property int index

            width: item_list.width
            height: 66

            readonly property var entry: root.results[index]
            readonly property bool selected: item_row.index === root.selected_index
            readonly property string row_icon: root.icon_text(entry)
            readonly property string row_title: root.title(entry)
            readonly property string row_subtitle: root.subtitle(entry)

            Rectangle {
              anchors.fill: parent
              radius: 13
              color: item_row.selected ? root.selected_color : (item_area.containsMouse ? Theme.c.black : "transparent")
              border.width: item_row.selected ? 0 : (item_area.containsMouse ? 1 : 0)
              border.color: root.border_color

              Behavior on color {
                ColorAnimation { duration: Motion.fast }
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              spacing: 10

              Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 10
                color: item_row.selected ? Qt.rgba(0.05, 0.05, 0.06, 0.32) : Theme.c.black
                border.width: item_row.selected ? 0 : 1
                border.color: root.border_color

                Text {
                  anchors.centerIn: parent
                  text: item_row.row_icon
                  color: item_row.selected ? Theme.c.bg : root.secondary_text
                  font.family: root.font_family
                  font.pixelSize: item_row.row_icon.length > 1 ? 13 : 18
                  font.bold: true
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                  Layout.fillWidth: true
                  text: item_row.row_title
                  color: item_row.selected ? Theme.c.bg : Theme.c.fg
                  font.family: root.font_family
                  font.pixelSize: 17
                  font.bold: item_row.selected
                  maximumLineCount: 1
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                }

                Text {
                  Layout.fillWidth: true
                  text: item_row.row_subtitle
                  color: item_row.selected ? Qt.rgba(0.06, 0.06, 0.07, 0.65) : root.secondary_text
                  font.family: root.font_family
                  font.pixelSize: 15
                  font.bold: item_row.selected
                  maximumLineCount: 1
                  elide: Text.ElideRight
                }
              }
            }

            MouseArea {
              id: item_area
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.select_item(item_row.index)
              onDoubleClicked: {
                root.select_item(item_row.index);
                root.copy_selected();
              }
            }
          }
        }
      }

      Rectangle {
        id: preview_panel
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 2
        radius: 16
        color: root.panel_color
        border.width: 1
        border.color: root.border_color

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 14
          spacing: 12

          Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 14
            color: Theme.c.black
            border.width: 1
            border.color: root.border_color
            clip: true

            Image {
              id: image_preview
              anchors.fill: parent
              anchors.margins: 14
              visible: !!root.selected_item && root.selected_item.isImage && root.image_preview_source.length > 0
              source: root.image_preview_source
              cache: false
              asynchronous: true
              smooth: true
              fillMode: Image.PreserveAspectFit
            }

            Text {
              anchors.centerIn: parent
              visible: !!root.selected_item && root.selected_item.isImage && (root.image_preview_source.length === 0 || image_preview.status === Image.Error)
              text: root.image_preview_loading ? "Loading image preview" : "Image preview unavailable"
              color: root.secondary_text
              font.family: root.font_family
              font.pixelSize: 17
              font.bold: true
            }

            TextArea {
              id: preview_text
              anchors.fill: parent
              anchors.margins: 14
              visible: !root.selected_item || !root.selected_item.isImage
              readOnly: true
              wrapMode: TextEdit.Wrap
              background: null
              text: root.text_preview_content.length > 0 ? root.text_preview_content : root.preview(root.selected_item)
              color: Theme.c.fg
              selectedTextColor: Theme.c.bg
              selectionColor: root.selected_color
              font.family: "monospace"
              font.pixelSize: 17
              textFormat: TextEdit.PlainText
            }
          }

          RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            Layout.minimumHeight: 38
            Layout.maximumHeight: 38
            spacing: 8

            Rectangle {
              Layout.preferredWidth: 86
              Layout.preferredHeight: 38
              Layout.minimumHeight: 38
              Layout.maximumHeight: 38
              radius: 12
              color: copy_area.containsMouse && root.selected_item ? root.selected_color : Theme.c.black
              border.width: copy_area.containsMouse && root.selected_item ? 0 : 1
              border.color: root.border_color
              opacity: root.selected_item ? 1 : 0.45

              Text {
                anchors.centerIn: parent
                text: "Copy"
                color: copy_area.containsMouse && root.selected_item ? Theme.c.bg : Theme.c.fg
                font.family: root.font_family
                font.pixelSize: 17
                font.bold: true
              }

              MouseArea {
                id: copy_area
                anchors.fill: parent
                enabled: !!root.selected_item
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.copy_selected()
              }
            }

            Rectangle {
              Layout.preferredWidth: 86
              Layout.preferredHeight: 38
              Layout.minimumHeight: 38
              Layout.maximumHeight: 38
              radius: 12
              color: delete_area.containsMouse && root.selected_item ? Theme.c.red : Theme.c.black
              border.width: delete_area.containsMouse && root.selected_item ? 0 : 1
              border.color: root.border_color
              opacity: root.selected_item ? 1 : 0.45

              Text {
                anchors.centerIn: parent
                text: "Delete"
                color: delete_area.containsMouse && root.selected_item ? Theme.c.bg : Theme.c.fg
                font.family: root.font_family
                font.pixelSize: 17
                font.bold: true
              }

              MouseArea {
                id: delete_area
                anchors.fill: parent
                enabled: !!root.selected_item
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.remove_selected()
              }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
              Layout.preferredWidth: 86
              Layout.preferredHeight: 38
              Layout.minimumHeight: 38
              Layout.maximumHeight: 38
              radius: 12
              color: refresh_area.containsMouse ? Theme.c.black2 : Theme.c.black
              border.width: 1
              border.color: root.border_color

              Text {
                anchors.centerIn: parent
                text: "Refresh"
                color: Theme.c.fg
                font.family: root.font_family
                font.pixelSize: 17
                font.bold: true
              }

              MouseArea {
                id: refresh_area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Cliphist.refresh()
              }
            }

            Rectangle {
              Layout.preferredWidth: 72
              Layout.preferredHeight: 38
              Layout.minimumHeight: 38
              Layout.maximumHeight: 38
              radius: 12
              color: wipe_area.containsMouse ? Theme.c.red : Theme.c.black
              border.width: wipe_area.containsMouse ? 0 : 1
              border.color: root.border_color

              Text {
                anchors.centerIn: parent
                text: "Wipe"
                color: wipe_area.containsMouse ? Theme.c.bg : Theme.c.fg
                font.family: root.font_family
                font.pixelSize: 17
                font.bold: true
              }

              MouseArea {
                id: wipe_area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.reset_view();
                  Cliphist.wipe();
                }
              }
            }
          }
        }
      }
    }
  }
}
