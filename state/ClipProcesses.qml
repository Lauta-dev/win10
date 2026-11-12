// ClipProcesses.qml — I/O del clipboard vía cliphist CLI, sin daemon propio.
//
// Un watcher persistente (`wl-paste --watch cliphist store`, hijo del
// shell) mantiene la DB fresca; las operaciones son one-shot:
// reload (cliphist list), copy (decode | wl-copy), delete y wipe.
// La copia va directo por pipe sin pasar bytes por QML (vale para
// texto e imágenes).
//
// Thumbnails: las imágenes binarias (`[[ binary data … ]]`, sin path)
// se decodifican en un solo batch a /tmp/quickshell-clipboard/<id>.png;
// al terminar se emite thumbsReady([{id, file}]) para
// que el delegate muestre el banner. /tmp se limpia al reiniciar y el
// guard [ ! -f ] evita re-decodificar.
//
// Uso:
//   ClipProcesses {
//       id: procs
//       clipEntry: clipEntry          // instancia de ClipEntry para parsear
//       onEntriesLoaded: entries => { root.entries = entries }
//       onLoadingChanged: v => { root.loading = v }
//       onWiped: { root.entries = []; root.searchQuery = "" }
//   }

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // ── Configuración ─────────────────────────────────────────────────────────
    // Referencia a ClipEntry para parsear cada línea del listado.
    property var clipEntry: null

    // ── Señales ───────────────────────────────────────────────────────────────
    signal entriesLoaded(var entries)
    signal loadingChanged(bool loading)
    signal wiped()
    signal thumbsReady(var thumbs)

    function ensureRunning() {
        if (!watchProc.running) watchProc.running = true
    }

    // ── API pública ───────────────────────────────────────────────────────────
    function reload() {
        _lines = []
        loadingChanged(true)
        listProc.running = false
        listProc.running = true
    }

    function copyEntry(id) {
        var nid = parseInt(id, 10)
        if (isNaN(nid)) return
        Quickshell.execDetached(["sh", "-c", "cliphist decode " + nid + " | wl-copy"])
    }

    function deleteEntry(id) {
        var nid = parseInt(id, 10)
        if (isNaN(nid)) return
        Quickshell.execDetached(["rm", "-f", _thumbDir + "/" + nid + ".png"])
        delProc.run(nid)
    }

    function wipe() {
        Quickshell.execDetached(["rm", "-rf", _thumbDir])
        wipeProc.running = false
        wipeProc.running = true
    }

    // ── Listado one-shot ──────────────────────────────────────────────────────
    property var _lines: []

    property var listProc: Process {
        command: ["cliphist", "list"]
        running: false
        stdout: SplitParser { onRead: data => root._lines.push(String(data)) }
        stderr: SplitParser { onRead: data => { root._listErr += data + "\n" } }
        onExited: {
            var out = []
            if (root.clipEntry) {
                for (var i = 0; i < root._lines.length; i++) {
                    var obj = root.clipEntry.parse(root._lines[i])
                    if (obj) out.push(obj)
                }
            }
            root._lines = []
            root.entriesLoaded(out)
            root.loadingChanged(false)
            root._queueThumbs(out)
        }
    }
    property string _listErr: ""

    // ── Borrado unitario one-shot (recarga al terminar) ───────────────────────
    property var delProc: Process {
        property int _id: -1
        command: ["cliphist", "delete", String(_id)]
        running: false
        onExited: root.reload()
        // Process estático con run(): evita que command sea reactivo.
        function run(id) {
            var nid = parseInt(id, 10)
            if (isNaN(nid)) return
            _id = nid
            running = false
            running = true
        }
    }

    // ── Wipe one-shot ─────────────────────────────────────────────────────────
    property var wipeProc: Process {
        command: ["cliphist", "wipe"]
        running: false
        onExited: root.wiped()
    }

    // ── Thumbnails de imágenes binarias (un solo batch) ───────────────────
    // Decode a .tmp + mv: el .png final solo existe si está completo.
    readonly property string _thumbDir: "/tmp/quickshell-clipboard"

    function _queueThumbs(out) {
        var ids = []
        for (var i = 0; i < out.length; i++) {
            var e = out[i]
            if (e && e.isImage === true && (e.raw ?? "") === "")
                ids.push(e.id)
        }
        if (ids.length === 0) return
        var cmd = "mkdir -p \"" + _thumbDir + "\""
        for (var j = 0; j < ids.length; j++)
            cmd += "; f=\"" + _thumbDir + "/" + ids[j] + ".png\"; if [ ! -f \"$f\" ]; then cliphist decode " + ids[j] + " > \"$f.tmp\" && mv \"$f.tmp\" \"$f\" || rm -f \"$f.tmp\"; fi"
        thumbBatchProc.run(cmd, ids)
    }

    property var thumbBatchProc: Process {
        property string _cmd: ""
        property var _ids: []
        command: ["bash", "-c", _cmd]
        running: false
        onExited: function(code) {
            if (code === 0) {
                var out = []
                for (var i = 0; i < _ids.length; i++)
                    out.push({ id: _ids[i], file: root._thumbDir + "/" + _ids[i] + ".png" })
                root.thumbsReady(out)
            }
            _ids = []
        }
        // Process estático con run(): evita que command sea reactivo.
        function run(cmd, ids) {
            if (!cmd || !ids || ids.length === 0) return
            _cmd = cmd
            _ids = ids
            running = false
            running = true
        }
    }

    // ── Watcher persistente (hijo del shell) ──────────────────────────────────
    property string _watchErr: ""
    property int _watchFails: 0

    property Timer _watchRetry: Timer {
        interval: 2000
        onTriggered: {
            if (!watchProc.running && root._watchFails < 10) {
                root._watchFails++
                watchProc.running = true
            }
        }
    }

    property var watchProc: Process {
        command: ["wl-paste", "--watch", "cliphist", "store"]
        running: false
        stderr: SplitParser { onRead: data => { root._watchErr += data + "\n" } }
        onExited: function(code) {
            // Salida limpia al morir el shell: no reintentar.
            if (code === 0) return
            if (root._watchFails < 10) {
                root._watchFails++
                root._watchRetry.restart()
            } else {
                console.warn("clipboard: watcher muriendo, no se reintenta:", root._watchErr.trim())
            }
        }
        onRunningChanged: {
            if (running) {
                root._watchErr = ""
                root._watchFails = 0
            }
        }
    }
}
