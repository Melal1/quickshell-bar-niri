import QtQuick

Item {
    id: root

    // Pass-through properties for the visual slider
    required property real value
    property bool disabled: false
    property string icon: ""

    // Signals for the OS
    signal moved(real v)
    signal committed(real v)

    // 1. The Visual Slider (Dumb Component)
    Slider {
        id: visualSlider
        anchors.fill: parent

        disabled: root.disabled
        icon: root.icon

        // If the mouse is dragging, use the live drag value to stop lag!
        // Otherwise, use the real value.
        value: dragArea.pressed ? dragArea.liveValue : root.value

        // 2. The Knob (Tick)
        Rectangle {
            id: knob
            width: 4
            height: 16
            radius: 2
            color: "white"

            // Anchor it exactly to the exposed 'baseBar' from Slider.qml!
            anchors.verticalCenter: visualSlider.baseBar.verticalCenter

            // Calculate the X position based on the width of the baseBar
            x: visualSlider.baseBar.x + (visualSlider.baseBar.width * Math.min(1, visualSlider.value)) - (width / 2)

            // Disable animation while dragging so the knob doesn't lag!
            Behavior on x {
                enabled: !dragArea.pressed
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutQuad
                }
            }
        }

        // 3. The Interactive Brain
        MouseArea {
            id: dragArea
            // Only attach the click zone to the bar itself!
            anchors.fill: visualSlider.baseBar
            anchors.margins: -10

            property real liveValue: root.value

            function setFromX(mx) {
                // Prevent crashing if they drag past the edges
                liveValue = Math.max(0, Math.min(1, mx / visualSlider.baseBar.width));
                root.moved(liveValue);
            }

            onPressed: e => setFromX(e.x)
            onPositionChanged: e => {
                if (pressed)
                    setFromX(e.x);
            }
            onReleased: root.committed(liveValue)
        }
    }
}
