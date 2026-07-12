pragma Singleton
import Quickshell

Singleton {
  property bool time12h: true
  property bool clock_sec: false
  property string screen_name: "eDP-1"
  property bool ignore_paused_mpd: false
  property bool ignore_mpd_mpris_art: false
  readonly property int rest_w: 217
  readonly property int rest_h: 60
  property int hover_w: 833
  readonly property int hover_h: 117
  readonly property int osd_w: 500
  readonly property int osd_h: rest_h
  readonly property int top_gap: 8
  readonly property int round_rad: 40
  readonly property int less_round_rad: 42
  readonly property string prayer_t_path: "/.cache/salawat/athan_cache.json"
  readonly property int prayer_alert_before: 10
  readonly property int popup_w : 666
  readonly property int notifcenter_w: 664
  readonly property int notifcenter_h: 833
  readonly property int launcher_w: 600
  readonly property int launcher_h: 700
  readonly property int clipboard_w: 500
  readonly property int clipboard_h: 600

}
