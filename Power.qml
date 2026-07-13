import QtQuick.Layouts
import QtQuick
import Quickshell
import Quickshell.Widgets

PillSurface {
  id:root
  focus:true
  property int active_index: 0
  property bool holding : false
  property var acts: [
  {label: "Shutdown", icon: "shutdown", hold: true,  cmd: "poweroff"},
  {label: "Reboot",   icon: "reboot",   hold: true,  cmd: "reboot"},
  {label: "Sleep",    icon: "moon",     hold: false, cmd: "systemctl suspend"}
  ]
  property var current_act: acts[active_index]
  implicitWidth: row.implicitWidth

  function execute_cmd(cmd) {
    request_close()
    // Quickshell.execDetached(["sh", "-c", cmd]);
    console.log("Running " + cmd)
  }

  function move(delta) {
    let dist = root.active_index + delta;
    if(dist > root.acts.length - 1) {
      root.active_index = 0;
      return;
    }
    if(dist < 0) {
      root.active_index = root.acts.length - 1;
      return;
    }
    root.active_index = dist;
  }

  onOpenChanged :{
    if(open){
      root.forceActiveFocus()
      active_index = 0
    }
  }

  Keys.onPressed: (e) => {
    if(e.key === Qt.Key_Enter || e.key === Qt.Key_Return )
    {
      let currentAction = root.acts[root.active_index];
      if (currentAction.hold) {
        root.holding = true
      } else {
        root.execute_cmd(currentAction.cmd);
      }
      e.accepted = true
    }

    if(e.key === Qt.Key_L)
    {
      root.move(1);
      e.accepted = true
      return
    }

    if(e.key === Qt.Key_H)
    {
      root.move(-1);
      e.accepted = true
      return
    }
  }

  Keys.onReleased: (e) => {
    if(e.key === Qt.Key_Enter || e.key === Qt.Key_Return )
    {
      root.holding = false
      e.accepted = true
    }
  }

  ColumnLayout {
    spacing:2
    anchors.fill:parent
    anchors.bottomMargin: 20
    anchors.topMargin: 20

    RowLayout {
      id:row
      spacing: 12
      Layout.alignment: Qt.AlignCenter

      Repeater {
        model: root.acts

        HoldButton {
          Layout.preferredHeight: 70
          Layout.preferredWidth: 70

          is_holding: modelData.hold && ((root.active_index === index && root.holding) || mouse.pressed)
          border_color: Theme.c.cyan
          outer_color: root.active_index === index  ?  Qt.alpha(Theme.c.black2,0.3) : Theme.c.bg
          border_w:1

          fill_gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Theme.c.magenta2, 0.7) }
            GradientStop { position: 1.0; color: Theme.c.magenta }
          }

          onFinished: {
            root.execute_cmd(modelData.cmd);
          }

          GlyphIcon {
            anchors.centerIn: parent
            width: 30
            height: 30
            stroke:2
            name: modelData.icon
            color: root.active_index === index ? Theme.c.yellow : Theme.c.fg
          }

          MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true

            onEntered: {
              root.active_index = index;
            }
            onClicked: {
              root.active_index = index;
              if (modelData.hold === false) {
                root.execute_cmd(modelData.cmd);
              }
            }
          }
        }
      }
    }

    Text {
      Layout.alignment: Qt.AlignHCenter
      Layout.preferredHeight: 22
      text: current_act.label + (current_act.hold ? " - hold required" : "")
      font.pixelSize: 20
      color: Theme.c.fg
    }
  }
}
