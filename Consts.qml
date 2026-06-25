pragma Singleton
import Quickshell

Singleton {
  readonly property int rest_w: 130
  readonly property int rest_h: 36
  readonly property int hover_w: 500
  readonly property int hover_h: 70
  readonly property int osd_w: 300
  readonly property int osd_h: rest_h
  readonly property int top_gap:8
  readonly property int round_rad: 40
  readonly property int less_round_rad: 25

  enum Modes {
    rest,
    hover,
  }

}
