// ClipboardState.qml — Historial vía cliphist (watcher + list/decode/wipe).
// Ventana de 50: la vista muestra visibleResults (prefijo de lo filtrado)
// y pide más al acercarse al final (prefetchAt).
pragma Singleton
import Quickshell
import QtQuick

Singleton {
    // ── Estado ────────────────────────────────────────────────────────────────
    property var    entries:      []
    property string searchQuery:  ""
    property bool   loading:      false
    property bool   isOpen:       false

    readonly property var resultsFiltered: clipFilter.results

    // ── Ventana visible (paginación en memoria) ────────────────────────────────
    property int  visibleCount: 50
    readonly property int pageSize:   50
    readonly property int prefetchAt: 5
    property var  visibleResults: []
    property bool hasMore: false

    function _updateVisible() {
        var all = clipFilter.results || []
        visibleResults = all.slice(0, visibleCount)
        hasMore = visibleCount < all.length
    }

    function loadMore() {
        if (!hasMore) return
        visibleCount += pageSize
        _updateVisible()
    }

    onSearchQueryChanged: visibleCount = pageSize

    Connections {
        target: clipFilter
        function onResultsChanged() { ClipboardState._updateVisible() }
    }

    // ── Componentes internos ──────────────────────────────────────────────────
    ClipEntry { id: clipEntry }

    ClipFilter {
        id: clipFilter
        entries:     ClipboardState.entries
        searchQuery: ClipboardState.searchQuery
    }

    ClipProcesses {
        id: clipProcs
        clipEntry: clipEntry
        onEntriesLoaded: newEntries => { ClipboardState.entries = newEntries }
        onLoadingChanged: l => { ClipboardState.loading = l }
        onThumbsReady: thumbs => {
            var list = ClipboardState.entries
            var changed = false
            for (var i = 0; i < thumbs.length; i++) {
                for (var j = 0; j < list.length; j++) {
                    if (list[j] && list[j].id === thumbs[i].id && (list[j].raw ?? "") === "") {
                        list[j].raw = thumbs[i].file
                        changed = true
                        break
                    }
                }
            }
            if (changed) ClipboardState.entries = list.slice()
        }
        onWiped: {
            ClipboardState.entries = []
            ClipboardState.searchQuery = ""
        }

        Component.onCompleted: ensureRunning()
    }

    // ── Recargar (listado completo, ventana desde el inicio) ───────────────────
    function reload() {
        visibleCount = pageSize
        clipProcs.reload()
    }

    // ── Copiar entry (decode | wl-copy, pega y cierra) ────────────────────────
    function pasteClip(entry) {
        if (entry && entry.id !== undefined) clipProcs.copyEntry(entry.id)
        TaskbarState._hideLauncher()
    }

    // ── Borrar una entrada ────────────────────────────────────────────────────
    function deleteAt(index) {
        var entry = resultsFiltered[index]
        if (entry) clipProcs.deleteEntry(entry.id)
    }

    // ── Borrar historial ──────────────────────────────────────────────────────
    function wipe() { clipProcs.wipe() }

    // ── Activar fila (pega y cierra) ────────────────────────────────
    function activateAt(index) {
        var entry = resultsFiltered[index]
        if (entry) pasteClip(entry)
        else TaskbarState._hideLauncher()
    }
}
