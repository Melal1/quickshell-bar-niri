import QtQuick

/**
 * Individual notification card for the NotifCenter.
 * Shows icon, app name eyebrow, summary, body, timestamp, and dismiss button.
 * Slides in on creation and scales down on dismiss with animation.
 */
Item {
    id: card

    property real s: 1
    property var notif

    implicitHeight: card_body.implicitHeight + 8 * s
    clip: true



    function dismiss() {
        if (card.notif) {
            NotificationsServer.remove_notif(card.notif);
        }
    }

    Rectangle {
        id: card_body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        implicitHeight: card_content.implicitHeight + 14 * card.s
        radius: 10 * card.s
        color: card_hover.containsMouse ? Theme.c.black : Theme.c.bg
        border.width: 1
        border.color: Theme.c.black2

        Behavior on color {
            ColorAnimation { duration: Motion.fast }
        }

        MouseArea {
            id: card_hover
            anchors.fill: parent
            hoverEnabled: true
        }

        Row {
            id: card_content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 7 * card.s
            spacing: 8 * card.s

            // Icon
            Rectangle {
                id: icon_tile
                width: 26 * card.s
                height: 26 * card.s
                radius: 8 * card.s
                color: Theme.c.black

                Image {
                    id: icon_img
                    anchors.fill: parent
                    anchors.margins: card.notif && card.notif.image ? 0 : 5 * card.s
                    source: card.notif ? NotificationsServer.icon_for(card.notif) : ""
                    sourceSize.width: 52
                    sourceSize.height: 52
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    visible: source.toString().length > 0
                }

                Rectangle {
                    anchors.centerIn: parent
                    visible: !icon_img.visible
                    width: 6 * card.s
                    height: 6 * card.s
                    radius: 3 * card.s
                    color: Theme.c.fg
                }
            }

            // Text content
            Column {
                width: parent.width - icon_tile.width - dismiss_col.width - 16 * card.s
                spacing: 2 * card.s

                Text {
                    width: parent.width
                    text: (card.notif && card.notif.app) ? card.notif.app : "System"
                    color: Theme.c.black2
                    font.pixelSize: Math.round(8 * card.s)
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1 * card.s
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: (card.notif && card.notif.summary) ? card.notif.summary : ""
                    color: Theme.c.fg
                    font.pixelSize: Math.round(11 * card.s)
                    font.bold: true
                    maximumLineCount: 1
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: card.notif && card.notif.body && card.notif.body.length > 0
                    text: (card.notif && card.notif.body) ? card.notif.body : ""
                    color: Theme.c.black2
                    font.pixelSize: Math.round(10 * card.s)
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
            }

            // Dismiss button
            Column {
                id: dismiss_col
                width: 16 * card.s
                spacing: 4 * card.s

                Text {
                    text: "✕"
                    color: x_area.containsMouse ? Theme.c.fg : Theme.c.black2
                    font.pixelSize: Math.round(10 * card.s)

                    Behavior on color {
                        ColorAnimation { duration: Motion.fast }
                    }

                    MouseArea {
                        id: x_area
                        anchors.fill: parent
                        anchors.margins: -6 * card.s
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.dismiss()
                    }
                }

                Text {
                    readonly property int age: {
                        if (!card.notif || !card.notif.ts) return -1;
                        return Math.floor((Date.now() - card.notif.ts) / 60000);
                    }
                    text: age < 0 ? "" : age < 1 ? "now" : age < 60 ? age + "m" : Math.floor(age / 60) + "h"
                    color: Theme.c.black2
                    font.pixelSize: Math.round(7.5 * card.s)
                    opacity: 0.7
                }
            }
        }
    }
}
