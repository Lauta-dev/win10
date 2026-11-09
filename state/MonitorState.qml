import Quickshell
import Quickshell.Io
pragma Singleton
import QtQuick

Singleton {
    id: monitorState

    // ── Snapshot de pantallas: on-demand, no polling ────────────────────
    // Antes: Timer 3s 24/7 re-evaluando 4 bindings aunque ningún UI mirara.
    // Ahora: refresh() al abrir UI que muestra layout + auto ante
    // Quickshell.screensChanged (hotplug / wlr-randr).
    property int _tick: 0
    function refresh() { _tick++ }

    Connections {
        target: Quickshell
        function onScreensChanged() { monitorState.refresh() }
    }

    readonly property var _screens: {
        var _ = _tick
        return Quickshell.screens
    }

    readonly property bool hdmiConnected: {
        var s = _screens
        for (var i = 0; i < s.length; i++)
            if (s[i].name === "HDMI-A-1") return true
        return false
    }

    readonly property bool edpConnected: {
        var s = _screens
        for (var i = 0; i < s.length; i++)
            if (s[i].name === "eDP-1") return true
        return false
    }

    readonly property string activeLayout: {
        var hdmi = hdmiConnected
        var edp  = edpConnected
        if      ( edp && !hdmi) return "netbook"
        else if ( edp &&  hdmi) return "dual"
        else if (!edp &&  hdmi) return "monitor"
        return "netbook"
    }

    readonly property var monitorNames: {
        var s = _screens
        var names = []
        for (var i = 0; i < s.length; i++)
            names.push(s[i].name)
        return names
    }

    // ── Procesos ────────────────────────────────────────────────────
    property alias monitorsProc: monitorsProc
    property alias randrProc: randrProc
    property alias layoutSwitchProc: layoutSwitchProc

    // ── Listado de monitores via list-monitors (binario Go) ─────
    Process {
        id: monitorsProc
        property string _bin: ""
        command: [monitorsProc._bin]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                if (!line.trim()) return
                try {
                    var d = JSON.parse(line)
                    monitorState._monitors = d.monitors || []
                } catch(e) {}
            }
        }
        function load() {
            _bin = Qt.resolvedUrl("../bin/list-monitors").toString().replace("file://", "")
            running = true
        }
    }

    property var _monitors: []

    // Proceso genérico para comandos wlr-randr disparados desde settings.
    Process {
        id: shellCmd
        property string _cmd: "true"
        command: ["sh", "-c", shellCmd._cmd]
        running: false
        onRunningChanged: { if (!running) monitorsProc.load() }
    }
    property alias mirrorCmd: shellCmd
    property alias primaryCmd: shellCmd

    // ── Control de monitores via wlr-randr ──────────────────────────
    Process {
        id: randrProc
        property string _cmd: "true"
        property bool   _dragging: false
        command: ["sh", "-c", randrProc._cmd]
        running: false
        function setMode(name, mode) {
            _cmd = "wlr-randr --output '" + name.replace(/'/g, "'\\''") + "' --mode " + mode + " --on"
            running = true
        }
        function setPos(name, x, y) {
            _cmd = "wlr-randr --output '" + name.replace(/'/g, "'\\''") + "' --pos " + x + "," + y
            running = true
        }
        function toggleOutput(name, enable) {
            _cmd = "wlr-randr --output '" + name.replace(/'/g, "'\\''") + "' " + (enable ? "--on" : "--off")
            running = true
        }
        onRunningChanged: { if (!running && !randrProc._dragging) monitorsProc.load() }
    }

    // Construye el comando wlr-randr para hacer primaria una salida.
    function buildPrimaryCmd(monitors, targetName) {
        var active = (monitors || []).filter(function(m) { return m.enabled && m.current_mode })
        var thisName = targetName
        var thisW = 1920
        for (var i = 0; i < active.length; i++) {
            if (active[i].name === thisName && active[i].current_mode)
                thisW = active[i].current_mode.width
        }
        var others = active.filter(function(m) { return m.name !== thisName })
            .sort(function(a, b) {
                var ax = a.position ? a.position.x : 0
                var bx = b.position ? b.position.x : 0
                return ax - bx
            })
        var parts = []
        parts.push("--output '" + String(thisName).replace(/'/g, "'\\''") + "' --pos 0,0")
        var offsetX = thisW
        for (var j = 0; j < others.length; j++) {
            parts.push("--output '" + String(others[j].name).replace(/'/g, "'\\''") +
                       "' --pos " + offsetX + ",0")
            offsetX += others[j].current_mode ? others[j].current_mode.width : 1920
        }
        return "wlr-randr " + parts.join(" ")
    }

    // Construye el comando wlr-randr para modo espejo/extendido.
    function buildMirrorCmd(active, mirror) {
        var list = (active || []).slice()
        if (list.length < 2) return "true"
        if (mirror) {
            var minW = list[0].current_mode.width
            var minH = list[0].current_mode.height
            for (var i = 1; i < list.length; i++) {
                if (list[i].current_mode.width  < minW) minW = list[i].current_mode.width
                if (list[i].current_mode.height < minH) minH = list[i].current_mode.height
            }
            var parts = []
            for (var j = 0; j < list.length; j++) {
                var mon = list[j]
                var best = mon.current_mode
                for (var k = 0; k < mon.modes.length; k++) {
                    if (mon.modes[k].width === minW && mon.modes[k].height === minH) {
                        best = mon.modes[k]; break
                    }
                }
                parts.push("--output '" + String(mon.name).replace(/'/g, "'\\''") +
                           "' --mode " + best.width + "x" + best.height +
                           " --pos 0,0")
            }
            return "wlr-randr " + parts.join(" ")
        }
        var sorted = list.slice().sort(function(a, b) { return a.name < b.name ? -1 : 1 })
        var offsetX = 0
        var partsE = []
        for (var s = 0; s < sorted.length; s++) {
            partsE.push("--output '" + String(sorted[s].name).replace(/'/g, "'\\''") +
                        "' --pos " + offsetX + ",0")
            offsetX += sorted[s].current_mode.width
        }
        return "wlr-randr " + partsE.join(" ")
    }

    // ── Cambio rápido de layout (wlr-randr) ────────────────────────
    Process {
        id: layoutSwitchProc
        property string _cmd: "true"
        command: ["sh", "-c", _cmd]
        running: false
        function modeFor(output) {
            return SettingsState.outputModes[output] || ""
        }
        function apply(layout) {
            var edp  = modeFor("eDP-1")
            var hdmi = modeFor("HDMI-A-1")
            if      (layout === "netbook")
                _cmd = "wlr-randr --output eDP-1 --mode " + edp + " --pos 0,0 --on --output HDMI-A-1 --off"
            else if (layout === "dual")
                _cmd = "wlr-randr --output eDP-1 --mode " + edp + " --pos 0,0 --on --output HDMI-A-1 --mode " + hdmi + " --pos 1366,0 --on"
            else if (layout === "monitor")
                _cmd = "wlr-randr --output HDMI-A-1 --mode " + hdmi + " --pos 0,0 --on --output eDP-1 --off"
            else return
            running = true
        }
    }
}
