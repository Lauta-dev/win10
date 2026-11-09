// AppMenuIpc.qml — IPC handlers del lanzador de apps.
// El target `command-palette` se conserva por compatibilidad con los: ahora abre el AppMenu en vez de la paleta.
import QtQuick
import Quickshell
import Quickshell.Io
import "../state"

Item {
    id: root
    function _toggleApp() {
        if (TaskbarState.appOpen) TaskbarState._hideLauncher()
        else TaskbarState._showLauncher("app")
    }
    IpcHandler {
        target: "command-palette"
        function toggle()      { root._toggleApp() }
        function open()        { TaskbarState._showLauncher("app") }
        function close()       { TaskbarState._hideLauncher() }
        function openClipboard() { TaskbarState._showLauncher("clip") }
        function openStartmenu() { root._toggleApp() }
        // Hub (Música/Calc/Claves): un popup con tabs.
        function openMpd(): string {
            if (TaskbarState.activePopup === "hub" && TaskbarState.hubTab === TaskbarState.hubTabMpd) {
                TaskbarState.activePopup = ""
                return "closed"
            }
            TaskbarState._hideLauncher()
            TaskbarState.hubTab = TaskbarState.hubTabMpd
            TaskbarState.activePopup = "hub"
            return "opened mpd"
        }
        function openMusic(): string { return openMpd() }
        function openCalc(): string {
            if (TaskbarState.activePopup === "hub" && TaskbarState.hubTab === TaskbarState.hubTabCalc) {
                TaskbarState.activePopup = ""
                return "closed"
            }
            TaskbarState._hideLauncher()
            TaskbarState.hubTab = TaskbarState.hubTabCalc
            TaskbarState.activePopup = "hub"
            return "opened calc"
        }
        function openCalculator(): string { return openCalc() }
        function openKeepass(): string {
            if (TaskbarState.activePopup === "hub" && TaskbarState.hubTab === TaskbarState.hubTabKeepass) {
                TaskbarState.activePopup = ""
                return "closed"
            }
            TaskbarState._hideLauncher()
            TaskbarState.hubTab = TaskbarState.hubTabKeepass
            TaskbarState.activePopup = "hub"
            return "opened keepass"
        }
        function openPasswords(): string { return openKeepass() }
    }
}
