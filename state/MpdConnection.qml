pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// MpdConnection — Bridge al daemon Go (scripts/daemon mpd run, modo full).
//
// El socket MPD lo posee el daemon (dial/close deterministas en Go con
// backoff, doble conexión cmd+idle); QML solo habla NDJSON con un Process:
// request/response ({type:"raw"} matcheado por id) + eventos push
// ({type:"status"|"song"|"queue"|"playlists"} por idle de MPD) que se
// reenvían tal cual vía daemonEvent para UI inmediata sin re-entrar.
// Ciclo de vida ATADO AL POPUP, explícito: cada entrada al modo mpd
// levanta el Process con debounce de 50ms (pollingActive=true) y al salir
// se programa su muerte a 100ms — recién cuando el popup quedó cerrado del
// todo (cubre fade de cierre y re-aperturas inmediatas como el toggle de
// MpdIpc). Proceso fresco por entrada: imposible acuñar reconexiones (el
// bug del Socket QML reutilizado, que tras el primer fallo tragaba todos
// los `connected = true` y solo revivía reiniciando el shell).
Singleton {
    id: root

    readonly property string socketPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000") + "/mpd/socket"
    readonly property bool connected: _ready

    // El bridge lo comparten Hub (tab Música) y MusicPopup (cola al cambiar
    // a MPD): se pide por consumidor para que cerrar uno no apague la
    // conexión del otro. Activo mientras cualquiera lo necesite.
    property var _consumers: ({})
    readonly property bool pollingActive: _consumers["hub"] === true
        || _consumers["music"] === true

    function setPollingConsumer(id, active) {
        if ((_consumers[id] === true) === active) return
        var c = {}
        for (var k in _consumers) c[k] = _consumers[k]
        c[id] = active
        _consumers = c
    }

    signal daemonEvent(var ev)

    property bool _ready: false
    property bool _tearingDown: false
    property int _backoffMs: 300
    property var _queue: []
    property var _pending: null

    property var pending: _queue
    property bool cmdReady: _ready

    property int _nextId: 1
    property var _cbs: ({})
    property var _outbox: []
    // Tope de reintentos como BrightConnection: si el daemon muere 5
    // veces seguidas se deja de revivir hasta la próxima entrada.
    property int _failCount: 0
    readonly property int _maxFails: 5

    function sendCommand(cmd, callback) {
        var id = _nextId++
        _cbs[id] = {kind: "raw", cb: callback || function(){}}
        if (!pollingActive) {
            var e0 = _cbs[id]; delete _cbs[id]
            try { e0.cb([], true, "ACK [0@0] {offline} polling inactive") } catch(e) {}
            return
        }
        attemptConnect()
        var line = JSON.stringify({id: id, cmd: "raw", args: {line: cmd}})
        if (daemonProc.running) {
            daemonProc.write(line + "\n")
        } else if (_outbox.length < 50) {
            _outbox.push(line)
        }
    }

    // Comando tipado al daemon (search/artists/albums/playlists/queue/
    // syncdb/add/addplay/playplaylist/...): el cb recibe el evento objeto
    // ({type, ok, names/items/..., error}). Sin cb = fire-and-forget.
    function sendJson(cmd, args, callback) {
        var id = _nextId++
        if (callback) _cbs[id] = {kind: "json", cb: callback}
        if (!pollingActive) {
            delete _cbs[id]
            if (callback) try { callback({type: "error", id: id, ok: false, error: "polling inactive"}) } catch(e) {}
            return
        }
        attemptConnect()
        var line = JSON.stringify({id: id, cmd: cmd, args: args || {}})
        if (daemonProc.running) {
            daemonProc.write(line + "\n")
        } else if (_outbox.length < 50) {
            _outbox.push(line)
        }
    }

    function sendList(cmds, callback) {
        if (!cmds || cmds.length === 0) { if (callback) callback([], false, ""); return }
        sendCommand(cmds.join("\n"), callback)
    }

    function ensureConnected() {
        if (!_ready) attemptConnect()
    }

    function attemptConnect() {
        if (!pollingActive || _ready) return
        if (daemonProc.running) return
        // Debounce 50ms: si se cierra antes, el daemon ni nace.
        startDelay.restart()
    }

    function forceReconnect() {
        reconnect()
    }

    function reconnect() {
        _tearingDown = true
        _ready = false
        _failPending("reconnect")
        if (daemonProc.running) daemonProc.running = false
        _tearingDown = false
        _backoffMs = 300
        if (pollingActive) Qt.callLater(function() {
            if (pollingActive && !_ready && !daemonProc.running) daemonProc.running = true
        })
    }

    function _failPending(reason) {
        var stale = _cbs; _cbs = {}
        _outbox = []
        _queue = []; _pending = null
        for (var k in stale) {
            var e = stale[k]
            try {
                if (e.kind === "json") e.cb({type: "error", ok: false, error: reason})
                else e.cb([], true, "ACK [0@0] {reconnect} " + reason)
            } catch(err) {}
        }
    }

    function _flushOutbox() {
        while (_outbox.length > 0 && daemonProc.running) daemonProc.write(_outbox.shift() + "\n")
    }

    function _onDaemonLine(data) {
        var line = String(data).trim()
        if (line === "") return
        var ev = null
        try { ev = JSON.parse(line) } catch(e) { return }
        if (!ev || !ev.type) return
        if (ev.type === "conn") {
            if (!pollingActive) return
            if (ev.connected && !_ready) { _ready = true }
            else if (!ev.connected && _ready) { _ready = false }
            return
        }
        // Respuesta con id: entregar al dueño (raw o json).
        if (ev.id !== undefined && ev.id !== null && _cbs[ev.id] !== undefined) {
            var entry = _cbs[ev.id]; delete _cbs[ev.id]
            if (entry.kind === "json") {
                try { entry.cb(ev) } catch(e) {}
                return
            }
            if (ev.type !== "raw") return // ack de un raw: ya entregado, ignorar
        }
        if (ev.type !== "raw") {
            // Eventos push del daemon (idle de MPD): reenviar a MpdState
            // para UI inmediata sin salir/entrar. El resto se ignora.
            if (ev.type === "status" || ev.type === "song" || ev.type === "queue" || ev.type === "playlists")
                root.daemonEvent(ev)
            return
        }
        var cb = _cbs[ev.id]
        if (cb === undefined || cb.kind !== "raw") return
        delete _cbs[ev.id]
        var ok = ev.ok === true
        if (ok) { if (pollingActive && !_ready) _ready = true }
        else if (!ev.ack) { if (_ready) _ready = false } // fallo de transporte (no ACK de MPD)
        try { cb.cb(ev.lines || [], !ok, ev.ack || ev.error || "") } catch(e) {}
    }

    onPollingActiveChanged: {
        if (pollingActive) {
            stopDelay.stop()
            restartDelay.stop()
            _backoffMs = 300
            _failCount = 0
            attemptConnect()
        } else {
            // MUERTE diferida 100ms: recién cuando el popup quedó cerrado
            // del todo (cubre fade de cierre y re-aperturas inmediatas).
            // Si se vuelve a entrar antes, se cancela y no pasa nada.
            startDelay.stop()
            stopDelay.restart()
        }
    }

    Timer { id: startDelay; interval: 50; repeat: false; onTriggered: {
        if (root.pollingActive && !root._ready && !daemonProc.running) daemonProc.running = true
    }}

    Timer { id: stopDelay; interval: 100; repeat: false; onTriggered: {
        if (root.pollingActive) return
        root._tearingDown = true
        root._failPending("polling stopped")
        root._ready = false
        if (daemonProc.running) daemonProc.running = false
        root._tearingDown = false
    }}

    Timer { id: restartDelay; interval: 500; repeat: false; onTriggered: {
        if (root.pollingActive && !root._ready && !daemonProc.running && root._failCount < root._maxFails) daemonProc.running = true
    }}

    Process {
        id: daemonProc
        stdinEnabled: true
        command: {
            var bin = Qt.resolvedUrl("../bin/daemon").toString().replace("file://", "")
            return [bin, "mpd", "run"]
        }
        running: false
        stdout: SplitParser { onRead: function(data) { root._onDaemonLine(data) } }
        onRunningChanged: {
            if (running) {
                root._flushOutbox()
            } else {
                root._ready = false
                root._failPending("daemon exited")
                if (root.pollingActive && !root._tearingDown) {
                    root._failCount++
                    if (root._failCount < root._maxFails) restartDelay.restart()
                    else console.log("[MpdConnection] daemon murió", root._failCount, "veces, no se revive hasta próxima entrada")
                }
            }
        }
    }

    Component.onCompleted: { }
}
