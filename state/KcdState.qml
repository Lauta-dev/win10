// KcdState — Info del dispositivo Android vía kcd (KDE Connect daemon).
// Fuente: `kcd watch --json` (NDJSON en vivo). Al arrancar llega
// state.snapshot (lista completa) y después eventos device.connected /
// device.disconnected / battery.update (payload {charge, charging}).
//
// Ciclo: ControlCenterNew llama start() al abrir el panel y stop() al
// cerrar — el watcher no queda corriendo de fondo. Si el daemon no está,
// reintenta hasta _maxFails veces por sesión del panel.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Dispositivos por id: { id, name, type, charge, charging, connected }
    property var devices: ({})
    // Primario: primer dispositivo conectado (caso común: un teléfono).
    readonly property var device: {
        for (var id in devices)
            if (devices[id] && devices[id].connected) return devices[id]
        return null
    }
    readonly property bool connected: device !== null
    // Atajos del primario para la UI (nivel -1 = desconocido).
    readonly property int battery: device && device.charge !== undefined ? device.charge : -1
    readonly property bool charging: !!(device && device.charging)

    property bool _wanted: false
    property int _fails: 0
    readonly property int _maxFails: 5

    function start() {
        _wanted = true
        _fails = 0
        _spawn()
    }

    function stop() {
        _wanted = false
        watchProc.running = false
    }

    function _spawn() {
        if (!_wanted || watchProc.running) return
        watchProc.running = false
        watchProc.running = true
    }

    Timer {
        id: retryTimer
        interval: 4000; repeat: false
        onTriggered: root._spawn()
    }

    Process {
        id: watchProc
        command: ["kcd", "watch", "--json",
                  "--events=battery.update",
                  "--events=device.connected",
                  "--events=device.disconnected"]
        running: false
        stdout: SplitParser { onRead: line => root._onLine(line) }
        onExited: {
            if (!root._wanted) return
            root._fails++
            if (root._fails < root._maxFails) retryTimer.restart()
            else console.log("[KcdState] kcd watch falló", root._fails, "veces; sin reintento hasta reabrir el CC")
        }
    }

    function _onLine(line) {
        var t = String(line).trim()
        if (t === "") return
        var ev = null
        try { ev = JSON.parse(t) } catch (e) { return }
        if (!ev || !ev.type) return
        var id = ev.deviceId || (ev.payload && ev.payload.id) || ""

        if (ev.type === "state.snapshot") {
            // Reset completo con la lista actual del daemon.
            var out = {}
            var list = (ev.payload && ev.payload.devices) || []
            for (var i = 0; i < list.length; i++) {
                var dv = list[i] || {}
                if (!dv.id) continue
                out[dv.id] = {
                    id: dv.id,
                    name: dv.name || "",
                    type: dv.type || "",
                    connected: dv.connected === true,
                    charge: (dv.battery && dv.battery.charge !== undefined) ? dv.battery.charge : -1,
                    charging: !!(dv.battery && dv.battery.charging)
                }
            }
            root.devices = out
            root._fails = 0

        } else if (ev.type === "device.connected" || ev.type === "device.disconnected") {
            var cur = root.devices[id]
            if (!cur) {
                if (ev.type !== "device.connected") return
                cur = { id: id, name: "", type: "", charge: -1, charging: false }
            }
            var c = {}
            for (var k in root.devices) c[k] = root.devices[k]
            c[id] = {
                id: cur.id,
                name: (ev.payload && ev.payload.name) || cur.name,
                type: (ev.payload && ev.payload.type) || cur.type,
                connected: ev.type === "device.connected",
                charge: cur.charge,
                charging: cur.charging
            }
            root.devices = c

        } else if (ev.type === "battery.update" && root.devices[id]) {
            var b = ev.payload || {}
            var cur2 = root.devices[id]
            var c2 = {}
            for (var k2 in root.devices) c2[k2] = root.devices[k2]
            c2[id] = {
                id: cur2.id,
                name: cur2.name,
                type: cur2.type,
                connected: cur2.connected,
                charge: b.charge !== undefined ? b.charge : cur2.charge,
                charging: b.charging === true
            }
            root.devices = c2
        }
    }
}
