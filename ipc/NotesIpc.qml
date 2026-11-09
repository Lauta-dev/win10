// NotesIpc.qml — IPC handler para el sidebar de notas.
import QtQuick
import Quickshell
import Quickshell.Io
import "../state"

Item {
    IpcHandler {
        target: "notes"
        function toggle() { TaskbarState.showNotesSidebar = !TaskbarState.showNotesSidebar }
        function open()   { TaskbarState.showNotesSidebar = true }
        function close()  { TaskbarState.showNotesSidebar = false }
    }
}
