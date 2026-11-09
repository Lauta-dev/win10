pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// NotesState — una sola nota con autoguardado (bloc simple).
// La UI edita content; cada cambio se escribe a notes.txt.
// El eco de la escritura propia se ignora para no pisar lo tipeado.
Singleton {
    id: root

    property string content: ""

    // Escritura propia: su eco (watch) se ignora para no reasignar
    // content con el texto viejo y comer/mover lo recién tipeado.
    property bool _ownWrite: false

    Process {
        id: mkdirProc
        command: ["mkdir", "-p", Quickshell.env("HOME") + "/.cache/qs7"]
        running: true
        onExited: fileView.reload()
    }

    FileView {
        id: fileView
        path: Quickshell.env("HOME") + "/.cache/qs7/notes.txt"
        watchChanges: true
        onFileChanged: { if (root._ownWrite) { root._ownWrite = false; return } reload() }
        onLoaded: function() {
            if (root._ownWrite) { root._ownWrite = false; return }
            var t = fileView.text()
            if (t !== root.content) root.content = t
        }
    }

    onContentChanged: function() {
        if (fileView.loaded) {
            root._ownWrite = true
            fileView.setText(root.content)
        }
    }
}
