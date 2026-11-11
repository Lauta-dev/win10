// CalcIpc.qml — IPC handlers de la calculadora. Abrir/cerrar van al panel
// "calc" de PanelPopupHost (TaskbarState.openPanel/closePanel); el target
// `command-palette` también expone openCalc (keybinds, en AppMenuIpc).
import QtQuick
import Quickshell
import Quickshell.Io
import "../state"

Item {
    IpcHandler {
        target: "calc"
        function toggle(): string {
            if (TaskbarState.panel === "calc") {
                TaskbarState.closePanel("calc")
                return "closed"
            }
            TaskbarState.openPanel("calc")
            return "opened calc"
        }
        function open(): string {
            if (TaskbarState.panel === "calc") return "already open"
            TaskbarState.openPanel("calc")
            return "opened calc"
        }
        function close(): string {
            TaskbarState.closePanel("calc")
            return "ok"
        }
    }
}
