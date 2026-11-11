pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

import "../logic/time.js" as TimeLogic
import "../logic/mpd.js" as MpdLogic
Singleton {
    id: root

    // ── Estado público ───────────────────────────────────────────────
    property var playlist: []
    property var recentSongs: []      // 5 últimos de la biblioteca (daemon "recent")
    // El pedido de recientes ya respondió (ok o error). Mientras es false,
    // CpRecentStrip reserva su lugar con skeletons (sin salto al abrir).
    property bool recentLoaded: false

    // ── Cache en disco de recientes ────────────────────────────────
    // La tira muestra lo último conocido al instante; el pedido al
    // daemon solo refresca en segundo plano (con throttle de 60s).
    property double _lastRecentAt: 0
    FileView {
        id: _recentCache
        path: Quickshell.cacheDir + "/mpd-recent.json"
        onLoaded: {
            try {
                var arr = JSON.parse(text())
                if (Array.isArray(arr) && arr.length > 0)
                    root.recentSongs = arr.filter(function(s) { return s && s.file }).slice(0, 5)
            } catch(e) {}
        }
    }
    function _saveRecentCache() {
        try { _recentCache.setText(JSON.stringify(root.recentSongs)) } catch(e) {}
    }
    property int playlistPos: -1          // 0-based, -1 = none
    property int playlistVersion: -1
    property bool _mpdPlaying: false
    readonly property bool musicPlaying: _mpdPlaying

    // daemonRunning sigue el socket; readonly para no romper el binding
    readonly property bool daemonRunning: MpdConnection.connected
    readonly property string socketPath: MpdConnection.socketPath

    // status fields (from `status`)
    property int volume: -1
    property bool repeat: false
    property bool random: false
    property bool single: false
    property bool consume: false
    property string mpdState: "stop"     // play|pause|stop
    property real elapsed: 0
    property real duration: 0
    property int songId: -1
    property bool updatingDb: false

    // currentsong
    property var currentSong: null       // {title, artist, album, file, duration, id, pos}
    property string currentTitle: ""
    property string currentArtist: ""

    // ── Timer para elapsed local (evita polling) mpd.md:422 ─────────
    Timer {
        id: elapsedTimer
        interval: 1000
        repeat: true
        running: root._mpdPlaying && root.mpdState === "play" && root.duration > 0 && root.daemonRunning
        onTriggered: {
            if (root.elapsed < root.duration) root.elapsed += 1
        }
    }

    Timer {
        id: syncTimeout
        interval: 8000
        repeat: false
        onTriggered: { if (root._syncingQueue) root._syncingQueue = false }
    }

    Connections {
        target: MpdConnection
        function onPollingActiveChanged() {
            // Al salir se corta el sync pendiente. Al entrar no hay nada
            // que reintentar: MpdConnection levanta el daemon solo.
            if (!MpdConnection.pollingActive) {
                root._syncingQueue = false; syncTimeout.stop()
            }
        }
        function onConnectedChanged() {
            if (!MpdConnection.connected) { root._syncingQueue = false; syncTimeout.stop() }
        }
    }
    Component.onCompleted: { }

    Connections {
        target: MpdConnection
        function onDaemonEvent(ev) { root._applyDaemonEvent(ev) }
        function onConnectedChanged() {
            // Solo refresh completo en frío: el burst del daemon + idle
            // mantienen todo fresco después. Evita recargar al entrar.
            if (MpdConnection.connected && root.playlist.length === 0) {
                root._refreshAll()
            }
        }
    }

    // ── Eventos push del daemon (idle de MPD) ────────────────────────
    // Misma info que _parseStatus/_parseCurrentSong pero
    // ya parseada en Go: la UI reacciona sin salir/entrar al menú.
    function _applyDaemonEvent(ev) {
        if (!ev || !ev.type) return
        if (ev.type === "status") {
            if (ev.volume !== undefined) root.volume = ev.volume
            root.repeat = !!ev.repeat
            root.random = !!ev.random
            root.single = !!ev.single
            root.consume = !!ev.consume
            if (ev.state) { root.mpdState = ev.state; root._mpdPlaying = (ev.state === "play") }
            if (ev.playlistPos !== undefined && ev.playlistPos !== null) root.playlistPos = ev.playlistPos
            if (ev.songId !== undefined && ev.songId !== null) root.songId = ev.songId
            if (ev.playlist !== undefined && ev.playlist !== null) root.playlistVersion = ev.playlist
            // El tiempo solo vale si es del tema actual: un status
            // desfasado (de otro songId) no pisa el elapsed reseteado.
            var fresh = !root.currentSong || ev.songId === undefined || ev.songId === null
                || root.currentSong.id === undefined || ev.songId === root.currentSong.id
            if (fresh && ev.elapsed !== undefined && ev.elapsed !== null) root.elapsed = ev.elapsed
            if (fresh && ev.duration !== undefined && ev.duration !== null && ev.duration > 0) root.duration = ev.duration
            root.updatingDb = !!ev.updatingDb
        } else if (ev.type === "song") {
            if (ev.song) {
                var s = ev.song
                var dur = s.duration > 0 ? Math.round(s.duration) : 0
                // Tema nuevo (había otro sonando): el elapsed vuelve a 0
                // acá mismo, sin esperar al status. Si no había previo
                // (entrada al menú) no se toca: el status trae la
                // posición real.
                var prev = root.currentSong
                if (prev && ((s.id !== undefined && s.id !== prev.id)
                    || ((s.file || "") !== (prev.file || "")))) root.elapsed = 0
                root.currentSong = { title: s.title || "", artist: s.artist || "", album: s.album || "", file: s.file || "", duration: dur, id: s.id, pos: s.pos, genre: "", date: "" }
                root.currentTitle = s.title || s.file || ""
                root.currentArtist = s.artist || ""
                if (s.pos !== undefined && s.pos >= 0) root.playlistPos = s.pos
                if (dur > 0) root.duration = dur
            } else {
                root.currentSong = null; root.currentTitle = ""; root.currentArtist = ""
            }
        } else if (ev.type === "queue") {
            var q = ev.queue || []
            // Sin cambios (misma versión y largo) no se reasigna: evita
            // reconstruir la lista en cada entrada al menú. MPD sube la
            // versión en cualquier edición, así que es comparación exacta.
            if (ev.version !== undefined && ev.version !== null
                && ev.version === root.playlistVersion && q.length === root.playlist.length) return
            MpdLogic.roundQueueDurations(q)
            root.playlist = q
            if (ev.version !== undefined && ev.version !== null) root.playlistVersion = ev.version
        }
    }

    function reconnect() {
        MpdConnection.reconnect()
    }

    // ── Levantar servidor y bridge (botón del EmptyState) ────────
    // Procesos estáticos detached: comandos pelados, sin tracking.
    // Secuencia: mpd primero, mpris 2s después (si mpd aún no acepta
    // conexiones, mpris sale sin reintentar). A los 3s se verifica:
    // reconnect al socket y reintento de mpris si sigue ausente.
    Process { id: _mpdProc; command: ["mpd"] }
    Process { id: _mprisProc; command: ["mpd-mpris"] }
    Timer {
        id: _mprisDelay
        interval: 2000; repeat: false
        onTriggered: _mprisProc.startDetached()
    }
    Timer {
        id: _startCheck
        interval: 3000; repeat: false
        onTriggered: {
            MpdConnection.reconnect()
            if (MprisState._mpdPlayer === null) _mprisProc.startDetached()
        }
    }
    function startMpd() { _mpdProc.startDetached() }
    function startMprisBridge() { _mprisProc.startDetached() }
    function startStack() {
        startMpd()
        _mprisDelay.restart()
        _startCheck.restart()
    }

    // watch daemonRunning alias
    onDaemonRunningChanged: {
        // alias already bound, but ensure sync on startup
    }

    // ── Sync ──────────────────────────────────────────────────────────
    function _refreshAll() {
        _refreshStatus()
        _refreshCurrentSong()
        loadPlaylist()
    }

    function _refreshStatus() {
        if (!MpdConnection.connected) {
            MpdConnection.ensureConnected()
            return
        }
        MpdConnection.sendCommand("status", function(lines, isAck, ack) {
            if (isAck) {
                console.log("[MpdState] status ACK:", ack)
                return
            }
            root._parseStatus(lines)
        })
    }

    function _refreshCurrentSong() {
        if (!MpdConnection.connected) return
        MpdConnection.sendCommand("currentsong", function(lines, isAck) {
            if (isAck) return
            root._parseCurrentSong(lines)
        })
    }

    function _parseStatus(lines) {
        var st = MpdLogic.parseStatusLines(lines || [])
        if (st.volume !== undefined) root.volume = st.volume
        root.repeat = st.repeat
        root.random = st.random
        root.single = st.single
        root.consume = st.consume
        if (st.state !== undefined) {
            root.mpdState = st.state
            root._mpdPlaying = (st.state === "play")
        }
        if (st.playlistPos !== undefined) root.playlistPos = st.playlistPos
        if (st.songId !== undefined) root.songId = st.songId
        if (st.playlistVersion !== undefined) root.playlistVersion = st.playlistVersion
        if (st.elapsed !== undefined) root.elapsed = st.elapsed
        if (st.duration !== undefined) root.duration = st.duration
        root.updatingDb = st.updatingDb
    }

    function _parseCurrentSong(lines) {
        var cs = MpdLogic.parseCurrentSongLines(lines || [])
        if (!cs) {
            root.currentSong = null
            root.currentTitle = ""
            root.currentArtist = ""
            return
        }
        root.currentSong = {
            title: cs.title,
            artist: cs.artist,
            album: cs.album,
            file: cs.file,
            duration: cs.duration,
            id: cs.id,
            pos: cs.pos,
            genre: cs.genre,
            date: cs.date
        }
        root.currentTitle = cs.title || cs.file
        root.currentArtist = cs.artist
        if (cs.pos >= 0) root.playlistPos = cs.pos
        if (cs.duration > 0) root.duration = cs.duration
    }

    // ── Playlist (push del daemon; el parseo vive en Go) ──────────

    property bool _syncingQueue: false
    // Entrada al modo: faltantes + recientes en UN pedido ("enter").
    // La cola actualizada llega sola vía push "queue"; los recientes se
    // piden solo si el throttle de 60s venció (el cache en disco cubre).
    function enterMpd() {
        if (root._syncingQueue) return
        if (!MpdConnection.connected) return
        root._syncingQueue = true; syncTimeout.restart()
        var wantRecent = root.recentSongs.length === 0 || (Date.now() - root._lastRecentAt) >= 60000
        MpdConnection.sendJson("enter", {limit: 5, recent: wantRecent}, function(ev) {
            syncTimeout.stop(); root._syncingQueue = false
            root.recentLoaded = true
            if (!ev || !ev.ok) { console.log("[MpdState] enter:", ev && ev.error); return }
            if (wantRecent && ev.items && ev.items.length > 0) {
                var res = MpdLogic.transformRecentItems(ev.items)
                root.recentSongs = res
                root._lastRecentAt = Date.now()
                root._saveRecentCache()
            }
        })
    }

    // ── Compat wrappers ───────────────────────────────────────────────
    // Reproduce un archivo de la biblioteca: si ya está en la cola salta
    // a su posición (sin duplicar); si no, lo agrega y lo reproduce.
    function playFile(file) {
        if (!file) return
        for (var i = 0; i < root.playlist.length; i++) {
            if (root.playlist[i].file === file) {
                playFromPosition(root.playlist[i].pos)
                return
            }
        }
        addAndPlay(file)
    }
    // ── Controles públicos mpd.md:113 / 347 ───────────────────────────
    function play() {
        MpdConnection.sendCommand("play", function(l, isAck, ack) {
            if (isAck) console.log("[MpdState] play ACK", ack)
        })
    }
    function pause() {
        MpdConnection.sendCommand("pause 1", function(l, isAck, ack) {
            if (isAck) console.log("[MpdState] pause ACK", ack)
        })
    }
    function togglePause() {
        if (root._mpdPlaying) pause()
        else {
            MpdConnection.sendCommand("pause 0", function(l, isAck, ack) {
                if (isAck) {
                    // if paused state was stop, try play
                    MpdConnection.sendCommand("play", function(){})
                }
            })
        }
    }
    function stop() {
        MpdConnection.sendCommand("stop", function(){})
    }
    function next() {
        MpdConnection.sendCommand("next", function(){})
    }
    function previous() {
        MpdConnection.sendCommand("previous", function(){})
    }

    function playFromPosition(pos) {
        // pos 0-based -> play pos
        MpdConnection.sendCommand("play " + pos, function(l, isAck, ack) {
            if (isAck) console.log("[MpdState] play pos ACK", ack)
        })
    }
    function playId(id) {
        MpdConnection.sendCommand("playid " + id, function(){})
    }

    // seek absoluto en segundos — relativo va por seekOffset()
    function seek(timeSec) {
        var t = Math.max(0, Math.floor(timeSec))
        MpdConnection.sendCommand("seekcur " + t, function(l, isAck, ack) {
            if (!isAck) root.elapsed = t
            else console.log("[MpdState] seekcur ACK", ack)
        })
    }
    // relative seek
    function seekOffset(offset) {
        if (offset === 0) return
        var sign = offset > 0 ? "+" + offset : String(offset)
        MpdConnection.sendCommand("seekcur " + sign, function(l, isAck, ack) {
            if (!isAck) root.elapsed = Math.max(0, root.elapsed + offset)
            else console.log("[MpdState] seekcur offset ACK", ack)
        })
    }
    function setVolume(level) {
        var v = Math.max(0, Math.min(100, Math.round(level)))
        MpdConnection.sendCommand("setvol " + v, function(l, isAck, ack) {
            if (!isAck) root.volume = v
            else console.log("[MpdState] setvol ACK", ack)
        })
    }
    // aliases for IPC
    function setVol(level) { setVolume(level) }

    function setRepeat(val) {
        MpdConnection.sendCommand("repeat " + (val ? "1" : "0"), function(){})
    }
    function setRandom(val) {
        MpdConnection.sendCommand("random " + (val ? "1" : "0"), function(){})
    }
    function setSingle(val) {
        MpdConnection.sendCommand("single " + (val ? "1" : "0"), function(){})
    }
    function setConsume(val) {
        MpdConnection.sendCommand("consume " + (val ? "1" : "0"), function(){})
    }

    function loadPlaylist() {
        if (!MpdConnection.connected) return
        MpdConnection.sendJson("queue", {}, function(ev) {
            if (ev && ev.ok && ev.queue) root._applyDaemonEvent({type: "queue", queue: ev.queue, version: ev.version})
        })
    }

    function clearQueue() {
        MpdConnection.sendCommand("clear", function(){})
    }
    function add(file) {
        // Quoting seguro en el daemon (mpdQuote); sin concatenar shell/MPD aquí.
        MpdConnection.sendJson("add", {file: file}, function(ev) {
            if (!ev || !ev.ok) console.log("[MpdState] add:", ev && ev.error)
        })
    }
    function addAndPlay(file) {
        // Daemon: addid + playid (reproduce lo añadido, no la posición actual).
        MpdConnection.sendJson("addplay", {file: file}, function(ev) {
            if (!ev || !ev.ok) console.log("[MpdState] addplay:", ev && ev.error)
        })
    }
    function removeById(id) {
        MpdConnection.sendCommand("deleteid " + id, function(){})
    }
    function shuffleQueue() {
        MpdConnection.sendCommand("shuffle", function(){})
    }

    // ── Filtros síncronos para Command Palette (mantener compat) ─────
    // Tope 300: la cola completa igual se muestra sin query.
    function filterPlaylist(query) {
        return MpdLogic.filterPlaylist(root.playlist, query, root.playlistPos)
    }

    function fmtTime(secs) {
        return TimeLogic.fmtTime(secs)
    }
}
