// MpdIpc.qml — IPC handlers para MPD. Abrir/cerrar van al panel "mpd" de
// PanelPopupHost (TaskbarState.openPanel/closePanel); controles directo a
// MpdState.
import QtQuick
import Quickshell
import Quickshell.Io
import "../state"

Item {
    IpcHandler {
        target: "mpd"
        function toggle(): string {
            if (TaskbarState.panel === "mpd") {
                TaskbarState.closePanel("mpd")
                return "closed"
            }
            TaskbarState.openPanel("mpd")
            return "opened mpd"
        }
        function open(): string {
            if (TaskbarState.panel === "mpd") return "already open"
            TaskbarState.openPanel("mpd")
            return "opened mpd"
        }
        function close(): string {
            TaskbarState.closePanel("mpd")
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
