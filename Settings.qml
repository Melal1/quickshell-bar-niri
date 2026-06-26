pragma Singleton
import Quickshell

Singleton {
    property bool time12h: true
    property bool clock_sec: false
    property string screen_name: "DP-1"
    readonly property int rest_w: 130
    readonly property int rest_h: 36
    readonly property int hover_w: 500
    readonly property int hover_h: 70
    readonly property int osd_w: 300
    readonly property int osd_h: rest_h
    readonly property int top_gap: 8
    readonly property int round_rad: 40
    readonly property int less_round_rad: 25

    enum Modes {
        Rest,
        Hover,
        Osd
    }

    property var modes_dim: ({
            [Settings.Modes.Rest]: [rest_w, rest_h],
            [Settings.Modes.Hover]: [hover_w, hover_h],
            [Settings.Modes.Osd]: [osd_w, osd_h]
        })
}
