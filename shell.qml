import Quickshell
import QtQuick
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import QtQuick.Layouts
import Quickshell.Wayland
import Quickshell.Io

// import "Singletons"

Scope {
  id: root
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: main_win
      screen: modelData
      readonly property real sc: modelData ? (modelData.height / 1080) : 1
      required property var modelData

      visible: modelData.name === Settings.screen_name
      anchors {
        top: true
        left: true

        right: true
        bottom: true
      }

      color: "transparent"
      Region {
        id: empty_reg
      }
      Region {
        id: pill_reg
        readonly property int base_w: Math.max(pill.width, pill.target_w)
        x: pill.x + (pill.width - base_w) / 2
        y: pill.y

        width: base_w
        height: Math.max(pill.height, pill.target_h)
      }

      mask: pill_reg

      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Top
      HoverHandler {

        onHoveredChanged: {
          pill.hovering = hovered;
        }
      }

      Pill {
        id: pill
        sc: main_win.sc
        bar_win: main_win
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Settings.top_gap
      }

    }
  }
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: res_win
      readonly property real scale: modelData ? (modelData.height / 1080) : 1
      readonly property real rest_h: Settings.rest_h * scale
      readonly property int top_gap: Settings.top_gap * scale - 6
      required property var modelData
      screen: modelData

      visible: modelData.name === "DP-1"
      anchors {
        top: true
        left: true
        right: true
      }

      exclusionMode: ExclusionMode.Normal
      aboveWindows: true
      exclusiveZone: rest_h + top_gap

      color: "transparent"
      Region {
        id: empty_res
      }
      mask: empty_res
    }
  }
}
