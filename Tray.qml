pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray

Item {
  id: tray
  signal menu_opened()
  signal menu_closed()

  required property var bar_win

  implicitWidth: visible ? row.implicitWidth : 0
  implicitHeight: 36.67

  function show_menu(item, anchor_item) {
    if (!item.hasMenu)
    return;
    card.expanded_idx = -1;
    opener.menu = item.menu;
    var p = anchor_item.mapToItem(null, anchor_item.width / 2, 0);
    menu.anchor_x = p.x;
    menu.open = true;
  }

  QsMenuOpener {
    id: opener
  }

  RowLayout {
    id: row
    anchors.fill: parent
    spacing: 5

    Repeater {
      model: SystemTray.items

      delegate: Item {
        id: slot

        required property var modelData

        Layout.preferredWidth: 41.66
        Layout.preferredHeight: 41.66

        // Rectangle {
        //   anchors.fill: parent
        //   radius: 10
        //   color: Theme.c.black
        //   border.width: 1
        //   border.color: Theme.c.black2
        //   opacity: area.containsMouse ? 0.8 : 0
        //   Behavior on opacity { NumberAnimation { duration: Motion.fast } }
        // }

        Image {
          anchors.centerIn: parent
          source: slot.modelData.icon
          sourceSize.width: 64
          sourceSize.height: 64
          width: 26.67
          height: 26.67
          fillMode: Image.PreserveAspectFit
          smooth: true
          cache: true
          asynchronous: true
        }

        MouseArea {
          id: area
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
          onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton) {
              slot.modelData.secondaryActivate();
            } else if (mouse.button === Qt.RightButton) {
              tray.show_menu(slot.modelData, slot);
            } else if (slot.modelData.onlyMenu) {
              tray.show_menu(slot.modelData, slot);
            } else {
              slot.modelData.activate();
            }
          }
          onWheel: (wheel) => {
            slot.modelData.scroll(wheel.angleDelta.y, false);
          }
        }
      }
    }
  }

  component MenuRow: Item {
    id: mrow

    property var entry_data
    property real indent: 0
    property bool expanded: false
    signal activated()

    height: entry_data && entry_data.isSeparator ? 13.33 : 50

    Rectangle {
      visible: mrow.entry_data && mrow.entry_data.isSeparator
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: 13.33 + mrow.indent
      anchors.rightMargin: 13.33
      height: 1
      color: Theme.c.black2
      opacity: 0.4
    }

    Rectangle {
      visible: mrow.entry_data && !mrow.entry_data.isSeparator
      anchors.fill: parent
      anchors.leftMargin: mrow.indent
      radius: 10
      color: mrow_area.containsMouse && mrow.entry_data && mrow.entry_data.enabled
      ? Theme.c.black : "transparent"

      // accent bar on hover
      Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 8.33
        width: 3.33
        height: parent.height * 0.44
        radius: width / 2
        color: Theme.c.cyan
        opacity: mrow_area.containsMouse && mrow.entry_data && mrow.entry_data.enabled ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
      }

      // checkbox / radio indicator
      Rectangle {
        id: state_box
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 23.33
        readonly property bool is_check: mrow.entry_data && mrow.entry_data.buttonType === QsMenuButtonType.CheckBox
        readonly property bool is_radio: mrow.entry_data && mrow.entry_data.buttonType === QsMenuButtonType.RadioButton
        readonly property bool present: is_check || is_radio
        readonly property bool checked: mrow.entry_data && mrow.entry_data.checkState === Qt.Checked
        visible: present
        width: present ? 16.67 : 0
        height: 16.67
        radius: is_radio ? width / 2 : 5
        color: "transparent"
        border.width: 1
        border.color: checked ? Theme.c.cyan : Theme.c.black2

        Rectangle {
          anchors.centerIn: parent
          visible: state_box.checked
          width: 8.33
          height: 8.33
          radius: state_box.is_radio ? width / 2 : 2.5
          color: Theme.c.cyan
        }
      }

      // entry icon
      Image {
        id: entry_icon
        anchors.left: state_box.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: state_box.present ? 10 : 0
        width: mrow.entry_data && mrow.entry_data.icon ? 23.33 : 0
        height: 23.33
        source: mrow.entry_data && mrow.entry_data.icon ? mrow.entry_data.icon : ""
        sourceSize.width: 28
        sourceSize.height: 28
        fillMode: Image.PreserveAspectFit
        smooth: true
        cache: true
        visible: mrow.entry_data && mrow.entry_data.icon
      }

      Text {
        anchors.left: entry_icon.right
        anchors.leftMargin: mrow.entry_data && mrow.entry_data.icon ? 13.33 : 0
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: chevron.visible ? chevron.left : parent.right
        anchors.rightMargin: 20
        text: mrow.entry_data && mrow.entry_data.text ? mrow.entry_data.text : ""
        color: mrow.entry_data && !mrow.entry_data.enabled ? Theme.c.black2
        : (mrow_area.containsMouse ? Theme.c.fg : Theme.c.white)
        font.pixelSize: 20
        font.bold: mrow_area.containsMouse
        elide: Text.ElideRight
      }

      Text {
        id: chevron
        anchors.right: parent.right
        anchors.rightMargin: 16.67
        anchors.verticalCenter: parent.verticalCenter
        visible: mrow.entry_data && mrow.entry_data.hasChildren === true
        text: mrow.expanded ? "▾" : "▸"
        color: mrow.expanded ? Theme.c.cyan : Theme.c.black2
        font.pixelSize: 20
      }

      MouseArea {
        id: mrow_area
        anchors.fill: parent
        hoverEnabled: true
        enabled: mrow.entry_data && mrow.entry_data.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: mrow.activated()
      }
    }
  }

  PanelWindow {
    id: menu

    property bool open: false
    property real anchor_x: 0

    onOpenChanged: {
      if (open) {
        tray.menu_opened();
      } else {
        card.expanded_idx = -1;
        opener.menu = null;
        tray.menu_closed();
      }
    }

    screen: tray.bar_win ? tray.bar_win.screen : null
    visible: open
    color: "transparent"

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "pill-tray"

    anchors { top: true; left: true; right: true; bottom: true }

    MouseArea {
      anchors.fill: parent
      onClicked: menu.open = false
    }

    FocusScope {
      anchors.fill: parent
      focus: menu.open

      Keys.onEscapePressed: menu.open = false

      GRect {
        id: card
        top_color: Theme.c.black
        bottom_color:Theme.c.black2
        body_color:Theme.c.bg
        border_w:3

        x: Math.max(13.33, Math.min(
            menu.anchor_x - width / 2,
            menu.width - width - 13.33))
        y: 100
        width: 349.99
        radius: 17
        clip: true

        property int expanded_idx: -1

        implicitHeight: col.implicitHeight + 20
        height: implicitHeight

        MouseArea { anchors.fill: parent }

        Column {
          id: col
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: 10
          spacing: 0

          Repeater {
            model: opener.children ? opener.children.values : []

            delegate: Column {
              id: entry

              required property var modelData
              required property int index
              readonly property bool expanded: card.expanded_idx === index

              width: col.width

              MenuRow {
                width: parent.width
                entry_data: entry.modelData
                expanded: entry.expanded
                onActivated: {
                  if (entry.modelData.hasChildren) {
                    card.expanded_idx = entry.expanded ? -1 : entry.index;
                  } else {
                    entry.modelData.triggered();
                    menu.open = false;
                  }
                }
              }

              QsMenuOpener {
                id: child_open
                menu: entry.expanded ? entry.modelData : null
              }

              Repeater {
                model: child_open.children ? child_open.children.values : []

                delegate: MenuRow {
                  required property var modelData
                  width: entry.width
                  indent: 20
                  entry_data: modelData
                  onActivated: {
                    if (!modelData.hasChildren) { // because menu trees can theoretically go multiple levels deep
                      modelData.triggered();
                      menu.open = false;
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
