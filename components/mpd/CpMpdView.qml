import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../../state"

Item {
    id: root

    property bool active: false
    property bool running: false

    signal escapeEmpty()
    signal backToRoot()
    signal focusWrapper()

    readonly property string searchText: mpdList.searchText
    readonly property string sub: MpdState.subFor(searchText) || MpdState.resolveSub(searchText)
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
        mpdList.highlightDuration = 0
        Qt.callLater(function() { restorePos() })
    }

    function savePos() {
        if (!root.active || inSubView || mpdList.searchText.trim() !== "") return
        var idx = mpdList.currentIndex
        if (idx < 0 || idx >= items.length) return
        _savedFile = items[idx].file || ""
        _savedIndex = idx
        _savedY = mpdList.listView.contentY
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
    property int _savedIndex: -1
    property string _savedFile: ""
    property real _savedY: 0

    readonly property var subcategories: [
        { isCategory: true, category: MpdState.subPlaylist, name: "Playlist", description: "Playlists guardadas", icon: Icons.musicNote },
        { isCategory: true, category: MpdState.subArtist,   name: "Artist",   description: "Buscar por artista", icon: Icons.musicPlayer },
        { isCategory: true, category: MpdState.subAlbum,    name: "Album",    description: "Buscar por álbum", icon: Icons.image },
        { isCategory: true, category: MpdState.subPlDelete, name: "Delete Playlist", description: "Eliminar playlist guardada", icon: Icons.trash }
    ]

    readonly property bool inSubView: mpdList.searchText.trim().startsWith(TaskbarState.searchPrefix)
    readonly property bool inCategories: mpdList.searchText.trim() === TaskbarState.searchPrefix

    function sameItems(a, b) {
        if (!a || !b || a.length !== b.length) return false
        for (var i = 0; i < a.length; i++) {
            if (a[i].pos !== b[i].pos || (a[i].file || "") !== (b[i].file || "")
                || ((a[i].title || a[i].name || "") !== (b[i].title || b[i].name || ""))) return false
        }
        return true
    }

    function focusPlaying() {
        var idx = -1
        for (var i = 0; i < items.length; i++) {
            if (items[i].pos === MpdState.playlistPos) { idx = i; break }
        }
        if (idx >= 0) mpdList.selectIndex(idx)
        else mpdList.selectFirst()
    }

    function restorePos() {
        var idx = -1
        if (_savedFile !== "") {
            for (var i = 0; i < items.length; i++) {
                if (items[i].file === _savedFile) { idx = i; break }
            }
        }
        if (idx < 0 && _savedIndex >= 0 && _savedIndex < items.length) idx = _savedIndex
        if (idx < 0) {
            focusPlaying()
            mpdList.highlightDuration = 180
            return
        }
        mpdList.selectIndex(idx)
        var y = _savedY
        Qt.callLater(function() {
            mpdList.listView.contentY = y
            mpdList.highlightDuration = 180
        })
    }

    function filterMpd(q) {
        var text = q.trim()
        var px = TaskbarState.searchPrefix
        if (text === px) return
        var sub = MpdState.subFor(text) || MpdState.resolveSub(text)
        var rawQuery = text.replace(new RegExp("^" + px + "\\w+\\s*"), "").trim()
        var query = rawQuery.toLowerCase()
        var cacheKey = (sub || "_root") + "|" + query
        if (cacheKey === _lastQuery) return
        _lastQuery = cacheKey

        if (!sub && text.startsWith(px)) { items = []; return }

        if (sub === MpdState.subPlaylist || sub === MpdState.subPlDelete) {
            items = MpdState.savedPlaylists.filter(p => query === "" || p.name.toLowerCase().indexOf(query) >= 0)
            Qt.callLater(function(){ mpdList.selectFirst() })
            return
        }
        if (sub === MpdState.subArtist) {
            if (query === "") {
                MpdState.listArtists(function(list){
                    items = list.map(function(a){ return { name: a, query: a } })
                    Qt.callLater(function(){ mpdList.selectFirst() })
                })
            } else {
                MpdState.songsByFilter(MpdState.subArtist, rawQuery, function(songs){
                    if (songs.length > 0) {
                        items = songs.map(function(s){
                            return { name: s.title || s.file, title: s.title, artist: s.artist, album: s.album, file: s.file, pos: s.pos, duration: s.duration, isPlaying: false, query: s.artist }
                        })
                    } else {
                        items = MpdState.filterArtists(query)
                    }
                    Qt.callLater(function(){ mpdList.selectFirst() })
                })
            }
            return
        }
        if (sub === MpdState.subAlbum) {
            if (query === "") {
                MpdState.listAlbums(function(list){
                    items = list.map(function(a){ return { name: a, query: a } })
                    Qt.callLater(function(){ mpdList.selectFirst() })
                })
            } else {
                MpdState.songsByFilter(MpdState.subAlbum, rawQuery, function(songs){
                    if (songs.length > 0) {
                        items = songs.map(function(s){
                            return { name: s.title || s.file, title: s.title, artist: s.artist, album: s.album, file: s.file, pos: s.pos, duration: s.duration, isPlaying: false, query: s.album }
                        })
                    } else {
                        items = MpdState.filterAlbums(query)
                    }
                    Qt.callLater(function(){ mpdList.selectFirst() })
                })
            }
            return
        }
        if (query === "") {
            var all = MpdState.playlist
            var mapped = all.map(function(s){
                return { pos: s.pos, title: s.title || s.file, artist: s.artist, album: s.album, file: s.file, duration: s.duration, isPlaying: s.pos === MpdState.playlistPos, name: s.title || s.file, query: s.file }
            })
            if (sameItems(items, mapped)) return
            items = mapped
            Qt.callLater(function(){ focusPlaying() })
        } else {
            var fitems = MpdState.filterPlaylist(rawQuery).map(function(s){
                return { pos: s.pos, title: s.title, artist: s.artist, album: s.album, file: s.file, duration: s.duration, isPlaying: s.isPlaying, name: s.title || s.name || s.file, query: s.file }
            })
            if (sameItems(items, fitems)) return
            items = fitems
            Qt.callLater(function(){ mpdList.selectFirst() })
        }
    }

    function activateItem(item) {
        var sub = MpdState.subFor(mpdList.searchText) || MpdState.resolveSub(mpdList.searchText)
        if (sub === MpdState.subPlaylist) MpdState.playPlaylist(item.name)
        else if (sub === MpdState.subPlDelete) { MpdState.deletePlaylist(item.name); Qt.callLater(() => { items = MpdState.savedPlaylists; mpdList.selectFirst() }) }
        else if (sub === MpdState.subArtist) {
            mpdList.searchInput.setText(TaskbarState.searchPrefix + MpdState.subArtist + " " + item.query + " ");
            MpdState.songsByFilter(MpdState.subArtist, item.query, function(songs){
                items = songs.map(function(s){ return { name: s.title || s.file, title: s.title, artist: s.artist, album: s.album, file: s.file, pos: s.pos, duration: s.duration, isPlaying: false, query: s.artist } })
                Qt.callLater(function(){ mpdList.selectFirst() })
            })
        }
        else if (sub === MpdState.subAlbum) {
            mpdList.searchInput.setText(TaskbarState.searchPrefix + MpdState.subAlbum + " " + item.query + " ");
            MpdState.songsByFilter(MpdState.subAlbum, item.query, function(songs){
                items = songs.map(function(s){ return { name: s.title || s.file, title: s.title, artist: s.artist, album: s.album, file: s.file, pos: s.pos, duration: s.duration, isPlaying: false, query: s.album } })
                Qt.callLater(function(){ mpdList.selectFirst() })
            })
        }
        else {
            if (item.file && (item.pos === -1 || item.pos === undefined)) MpdState.addAndPlay(item.file)
            else MpdState.playFromPosition(item.pos)
        }
    }

    function activateFilterItem(q) {
        var sub = MpdState.subFor(mpdList.searchText) || MpdState.resolveSub(mpdList.searchText)
        if (sub === MpdState.subPlaylist) MpdState.playPlaylist(q)
        else if (sub === MpdState.subPlDelete) { MpdState.deletePlaylist(q); Qt.callLater(() => { items = MpdState.savedPlaylists; mpdList.selectFirst() }) }
        else {
            mpdList.searchInput.setText(TaskbarState.searchPrefix + sub + " " + q + " ");
            MpdState.songsByFilter(sub, q, function(songs){
                items = songs.map(function(s){ return { name: s.title || s.file, title: s.title, artist: s.artist, album: s.album, file: s.file, pos: s.pos, duration: s.duration, isPlaying: false, query: sub === MpdState.subArtist ? s.artist : s.album } })
                Qt.callLater(function(){ mpdList.selectFirst() })
            })
        }
    }

    Connections {
        target: MpdState
        property bool entering: false
        function onDaemonRunningChanged() {
            if (MpdState.daemonRunning && root.active)
                Qt.callLater(function() { root.focusSearch() })
        }
        function onPlaylistChanged() {
            if (!root.active) return
            _lastQuery = "%%"; filterMpd(mpdList.searchText)
            if (mpdList.searchText.trim() === "" || mpdList.searchText.trim() === TaskbarState.searchPrefix) {
                entering = true
                Qt.callLater(function() {
                    focusPlaying()
                    entering = false
                })
            } else {
                var i = mpdList.currentIndex
                Qt.callLater(() => mpdList.selectIndex(i))
            }
        }
        function onPlaylistPosChanged() {
            if (!root.active || root.inSubView) return
            var t = mpdList.searchText.trim()
            if (t !== "" && t !== TaskbarState.searchPrefix) return
            var pos = MpdState.playlistPos
            if (pos === undefined || pos === null || pos < 0) return
            var idx = -1
            for (var i = 0; i < items.length; i++) {
                if (items[i].pos === pos) { idx = i; break }
            }
            if (idx < 0) return
            var lv = mpdList.listView
            if (lv.currentIndex !== idx) mpdList.selectIndex(idx)
            lv.positionViewAtIndex(idx, ListView.Contain)
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
            visible: MpdState.daemonRunning && !root.inSubView && mpdList.searchText.trim() === "" && MpdState.recentSongs.length > 0
            items: MpdState.recentSongs
            loading: MpdState.recentSongs.length === 0
            accent: root.tint
            textAccent: root.tintText
            onTrackRequested: file => MpdState.playFile(file)
        }

        PanelList {
            id: mpdList
            Layout.fillWidth: true; Layout.fillHeight: true
            model: root.inCategories ? root.subcategories : root.items
            showSearch: false
            searchPlaceholder: {
                if (root.inCategories) return "Seleccionar categoría…"
                if (root.inSubView) {
                    if (root.sub === MpdState.subPlaylist) return "Buscar playlist…"
                    if (root.sub === MpdState.subArtist) return "Buscar artista…"
                    if (root.sub === MpdState.subAlbum) return "Buscar álbum…"
                    if (root.sub === MpdState.subPlDelete) return "Eliminar playlist…"
                    return "Prefijo desconocido…"
                }
                return "Buscar música  ·  > para filtrar…"
            }
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
                sourceComponent: {
                    if (root.inCategories) return categoryComponent
                    if (root.inSubView && root.sub !== "") return mpdFilterComponent
                    return mpdComponent
                }
                Binding { target: item; property: "itemData"; value: modelData; when: status === Loader.Ready }
                Binding { target: item; property: "itemIndex"; value: index; when: status === Loader.Ready }
                Binding { target: item; property: "isSelected"; value: mpdList.currentIndex === index; when: status === Loader.Ready }
                Binding { target: item; property: "isPlaying"; value: (modelData.pos ?? -1) === MpdState.playlistPos; when: status === Loader.Ready && item && item.hasOwnProperty("isPlaying") }
                Binding { target: item; property: "progress"; value: (modelData.pos ?? -1) === MpdState.playlistPos ? (_pos / (MpdState.duration || 1)) : 0; when: status === Loader.Ready && item && item.hasOwnProperty("progress") }
                Binding { target: item; property: "accent"; value: root.tint; when: status === Loader.Ready && item && item.hasOwnProperty("accent") }
                Binding { target: item; property: "textAccent"; value: root.tintText; when: status === Loader.Ready && item && item.hasOwnProperty("textAccent") }
                Binding { target: item; property: "hoverColor"; value: root.hover; when: status === Loader.Ready && item && item.hasOwnProperty("hoverColor") }
                Binding { target: item; property: "useAccent"; value: true; when: status === Loader.Ready && item && item.hasOwnProperty("useAccent") }
            }
        }

        SmartSearchInput {
            id: mpdSearchInput
            bgColor: Style.surface_container
            // Sin daemon no hay con qué interactuar: se oculta (colapsa en el layout).
            visible: MpdState.daemonRunning
            Layout.fillWidth: true
            Layout.leftMargin: 10; Layout.rightMargin: 10
            Layout.bottomMargin: 10
            Layout.preferredHeight: 44
            placeholder: mpdList.searchPlaceholder
            text: mpdList.searchText
            onQueryChanged: text => {
                mpdList.searchText = text
                if (text === TaskbarState.searchPrefix) {
                    items = subcategories
                    mpdList.selectFirst()
                    return
                }
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

        // ── Sidebar derecho fijo: cover full-h + degradado + controles ──
        Rectangle {
            Layout.preferredWidth: 264; Layout.fillHeight: true
            Layout.leftMargin: 10; Layout.rightMargin: 12
            Layout.topMargin: 8; Layout.bottomMargin: 10
            visible: MpdState.daemonRunning || MpdState.playlist.length > 0
            radius: 12
            color: root.card
            clip: true

            // Cover inset con padding + contenido encima
            Item {
                anchors.fill: parent
                anchors.margins: 10
                clip: true

                Rectangle {
                    anchors.fill: parent; radius: 18
                    color: root.hover
                }
                RoundedImage {
                    anchors.fill: parent
                    radius: 18
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
                    radius: 18
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

    Component {
        id: categoryComponent
        CpCategoryDelegate {
            onCategorySelected: cat => {
                mpdList.searchInput.setText(TaskbarState.searchPrefix + cat + " ")
                Qt.callLater(function() { mpdList.forceSearchFocus(); mpdList.selectFirst() })
            }
        }
    }
    Component { id: mpdComponent; CpMpdDelegate { panelWidth: 640; onTrackActivated: (pos, file) => {
                if (file && (pos === -1 || pos === undefined)) MpdState.addAndPlay(file)
                else MpdState.playFromPosition(pos)
            } } }
    Component {
        id: mpdFilterComponent
        CpMpdFilterDelegate {
            panelWidth: 640
            onItemActivated: q => activateFilterItem(q)
        }
    }
}
