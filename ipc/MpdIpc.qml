// MpdIpc.qml — IPC handlers para MPD. Abrir/cerrar van al tab Música del
// HubPopup (lazy vía activePopup="hub"); controles directo a MpdState.
import QtQuick
import Quickshell
import Quickshell.Io
import "../state"

Item {
    IpcHandler {
        target: "mpd"
        function toggle(): string {
            if (TaskbarState.activePopup === "hub" && TaskbarState.hubTab === TaskbarState.hubTabMpd) {
                TaskbarState.activePopup = ""
                return "closed"
            }
            TaskbarState.hubTab = TaskbarState.hubTabMpd
            TaskbarState.activePopup = "hub"
            return "opened mpd"
        }
        function open(): string {
            if (TaskbarState.activePopup === "hub" && TaskbarState.hubTab === TaskbarState.hubTabMpd) return "already open"
            TaskbarState.hubTab = TaskbarState.hubTabMpd
            TaskbarState.activePopup = "hub"
            return "opened mpd"
        }
        function close(): string {
            if (TaskbarState.activePopup === "hub")
                TaskbarState.activePopup = ""
            return "ok"
        }
        function play()        { MpdState.play(); return "ok" }
        function pause()       { MpdState.pause(); return "ok" }
        function togglePause() { MpdState.togglePause(); return "ok" }
        function next()        { MpdState.next(); return "ok" }
        function prev()        { MpdState.previous(); return "ok" }
        function stop()        { MpdState.stop(); return "ok" }
        function seek(pos: int)     { MpdState.seek(pos); return "ok" }
        function seekOffset(off: int) { MpdState.seekOffset(off); return "ok" }
        function volume(level: int) { MpdState.setVolume(level); return "ok" }
    }
}
