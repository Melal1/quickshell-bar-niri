pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
  enum Modes {
    Nothing,
    Paused,
    Stopped,
    Playing
  }

  readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

  readonly property int status: !player ? Player.Modes.Nothing :
  player.playbackState === MprisPlaybackState.Playing ? Player.Modes.Playing :
  player.playbackState === MprisPlaybackState.Paused  ? Player.Modes.Paused  :
  Player.Modes.Stopped
}
