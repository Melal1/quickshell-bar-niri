import QtQuick

Item {
    id: root

    property string text: ""
    property color color: "white"
    property alias font: label.font
    property bool active: true

    implicitHeight: label.implicitHeight
    clip: true

    readonly property bool overflowing: label.implicitWidth > width

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        x: 0
        text: root.text
        color: root.color
        elide: Text.ElideNone
        width: implicitWidth

        SequentialAnimation {
            id: anim
            loops: Animation.Infinite
            PauseAnimation { duration: 1800 }
            NumberAnimation {
                target: label
                property: "x"
                from: 0
                to: -(label.implicitWidth - root.width)
                duration: Math.max(1, label.implicitWidth - root.width) * 22
                easing.type: Easing.InOutSine
            }
            PauseAnimation { duration: 1800 }
            NumberAnimation {
                target: label
                property: "x"
                from: -(label.implicitWidth - root.width)
                to: 0
                duration: Math.max(1, label.implicitWidth - root.width) * 22
                easing.type: Easing.InOutSine
            }
        }

        onTextChanged: root.sync()
    }

    onActiveChanged: sync()
    onOverflowingChanged: sync()
    Component.onCompleted: sync()

    function sync() {
        anim.stop();
        label.x = 0;
        if (overflowing && active)
            anim.start();
    }
}
