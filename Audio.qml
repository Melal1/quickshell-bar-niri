pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire

Singleton{
  PwObjectTracker {
    objects: [ Pipewire.defaultAudioSink ]
  }

  readonly property var audio: Pipewire.defaultAudioSink?.audio
  readonly property real volume: Pipewire.defaultAudioSink?.audio.volume ?? 0
  readonly property bool is_muted: Pipewire.defaultAudioSink?.audio.muted ?? false

}
