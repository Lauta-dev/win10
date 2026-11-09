import QtQuick
import Quickshell
import Quickshell.Io
import "../state"

// BrightIpc — control de brillo por CLI/teclas.
//
//   qs ipc call bright adjust +10   # sube 10
//   qs ipc call bright adjust -10   # baja 10 (entre comillas si el parser lo toma como flag)
Item {
    id: root

    function _apply(v): string {
        var nv = Math.max(0, Math.min(100, Math.round(v)))
        BrightState.setBrightness(nv)
        TaskbarState._showOsd("bright")
        return nv.toString()
    }

    IpcHandler {
        target: "bright"

        function adjust(delta: int): string {
            return root._apply(BrightState.brightness + delta)
        }
    }
}
