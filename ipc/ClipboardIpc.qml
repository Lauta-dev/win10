// ClipboardIpc.qml — IPC handlers del portapapeles.
import QtQuick
import Quickshell
import Quickshell.Io
import "../state"

Item {
    id: root
    IpcHandler {
        target: "clipboard"

        function toggle(): string {
            if (TaskbarState.clipOpen) {
                TaskbarState._hideLauncher()
                return "closed"
            }
            TaskbarState._showLauncher("clip")
            return "opened clipboard"
        }

        function open(): string {
            TaskbarState._showLauncher("clip")
            return "opened clipboard"
        }

        function close(): string {
            if (TaskbarState.clipOpen)
                TaskbarState._hideLauncher()
            return "closed"
        }
    }
}
