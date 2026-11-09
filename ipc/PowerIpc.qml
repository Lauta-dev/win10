import QtQuick
import Quickshell
import Quickshell.Io
import "../state"

// PowerIpc — powermenu OSD por CLI/teclas. La ejecución vive en
// TaskbarState (procesos persistentes).
//
//   qs ipc call power toggle   # muestra/oculta el OSD
//   qs ipc call power logout   # cierra sesión directo
//   qs ipc call power reboot   # reinicia directo
//   qs ipc call power off      # apaga directo
Item {
    IpcHandler {
        target: "power"

        function toggle(): string {
            return TaskbarState.togglePowerMenu() ? "shown" : "hidden"
        }

        function logout(): string {
            return TaskbarState.runPower("logout")
        }

        function reboot(): string {
            return TaskbarState.runPower("reboot")
        }

        function off(): string {
            return TaskbarState.runPower("off")
        }
    }
}
