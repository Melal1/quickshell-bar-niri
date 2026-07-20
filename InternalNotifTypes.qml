pragma Singleton
import Quickshell

/**
* Internal notification types for the Pill. Each type carries the dim
* (width, height) the Pill should morph to and the duration the notif
* stays on screen before auto-dismissing. The Pill's `internal_notif(type)`
* reads these via `info_for` and restarts a single timer; a new call while
* one is active overrides the old (restarts the timer + swaps the Loader's
* sourceComponent).
*/
Singleton {
  id: root

  enum Types {
    None,
    Dnd,
    Charging
  }

  function info_for(type) {
    if (type === InternalNotifTypes.Types.Charging) return {w: Settings.rest_w +300, h: Settings.rest_h, r: 30,duration: 3000}
    if (type === InternalNotifTypes.Types.Dnd) return {w: Settings.rest_w +40, h: Settings.rest_h, r: 30,duration: 3000}
    return {w: 0, h: 0, duration: 0}
  }
}
