import Quickshell.Services.Mpris

pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  
  property string _forcedPlayerDbus: ""

    // Sticky: último player que entró en Playing (vale para mpv, vlc,
    // spotify, firefox, MPD... — se trackea por dbusName, sin casos por app).
    // Pausar NO destrona: solo otro play explícito, cierre o Stopped cambian.
    property string _stickyDbus: ""
    property var _prevStates: ({})  // dbusName -> último playbackState visto

    // MPD player filtrado (para popup de MPD)
    readonly property var _mpdPlayer: {
        var players = Mpris.players.values
        for (var i = 0; i < players.length; i++) {
            var p = players[i]
            if (p.identity === "MPD" || p.desktopEntry === "mpd-mpris")
                return p
        }
        return null
    }

    // Arte del player MPD (mpd-mpris expone mpris:artUrl del tema actual)
    readonly property string mpdArtUrl: _mpdPlayer ? _mpdPlayer.trackArtUrl : ""

    // Escritura diferida del sticky: el binding lo detecta pero NO lo
    // escribe sincrónicamente (eso Qt lo reporta como binding loop).
    // El valor que retorna cada evaluación ya es correcto igual (paso 4).
    function _setSticky(dbus) {
        if (dbus === "" || dbus === _stickyDbus) return
        Qt.callLater(function() {
            if (dbus !== _stickyDbus) _stickyDbus = dbus
        })
    }

    // Active player: forced > sticky (último en darle play, si sigue
    // presente y no está Stopped — vale Paused) > Playing > Paused > any.
    readonly property var _activeMprisPlayer: {
        var players = Mpris.players.values
        var i, p, st

        // 1. Detectar transiciones a Playing (incluye "ya sonaba al aparecer").
        //    Mutar el contenido de _prevStates no emite señales: seguro acá.
        //    Se purgan los players cerrados para no acumular claves.
        var latestPlaying = ""
        var seen = {}
        for (i = 0; i < players.length; i++) {
            p = players[i]
            st = p.playbackState
            seen[p.dbusName] = true
            if (st === MprisPlaybackState.Playing && _prevStates[p.dbusName] !== MprisPlaybackState.Playing)
                latestPlaying = p.dbusName
            _prevStates[p.dbusName] = st
        }
        for (var old in _prevStates) {
            if (!seen[old]) delete _prevStates[old]
        }
        if (latestPlaying !== "")
            _setSticky(latestPlaying)

        // 2. Forzado manual (musicSetActivePlayer)
        if (_forcedPlayerDbus !== "") {
            for (i = 0; i < players.length; i++)
                if (players[i].dbusName === _forcedPlayerDbus) return players[i]
        }

        // 3. Sticky + fallback clásico
        var sticky = null, playing = null, paused = null, any = null
        for (i = 0; i < players.length; i++) {
            p = players[i]
            if (!any) any = p
            if (p.dbusName === _stickyDbus && p.playbackState !== MprisPlaybackState.Stopped)
                sticky = p
            if (p.playbackState === MprisPlaybackState.Playing && !playing) playing = p
            if (p.playbackState === MprisPlaybackState.Paused && !paused) paused = p
        }

        // 4. Si otro distinto al sticky está sonando, gana él (y pasa a
        //    ser el sticky) — así el play en Firefox/VLC sí cambia.
        if (playing && (!sticky || playing.dbusName !== sticky.dbusName)) {
            _setSticky(playing.dbusName)
            return playing
        }
        return sticky || playing || paused || any
    }

    // Propiedades públicas (mismos nombres que antes para compatibilidad)
    readonly property string musicPlayer: _activeMprisPlayer ? _activeMprisPlayer.dbusName : ""
    readonly property bool musicPlaying: _activeMprisPlayer ? _activeMprisPlayer.isPlaying : false
    readonly property string musicTitle: _activeMprisPlayer ? _activeMprisPlayer.trackTitle : ""
    readonly property string musicArtist: _activeMprisPlayer ? _activeMprisPlayer.trackArtist : ""
    readonly property string musicArtUrl: _activeMprisPlayer ? _activeMprisPlayer.trackArtUrl : ""
    readonly property real musicLength: _activeMprisPlayer ? _activeMprisPlayer.length : 0

    // Position: la lee cada popup con su propio timer gateado por isOpen.
    // Sin timer global acá.

    // Lista de players activos (para el popup)
    readonly property var musicPlayerList: {
        var list = []
        var players = Mpris.players.values
        var activeDbus = _activeMprisPlayer ? _activeMprisPlayer.dbusName : ""
        for (var i = 0; i < players.length; i++) {
            var p = players[i]
            list.push({
                name:   p.identity || p.dbusName.replace("org.mpris.MediaPlayer2.", ""),
                dbusName: p.dbusName,
                isActive: p.dbusName === activeDbus,
                status: p.playbackState === MprisPlaybackState.Playing ? "Playing" :
                        p.playbackState === MprisPlaybackState.Paused ? "Paused" : "Stopped",
                artist: p.trackArtist,
                title:  p.trackTitle,
                artUrl: p.trackArtUrl,
                volumeSupported: p.volumeSupported,
                volume: p.volumeSupported ? Math.round(p.volume * 100) : 100,
                isPlaying: p.playbackState === MprisPlaybackState.Playing
            })
        }
        return list
    }

    // ─ Controles — MPRIS nativo (player activo) ────────────────────────
    function musicSetActivePlayer(dbusName) {
        _forcedPlayerDbus = dbusName
    }
    function musicPlayPause() {
        if (_activeMprisPlayer) _activeMprisPlayer.togglePlaying()
    }
    function musicPlay() {
        if (_activeMprisPlayer) _activeMprisPlayer.play()
    }
    function musicPause() {
        if (_activeMprisPlayer) _activeMprisPlayer.pause()
    }
    function musicPrev() {
        if (_activeMprisPlayer) _activeMprisPlayer.previous()
    }
    function musicNext() {
        if (_activeMprisPlayer) _activeMprisPlayer.next()
    }

    // ─ Controles específicos para MPD (target _mpdPlayer) ──────────────
    function mpdPlay() {
        if (_mpdPlayer) _mpdPlayer.play()
    }
    function mpdPause() {
        if (_mpdPlayer) _mpdPlayer.pause()
    }
    function mpdPlayPause() {
        if (_mpdPlayer) _mpdPlayer.togglePlaying()
    }
    function mpdPrev() {
        if (_mpdPlayer) _mpdPlayer.previous()
    }
    function mpdNext() {
        if (_mpdPlayer) _mpdPlayer.next()
    }
    function mpdSeek(seconds) {
        if (_mpdPlayer) _mpdPlayer.seek((seconds - _mpdPlayer.position) * 1000000)
    }
    function mpdSetVolume(level) {
        if (_mpdPlayer) _mpdPlayer.volume = Math.max(0, Math.min(100, level)) / 100.0
    }

    function setPlayerVolume(dbusName, level) {
        var players = Mpris.players.values
        for (var i = 0; i < players.length; i++) {
            if (players[i].dbusName === dbusName) {
                players[i].volume = Math.max(0, Math.min(1, level / 100))
                return
            }
        }
    }

    function togglePlayerPlayPause(dbusName) {
        var players = Mpris.players.values
        for (var i = 0; i < players.length; i++) {
            if (players[i].dbusName === dbusName) {
                players[i].togglePlaying()
                return
            }
        }
    }
}
