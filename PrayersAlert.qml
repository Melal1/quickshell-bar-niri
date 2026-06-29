pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell

Singleton {
  id: prayers

  property var prayer_times: ({})
  property bool prayer_upcoming: false

  FileView {
    id: prayer_file
    path: Quickshell.env("HOME") + Settings.prayer_t_path
    watchChanges: true

    onFileChanged: {
      prayer_file.reload();
      try {
        prayers.prayer_times = JSON.parse(prayer_file.text());
        prayers.check_prayer_time();
      } catch(e) {
        console.log("Error parsing prayers: " + e);
      }
    }
  }

  function check_prayer_time() {
    console.log("prayer time checking");
    if (!prayers.prayer_times.Fajr) return;

    let now = new Date();
    let current_mins = now.getHours() * 60 + now.getMinutes();

    let prayer_list = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"];
    let is_upcoming = false;

    for (let i = 0; i < prayer_list.length; i++) {
      let time_str = prayers.prayer_times[prayer_list[i]];
      if (time_str) {
        let is_pm = time_str.toLowerCase().includes("pm");
        let is_am = time_str.toLowerCase().includes("am");

        let clean_time = time_str.replace(/[^0-9:]/g, "").trim();
        let parts = clean_time.split(":");
        let hours = parseInt(parts[0], 10);
        let mins = parseInt(parts[1], 10);

        if (is_pm && hours < 12) {
          hours += 12;
        } else if (is_am && hours === 12) {
          hours = 0;   // "12:00 AM" -> 00:00
        }
        else if (hours < 11 && prayer_list[i] !== "Fajr") {
          hours += 12;
        }

        let prayer_mins = hours * 60 + mins;

        let diff = prayer_mins - current_mins;

        if (diff > 0 && diff <= Settings.prayer_alert_before) {
          is_upcoming = true;
          break;
        }
      }
    }
    prayers.prayer_upcoming = is_upcoming;
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: prayers.check_prayer_time()
  }
}
