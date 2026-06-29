import QtQuick

Item {
  id: root

  required property bool active
  required property color default_color

  property var sequence: []

  property int step_duration: 500

  property var target_item: parent
  property string target_property: "color"

  property int current_index: 0
  visible: false

  function apply_current_step() {
    if (root.sequence.length === 0) return;

    if (root.current_index >= root.sequence.length) root.current_index = 0;

    let step = root.sequence[root.current_index];

    pulse_anim.to = (step.color !== undefined) ? step.color : step;
    pulse_anim.duration = (step.duration !== undefined) ? step.duration : root.step_duration;
  }

  ColorAnimation {
    id: pulse_anim
    target: root.target_item
    property: root.target_property

    onStopped: {
      if (root.active && root.sequence.length > 0) {
        root.current_index = (root.current_index + 1) % root.sequence.length;
        root.apply_current_step();
        pulse_anim.start();
      }
    }
  }

  ColorAnimation {
    id: reset_anim
    target: root.target_item
    property: root.target_property
    to: root.default_color
    duration: 500
  }

  onActiveChanged: {
    if (root.active) {
      reset_anim.stop();
      root.current_index = 0;
      if (root.sequence.length > 0) {
        root.apply_current_step();
        pulse_anim.start();
      }
    } else {
      pulse_anim.stop();
      reset_anim.start();
    }
  }

  Component.onCompleted: {
    if (root.active && root.sequence.length > 0) {
      root.apply_current_step();
      pulse_anim.start();
    }
  }
}
