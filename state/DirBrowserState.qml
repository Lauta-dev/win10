// DirBrowserState.qml — Listado de directorios/archivos para DirBrowser.
// Centraliza el Process (list-dirs) fuera de la UI.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string _path: ""
    property string _mode: "directories"
    property bool _showHidden: false
    property string _buf: ""

    property var lastEntries: []
    property string lastPath: ""

    signal loaded(string path, var entries)

    Process {
        id: proc
        property string _bin: ""
        command: {
            var args = [proc._bin, root._path, "--mode", root._mode]
            if (root._showHidden) args.push("--show-hidden")
            return args
        }
        running: false
        stdout: SplitParser { onRead: (line) => { root._buf += line } }
        onRunningChanged: {
            if (!running && root._buf !== "") {
                try {
                    var data = JSON.parse(root._buf)
                    root.lastEntries = data.entries
                    root.lastPath = data.path
                    root.loaded(data.path, data.entries)
                } catch (e) {}
                root._buf = ""
            }
        }
        function listDir(path, mode, showHidden) {
            root._path = path
            root._mode = mode || "directories"
            root._showHidden = !!showHidden
            root._buf = ""
            if (proc._bin === "") proc._bin = Qt.resolvedUrl("../scripts/list-dirs").toString().replace("file://", "")
            running = false
            running = true
        }
    }

    function listDir(path, mode, showHidden) {
        proc.listDir(path, mode, showHidden)
    }
}