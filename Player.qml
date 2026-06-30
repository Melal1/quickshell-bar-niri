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

  readonly property var player: Mpris.players.values.length > 0 ? get_player() : null

  function get_player() {
    const players = Mpris.players.values;

    let playing_non_mpd = null;
    let playing_mpd = null;
    let first_non_mpd = null;
    let first_mpd = null;

    for (let i = 0; i < players.length; i++) {
      let p = players[i];
      let is_mpd = p.desktopEntry === "mpd-mpris";
      let is_playing = p.playbackState === MprisPlaybackState.Playing;

      if (is_mpd) {
        if (!first_mpd) first_mpd = p;
        if (is_playing && !playing_mpd) playing_mpd = p;
      } else {
        if (!first_non_mpd) first_non_mpd = p;
        if (is_playing && !playing_non_mpd) playing_non_mpd = p;
      }
    }

    // 1. "If both are playing, return the other one" AND "Else return the one playing"
    // Prioritizing the non-mpd playing player covers both of these conditions.
    if (playing_non_mpd) return playing_non_mpd;
    if (playing_mpd) return playing_mpd;

    // 2. "If there more than 3 with one of them being mpd return the first one else than mpd"
    // If we reach this line, NOTHING is playing, simply return the first non-mpd player found.
    if (first_non_mpd) return first_non_mpd;

    // 3. Optional: ignore mpd-mpris if it's there and paused.
    if (!Settings.ignore_paused_mpd && first_mpd) return first_mpd;

    return null;
  }

  readonly property int status: !player ? Player.Modes.Nothing :
  player.playbackState === MprisPlaybackState.Playing ? Player.Modes.Playing :
  player.playbackState === MprisPlaybackState.Paused  ? Player.Modes.Paused  :
  Player.Modes.Stopped
}
