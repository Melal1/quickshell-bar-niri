import QtQuick

/**
 * Reusable surface base for the Pill's morphing surfaces.
 * The host Pill sets `open`, `s`, and `morph_closeness`.
 * Each surface sets its own margin insets.
 * Content fades in as morph_closeness approaches 1.0.
 */
Item {
    id: surface

    property real s: 1
    property bool open: false
    property real morph_closeness: 1

    property real m_top: 0
    property real m_left: 0
    property real m_right: 0
    property real m_bottom: 0

    signal request_close()

    readonly property bool active: open

    property bool settled: false
    onOpenChanged: if (!open) settled = false
    onMorph_closenessChanged: if (open && morph_closeness > 0.92) settled = true

    anchors.fill: parent
    anchors.topMargin: m_top * s
    anchors.leftMargin: m_left * s
    anchors.rightMargin: m_right * s
    anchors.bottomMargin: m_bottom * s

    enabled: open
    opacity: open ? (settled ? 1 : Math.pow(morph_closeness, 1.3)) : 0
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation { duration: Motion.std; easing.type: Motion.std_ease }
    }
}
