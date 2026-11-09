// OpenAppsState.qml — Lista de ventanas (oculta minimizadas, sin filtro de workspaces)

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
    property var appIds: []
    property var toplevelsFor: {}
    property var appDataFor: {}

    property var _sig: ""

    readonly property var liveToplevels: ToplevelManager.toplevels.values
    onLiveToplevelsChanged: _recalc()
    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() { OpenAppsState._recalc() }
    }

    Timer {
        id: _recalcTimer
        interval: 500
        repeat: true
        running: true
        onTriggered: _recalc()
    }

    function _norm(s) {
        return (s || "").toLowerCase().replace(/-\d+$/, "");
    }

    function _recalc() {
        var mgr = ToplevelManager
        var raw = mgr ? mgr.toplevels.values : []
        var all = raw.filter(function(t) { return t && !t.minimized; })

        // 1) Firma barata: appIds + conteo de ventanas por app + estado activo.
        var winCounts = {}
        var activeFlags = {}
        var ids = []
        var seen = {}
        for (var i = 0; i < all.length; i++) {
            var t = all[i];
            var aid = t ? (t.appId ?? "__unknown__") : "__unknown__";
            winCounts[aid] = (winCounts[aid] || 0) + 1;
            if (t && t.activated) activeFlags[aid] = true;
            if (!seen[aid]) { seen[aid] = true; ids.push(aid); }
        }

        var sigParts = []
        for (var aid in winCounts) {
            sigParts.push(aid + ":" + winCounts[aid] + ":" + (activeFlags[aid] ? "1" : "0"));
        }
        sigParts.sort();
        var newSig = sigParts.join("\u0000");
        if (newSig === _sig) return;
        _sig = newSig;

        // 2) Solo si cambió algo: construir mapas por appId
        var result = ids.slice()
        var map = {}
        var appData = {}
        for (var i = 0; i < result.length; i++) {
            var aid = result[i];
            var key = _norm(aid);
            var tl = [];
            for (var j = 0; j < all.length; j++) {
                var t2 = all[j];
                var t2aid = t2 ? (t2.appId ?? "__unknown__") : "__unknown__";
                if (_norm(t2aid) === key || t2aid === aid) tl.push(t2);
            }
            map[key] = tl;

            var winCount = tl.length;
            var anyActive = false;
            for (var j = 0; j < tl.length; j++) {
                if (tl[j].activated) { anyActive = true; break; }
            }
            appData[aid] = { winCount: winCount, anyActive: anyActive };
        }

        appIds = result;
        toplevelsFor = map;
        appDataFor = appData;
    }

    Component.onCompleted: _recalc()
}
