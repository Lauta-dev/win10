// KeybindsIpc.qml — IPC handlers de la hoja de atajos de labwc. Abrir/cerrar
// van al panel "keybinds" de PanelPopupHost (TaskbarState.openPanel/closePanel);
// el target `command-palette` también expone openKeybinds (AppMenuIpc).
import QtQuick
import Quickshell
import Quickshell.Io
import "../state"

Item {
    IpcHandler {
        target: "keybinds"
        function toggle(): string {
            if (TaskbarState.panel === "keybinds") {
                TaskbarState.closePanel("keybinds")
                return "closed"
            }
            TaskbarState.openPanel("keybinds")
            return "opened keybinds"
        }
        function open(): string {
            if (TaskbarState.panel === "keybinds") return "already open"
            TaskbarState.openPanel("keybinds")
            return "opened keybinds"
        }
        function close(): string {
            TaskbarState.closePanel("keybinds")
            return "ok"
        }
    }
}
