// CpMpdView.qml — Vista MPD: cola única sobre PanelList (compartida por
// el panel "mpd" de PanelPopupHost y el tab Música del Hub).
//
// Diseño:
//   - Sin subvistas ni prefijos (`>` retirado): solo cola + filtro de texto.
//   - Sin restauración de posición al reabrir: el panel entra siempre en
//     la primera fila (PanelList) y no sigue/salta al track sonando.
//   - Recientes (CpRecentStrip): slot estático con fallback — skeletons
//     mientras espera datos o con el daemon apagado; cartas con datos; se
//     oculta solo si el daemon activo respondió sin recientes.
//   - Slots estáticos: buscador, sidebar y recientes están siempre presentes
//     (la vista no se reflowea cuando el daemon conecta después de abrir).
//   - Cover full-bleed en la sidebar derecha (sin padding externo; los
//     controles conservan su margen interno).
//   - Focus único: el hover mueve el currentIndex (norma hoverSelects del
//     PanelList); el delegado no pinta hover propio. La fila sonando se
//     distingue con wash del cover (y pill sólida con playingBg).

import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../../state"

Item {
    id: root

    property bool active: false
    property bool running: false
    // Bg sólido en la fila en reproducción (opt-in; lo usa MpdPopup).
    property bool playingRowBg: false

    signal escapeEmpty()
    signal backToRoot()
    signal focusWrapper()

    readonly property string searchText: mpdList.searchText
    readonly property real _pos: MpdState.elapsed

    function moveUp() { mpdList.moveUp() }
    function moveDown() { mpdList.moveDown() }
    function selectFirst() { mpdList.selectFirst() }
    function activateCurrent() { mpdList.activate() }
    function clearSearch() { mpdList.clearSearch() }
    function appendText(t) { mpdSearchInput.forceActiveFocus(); mpdSearchInput.appendText(t) }
    function focusSearch() { mpdSearchInput.forceActiveFocus() }

    function enter() {
        mpdList.clearSearch()
        filterMpd("")
    }

    readonly property string bgSource: MprisState.mpdArtUrl !== "" ? MprisState.mpdArtUrl.replace(/#/g, "%23") : ""

    ColorQuantizer {
        id: quant
        source: root.bgSource
        depth: 3
        rescaleSize: 64
    }

    function colorSaturation(c) {
        var mx = Math.max(c.r, c.g, c.b), mn = Math.min(c.r, c.g, c.b)
        return mx <= 0 ? 0 : (mx - mn) / mx
    }

    function sortedBySaturation() {
        var arr = []
        for (var i = 0; i < quant.colors.length; i++) arr.push(quant.colors[i])
        arr.sort(function(a, b) { return colorSaturation(b) - colorSaturation(a) })
        return arr
    }

    property var palette: []
    Connections {
        target: quant
        function onColorsChanged() { root.palette = root.sortedBySaturation() }
    }

    property color accent1: {
        if (palette.length === 0) return Style.primary
        return Style.dark ? mixTint(palette[0], "#FFFFFF", 0.15) : palette[0]
    }
    readonly property bool live: MpdState.musicPlaying
    property color tint: (root.active && live) ? accent1 : Style.primary

    function colorLightness(c) {
        return (Math.max(c.r, c.g, c.b) + Math.min(c.r, c.g, c.b)) / 2
    }

    property color tintText: {
        if (!root.active || !live || palette.length === 0) return Style.primary
        var best = palette[0], bestL = colorLightness(best)
        for (var i = 1; i < palette.length; i++) {
            var l = colorLightness(palette[i])
            if (Style.dark ? (l > bestL) : (l < bestL)) { best = palette[i]; bestL = l }
        }
        if (Style.dark && bestL < 0.55) return "#FFFFFF"
        if (!Style.dark && bestL > 0.45) return "#1a1a1a"
        if (Style.dark) return mixTint(best, "#FFFFFF", 0.6)
        return mixTint(best, "#1a1a1a", 0.6)
    }

    function mixTint(base, tint, amount) {
        var b = Qt.color(base), t = Qt.color(tint)
        var a = Math.max(0, Math.min(1, amount))
        return Qt.rgba(b.r + (t.r - b.r) * a, b.g + (t.g - b.g) * a, b.b + (t.b - b.b) * a, 1)
    }

    readonly property bool surfaceOn: root.active && root.bgSource !== "" && live
    property color surface: surfaceOn ? mixTint(Style.surface_container_lowest, accent1, 0.15) : Style.surface_container_lowest
    property color hover: surfaceOn ? mixTint(Style.surface_container_highest, accent1, 0.35) : Style.surface_container_highest
    property color card: surfaceOn ? mixTint(Style.surface_container_high, accent1, 0.30) : Style.surface_container_high
    property color focusBg: {
        if (!surfaceOn) return Qt.alpha(Style.primary, 0.1)
        if (Style.dark) return Qt.alpha(mixTint(accent1, "#FFFFFF", 0.35), 0.45)
        return Qt.alpha(accent1, 0.22)
    }

    property var items: []
    property string _lastQuery: ""

    function sameItems(a, b) {
        if (!a || !b || a.length !== b.length) return false
        for (var i = 0; i < a.length; i++) {
            if (a[i].pos !== b[i].pos || (a[i].file || "") !== (b[i].file || "")
                || ((a[i].title || a[i].name || "") !== (b[i].title || b[i].name || ""))) return false
        }
        return true
    }

    function filterMpd(q) {
        var text = q.trim()
        var query = text.toLowerCase()
        var cacheKey = "_root|" + query
        if (cacheKey === _lastQuery) return
        _lastQuery = cacheKey

        if (query === "") {
            var all = MpdState.playlist
            var mapped = all.map(function(s){
                return { pos: s.pos, title: s.title || s.file, artist: s.artist, album: s.album, file: s.file, duration: s.duration, isPlaying: s.pos === MpdState.playlistPos, name: s.title || s.file, query: s.file }
            })
            if (sameItems(items, mapped)) return
            items = mapped
        } else {
            var fitems = MpdState.filterPlaylist(text).map(function(s){
                return { pos: s.pos, title: s.title, artist: s.artist, album: s.album, file: s.file, duration: s.duration, isPlaying: s.isPlaying, name: s.title || s.name || s.file, query: s.file }
            })
            if (sameItems(items, fitems)) return
            items = fitems
            Qt.callLater(function(){ mpdList.selectFirst() })
        }
    }

    function activateItem(item) {
        if (item.file && (item.pos === -1 || item.pos === undefined)) MpdState.addAndPlay(item.file)
        else MpdState.playFromPosition(item.pos)
    }

    Connections {
        target: MpdState
        function onDaemonRunningChanged() {
            if (MpdState.daemonRunning && root.active)
                Qt.callLater(function() { root.focusSearch() })
        }
        function onPlaylistChanged() {
            if (!root.active) return
            _lastQuery = "%%"; filterMpd(mpdList.searchText)
            var i = mpdList.currentIndex
            Qt.callLater(() => mpdList.selectIndex(i))
        }
    }

    // Fondo de la vista: se tiñe con el arte del disco al reproducir
    // (la transición vive en `surface`, sin Behavior local).
    Rectangle {
        anchors.fill: parent
        color: root.surface
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Izquierda: recientes + lista + buscador
        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: 0

        CpRecentStrip {
            Layout.fillWidth: true
            // Slot estático con fallback: con MPD inactivo muestra skeletons
            // (items vacíos + loading); se oculta solo si el daemon está
            // activo y respondió sin recientes.
            visible: MpdState.daemonRunning || MpdState.recentSongs.length > 0 || !MpdState.recentLoaded
            items: MpdState.daemonRunning ? MpdState.recentSongs : []
            loading: !MpdState.daemonRunning || MpdState.recentSongs.length === 0
            accent: root.tint
            textAccent: root.tintText
            onTrackRequested: file => MpdState.playFile(file)
        }

        PanelList {
            id: mpdList
            Layout.fillWidth: true; Layout.fillHeight: true
            model: root.items
            showSearch: false
            searchPlaceholder: "Buscar música…"
            preserveIndexOnModelChange: true
            highlightDuration: 180
            accent: root.tint
            highlightBg: root.focusBg
            emptyIcon: !MpdState.daemonRunning ? Icons.power : Icons.question
            emptyTitle: !MpdState.daemonRunning ? "MPD detenido" : "Sin resultados"
            emptySubtitle: !MpdState.daemonRunning ? "El daemon no está corriendo" : "Intentá otra búsqueda"
            emptySearchTitle: !MpdState.daemonRunning ? "MPD detenido" : "Sin resultados"
            emptySearchSubtitle: !MpdState.daemonRunning ? "El daemon no está corriendo" : "Intentá otra búsqueda"
            emptyActions: !MpdState.daemonRunning ? [
                { label: "Iniciar MPD + MPRIS", icon: Icons.musicPlay }
            ] : []
            onEmptyActionTriggered: MpdState.startStack()
            onSearchEmptyBackspace: root.focusWrapper()
            onItemActivated: index => {
                var m = model; if (!m || index < 0) return
                var item = m.get ? m.get(index) : m[index]; if (!item) return
                activateItem(item)
            }
            delegate: Loader {
                width: ListView.view ? ListView.view.width : 640
                required property var modelData; required property int index
                sourceComponent: mpdComponent
                Binding { target: item; property: "itemData"; value: modelData; when: status === Loader.Ready }
                Binding { target: item; property: "itemIndex"; value: index; when: status === Loader.Ready }
                Binding { target: item; property: "isSelected"; value: mpdList.currentIndex === index; when: status === Loader.Ready }
                Binding { target: item; property: "isPlaying"; value: (modelData.pos ?? -1) === MpdState.playlistPos; when: status === Loader.Ready && item && item.hasOwnProperty("isPlaying") }
                Binding { target: item; property: "progress"; value: (modelData.pos ?? -1) === MpdState.playlistPos ? (_pos / (MpdState.duration || 1)) : 0; when: status === Loader.Ready && item && item.hasOwnProperty("progress") }
                Binding { target: item; property: "accent"; value: root.tint; when: status === Loader.Ready && item && item.hasOwnProperty("accent") }
                Binding { target: item; property: "textAccent"; value: root.tintText; when: status === Loader.Ready && item && item.hasOwnProperty("textAccent") }
                Binding { target: item; property: "hoverColor"; value: root.hover; when: status === Loader.Ready && item && item.hasOwnProperty("hoverColor") }
                Binding { target: item; property: "useAccent"; value: true; when: status === Loader.Ready && item && item.hasOwnProperty("useAccent") }
                Binding { target: item; property: "playingBg"; value: root.playingRowBg; when: status === Loader.Ready && item && item.hasOwnProperty("playingBg") }
            }
        }

        SmartSearchInput {
            id: mpdSearchInput
            bgColor: Style.surface_container
            // Siempre visible: los slots de la vista son estáticos para que
            // nada se reflowee cuando el daemon conecta después de abrir.
            Layout.fillWidth: true
            Layout.leftMargin: 10; Layout.rightMargin: 10
            Layout.bottomMargin: 10
            Layout.preferredHeight: 44
            placeholder: mpdList.searchPlaceholder
            text: mpdList.searchText
            onQueryChanged: text => {
                mpdList.searchText = text
                _lastQuery = "%%"
                filterMpd(text)
                mpdList.selectFirst()
            }
            onUpPressed:        mpdList.moveUp()
            onDownPressed:      mpdList.moveDown()
            onReturnPressed:    mpdList.activate()
            onEmptyBackspace:   root.focusWrapper()
            onEscapePressed: {
                if (mpdList.searchText === "") root.escapeEmpty()
                else mpdList.clearSearch()
            }
            onSuperPressed: TaskbarState.activePopup = ""
            onBackspaceOnEmpty: {
                if (!TaskbarState.rootLocked) root.backToRoot()
            }
        }
        } // ← cierra la columna izquierda

        // ── Sidebar derecho: cover full-bleed + degradado + controles ──
        // (slot estático: visible aunque el daemon no esté conectado)
        Rectangle {
            Layout.preferredWidth: 264; Layout.fillHeight: true
            Layout.leftMargin: 10
            radius: 12
            color: root.card
            clip: true

            // Cover a sangre (sin padding externo); el contenido lleva
            // su propio margen interno.
            Item {
                anchors.fill: parent
                clip: true

                Rectangle {
                    anchors.fill: parent; radius: 12
                    color: root.hover
                }
                RoundedImage {
                    anchors.fill: parent
                    radius: 12
                    source: root.bgSource
                    sourceSize: Qt.size(528, 0)
                    visible: root.bgSource !== ""
                }
                Text {
                    anchors.centerIn: parent
                    visible: root.bgSource === ""
                    text: Icons.musicNote
                    font.pixelSize: 48; font.family: Icons.font
                    color: Style.on_surface_variant
                }
                Rectangle {
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Math.min(parent.height * 0.55, 300)
                    radius: 12
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.82) }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Item { Layout.fillWidth: true; Layout.fillHeight: true }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            Layout.fillWidth: true
                            text: MpdState.currentTitle !== "" ? MpdState.currentTitle : "Sin reproducción"
                            font.pixelSize: Config.fontSizeBody; font.weight: Config.fontWeightBold; font.family: Config.uiFont
                            color: "#FFFFFF"
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: MpdState.currentArtist !== ""
                            text: MpdState.currentArtist
                            font.pixelSize: Config.fontSizeCaption; font.family: Config.uiFont
                            color: Qt.rgba(1, 1, 1, 0.75)
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    MprisControl {
                        Layout.alignment: Qt.AlignHCenter
                        prevH: 34; prevW: 34
                        toggleW: 52; toggleH: 34
                        nextH: 34; nextW: 34
                        iconSize: 20
                        playing: MpdState.musicPlaying
                        prevColor: (root.bgSource !== "" && root.live) ? Qt.rgba(1, 1, 1, 0.9) : Style.on_surface_variant
                        nextColor: (root.bgSource !== "" && root.live) ? Qt.rgba(1, 1, 1, 0.9) : Style.on_surface_variant
                        prevHoverColor: (root.bgSource !== "" && root.live) ? Qt.rgba(1, 1, 1, 0.2) : Style.surface_container_highest
                        nextHoverColor: (root.bgSource !== "" && root.live) ? Qt.rgba(1, 1, 1, 0.2) : Style.surface_container_highest
                        toggleColor: (root.bgSource !== "" && root.live) ? root.accent1 : Style.primary
                        toggleTextColor: (root.bgSource !== "" && root.live) ? Config._contrastOn(root.accent1) : Style.on_primary
                        toggleHoverColor: Qt.darker((root.bgSource !== "" && root.live) ? root.accent1 : Style.primary, 1.2)
                        prevAction: function() { MpdState.previous() }
                        toggleAction: function() { MpdState.togglePause() }
                        nextAction: function() { MpdState.next() }
                    }

                    SeekBar {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 18
                        ratio: MpdState.duration > 0 ? (root._pos / MpdState.duration) : 0
                        animations: root.running
                        tickMode: true
                        trackColor: (root.bgSource !== "" && root.live) ? Qt.rgba(1, 1, 1, 0.25) : Style.surface_variant
                        activeColor: (root.bgSource !== "" && root.live) ? root.accent1 : Style.primary
                        onSeekAt: r => MpdState.seek(r * MpdState.duration)
                    }
                }
            }
        }
    }

    Component { id: mpdComponent; CpMpdDelegate { panelWidth: 640; onTrackActivated: (pos, file) => {
                if (file && (pos === -1 || pos === undefined)) MpdState.addAndPlay(file)
                else MpdState.playFromPosition(pos)
            } } }
}
