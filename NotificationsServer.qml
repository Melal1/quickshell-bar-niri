pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

/**
* Resident notification model: every incoming notif is added to `history`
* immediately on arrival with a live ref to the Notification object, so its
* actions remain invokable from the inbox. `hook_closed` removes the notif
* from history + popups when it closes (external close, app-initiated close,
* or our own dismiss() from inbox/clear-all).
*
* Popups are a transient view layer on top: timeout / yellow-dot just
* removes from the popup list (notif stays in history); red-dot calls
* dismiss() which permanently removes it from both.
*/
Singleton {
  id: root

  property var history: []
  property bool dnd: false
  property bool suppress_popups: false
  property var popups: []
  property var seen_ids: ({})

  /**
  * Generic per-surface notification filter. Surfaces register a named group
  * of desktop entry IDs at startup with `register_filter`, then call
  * `set_filter_active` to flip the suppression on/off as the surface opens
  * and closes. The `onNotification` handler below checks every active group
  * against the incoming notification's `desktopEntry` and silently expires
  * matches before they reach history or popups.
  */
  property var suppressed_groups: ({})

  function register_filter(name, ids) {
    suppressed_groups[name] = { enabled: false, ids: ids };
  }

  function set_filter_active(name, active) {
    var g = suppressed_groups[name];
    if (g)
    g.enabled = active;
  }

  readonly property int unread: {
    var u = 0;
    for (var i = 0; i < history.length; i++)
    if (!seen_ids[history[i].id]) u++;
    return u;
  }

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
        root.history = root.history.filter(item => item.id !== notif.id);
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
    let to_dismiss = [];
    for (let i = 0; i < root.history.length; i++) {
      if (root.history[i].app === targetApp && root.history[i].notif) {
        to_dismiss.push(root.history[i].notif);
      }
    }
    root.history = root.history.filter(item => item.app !== targetApp);
    for (let i = 0; i < to_dismiss.length; i++) {
      to_dismiss[i].dismiss();
    }
  }

  function remove_notif(entry) {
    if (!entry || !entry.id) return;
    if (entry.notif) entry.notif.dismiss();
    root.history = root.history.filter(item => item.id !== entry.id);
  }

  function add_popup(notif) {
    root.popups = root.popups.concat([notif]).slice(-3);
  }

  function remove_popup(notif) {
    if (!notif || !notif.id) return;
    root.popups = root.popups.filter(p => p.id !== notif.id);
  }

  function mark_all_seen() {
    var m = {};
    for (var i = 0; i < history.length; i++) m[history[i].id] = true;
    root.seen_ids = m;
  }

  function clear_all() {
    let to_dismiss = [];
    for (let i = 0; i < root.history.length; i++) {
      if (root.history[i].notif) to_dismiss.push(root.history[i].notif);
    }
    root.history = [];
    root.popups = [];
    root.seen_ids = ({});
    for (let i = 0; i < to_dismiss.length; i++) {
      to_dismiss[i].dismiss();
    }
  }

  NotificationServer {
    id: server
    keepOnReload: true
    bodySupported: true
    actionsSupported: true
    imageSupported: true
    inlineReplySupported: true

    onNotification: new_notif => {
      // Generic per-surface filter: any active group whose IDs match this
      // notification's `desktopEntry`, `appName`, or `app` silently expires
      // it. The notification never reaches history, popups, or DND logic.
      var de = (new_notif.desktopEntry || "").toLowerCase();
      var app_name = (new_notif.appName || new_notif.app || "").toLowerCase();
      for (var group_name in suppressed_groups) {
        var g = suppressed_groups[group_name];
        if (!g.enabled)
        continue;
        for (var i = 0; i < g.ids.length; i++) {
          var id = g.ids[i];
          var hit_de = de.length > 0 && de.indexOf(id) >= 0;
          var hit_app = app_name.length > 0 && app_name.indexOf(id) >= 0;
          if (hit_de || hit_app) {
            new_notif.expire();
            return;
          }
        }
      }

      new_notif.tracked = true;

      root.history = [{
        app: (new_notif.appName && new_notif.appName.length) ? new_notif.appName : "System",
        summary: new_notif.summary,
        body: new_notif.body,
        appIcon: new_notif.appIcon,
        desktopEntry: new_notif.desktopEntry,
        image: icon_for(new_notif),
        urgency: new_notif.urgency,
        ts: Date.now(),
        id: new_notif.id,
        notif: new_notif,
        actions: new_notif.actions ? new_notif.actions.filter(function(a) { return a.text.length > 0; }) : []
      }].concat(root.history).slice(0, 100);

      hook_closed(new_notif);

      let is_crit = new_notif.urgency === NotificationUrgency.Critical;
      let skip_popup = dnd || suppress_popups;
      if (!skip_popup || is_crit) {
        add_popup(new_notif);
      }
    }
  }
}
