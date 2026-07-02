pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

/**
* Any notif that will call dismiss will not be added to history, if you want to add the notif
* to history just call expire() or use the expireTimeout attr
*/
Singleton {
  id: root

  property var history: []
  property bool dnd: false
  property var popups: []

  function icon_for(n) {
    if (!n) return "";
    var img = n.image || "";
    var names = [];

    if (img.indexOf("image://icon/") === 0) {
      names.push(img.substring(13));
    } else if (img.length && !/\.svg$/i.test(img)) {
      return img;
    }

    names.push(n.appIcon, n.desktopEntry, (n.appName || n.app || "").toLowerCase());

    for (var i = 0; i < names.length; i++) {
      var nm = names[i];
      if (!nm || !nm.length) continue;
      if (nm.indexOf("/") === 0 || nm.indexOf("file://") === 0) return nm;
      var p = Quickshell.iconPath(nm, true);
      if (p.length) return p;
    }
    return "";
  }

  function hook_closed(notif) {
    notif.closed.connect(res => {
        root.popups = root.popups.filter(p => p.id !== notif.id);

        if (!(res === NotificationCloseReason.Expired)) return;

        root.history = [{
          app: (notif.appName && notif.appName.length) ? notif.appName : "System",
          summary: notif.summary,
          body: notif.body,
          appIcon: notif.appIcon,
          desktopEntry: notif.desktopEntry,
          image: icon_for(notif),
          urgency: notif.urgency,
          ts: Date.now(),
          id: notif.id
        }].concat(root.history).slice(0, 50);
    });
  }

  readonly property var groups: {
    let app_map = {};
    let result = [];

    for (let i = 0; i < history.length; i++) {
      let item = history[i];

      if (app_map[item.app] === undefined) {
        app_map[item.app] = {
          preview: item,
          items: []
        };
        result.push(app_map[item.app]);
      }

      app_map[item.app].items.push(item);
    }

    result.sort((a, b) => b.preview.ts - a.preview.ts);

    return result;
  }

  function remove_group(group) {
    if (!group || !group.preview) return;
    let targetApp = group.preview.app;
    root.history = root.history.filter(item => item.app !== targetApp);
  }

  function remove_notif(notif) {
    if (!notif || !notif.id) return;
    root.history = root.history.filter(item => item.id !== notif.id);
  }

  function add_popup(notif) {
    if (root.popups.length >= 3) {
      root.popups[0].expire();
    }
    root.popups = root.popups.concat([notif]).slice(-3);
  }

  function remove_popup(notif) {
    if (!notif || !notif.id) return;

    root.popups = root.popups.filter(p => p.id !== notif.id);

    notif.expire();
  }

  NotificationServer {
    id: server

    onNotification: new_notif => {
      // TODO: Exclude some notifs
      new_notif.tracked = true;

      hook_closed(new_notif);

      let is_crit = new_notif.urgency === NotificationUrgency.Critical;
      if (!dnd || is_crit) {
        add_popup(new_notif);
        return;
      }

      // If DND is on and not critical route it straight into history
      new_notif.expire();
    }
  }
}
