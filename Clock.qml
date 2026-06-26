import Quickshell
import QtQuick

// Pure time display — no state, no animation, no layout opinions.

Text {
  text: {
    let fmt = Settings.time12h ? "h:mm" : "HH:mm"
    if (Settings.clock_sec) fmt += ":ss"
    if (Settings.time12h) fmt += " AP"
    return Qt.formatDateTime(Time.date, fmt)
  }
  color: Theme.c.fg
  font.bold: true
  font.family: Theme.clock_font
  font.pixelSize: 24
}
