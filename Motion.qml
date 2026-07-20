pragma Singleton
import QtQuick
import Quickshell

Singleton {
  property bool reduce_motion: false
  readonly property bool reduce: reduce_motion
  readonly property real mult: reduce_motion ? 0.4 : 1

  readonly property int v_fast:     Math.round(60 * mult)
  readonly property int fast:     Math.round(140 * mult)
  readonly property int std: Math.round(300 * mult)
  readonly property int morph:    Math.round(420 * mult)
  readonly property int slow: Math.round(1000 * mult)
  readonly property int shapeshift: Math.round(820 * mult)
  readonly property int glide:      Math.round(260 * mult)
  readonly property int heat:       Math.round(1100 * mult)
  readonly property int pulse:      Math.round(420 * mult)

  readonly property int std_ease: Easing.OutCubic
  readonly property int custom:    Easing.BezierSpline

  readonly property var morph_curve: [0.16, 1, 0.3, 1, 1, 1]
}
