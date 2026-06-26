import QtQuick

Row {
  id: visualizer
  required property bool playing
  property bool paused : false
  required property string color
  property real amp : 1
  height: 16
  spacing: 3
  Repeater {
    model: 4
    delegate: Rectangle {
      id: bar
      width: 3
      color: visualizer.color
      radius: 1.5
      anchors.bottom: parent.bottom
      property real animOffset: 0

      height: {
        if (playing)
        { return 3 + animOffset; }
        if(paused) return 3;
        return 0;
      }

      Behavior on height { NumberAnimation { duration: 300 } }

      Timer {
        interval: 100 + Math.random() * 100
        running: playing
        repeat: true
        onTriggered: {
          bar.animOffset = Math.random() * 13 * amp
        }
      }
    }
  }
}
