import QtQuick
import QtQuick.Shapes

/**
* Hand-drawn wifi glyph: three concentric arcs over a base dot, the lit-arc
* count standing in for signal strength. Adapted from quickshell9's
* WifiGlyph.qml — the geometry is the same (concentric arcs at radii 4/8/12
* in a 24x24 space, with a 1.5-unit base dot at the bottom). What changed:
* the colour palette now reads from `Theme.c.fg` (and an alpha-dimmed variant
* of the same) instead of the old `Theme.iconDim`, and a `color` override
* lets callers tint the lit strokes (e.g. green when connected).
*
* Thresholds: level > 0.66 lights all three arcs, > 0.33 two, > 0 one.
* The base dot is lit whenever at least one arc is. The off-state diagonal
* slash is drawn over the same transform so it stays registered with the
* arcs when the radio is off.
*/
Item {
  id: root

  property real s: 1
  property real level: 0
  property bool on: true
  property color color: Theme.c.fg
  property color off_color: Qt.alpha(Theme.c.fg, 0.18)

  implicitWidth: 18 * s
  implicitHeight: 18 * s

  readonly property int lit_count: !on
    ? 0
    : (level > 0.66 ? 3 : (level > 0.33 ? 2 : (level > 0 ? 1 : 0)))

  readonly property real u: Math.min(width, height) / 24

  readonly property real glyph_x: arcs.boundingRect.width > 0
    ? root.width / 2 - (arcs.boundingRect.x + arcs.boundingRect.width / 2) * root.u
    : (root.width - 24 * root.u) / 2
  readonly property real glyph_y: arcs.boundingRect.height > 0
    ? root.height / 2 - (arcs.boundingRect.y + arcs.boundingRect.height / 2) * root.u
    : (root.height - 24 * root.u) / 2

  Shape {
    id: arcs
    width: 24
    height: 24
    scale: root.u
    transformOrigin: Item.TopLeft
    x: root.glyph_x
    y: root.glyph_y
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeColor: root.lit_count >= 1 ? root.color : root.off_color
      fillColor: "transparent"
      strokeWidth: (2 / root.u) * root.s
      capStyle: ShapePath.RoundCap
      PathSvg { path: "M9.17 13.17 A4 4 0 0 1 14.83 13.17" }
    }
    ShapePath {
      strokeColor: root.lit_count >= 2 ? root.color : root.off_color
      fillColor: "transparent"
      strokeWidth: (2 / root.u) * root.s
      capStyle: ShapePath.RoundCap
      PathSvg { path: "M6.34 10.34 A8 8 0 0 1 17.66 10.34" }
    }
    ShapePath {
      strokeColor: root.lit_count >= 3 ? root.color : root.off_color
      fillColor: "transparent"
      strokeWidth: (2 / root.u) * root.s
      capStyle: ShapePath.RoundCap
      PathSvg { path: "M3.5 7.5 A12 12 0 0 1 20.5 7.5" }
    }
    ShapePath {
      strokeColor: "transparent"
      fillColor: root.lit_count >= 1 ? root.color : root.off_color
      PathSvg { path: "M12 14.1 A1.5 1.5 0 0 1 12 17.1 A1.5 1.5 0 0 1 12 14.1z" }
    }
  }

  Shape {
    id: slash
    width: 24
    height: 24
    scale: root.u
    transformOrigin: Item.TopLeft
    x: root.glyph_x
    y: root.glyph_y
    visible: !root.on
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeColor: Qt.alpha(Theme.c.fg, 0.3)
      fillColor: "transparent"
      strokeWidth: (1.7 / root.u) * root.s
      capStyle: ShapePath.RoundCap
      PathSvg { path: "M4 3 L20 19" }
    }
  }
}
