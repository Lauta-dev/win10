// KeybindsState.qml — Atajos de labwc para el panel "keybinds".
// Corre bin/keybinds (Go one-shot) que parsea ~/.config/labwc/rc.xml y
// devuelve secciones con labels ya interpretadas. El popup llama reload()
// cada vez que entra; acá vive el Process (la UI no accede al sistema
// directo). El resultado queda cacheado hasta el próximo reload.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // [{title, rows:[{desc, keys, raw}]}] — orden canónico del binario
    property var sections: []
    property bool loading: false
    property bool failed: false

    function reload() {
        if (proc.running) return
        root.loading = true
        root.failed = false
        proc._buf = ""
        if (proc._bin === "") proc._bin = Qt.resolvedUrl("../bin/keybinds").toString().replace("file://", "")
        proc.running = true
    }

    Process {
        id: proc
        property string _bin: ""
        property string _buf: ""
        command: [proc._bin]
        running: false
        stdout: SplitParser { onRead: (line) => { proc._buf += line } }
        stderr: SplitParser { onRead: (line) => { console.warn("keybinds:", line) } }
        onRunningChanged: {
            if (running) return
            root.loading = false
            if (proc._buf === "") {
                root.failed = root.sections.length === 0
                return
            }
            try {
                var data = JSON.parse(proc._buf)
                root.sections = data.sections || []
                root.failed = root.sections.length === 0
            } catch (e) {
                console.warn("keybinds: JSON inválido:", e)
                root.failed = true
            }
            proc._buf = ""
        }
    }
}
