// BrightState.qml — Estado de brillo vía daemon Go (scripts/daemon bright).
//
// API pública intacta: brightness, setBrightness(v), syncBrightProc.
// Ciclo de vida LAZY: el daemon NO nace con la barra. El primer
// sendJson (slider, OSD, IPC, sync al abrir vista) lo levanta vía
// ensureStarted() y la outbox hace flush al estar listo. Solo se
// pierde el watcher pasivo de cambios externos antes del primer uso
// (despreciable: toda vía de control pasa por acá).
pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: brightState

    property int brightness: 80
    property bool available: BrightConnection.available

    // Compat: DisplayView/ControlCenterNew hacen `syncBrightProc.running = true`.
    // Ahora solo dispara un `get` al daemon.
    property alias syncBrightProc: syncStub

    QtObject {
        id: syncStub
        property bool running: false
        onRunningChanged: {
            if (running) {
                running = false
                brightState.sync()
            }
        }
    }

    function sync() {
        BrightConnection.sendJson("get", {}, function(ev) {
            if (ev && ev.ok && ev.value !== undefined) brightState.brightness = ev.value
        })
    }

    // ── Anti-salto durante el drag ────────────────────────────────────
    // El slider emite changeRequested por cada píxel arrastrado. Mandar un
    // `brightnessctl` por tick encola forks en el daemon y las
    // confirmaciones llegan tarde (con redondeo ±1 del hardware) pisando
    // el valor bajo el dedo. Esquema: optimista inmediato en UI + envío
    // con leading + trailing (máx ~1 fork cada 70ms) + confirmaciones
    // rancias ignoradas mientras el usuario está activo.
    property int _pending: -1
    property double _lastLocalChange: 0

    property Timer _sendTimer: Timer {
        interval: 70
        repeat: false
        onTriggered: {
            if (brightState._pending >= 0) {
                brightState._push(brightState._pending)
                brightState._pending = -1
            }
        }
    }

    function _push(target) {
        BrightConnection.sendJson("set", {value: target}, function(ev) {
            // Confirmación: solo corregir si difiere de verdad (>1 por
            // redondeo) y el usuario no está arrastrando ahora mismo.
            if (ev && ev.ok && ev.value !== undefined
                    && Math.abs(ev.value - brightState.brightness) > 1
                    && Date.now() - brightState._lastLocalChange > 400)
                brightState.brightness = ev.value
        })
    }

    function setBrightness(v) {
        var target = Math.max(0, Math.min(100, Math.round(v)))
        if (target === brightness && _pending < 0) return
        brightness = target
        _lastLocalChange = Date.now()
        if (!_sendTimer.running) {
            _push(target)
            _sendTimer.restart()
        } else {
            _pending = target
        }
    }

    Connections {
        target: BrightConnection
        function onDaemonEvent(ev) {
            if (!ev) return
            if ((ev.type === "bright" || ev.type === "ready") && ev.ok && ev.value !== undefined
                    && ev.value !== brightState.brightness) {
                // Push del watcher justo después de un set local: es el eco
                // de nuestro propio cambio (o redondeo ±1) → no pisar el drag.
                if (Date.now() - brightState._lastLocalChange < 900
                        && Math.abs(ev.value - brightState.brightness) <= 2) return
                brightState.brightness = ev.value
            }
        }
    }

    // Sin onCompleted: el daemon arranca al primer uso (C8).
    // DisplayView/ControlCenterNew piden sync() al abrir su vista.
}
