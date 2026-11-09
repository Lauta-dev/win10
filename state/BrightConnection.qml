// BrightConnection.qml — Bridge al daemon Go (scripts/daemon bright run).
//
// QML solo habla NDJSON por un Process persistente: request/response
// ({type:"bright"} matcheado por id) + acks + empujones del watcher
// ({"type":"bright"} sin id por cambios externos: teclas Fn, etc.).
// Ciclo de vida LAZY: el daemon arranca al primer sendJson
// (ensureStarted + outbox con flush al estar listo) y vive hasta que
// el shell muera. Si muere inesperado se reintenta (tope 5).
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property bool ready: _ready
    readonly property bool available: _available

    signal daemonEvent(var ev)

    property bool _ready: false
    property bool _available: true
    property int _nextId: 1
    property var _cbs: ({})
    property var _outbox: []
    property string _bridgeErr: ""
    property int _failCount: 0

    // Comando tipado al daemon (get/set/inc/dec/ping): el cb recibe el
    // evento objeto ({type, ok, value/error}). Sin cb = fire-and-forget.
    function sendJson(cmd, args, callback) {
        var id = _nextId++
        if (callback) _cbs[id] = callback
        ensureStarted()
        var line = JSON.stringify({id: id, cmd: cmd, args: args || {}})
        if (daemonProc.running) {
            daemonProc.write(line + "\n")
        } else {
            _outbox.push(line)
        }
    }

    function ensureStarted() {
        if (!_available) return
        if (daemonProc.running) return
        daemonProc.running = true
    }

    function _failPending(reason) {
        var stale = _cbs; _cbs = {}
        _outbox = []
        for (var k in stale) {
            try { stale[k]({type: "error", ok: false, error: reason}) } catch(e) {}
        }
    }

    function _onBridgeLine(data) {
        var ev = null
        try { ev = JSON.parse(String(data).trim()) } catch(e) { return }
        if (!ev || !ev.type) return
        if (ev.type === "ready") {
            root._ready = true
            root._available = true
            root.daemonEvent(ev)
            return
        }
        if (ev.type === "bright" && (ev.id === undefined || ev.id === null)) {
            root.daemonEvent(ev)
            return
        }
        if (ev.id === undefined || ev.id === null) return
        var cb = _cbs[ev.id]
        if (cb !== undefined) {
            delete _cbs[ev.id]
            try { cb(ev) } catch(e) {}
        }
        if (ev.type === "bright") root.daemonEvent(ev)
        // El ack que sigue al tipado llega sin cb pendiente: se ignora.
    }

    property Timer _restartTimer: Timer {
        interval: 1000
        onTriggered: {
            if (!daemonProc.running && root._available && root._failCount < 5) {
                root._failCount++
                daemonProc.running = true
            }
        }
    }

    property var daemonProc: Process {
        stdinEnabled: true
        running: false
        command: {
            var bin = Qt.resolvedUrl("../bin/daemon").toString().replace("file://", "")
            return [bin, "bright", "run"]
        }
        stdout: SplitParser { onRead: function(data) { root._onBridgeLine(data) } }
        stderr: SplitParser { onRead: function(data) { root._bridgeErr += data + "\n" } }
        onExited: {
            root._ready = false
            var code = arguments[0]
            var hadPending = false
            for (var k in root._cbs) { hadPending = true; break }
            root._failPending("bridge detenido")
            // Sin backlight el daemon sale con código 2 a propósito:
            // no reintentar, solo marcar no disponible.
            if (code === 2) {
                root._available = false
                return
            }
            if (code !== 0 && hadPending && root._failCount < 5) root._restartTimer.restart()
            else if (root._failCount >= 5) console.warn("bright: bridge muriendo, no se reintenta:", root._bridgeErr.trim())
        }
        onRunningChanged: {
            if (running) {
                root._bridgeErr = ""
                root._failCount = 0
                while (_outbox.length > 0) daemonProc.write(_outbox.shift() + "\n")
            } else {
                root._ready = false
                root._failPending("bridge detenido")
            }
        }
    }
}
