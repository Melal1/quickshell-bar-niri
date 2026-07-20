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

  function get_screen_by_name(name) {
    if (!Quickshell.screens) return null;
    for (var i = 0; i < Quickshell.screens.length; i++) {
      if (Quickshell.screens[i].name === name) {
        return Quickshell.screens[i];
      }
    }
    return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
  }

  property var main_screen_data: get_screen_by_name(Settings.screen_name)
  property var res_screen_data: get_screen_by_name(Settings.screen_name)

  PanelWindow {
    id: main_win
    screen: main_screen_data

    visible: main_screen_data !== null && main_screen_data.name === Settings.screen_name
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

    mask: pill.is_surface ? null : pill_reg

    MouseArea {
      anchors.fill: parent
      visible: pill.is_surface
      onClicked: pill.close_surface()
      z: -2
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: pill.is_surface ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

    FocusScope {
      anchors.fill: parent
      focus: pill.is_surface
      Keys.onEscapePressed: pill.close_surface()
    }

    HoverHandler {
      onHoveredChanged: {
        if (!hovered) {
          pill.suppress_hover = false;
        }
        pill.hovering = hovered;
      }
    }

    Pill {
      id: pill
      scale: 0.8
      transformOrigin: Item.Top // fix the scale

      bar_win: main_win
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.topMargin: Settings.top_gap * parent.scale - 3
    }
  }

  PanelWindow {
    id: res_win
    readonly property real scale: 0.8
    readonly property real rest_h: Settings.rest_h * scale
    readonly property int top_gap: Settings.top_gap * scale - 5
    screen: res_screen_data

    visible: res_screen_data !== null && res_screen_data.name === Settings.screen_name
    anchors {
      top: true
      left: true
      right: true
    }

    exclusionMode: ExclusionMode.Normal
    aboveWindows: true
    exclusiveZone: ( rest_h + top_gap  )

    color: "transparent"
    Region {
      id: empty_res
    }
    mask: empty_res
  }

  IpcHandler {
    target: "pill"
    function toggle_surface(name: string): void {
      console.log("IpcHandler received name:", name);
      if (name === "launcher" || name === "\"launcher\"") {
        console.log("Toggling launcher surface");
        pill.toggle_surface(Pill.Surfaces.Launcher);
      } else if (name === "clipboard" || name === "\"clipboard\"") {
        console.log("Toggling clipboard surface");
        pill.toggle_surface(Pill.Surfaces.Clipboard);
      }else if(name === "power") {
        pill.toggle_surface(Pill.Surfaces.Power);

      } else if (name === "bluetooth" || name === "\"bluetooth\"") {
        pill.toggle_surface(Pill.Surfaces.Bluetooth);

      } else if (name === "link" || name === "\"link\"" || name === "connectivity" || name === "\"connectivity\"") {
        pill.toggle_surface(Pill.Surfaces.Link);

      } else if (name === "network" || name === "\"network\"" || name === "wifi" || name === "\"wifi\"") {
        pill.toggle_surface(Pill.Surfaces.Network);

      } else if (name === "hide") {
        pill.close_surface();
      } else if (name === "dnd") {
        NotificationsServer.dnd = !NotificationsServer.dnd
      }
    }
  }
}
