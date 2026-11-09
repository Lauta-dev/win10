// AppLaunchState.qml — Lanzador centralizado con watchdog de apertura.
// Singleton: registra apps en lanzamiento, vigila ToplevelManager con match
// fuzzy y notifica si no aparece ventana en 15s.
pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Singleton {
    id: root

    readonly property int timeoutMs: 15000
    readonly property int pollMs: 500

    // Apps con lanzamiento pendiente (array de appIds)
    property var launching: []
    // appId -> deadline epoch ms
    property var _deadlines: ({})

    function isLaunching(appId) {
        return launching.indexOf(appId) >= 0
    }

    // ── Normalización para match fuzzy ──────────────────────────────────
    function _norm(s) {
        return (s || "").toLowerCase().replace(/-\d+$/, "")
    }

    function _lastPart(s) {
        var p = (s || "").split(".")
        return p.length > 0 ? p[p.length - 1] : ""
    }

    // ¿El toplevel corresponde a la app lanzada? (fuzzy)
    // Cubre: exacto, case-insensitive, misma DesktopEntry, reverse-domain.
    function _matches(launchedId, topId) {
        if (!launchedId || !topId) return false
        if (topId === "__unknown__") return false
        if (launchedId === topId) return true
        var ln = _norm(launchedId)
        var tn = _norm(topId)
        if (ln !== "" && ln === tn) return true
        // Misma DesktopEntry resuelta
        var e1 = null, e2 = null
        try { e1 = Config._resolveEntry(launchedId) } catch (e) { e1 = null }
        try { e2 = Config._resolveEntry(topId) } catch (e) { e2 = null }
        if (e1 && e2 && e1.id && e2.id && e1.id === e2.id) return true
        // Entry id cruzado contra el otro appId
        if (e1 && e1.id && (e1.id === topId || _norm(e1.id) === tn)) return true
        if (e2 && e2.id && (e2.id === launchedId || _norm(e2.id) === ln)) return true
        // Último segmento del reverse-domain (org.foo.Bar -> bar)
        var l1 = _norm(_lastPart(launchedId))
        var l2 = _norm(_lastPart(topId))
        if (l1 !== "" && l1 === l2) return true
        return false
    }

    function _hasWindow(appId) {
        var all = []
        try { all = ToplevelManager.toplevels.values } catch (e) { return false }
        for (var i = 0; i < all.length; i++) {
            var tid = all[i].appId ?? ""
            if (_matches(appId, tid)) return true
        }
        return false
    }

    function _markDone(appId) {
        var arr = launching.slice()
        var idx = arr.indexOf(appId)
        if (idx >= 0) arr.splice(idx, 1)
        launching = arr
        var d = _deadlines
        delete d[appId]
        _deadlines = d
    }

    // ── Lanzar app ──────────────────────────────────────────────────────
    // Devuelve true si se inició (o ya estaba abierta/en curso).
    function launch(appId) {
        if (!appId || appId === "") return false
        if (isLaunching(appId)) return true
        if (_hasWindow(appId)) return true

        var entry = null
        try { entry = Config._resolveEntry(appId) } catch (e) { entry = null }
        if (!entry) {
            console.warn("[AppLaunch] sin entry para:", appId)
            return false
        }

        var label = entry.name ?? appId
        var ok = false

        // Preferir API nativa (maneja terminal/env por sí sola)
        try {
            var live = DesktopEntries.byId(entry.id)
            if (live && live.execute) {
                live.execute()
                ok = true
            }
        } catch (e) {
            console.warn("[AppLaunch] execute() falló:", appId, e)
            ok = false
        }

        // Fallback: Process estático (command no reactivo, vía run())
        if (!ok) {
            var raw = ""
            try {
                raw = (entry.execString ?? entry.exec ?? "").replace(/%[uUfFdDnNickvm]/g, "").trim()
            } catch (e) { raw = "" }
            if (!raw || raw === "") {
                console.warn("[AppLaunch] exec vacío para:", appId)
                return false
            }
            var needsTerm = false
            try { needsTerm = entry.runInTerminal ?? entry.terminal ?? false } catch (e) { needsTerm = false }
            _fallbackProc.run(raw, needsTerm)
            ok = true
        }

        var arr = launching.slice()
        arr.push(appId)
        launching = arr
        var d = _deadlines
        d[appId] = Date.now() + timeoutMs
        _deadlines = d
        return true
    }

    function _check() {
        var now = Date.now()
        var pending = launching.slice()
        for (var i = 0; i < pending.length; i++) {
            var appId = pending[i]
            if (_hasWindow(appId)) {
                _markDone(appId)
                continue
            }
            var dl = _deadlines[appId] ?? 0
            if (now >= dl) {
                _markDone(appId)
                var label = appId
                try { label = Config.resolveAppName(appId) || appId } catch (e) {}
                console.warn("[AppLaunch] timeout sin ventana (fuzzy):", appId)
            }
        }
    }

    Timer {
        id: _watchdog
        interval: root.pollMs
        repeat: true
        running: root.launching.length > 0
        onTriggered: root._check()
    }

    // Process estático con función run() — evita command reactivo (convención).
    Process {
        id: _fallbackProc
        property string _cmd: ""
        property bool _term: false
        command: _term
            ? ["setsid", "alacritty", "-e", "sh", "-c", _cmd]
            : ["setsid", "sh", "-c", _cmd]
        running: false
        function run(raw, needsTerm) {
            _fallbackProc._cmd = raw + " &"
            _fallbackProc._term = !!needsTerm
            _fallbackProc.running = false
            _fallbackProc.running = true
        }
    }
}
