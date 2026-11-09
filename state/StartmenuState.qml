// StartmenuState.qml — Lógica del modo startmenu del Command Palette.
// Apps con recientes primero, comandos (">b", ">ia", ">sf") y launch.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

import "../logic/startmenu.js" as StartmenuLogic
Singleton {
    // ── Estado ────────────────────────────────────────────────────────────────
    property var    allApps:      DesktopEntries.applications.values
    property var    filteredApps: []
    property string pendingFilter: ""
    property int    _filterGen:   0
    property int    _lastAppliedGen: -1
    property var    _pinnedCache: {}
    property var    _recentSet: {}

    // ── Timer debounce ────────────────────────────────────────────────────────
    Timer {
        id: filterDebounce
        interval: 50
        repeat: false
        onTriggered: StartmenuState.filterApps(StartmenuState.pendingFilter)
    }

    function applyPendingFilter() {
        filterDebounce.restart()
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    function toAppObject(entry) {
        if (!entry) return null
        return {
            id: entry.id,
            name: entry.name,
            comment: entry.comment || "",
            icon: entry.icon || "",
            categories: entry.categories || [],
            execString: entry.execString,
            noDisplay: entry.noDisplay
        }
    }

    function isPinnedCached(appId) {
        if (!appId || appId === "") return false
        if (!_pinnedCache) _pinnedCache = {}
        var key = _filterGen + "\u0000" + appId
        if (_pinnedCache[key] !== undefined) return _pinnedCache[key]
        var pinned = TaskbarState.isPinned(appId)
        if (!pinned) {
            for (var i = 0; i < TaskbarState.pinnedApps.length; i++)
                if (AppLaunchState._matches(TaskbarState.pinnedApps[i], appId)) { pinned = true; break }
        }
        _pinnedCache[key] = pinned
        return pinned
    }

    function isRecentCached(exec) {
        if (!exec) return false
        if (!_recentSet) _recentSet = {}
        return _recentSet[exec] === true
    }

    function enrichApp(a) {
        var obj = toAppObject(a)
        obj.isPinned = isPinnedCached(a.id || "")
        obj.isRecent = isRecentCached(a.execString || "")
        return obj
    }

    function setFilteredApps(arr) {
        if (arr.length === filteredApps.length && _filterGen === _lastAppliedGen) {
            var same = arr.length > 0
            for (var i = 0; i < arr.length; i++) {
                var a = arr[i], b = filteredApps[i]
                var ka = a.id ?? a.path ?? a.cmd ?? ""
                var kb = b.id ?? b.path ?? b.cmd ?? ""
                if (ka !== kb || (a.name ?? "") !== (b.name ?? "")) { same = false; break }
            }
            if (same) return
        }
        _lastAppliedGen = _filterGen
        filteredApps = arr
    }

    // ── Filtro principal ──────────────────────────────────────────────────────
    function filterApps(q) {
        var query = q.trim()

        // Comandos del menú: ">b <q>", ">ia <proveedor> <prompt>", ">sf <q>".
        if (query.startsWith(">")) {
            _filterCommands(query.slice(1))
            return
        }

        // Modo normal: cortar búsqueda de archivos pendiente.
        _exitFileMode()

        // Búsqueda normal
        var lower = query.toLowerCase()
        var ra = SettingsState.recentApps || []
        var recentSet = {}
        for (var i = 0; i < ra.length; i++) recentSet[ra[i].exec] = true
        _recentSet = recentSet
        var result = StartmenuLogic.filterAppsRecentFirst(
            allApps,
            ra,
            function(a) { return lower === "" ||
                (a.name || "").toLowerCase().indexOf(lower) >= 0 ||
                (a.comment || "").toLowerCase().indexOf(lower) >= 0 },
            function(a) { return enrichApp(a) }
        )
        setFilteredApps(result)
    }

    // ── Comandos del menú (">b", ">ia", ">sf") ────────────────────────────────
    // Se escriben en el buscador del appmenu con ">" adelante. Los ítems son
    // sintéticos: { isCommand, cmd, arg, name, comment } y { isFile, path, ... }.
    readonly property string _homeDir: Quickshell.env("HOME")
    property bool fileSearching: false
    property var  fileResults: []
    property string _fileQuery: ""
    property bool _wantFiles: false

    readonly property var _commandDefs: [
        { cmd: "b",  name: "Buscar en la web",     hint: ">b <texto> · DuckDuckGo" },
        { cmd: "ia", name: "Preguntar a una IA",   hint: ">ia <gpt|claude|gemini> <prompt>" },
        { cmd: "sf", name: "Buscar archivos",      hint: ">sf <nombre> · en tu home" }
    ]

    // Proveedores de IA: primer token del argumento (default gpt).
    readonly property var _aiProviders: ({
        gpt:     { label: "ChatGPT", url: "https://chatgpt.com/?q=" },
        chatgpt: { label: "ChatGPT", url: "https://chatgpt.com/?q=" },
        claude:  { label: "Claude",  url: "https://claude.ai/new?q=" },
        gemini:  { label: "Gemini",  url: "https://gemini.google.com/app?q=" }
    })

    // Daemon Go (`scripts/daemon search run`): índice en memoria del home,
    // protocolo NDJSON por stdin/stdout (igual que mpd/keepass/bright).
    // Arranca bajo demanda al consultar y se apaga por inactividad.
    readonly property string _daemonBin: Qt.resolvedUrl("../scripts/daemon").toString().replace("file://", "")
    property bool _searchReady: false
    property int _searchNextId: 1
    property int _searchPendingId: -1
    property var _searchOutbox: []

    Timer {
        id: fileDebounce
        interval: 220
        repeat: false
        onTriggered: StartmenuState._runFileSearch(StartmenuState._fileQuery)
    }

    Timer {
        id: searchIdle
        interval: 20000
        repeat: false
        onTriggered: StartmenuState.stopSearchDaemon()
    }

    Process {
        id: searchProc
        stdinEnabled: true
        command: [StartmenuState._daemonBin, "search", "run"]
        running: false
        stdout: SplitParser { onRead: (line) => StartmenuState._onSearchLine(line) }
        onRunningChanged: {
            if (running) return
            StartmenuState._searchReady = false
            StartmenuState._searchOutbox = []
            StartmenuState._searchPendingId = -1
            StartmenuState.fileSearching = false
        }
    }

    function _startSearchDaemon() {
        if (!searchProc.running) searchProc.running = true
    }

    function _sendToSearch(obj) {
        var line = JSON.stringify(obj)
        if (_searchReady && searchProc.running) searchProc.write(line + "\n")
        else if (_searchOutbox.length < 10) _searchOutbox.push(line)
    }

    function _flushSearchOutbox() {
        while (_searchOutbox.length > 0 && searchProc.running)
            searchProc.write(_searchOutbox.shift() + "\n")
    }

    function _onSearchLine(data) {
        var line = String(data).trim()
        if (line === "") return
        var ev = null
        try { ev = JSON.parse(line) } catch (e) { return }

        if (ev.type === "ready") {
            _searchReady = true
            _flushSearchOutbox()
            return
        }
        if (ev.type !== "results") return
        if (ev.id !== _searchPendingId) return   // respuesta vieja: ignorar

        var items = []
        var arr = ev.items || []
        for (var i = 0; i < arr.length; i++) {
            var p = arr[i].path
            items.push({
                isFile: true,
                path: p,
                name: arr[i].name || p.slice(p.lastIndexOf("/") + 1),
                comment: _prettyPath(p)
            })
        }
        fileResults = items
        fileSearching = false
        setFilteredApps(items)
    }

    // Rehace el índice (se llama al abrir el menú, si el daemon ya vive).
    function refreshSearchIndex() {
        if (!searchProc.running) return
        _sendToSearch({ id: _searchNextId++, cmd: "refresh" })
    }

    function stopSearchDaemon() {
        searchIdle.stop()
        if (searchProc.running) searchProc.running = false
    }

    // Al cerrar el launcher, apagar el daemon de búsqueda (el índice se
    // rearma en la próxima sesión).
    Connections {
        target: TaskbarState
        function onShowLauncherChanged() {
            if (!TaskbarState.showLauncher) StartmenuState.stopSearchDaemon()
        }
        function onPinnedAppsChanged() {
            _filterGen++
            _pinnedCache = {}
            // Re-aplica el filtro vigente para refrescar los badges de pin.
            StartmenuState.filterApps(StartmenuState.pendingFilter)
        }
    }

    function _prettyPath(p) {
        return StartmenuLogic.prettyPath(p, _homeDir)
    }

    function _exitFileMode() {
        fileDebounce.stop()
        _wantFiles = false
        fileSearching = false
        if (fileResults.length > 0) fileResults = []
    }

    function _filterCommands(inner) {
        var sp = inner.indexOf(" ")
        var token = (sp >= 0 ? inner.slice(0, sp) : inner).trim().toLowerCase()
        var arg = sp >= 0 ? inner.slice(sp + 1) : ""
        var items = []

        if (token === "sf") {
            _wantFiles = true
            _fileQuery = arg.trim()
            if (_fileQuery === "") {
                // Sin argumento: solo el hint (y cortar cualquier búsqueda
                // pendiente para que no pise la lista al terminar).
                _wantFiles = false
                fileDebounce.stop()
                fileSearching = false
                items.push({
                    isCommand: true, cmd: "sf", arg: "",
                    name: "Buscar archivos",
                    comment: "Escribí un nombre para buscar en ~/"
                })
                setFilteredApps(items)
                return
            }
            fileSearching = true
            // Mantener los resultados previos mientras responde el daemon.
            fileDebounce.restart()
            setFilteredApps(fileResults)
            return
        }

        _exitFileMode()

        if (token === "b" && sp >= 0 && arg.trim() !== "") {
            items.push({
                isCommand: true, cmd: "b", arg: arg,
                name: "Buscar «" + arg.trim() + "» en la web",
                comment: "DuckDuckGo · Enter para abrir el navegador"
            })
            setFilteredApps(items)
            return
        }

        if (token === "ia" && sp >= 0 && arg.trim() !== "") {
            var ai = _parseAI(arg)
            var label = _aiProviders[ai.key].label
            items.push({
                isCommand: true, cmd: "ia", arg: arg,
                name: ai.prompt === "" ? "Abrir " + label
                                       : "Preguntar a " + label + ": «" + ai.prompt + "»",
                comment: "Enter para abrir en el navegador"
            })
            setFilteredApps(items)
            return
        }

        // Lista de comandos (todos o los que empiezan con lo tipeado).
        for (var i = 0; i < _commandDefs.length; i++) {
            var d = _commandDefs[i]
            if (token !== "" && d.cmd.indexOf(token) !== 0) continue
            items.push({
                isCommand: true, cmd: d.cmd, arg: "",
                name: d.name,
                comment: d.hint
            })
        }
        setFilteredApps(items)
    }

    function _parseAI(arg) {
        return StartmenuLogic.parseAI(arg, _aiProviders)
    }

    function _runFileSearch(query) {
        if (!_wantFiles || query === "") return
        fileSearching = true
        _startSearchDaemon()
        _searchPendingId = _searchNextId++
        _sendToSearch({ id: _searchPendingId, cmd: "query", args: { q: query, max: 80 } })
        searchIdle.restart()
    }

    // Ejecuta un ítem del menú: comando, archivo o app.
    function activateItem(item) {
        if (!item) return
        if (item.isFile) {
            TaskbarState.openExternal(item.path)
            TaskbarState._hideLauncher()
            return
        }
        if (item.isCommand) {
            runCommand(item)
            return
        }
        launchApp(item)
    }

    // URL de un comando ("" si no hay nada que abrir). Separado de runCommand
    // para poder testearlo sin lanzar el navegador.
    function commandUrl(item) {
        return StartmenuLogic.commandUrl(item, _aiProviders)
    }

    function runCommand(item) {
        var url = commandUrl(item)
        if (url === "") return
        TaskbarState.openExternal(url)
        TaskbarState._hideLauncher()
    }

    // Glifo Nerd Font según extensión (para los resultados de ">sf").
    function fileIconFor(path) {
        return StartmenuLogic.fileIconFor(path, Icons)
    }

    // ── Recargar apps ─────────────────────────────────────────────────────────
    function reloadApps() {
        allApps = DesktopEntries.applications.values
    }

    // ── Lanzar app ────────────────────────────────────────────────────────────
    function launchApp(entry) {
        SettingsState.addRecentApp(entry.execString, entry.name)
        var liveEntry = DesktopEntries.byId(entry.id)
        if (liveEntry) liveEntry.execute()
        TaskbarState._hideLauncher()
    }
}
