pragma Singleton
import Quickshell

Singleton {
  // Set this to true for FHD Laptop, false for 2K Desktop
  // Alternatively, you can use automatic detection if your shell exports HOSTNAME:
  // property bool is_laptop: Quickshell.env("HOSTNAME") === "zeta"
  property bool is_laptop: true

  property bool time12h: true
  property bool clock_sec: false
  
  // Note: Change "DP-1" to your actual desktop monitor name if different
  property string screen_name: is_laptop ? "eDP-1" : "DP-1" 
  
  property bool ignore_paused_mpd: false
  property bool ignore_mpd_mpris_art: false
  
  // Conditionally set sizes for FHD vs 2K (FHD values are ~0.75x of 2K)
  readonly property int rest_w: is_laptop ? 98 : 130
  readonly property int rest_h: is_laptop ? 27 : 36
  property int hover_w: is_laptop ? 375 : 500
  readonly property int hover_h: is_laptop ? 52 : 70
  readonly property int osd_w: is_laptop ? 225 : 300
  readonly property int osd_h: rest_h
  readonly property int top_gap: is_laptop ? 6 : 8
  readonly property int round_rad: is_laptop ? 30 : 40
  readonly property int less_round_rad: is_laptop ? 19 : 25
  
  readonly property string prayer_t_path: "/.cache/salawat/athan_cache1.json"
  readonly property int prayer_alert_before: 10
  
  readonly property int popup_w: is_laptop ? 300 : 400
  readonly property int notifcenter_w: is_laptop ? 300 : 400
  readonly property int notifcenter_h: is_laptop ? 375 : 500
  readonly property int launcher_w: is_laptop ? 375 : 500
  readonly property int launcher_h: is_laptop ? 450 : 600
}
