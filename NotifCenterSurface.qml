import QtQuick

/**
* Notification Center surface: grouped or chronological history view,
* individual dismiss, clear-all, and view toggle.
*/
PillSurface {
  id: center
  focus: true

  m_top: 15
  m_left: 17
  m_right: 17
  m_bottom: 14

  property bool grouped_view: false
  property bool clear_holding: false
  property var expanded_groups: ({})
  property var current_time: Date.now()

  Timer {
    interval: 30000
    running: center.open
    repeat: true
    onTriggered: center.current_time = Date.now()
  }

  onOpenChanged: {
    if (open) {
      center.forceActiveFocus();
      center.current_time = Date.now();
      NotificationsServer.suppress_popups = true;
      NotificationsServer.mark_all_seen();
      grouped_list.contentY = 0;
      chrono_list.contentY = 0;
    } else {
      NotificationsServer.suppress_popups = false;
      center.expanded_groups = ({});
      center.clear_holding = false;
    }
  }

  Keys.onPressed: (event) => {
    if (event.key === Qt.Key_Escape) {
      center.request_close();
      event.accepted = true;
      return;
    }

    if (event.modifiers === Qt.NoModifier && event.key === Qt.Key_G && !event.isAutoRepeat) {
      center.grouped_view = !center.grouped_view;
      event.accepted = true;
      return;
    }

    if (event.modifiers === Qt.NoModifier && event.key === Qt.Key_C && NotificationsServer.history.length > 0) {
      center.clear_holding = true;
      event.accepted = true;
    }
  }

  Keys.onReleased: (event) => {
    if (event.key === Qt.Key_C) {
      center.clear_holding = false;
      event.accepted = true;
    }
  }

  SurfaceHeader {
    id: header
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: 34
    title: "Notifications"
    detail: ""

    Rectangle {
      id: view_toggle
      anchors.centerIn: parent
      width: view_text.implicitWidth + 28
      height: 28
      radius: 14
      color: view_area.containsMouse ? Theme.c.magenta : Theme.c.black
      anchors.verticalCenterOffset: 1

      Behavior on width {
        NumberAnimation { duration: Motion.fast; easing.type: Motion.std_ease }
      }
      Behavior on color {
        ColorAnimation { duration: Motion.fast }
      }

      Text {
        id: view_text
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 3
        text: center.grouped_view ? "Grouped" : "All"
        color: view_area.containsMouse ? Theme.c.bg : Theme.c.black2
        font.pixelSize: 13
        font.bold: true

        Behavior on color {
          ColorAnimation { duration: Motion.fast }
        }
      }

      MouseArea {
        id: view_area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: center.grouped_view = !center.grouped_view
      }
    }

    HoldButton {
      id: clear_btn
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: clear_text.implicitWidth + 24
      height: 28
      radius: 14
      outer_color: clear_area.containsMouse ? Qt.alpha(Theme.c.red, 0.18) : Theme.c.black
      border_color: clear_area.containsMouse || clear_area.pressed || center.clear_holding ? Theme.c.red : Theme.c.black2
      border_w: 1
      is_holding: clear_area.pressed || center.clear_holding
      visible: NotificationsServer.history.length > 0
      fill_gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.alpha(Theme.c.red2, 0.78) }
        GradientStop { position: 1.0; color: Theme.c.red }
      }

      onFinished: {
        center.clear_holding = false;
        NotificationsServer.clear_all();
      }

      Behavior on outer_color {
        ColorAnimation { duration: Motion.fast }
      }
      Behavior on border_color {
        ColorAnimation { duration: Motion.fast }
      }

      Text {
        id: clear_text
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 3

        text: "Clear all"
        color: clear_area.pressed || center.clear_holding ? Theme.c.fg : (clear_area.containsMouse ? Theme.c.red2 : Theme.c.black2)
        font.pixelSize: 13
        font.bold: true

        Behavior on color {
          ColorAnimation { duration: Motion.fast }
        }
      }

      MouseArea {
        id: clear_area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
      }

      scale: clear_area.pressed ? 0.92 : 1.0
      Behavior on scale {
        NumberAnimation { duration: Motion.v_fast; easing.type: Motion.std_ease }
      }
    }
  }

  Rectangle {
    id: sep
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: header.bottom
    anchors.topMargin: 12
    height: 1
    color: Theme.c.black2
    opacity: 0.5
  }

  // ── Empty State ──
  Text {
    anchors.centerIn: content_area
    visible: NotificationsServer.history.length === 0
    text: "No notifications"
    color: Theme.c.black2
    font.pixelSize: 18
    font.bold: true
    opacity: 0.6
  }

  // ── Content Area ──
  Item {
    id: content_area
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: sep.bottom
    anchors.topMargin: 10
    anchors.bottom: parent.bottom
    clip: true

    // ── Grouped View ──
    ListView {
      id: grouped_list
      anchors.fill: parent
      visible: center.grouped_view
      model: center.grouped_view ? NotificationsServer.groups : []
      spacing: 7

      boundsBehavior: Flickable.StopAtBounds

      delegate: Column {
        id: group_col
        required property var modelData
        required property int index
        property bool collapsed: !center.expanded_groups[modelData.preview.app]
        width: grouped_list.width
        spacing: 13

        // Group header
        Item {
          width: parent.width
          implicitHeight: 31
          clip: true

          Row {
            id: group_header_row
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Text {
              text: (group_col.collapsed ? "› " : "⌄ ") + group_col.modelData.preview.app
              color: Theme.c.black2
              font.pixelSize: 13
              font.bold: true
              font.capitalization: Font.AllUppercase
              font.letterSpacing: 2
            }

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: count_text.implicitWidth + 12
              height: 22
              radius: 12
              color: Theme.c.black
              visible: group_col.modelData.items.length > 1

              Text {
                id: count_text
                anchors.centerIn: parent
                text: group_col.modelData.items.length
                color: Theme.c.fg
                font.pixelSize:12
                font.bold: true
              }
            }
          }

          MouseArea {
            anchors.fill: group_header_row
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              let app = group_col.modelData.preview.app;
              let m = Object.assign({}, center.expanded_groups);
              if (m[app]) delete m[app]; else m[app] = true;
              center.expanded_groups = m;
            }
          }

          // Dismiss group
          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "✕"
            color: grp_dismiss_area.containsMouse ? Theme.c.fg : Theme.c.black2
            font.pixelSize: 15

            Behavior on color {
              ColorAnimation { duration: Motion.fast }
            }

            MouseArea {
              id: grp_dismiss_area
              anchors.fill: parent
              anchors.margins: 10
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: group_remove_anim.start()
            }
          }
        }

        SequentialAnimation {
          id: group_remove_anim
          ParallelAnimation {
            NumberAnimation { target: group_col; property: "scale"; to: 0.8; duration: Motion.fast; easing.type: Easing.OutQuad }
            NumberAnimation { target: group_col; property: "opacity"; to: 0; duration: Motion.fast; easing.type: Easing.OutQuad }
            NumberAnimation { target: group_col; property: "implicitHeight"; to: 0; duration: Motion.fast; easing.type: Easing.OutQuad }
          }
          ScriptAction {
            script: NotificationsServer.remove_group(group_col.modelData)
          }
        }

        // Group items
        Item {
          width: parent.width
          implicitHeight: group_col.collapsed ? preview_card.implicitHeight : items_col.implicitHeight
          clip: true

          Behavior on implicitHeight {
            NumberAnimation { duration: Motion.fast; easing.type: Motion.std_ease }
          }

          NotifCard {
            id: preview_card
            width: parent.width
            s: 1.666
            notif: group_col.modelData.preview
            current_time: center.current_time
            opacity: group_col.collapsed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Motion.fast } }
          }

          Column {
            id: items_col
            width: parent.width
            opacity: group_col.collapsed ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Motion.fast } }

            ListView {
              id: inner_list
              width: parent.width
              implicitHeight: contentHeight
              interactive: false
              model: group_col.modelData.items
              spacing: 6

              delegate: NotifCard {
                id: inner_card
                required property var modelData
                required property int index
                width: inner_list.width
                s: 1.666
                notif: modelData
                current_time: center.current_time

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

        // Group separator
        Rectangle {
          width: parent.width
          height: 1
          color: Theme.c.black2
          opacity: 0.3
          visible: group_col.index < NotificationsServer.groups.length - 1

          Behavior on height { NumberAnimation { duration: Motion.fast } }
          Behavior on opacity { NumberAnimation { duration: Motion.fast } }
        }
      }
    }

    // ── Chronological View ──
    ListView {
      id: chrono_list
      anchors.fill: parent
      visible: !center.grouped_view
      model: !center.grouped_view ? NotificationsServer.history : []
      spacing: 6
      boundsBehavior: Flickable.StopAtBounds

      add: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.std }
        NumberAnimation { property: "y"; from: -20; duration: Motion.std; easing.type: Motion.std_ease }
      }
      displaced: Transition {
        NumberAnimation { properties: "y"; duration: Motion.std; easing.type: Motion.std_ease }
      }

      delegate: NotifCard {
        id: chrono_card
        required property var modelData
        required property int index
        width: chrono_list.width
        s: 1.666
        notif: modelData
        current_time: center.current_time

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
