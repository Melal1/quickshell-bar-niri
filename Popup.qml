import Quickshell
import QtQuick

Item {
  id:root
  required property real sc
  required property  var notif
  required property bool live
  readonly property bool _is_crit: notif.urgency === NotificationUrgency.Critical

  onNotifChanged: {
    expire_t.restart()
  }

  Timer {
    id:expire_t
    interval: root._is_crit ? 20000 : 4000;
    onTriggered: {
      let p = NotificationsServer.popups
      for(let i = 0 ; i < p.length ; i++)
      { NotificationsServer.remove_popup(p[i]) }
    }
  }

}
