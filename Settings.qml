pragma Singleton
import Quickshell

Singleton {
  property bool time12h: true
  property bool clock_sec: false
  property string screen_name: "eDP-1"
  property bool ignore_paused_mpd: false
  property bool ignore_mpd_mpris_art: false
  readonly property int rest_w: 130
  readonly property int rest_h: 36
  property int hover_w: 500
  readonly property int hover_h: 70
  readonly property int osd_w: 300
  readonly property int osd_h: rest_h
  readonly property int top_gap: 8
  readonly property int round_rad: 40
  readonly property int less_round_rad: 25
  readonly property string prayer_t_path: "/.cache/salawat/athan_cache1.json"
  readonly property int prayer_alert_before: 10
  readonly property int popup_w : 400
  readonly property int notifcenter_w: 400
  readonly property int notifcenter_h: 500
  readonly property int launcher_w: 500
  readonly property int launcher_h: 600

}
