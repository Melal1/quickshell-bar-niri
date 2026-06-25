pragma Singleton
import QtQuick
import Quickshell

Singleton {
  readonly property real mult: 1

  readonly property int v_fast:     Math.round(60 * mult)
  readonly property int fast:     Math.round(140 * mult)
  readonly property int std: Math.round(300 * mult)
  readonly property int morph:    Math.round(420 * mult)
  readonly property int slow: Math.round(500 * mult)

  readonly property int std_ease: Easing.OutCubic
  readonly property int custom:    Easing.BezierSpline

  readonly property var morphCurve: [0.16, 1, 0.3, 1, 1, 1]
}
