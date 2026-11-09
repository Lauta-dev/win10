// KeePassState.qml — Estado KeePassXC para Command Palette.
// Habla con scripts/daemon keepass (NDJSON por stdin/stdout): la base se
// abre nativa en Go, la contraseña vive en el bridge y los secretos van
// directo a wl-copy sin pasar por QML. El bridge queda con la base
// descifrada en cache (invalidada por mtime) y se auto-bloquea a los
// 15 min sin uso; acá solo se refleja ese estado.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

import "../logic/keepass.js" as KeepassLogic
Singleton {
    id: root

    // ── Config ───────────────────────────────────────────────────────────────
    readonly property string dbPath: "/home/lautaro/Documentos/.syncthing/keepass/main.kdbx"

    // ── Mock DEV (SOLO keepass): datos falsos + apertura directa ────────
    // true = sin daemon ni DB real, abre desbloqueado en la lista.
    // false = DB real.
    property bool mockMode: false

    Component.onCompleted: { if (mockMode) _mockUnlock() }

    function _mockEntries() {
        return [
            { path: "Web/GitHub", title: "GitHub", username: "lautaro", hasTotp: true, url: "https://github.com" },
            { path: "Web/Proton Mail", title: "Proton Mail", username: "lautaro@proton.me", hasTotp: true, url: "https://mail.proton.me" },
            { path: "Banco/Cuenta sueldo", title: "Banco", username: "00112233", hasTotp: false, url: "" },
            { path: "Servidores/Homeserver", title: "Homeserver", username: "root", hasTotp: false, url: "" },
            { path: "Web/Reddit", title: "Reddit", username: "lautaro_dev", hasTotp: false, url: "https://reddit.com" }
        ]
    }

    function _mockUnlock() {
        entries = _mockEntries()
        filtered = entries.slice()
        selectedPath = ""; selectedTitle = ""; detailActions = []; detailBase = []
        addingEntry = false; editingEntry = false; editPath = ""
        pendingDel = ""
        enteringTotp = false; totpTarget = ""
        loading = false; error = ""
        isUnlocked = true
    }

    // ── Estado público (misma API que antes) ─────────────────────────────────
    property bool isUnlocked: false
    property bool loading: false
    property var entries: []   // todos los paths
    property var filtered: []  // filtrados por búsqueda
    property string error: ""

    // ── Detalle de entry seleccionado ──────────────────────────────────────
    property string selectedPath: ""
    property string selectedTitle: ""
    property var detailActions: []
    property var detailBase: []

    // ── Alta y edición (form CpKeepassAddForm) ────────────────────────────
    property bool addingEntry: false
    property bool editingEntry: false
    property string editPath: ""

    // ── Borrado con confirmación ───────────────────────────────────────────
    property string pendingDel: ""

    // ── Input de secreto TOTP para una entrada existente ───────────────────
    property bool enteringTotp: false
    property string totpTarget: ""

    // Filas del paso secreto: usar lo escrito o generar aleatorio.
    function totpRows() {
        return [
            { id: "use-typed", label: "Usar lo escrito como secreto", description: "Enter con el campo escrito", icon: Icons.timer },
            { id: "gen", label: "Generar secreto aleatorio", description: "Secreto nuevo → portapapeles", icon: Icons.refresh }
        ]
    }

    function enterDetail(entry) {
        if (!entry || !entry.path) return
        selectedPath = entry.path
        selectedTitle = entry.title || entry.path
        var acts = KeepassLogic.buildDetailActions(entry, kindUser, kindPassword, kindTotp, actTotpNew, actTotpPaste, Icons)
        detailActions = acts
        detailBase = acts.slice()
        // avisa actividad para que no auto-bloquee mirando el detalle
        if (bridgeProc.running) root._send("ping", {}, null)
    }

    function leaveDetail() {
        selectedPath = ""
        selectedTitle = ""
        detailActions = []
        detailBase = []
    }

    function isInDetail() { return selectedPath !== "" }

    function lock() {
        if (bridgeProc.running) {
            // al morir el proceso se limpia el estado (ver onRunningChanged)
            _expectExit = true
            bridgeProc.running = false
        } else {
            root._clearState()
        }
    }

    function _clearState() {
        isUnlocked = false
        entries = []
        filtered = []
        selectedPath = ""
        selectedTitle = ""
        detailActions = []
        detailBase = []
        addingEntry = false
        editingEntry = false
        editPath = ""
        pendingDel = ""
        enteringTotp = false
        totpTarget = ""
        error = ""
        loading = false
        _reunlock = ""
    }

    function openAddForm() {
        editingEntry = false
        editPath = ""
        addingEntry = true
    }

    function openEditForm(entry) {
        if (!entry || !entry.path) return
        leaveDetail()
        editPath = entry.path
        editingEntry = true
        addingEntry = true
    }

    function closeAddForm() {
        addingEntry = false
        editingEntry = false
        editPath = ""
    }

    // Guarda el form de alta: crea la entrada y, si pide TOTP, lo
    // encadena con la misma respuesta refrescada.
    function submitAdd(form) {
        if (!isUnlocked || loading) return
        if (mockMode) {
            var e = { path: form.title, title: form.title, username: form.username || "",
                      url: form.url || "", hasTotp: form.totpMode === "generate" || form.totpMode === "paste" }
            entries = entries.concat([e])
            filtered = entries.slice()
            closeAddForm()
            return
        }
        loading = true
        _send("add", {title: form.title, username: form.username, password: form.password, url: form.url}, function(ev) {
            if (ev && ev.entries) {
                entries = ev.entries
                filtered = ev.entries.slice()
            }
            if (!(ev && ev.ok)) {
                loading = false
                return
            }
            var path = (ev && ev.label) || form.title
            if (form.totpMode === "generate") {
                _send("totp-new", {path: path}, function(ev2) {
                    loading = false
                    _refreshAfterTotp(ev2, "Creada, pero falló el TOTP")
                    closeAddForm()
                })
            } else if (form.totpMode === "paste") {
                _send("totp-set", {path: path, secret: form.totpSecret}, function(ev2) {
                    loading = false
                    _refreshAfterTotp(ev2, "Creada, pero falló el TOTP")
                    closeAddForm()
                })
            } else {
                loading = false
                closeAddForm()
            }
        })
    }

    // Guarda el form de edición. password vacío = mantener la actual.
    function submitEdit(form) {
        if (!isUnlocked || loading) return
        if (mockMode) {
            for (var i = 0; i < entries.length; i++) {
                if (entries[i].path === form.origPath) {
                    entries[i].title = form.title
                    entries[i].username = form.username || ""
                    entries[i].url = form.url || ""
                    break
                }
            }
            entries = entries.slice()
            filtered = entries.slice()
            closeAddForm()
            return
        }
        loading = true
        _send("edit", {path: form.origPath, title: form.title, username: form.username, password: form.password, url: form.url}, function(ev) {
            loading = false
            if (ev && ev.entries) {
                entries = ev.entries
                filtered = ev.entries.slice()
            }
            if (ev && ev.ok) {
                closeAddForm()
            } else {
            }
        })
    }

    // Pide una clave nueva al daemon (crypto/rand) y la devuelve por
    // callback para mostrarla en el form. No toca loading: es rápido y
    // el form sigue usable.
    function genPassword(cb) {
        if (mockMode) { try { cb("Mock-1234-falso") } catch(e) {} return }
        if (!isUnlocked) return
        _send("genpass", {}, function(ev) {
            if (ev && ev.ok && ev.password) {
                try { cb(ev.password) } catch(e) {}
            } else {
            }
        })
    }

    function startDel(path) {
        pendingDel = path
    }

    function cancelDel() {
        pendingDel = ""
    }

    function confirmDel() {
        if (!isUnlocked || loading || pendingDel === "") return
        if (mockMode) {
            var gone = pendingDel
            pendingDel = ""
            entries = entries.filter(function(e) { return e.path !== gone })
            filtered = entries.slice()
            return
        }
        loading = true
        var target = pendingDel
        _send("del", {path: target}, function(ev) {
            loading = false
            pendingDel = ""
            if (ev && ev.entries) {
                entries = ev.entries
                filtered = ev.entries.slice()
            }
            if (!(ev && ev.ok)) {
            }
        })
    }

    function _refreshAfterTotp(ev, errTitle) {
        if (ev && ev.entries) {
            entries = ev.entries
            filtered = ev.entries.slice()
            for (var i = 0; i < ev.entries.length; i++) {
                if (ev.entries[i].path === selectedPath) { enterDetail(ev.entries[i]); break }
            }
        }
        if (ev && !ev.ok) {
        }
    }

    function startTotpInput(path) {
        totpTarget = path
        enteringTotp = true
    }

    function cancelTotpInput() {
        enteringTotp = false
        totpTarget = ""
    }

    // Secreto pegado para una entrada existente; vacío = generar.
    function confirmTotpInput(secret) {
        if (!isUnlocked || loading) return
        if (mockMode) {
            enteringTotp = false
            totpTarget = ""
            return
        }
        if ((secret || "") === "") {
            enteringTotp = false
            var t = totpTarget
            totpTarget = ""
            totpNew(t)
            return
        }
        loading = true
        var target = totpTarget
        _send("totp-set", {path: target, secret: secret}, function(ev) {
            loading = false
            enteringTotp = false
            totpTarget = ""
            _refreshAfterTotp(ev, "Error al guardar TOTP")
        })
    }

    // Genera un secreto TOTP nuevo para la entrada y lo deja en el
    // portapapeles para registrarlo en el servicio.
    function totpNew(path) {
        if (!isUnlocked || loading) return
        if (mockMode) {
            return
        }
        loading = true
        _send("totp-new", {path: path || selectedPath}, function(ev) {
            loading = false
            _refreshAfterTotp(ev, "Error al generar TOTP")
        })
    }

    function filterEntries(q) {
        if (isInDetail()) {
            detailActions = KeepassLogic.filterActions(detailBase, q)
            return
        }
        filtered = KeepassLogic.filterEntryList(entries, q)
    }

    // ── Palette: búsqueda plana, sin submenús ">" ─────────────────────────
    readonly property string actGen: "gen"
    readonly property string actDelYes: "del-yes"
    readonly property string kindUser: "user"
    readonly property string kindPassword: "password"
    readonly property string kindTotp: "totp"
    readonly property string actTotpNew: "totp-new"
    readonly property string actTotpPaste: "totp-paste"
    readonly property string resClear: "clear"
    readonly property string resOpenEdit: "open-edit"
    readonly property string resEnterDetail: "enter-detail"

    function visibleRows(searchText) {
        return KeepassLogic.visibleRows(isUnlocked, addingEntry, pendingDel, enteringTotp, selectedPath, filtered, totpRows(), detailActions)
    }

    function placeholderFor(searchText) {
        return KeepassLogic.placeholderFor(isUnlocked, enteringTotp, selectedPath)
    }

    // Retorna true si filtró (el llamador selecciona la primera fila).
    function handleSearch(text) {
        if (!isUnlocked || addingEntry || enteringTotp || pendingDel !== "") return false
        filterEntries(text)
        return true
    }

    function findFullEntry(item) {
        for (var i = 0; i < entries.length; i++) {
            if (entries[i].path === item.path) return entries[i]
        }
        return item
    }

    // Retorna un código (resClear, resOpenEdit, resEnterDetail) o vacío
    // si no hay acción de vista.
    function dispatchAction(id, searchText) {
        if (enteringTotp) {
            if (id === actGen) confirmTotpInput("")
            else confirmTotpInput(searchText)
            return ""
        } else if (pendingDel !== "") {
            if (id === actDelYes) { confirmDel(); return resClear }
            cancelDel()
            return ""
        }
        copyAction(id)
        return ""
    }

    // Click/Enter en una entrada = copiar contraseña (sin vista detalle).
    function activateItem(item, searchText) {
        if (enteringTotp || pendingDel !== "")
            return dispatchAction(item.id, searchText)
        if (item && item.path) copyPassword(item.path)
        return ""
    }

    function unlock(pwd) {
        if (mockMode) { _mockUnlock(); return }
        if (loading) return
        if (!pwd || pwd.trim() === "") {
            return
        }
        loading = true
        error = ""
        if (bridgeProc.running) {
            // ya hay bridge (otra contraseña?): matarlo y reintentar al morir
            _reunlock = pwd
            bridgeProc.running = false
        } else {
            _startBridge(pwd)
        }
    }

    function _startBridge(pwd) {
        _reunlock = ""
        _expectExit = false
        _bridgeErr = ""
        var bin = Qt.resolvedUrl("../bin/daemon").toString().replace("file://", "")
        bridgeProc.command = [bin, "keepass", "--db", dbPath]
        bridgeProc.running = true
        _outbox.push(JSON.stringify({id: _nextUnlockId(), cmd: "unlock", args: {password: pwd}}))
    }

    function _nextUnlockId() {
        // el unlock siempre usa id reservado: si llega tarde no pisa nada
        _unlockSeq++
        return -_unlockSeq
    }
    property int _unlockSeq: 0

    function reload() {
        if (!isUnlocked) return
        if (mockMode) return
        loading = true
        _send("list", {}, function(ev) {
            loading = false
            if (ev && ev.ok && ev.entries) {
                entries = ev.entries
                filtered = ev.entries.slice()
            } else if (ev && !ev.ok) {
                error = ev.error || ""
            }
        })
    }

    // ── Copy — el secreto lo mueve el bridge a wl-copy; acá solo avisos ────
    function copyUser(path) { _doCopy(path || selectedPath, "UserName", false) }
    function copyPassword(path) { _doCopy(path || selectedPath, "Password", false) }
    function copyTotp(path) { _doCopy(path || selectedPath, "", true) }
    function copyAction(actionId) {
        if (!selectedPath) return
        if (actionId === kindUser) copyUser(selectedPath)
        else if (actionId === kindPassword) copyPassword(selectedPath)
        else if (actionId === kindTotp) copyTotp(selectedPath)
        else if (actionId === actTotpNew) totpNew(selectedPath)
        else if (actionId === actTotpPaste) startTotpInput(selectedPath)
    }
    function _doCopy(entryPath, attr, isTotp) {
        if (!isUnlocked) {
            return
        }
        if (!entryPath) return
        if (mockMode) return
        var wantLabel = isTotp ? "TOTP" : (attr === "UserName" ? "usuario" : "contraseña")
        var args = {path: entryPath, totp: isTotp}
        if (!isTotp) args.attr = attr
        _send("copy", args, function(ev) {
            if (ev && ev.ok) return
        })
    }

    // ── Bridge: request/response por id + outbox ───────────────────────────
    property int _nextId: 1
    property var _cbs: ({})
    property var _outbox: []
    property string _reunlock: ""
    property bool _expectExit: false
    property string _bridgeErr: ""
    property int _exitCode: 0

    function _send(cmd, args, callback) {
        var id = _nextId++
        if (callback) _cbs[id] = callback
        var line = JSON.stringify({id: id, cmd: cmd, args: args || {}})
        if (bridgeProc.running) {
            bridgeProc.write(line + "\n")
        } else {
            _outbox.push(line)
        }
    }

    function _failPending(reason) {
        var stale = _cbs; _cbs = {}
        _outbox = []
        for (var k in stale) {
            try { stale[k]({type: "error", ok: false, error: reason}) } catch(e) {}
        }
    }

    function _onBridgeLine(data) {
        var ev = null
        try { ev = JSON.parse(String(data).trim()) } catch(e) { return }
        if (!ev || !ev.type) return
        if (ev.type === "locked") {
            // auto-bloqueo del bridge: avisar y limpiar como lock manual
            if (bridgeProc.running) bridgeProc.running = false
            root._clearState()
            return
        }
        if (ev.id !== undefined && ev.id !== null) {
            if (ev.id < 0) {
                // respuesta de unlock (id reservado negativo): ignorar el
                // ack que cierra el pedido, si no pisa la lista con [].
                if (ev.type === "ack") return
                root._onUnlockResponse(ev)
                return
            }
            var cb = _cbs[ev.id]
            if (cb !== undefined) {
                delete _cbs[ev.id]
                try { cb(ev) } catch(e) {}
            }
        }
    }

    function _onUnlockResponse(ev) {
        loading = false
        if (ev && ev.ok && ev.entries) {
            entries = ev.entries
            filtered = ev.entries.slice()
            isUnlocked = true
            error = ""
        } else {
            isUnlocked = false
            entries = []
            filtered = []
            error = (ev && ev.error) || "No se pudo abrir la base de datos"
        }
    }

    Process {
        id: bridgeProc
        stdinEnabled: true
        running: false
        stdout: SplitParser { onRead: function(data) { root._onBridgeLine(data) } }
        stderr: SplitParser { onRead: function(data) { root._bridgeErr += data + "\n" } }
        onExited: {
            // código real de salida (onRunningChanged no lo trae)
            root._exitCode = arguments[0]
            // Muerte inesperada con código != 0: avisar en vez de quedar
            // en "nada" silencioso. El re-unlock y el lock manual no avisan.
            if (arguments[0] !== 0 && !root._expectExit && root._reunlock === "") {
                var msg = root._bridgeErr.trim()
                if (msg === "") msg = "código " + arguments[0]
            }
        }
        onRunningChanged: {
            if (running) {
                root._bridgeErr = ""
                root._exitCode = 0
                while (_outbox.length > 0) bridgeProc.write(_outbox.shift() + "\n")
            } else {
                root._failPending("bridge detenido")
                if (root._reunlock !== "") {
                    // re-unlock pedido mientras moría el anterior
                    var pwd = root._reunlock
                    root._startBridge(pwd)
                } else {
                    root._expectExit = false
                    root._clearState()
                }
            }
        }
    }
}
