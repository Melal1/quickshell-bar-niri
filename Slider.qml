import QtQuick

Item {
    id: root

    required property real value
    property alias baseBar: base
    property bool disabled: false
    property color active_col: "#8B8888"
    property color muted_col: "#4A4A4A"
    property color overdride_col: "#BD6161"
    property color disabled_overdrive_col: "#272727"
    property string icon: ""
    property real _anim_val: value

    Behavior on _anim_val {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutQuad
        }
    }

    Text {
        id: percentText
        width: 40
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        color: "white"
        font.bold: true
        font.family: "Liberation Sans"
        font.pixelSize: 16
        text: root.disabled ? "  off" : Math.round(root._anim_val * 100) + "%"
    }
    Text {
        id: icon_t
        width: 20
        anchors.right: parent.left
        anchors.verticalCenter: parent.verticalCenter
        color: "white"
        font.bold: true
        font.family: "Agave Nerd Font Propo"
        font.pixelSize: 20
        visible: root.icon !== ""
        text: root.icon
    }

    Rectangle {
        id: base
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: percentText.left
        anchors.rightMargin: 15
        anchors.leftMargin: 15
        height: parent.height / 5
        color: "#292828"
        radius: 50

        Rectangle {
            radius: parent.radius
            color: root.disabled ? root.muted_col : root.active_col
            anchors {
                bottom: parent.bottom
                left: parent.left
                top: parent.top
            }
            width: root._anim_val > 1 ? parent.width : Math.min(parent.width, parent.width * root._anim_val)

            Behavior on color {
                ColorAnimation {
                    duration: 300
                }
            }
        }

        Rectangle {
            radius: base.radius
            color: root.disabled ? root.disabled_overdrive_col : root.overdride_col
            anchors {
                bottom: base.bottom
                left: base.left
                top: base.top
            }
            width: root._anim_val < 1 ? 0 : Math.min(base.width, base.width * (root._anim_val - 1))

            Behavior on color {
                ColorAnimation {
                    duration: 300
                }
            }
        }
    }
}
