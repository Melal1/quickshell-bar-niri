pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

PillSurface {
  id: root

  m_top: 16
  m_left: 18
  m_right: 18
  m_bottom: 16

  property string query: ""
  property int selected_index: 0
  property point last_pointer: Qt.point(-1, -1)
  property real wipe_hold: 0
  property bool wipe_fired: false

  readonly property var results: {
    var all = Cliphist.entries
    var q = query.trim().toLowerCase()
    if (q.length === 0) return all

    var out = []
    for (var i = 0; i < all.length; i++) {
      var entry = all[i]
      var hay = entry.isImage
        ? (entry.label + " " + entry.sizeLabel)
        : entry.preview

      if (hay.toLowerCase().indexOf(q) !== -1) out.push(entry)
    }
    return out
  }

  function focus_field() {
    search_field.forceActiveFocus()
  }

  function move(delta) {
    if (results.length === 0) return

    selected_index = Math.max(0, Math.min(results.length - 1, selected_index + delta))
    clip_list.positionViewAtIndex(selected_index, ListView.Contain)
  }

  function activate() {
    if (results.length === 0 || selected_index < 0 || selected_index >= results.length) return

    Cliphist.copy(results[selected_index])
    root.request_close()
  }

  function remove_at(index) {
    if (index < 0 || index >= results.length) return
    Cliphist.remove(results[index])
  }

  function start_wipe() {
    wipe_fired = false
    wipe_drain.stop()
    wipe_fill.restart()
  }

  function stop_wipe() {
    wipe_fill.stop()
    if (!wipe_fired && wipe_hold < 1) wipe_drain.restart()
  }

  onActiveChanged: {
    if (active) {
      query = ""
      search_field.text = ""
      selected_index = 0
      clip_list.contentY = 0
      Cliphist.refresh()
      Qt.callLater(root.focus_field)
    }
  }

  onResultsChanged: {
    if (selected_index >= results.length) {
      selected_index = Math.max(0, results.length - 1)
    }
  }

  NumberAnimation {
    id: wipe_fill
    target: root
    property: "wipe_hold"
    from: 0
    to: 1
    duration: Motion.heat
    onFinished: {
      root.wipe_fired = true
      Cliphist.wipe()
      wipe_drain.restart()
    }
  }

  NumberAnimation {
    id: wipe_drain
    target: root
    property: "wipe_hold"
    to: 0
    duration: 180
  }

  Item {
    id: header
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: 46

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "Clipboard"
      color: Theme.c.fg
      font.family: Theme.clock_font
      font.pixelSize: 22
      font.bold: true
    }

    Text {
      anchors.right: wipe_button.left
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      text: root.results.length + " / " + Cliphist.count
      color: Theme.c.black2
      font.family: Theme.clock_font
      font.pixelSize: 13
      font.bold: true
    }

    Rectangle {
      id: wipe_button
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: 34
      height: 34
      radius: 17
      color: wipe_area.containsMouse || root.wipe_hold > 0 ? Theme.c.red : Theme.c.black

      Behavior on color {
        ColorAnimation { duration: Motion.fast }
      }

      Text {
        anchors.centerIn: parent
        text: "W"
        color: wipe_area.containsMouse || root.wipe_hold > 0 ? Theme.c.bg : Theme.c.black2
        font.family: Theme.clock_font
        font.pixelSize: 13
        font.bold: true
      }

      MouseArea {
        id: wipe_area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: root.start_wipe()
        onReleased: root.stop_wipe()
        onExited: root.stop_wipe()
      }
    }
  }

  Rectangle {
    id: search_box
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: header.bottom
    height: 44
    radius: 14
    color: Theme.c.black
    border.width: search_field.activeFocus ? 2 : 1
    border.color: search_field.activeFocus ? Theme.c.magenta : Theme.c.black2

    Behavior on border.color {
      ColorAnimation { duration: Motion.fast }
    }

    Text {
      id: search_icon
      anchors.left: parent.left
      anchors.leftMargin: 14
      anchors.verticalCenter: parent.verticalCenter
      text: "⌕"
      color: Theme.c.black2
      font.family: Theme.clock_font
      font.pixelSize: 20
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
      selectionColor: Theme.c.magenta
      placeholderText: "Search clipboard"
      placeholderTextColor: Theme.c.black2
      font.family: Theme.clock_font
      font.pixelSize: 16

      onTextChanged: {
        root.query = text
        root.selected_index = 0
        clip_list.contentY = 0
      }

      Keys.onUpPressed: (event) => {
        root.move(-1)
        event.accepted = true
      }
      Keys.onDownPressed: (event) => {
        root.move(1)
        event.accepted = true
      }
      Keys.onReturnPressed: (event) => {
        root.activate()
        event.accepted = true
      }
      Keys.onEnterPressed: (event) => {
        root.activate()
        event.accepted = true
      }
      Keys.onEscapePressed: (event) => {
        root.request_close()
        event.accepted = true
      }
      Keys.onPressed: (event) => {
        if (event.key === Qt.Key_X && (event.modifiers & Qt.ControlModifier) && search_field.selectedText.length === 0) {
          root.remove_at(root.selected_index)
          event.accepted = true
        }
      }
    }
  }

  Rectangle {
    id: sep
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: search_box.bottom
    anchors.topMargin: 14
    height: 1
    color: Theme.c.black2
    opacity: 0.45

    Rectangle {
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      width: parent.width * root.wipe_hold
      visible: root.wipe_hold > 0
      color: Theme.c.red
    }
  }

  Text {
    anchors.centerIn: clip_list
    visible: root.results.length === 0
    text: root.query.length > 0 ? "No matches" : "History empty"
    color: Theme.c.black2
    font.family: Theme.clock_font
    font.pixelSize: 18
    font.bold: true
  }

  ListView {
    id: clip_list
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: sep.bottom
    anchors.topMargin: 10
    anchors.bottom: parent.bottom
    clip: true
    spacing: 6
    boundsBehavior: Flickable.StopAtBounds
    model: root.results.length

    delegate: Item {
      id: clip_row
      required property int index

      width: clip_list.width
      height: 44

      readonly property var entry: root.results[index]
      readonly property bool selected: index === root.selected_index
      readonly property string body: {
        if (!entry) return ""
        if (entry.isImage) return entry.label
        return entry.preview
      }

      Rectangle {
        anchors.fill: parent
        radius: 13
        color: clip_row.selected ? Theme.c.magenta : (row_area.containsMouse ? Theme.c.black : "transparent")
        border.width: clip_row.selected ? 0 : (row_area.containsMouse ? 1 : 0)
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
          var global = row_area.mapToItem(null, mouse.x, mouse.y)
          if (global.x !== root.last_pointer.x || global.y !== root.last_pointer.y) {
            root.last_pointer = Qt.point(global.x, global.y)
            root.selected_index = clip_row.index
          }
        }
        onClicked: {
          root.selected_index = clip_row.index
          root.activate()
        }
      }

      Rectangle {
        id: type_badge
        anchors.left: parent.left
        anchors.leftMargin: 11
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 24
        radius: 8
        color: clip_row.selected ? Qt.rgba(0.06, 0.06, 0.07, 0.35) : Theme.c.black

        Text {
          anchors.centerIn: parent
          text: clip_row.entry && clip_row.entry.isImage ? "IMG" : "TXT"
          color: clip_row.selected ? Theme.c.bg : Theme.c.black2
          font.family: Theme.clock_font
          font.pixelSize: 8
          font.bold: true
        }
      }

      Text {
        anchors.left: type_badge.right
        anchors.leftMargin: 12
        anchors.right: meta.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: clip_row.body
        color: clip_row.selected ? Theme.c.bg : Theme.c.fg
        font.family: Theme.clock_font
        font.pixelSize: 14
        font.bold: clip_row.selected
        maximumLineCount: 1
        elide: Text.ElideRight
        textFormat: Text.PlainText
      }

      Text {
        id: meta
        anchors.right: remove_button.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: text.length > 0 ? Math.min(95, implicitWidth) : 0
        text: clip_row.entry && clip_row.entry.isImage ? clip_row.entry.sizeLabel : ""
        color: clip_row.selected ? Theme.c.bg : Theme.c.black2
        opacity: text.length > 0 ? 0.85 : 0
        font.family: Theme.clock_font
        font.pixelSize: 11
        font.bold: clip_row.selected
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
      }

      Text {
        id: remove_button
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        text: row_area.containsMouse ? "x" : (clip_row.selected ? "↵" : "")
        color: clip_row.selected ? Theme.c.bg : Theme.c.black2
        font.family: Theme.clock_font
        font.pixelSize: row_area.containsMouse ? 14 : 12
        font.bold: true
        horizontalAlignment: Text.AlignRight

        MouseArea {
          anchors.fill: parent
          anchors.margins: -8
          enabled: row_area.containsMouse
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.remove_at(clip_row.index)
        }
      }
    }
  }
}
