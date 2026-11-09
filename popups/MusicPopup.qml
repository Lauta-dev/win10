// MusicPopup.qml — Player MPRIS en el panel "music" de PanelPopupHost.
// Se abre desde el widget de música de la barra (tapa del vinilo / título).
//
// Si el player activo es MPD el popup se expande a la derecha y muestra la
// cola de MPD (la levanta MpdConnection con polling solo mientras está
// abierto en modo MPD). El borde izquierdo queda fijo: el ancho crece hacia
// la derecha y `viewX` acompaña la animación.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "../state"
import "../components"

Item {
    id: root
    // ── API de PanelPopupHost ──
    // El shell ya no da el tamaño: la vista mide lo que informa al host.
    width: viewWidth
    height: viewHeight
    // Ancho dinámico: crece a la derecha al abrir la cola MPD; viewX
    // acompaña para que el borde izquierdo (y el player) queden fijos.
    // (escritura porque la anima el Behavior; el host solo la lee)
    property real viewWidth: root._baseW + (root.showQueue ? root._queueW : 0)
    readonly property real viewHeight: 346
    readonly property real viewX: TaskbarState.popupX + (root.viewWidth - root._baseW) / 2
    readonly property bool viewOpen: TaskbarState.panel === "music"
    Behavior on viewWidth {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    readonly property real _baseW: 396
    readonly property real _queueW: 288

    // Lista de players activos (botón de la esquina)
    property bool _plOpen: false

    readonly property var allPlayers: Mpris.players.values
    readonly property var players: {
        var list = []
        for (var i = 0; i < allPlayers.length; i++)
            if (allPlayers[i].trackTitle !== "")
                list.push(allPlayers[i])
        return list
    }
    readonly property var player: {
        if (MprisState.musicTitle === "") return null
        for (var i = 0; i < allPlayers.length; i++)
            if (allPlayers[i].dbusName === MprisState.musicPlayer) return allPlayers[i]
        return null
    }
    readonly property bool hasPlayer: MprisState.musicTitle !== "" && player !== null
    // Nombre del player para el botón (recortado si es muy largo).
    readonly property string playerLabel: {
        var n = player ? (player.identity || "Player") : ""
        return n.length > 18 ? n.substring(0, 17) + "…" : n
    }
    property real _pos: 0
    readonly property real _ratio: {
        if (!player || !player.positionSupported || !(player.length > 0)) return 0
        return Math.min(1, Math.max(0, _pos / player.length))
    }

    // ── MPD: quién está seleccionado y si toca mostrar la cola ─────────
    readonly property var _selectedPlayer: {
        for (var i = 0; i < allPlayers.length; i++)
            if (allPlayers[i].dbusName === MprisState.musicPlayer) return allPlayers[i]
        return null
    }
    readonly property bool isMpd: _selectedPlayer !== null
        && (_selectedPlayer.identity === "MPD" || _selectedPlayer.desktopEntry === "mpd-mpris")
    readonly property bool showQueue: isMpd

    onViewOpenChanged: {
        if (!viewOpen) _plOpen = false
        _syncMpd()
    }
    onShowQueueChanged: _syncMpd()

    // El bridge MPD vive atado al popup: polling solo con la cola a la vista.
    function _syncMpd() {
        var live = root.viewOpen && root.showQueue
        MpdConnection.setPollingConsumer("music", live)
        if (!live) { mpdRetry.stop(); return }
        MpdConnection.ensureConnected()
        if (MpdConnection.connected) Qt.callLater(root._loadQueue)
        else mpdRetry.restart()
    }

    function _loadQueue() {
        if (!MpdConnection.connected) return
        MpdState.loadPlaylist()
        Qt.callLater(root._scrollToCurrent)
    }

    function _scrollToCurrent() {
        var pos = MpdState.playlistPos
        if (pos >= 0 && pos < queueList.count)
            queueList.positionViewAtIndex(pos, ListView.Contain)
    }

    Timer {
        id: mpdRetry
        interval: 700
        repeat: false
        onTriggered: if (root.viewOpen && root.showQueue && MpdConnection.connected) root._loadQueue()
    }

    Connections {
        target: MpdConnection
        function onConnectedChanged() {
            if (MpdConnection.connected && root.viewOpen && root.showQueue)
                Qt.callLater(root._loadQueue)
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.viewOpen
        triggeredOnStart: true
        onTriggered: {
            if (!seek.seeking && root.player && root.player.positionSupported)
                root._pos = root.player.position
        }
    }

    // ── Reproductor (ancho fijo) ───────────────────────────────────────
    Item {
        id: playerPane
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root._baseW

        // ── Fondo: la carátula del track, con degradado abajo→arriba ───────
        RoundedImage {
            id: bgArt
            anchors.fill: parent
            radius: Style.popup_radius
            fillMode: Image.PreserveAspectCrop
            source: root.player ? (root.player.trackArtUrl || "") : ""
            sourceSize: Qt.size(root._baseW, root.viewHeight)
        }

        // ── Player: cover grande · título · artista · seek · controles ──
        Rectangle {
            id: bottomBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 5
            anchors.rightMargin: 5
            anchors.bottomMargin: 5
            radius: Style.popup_radius
            color: Qt.rgba(0, 0, 0, 0.6)
            visible: root.hasPlayer
            height: infoCol.height + controlsRow.height + 12

            Column {
                id: infoCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 8
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 3

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    maximumLineCount: 1
                    text: root.player
                        ? (root.player.trackTitle || root.player.identity || "Player")
                        : ""
                    font.pixelSize: Config.fontSizeTitle
                    font.family: Config.uiFont
                    font.weight: Font.DemiBold
                    color: Style.on_surface
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    maximumLineCount: 1
                    opacity: root.player && root.player.trackArtist !== "" ? 1 : 0
                    text: root.player ? (root.player.trackArtist || "") : ""
                    font.pixelSize: Config.fontSizeBodySm
                    font.family: Config.uiFont
                    color: Style.on_surface_variant
                    elide: Text.ElideRight
                }

                SeekBar {
                    id: seek
                    width: parent.width
                    height: 18
                    ratio: root._ratio
                    activeColor: Style.primary
                    trackColor: Style.surface_container_highest
                    onSeekAt: ratio01 => {
                        var p = root.player
                        if (!p || !p.positionSupported || !(p.length > 0)) return
                        var target = ratio01 * p.length
                        if (p.canSeek) p.position = target
                        else p.seek((target - p.position) * 1000000)
                        root._pos = target
                    }
                    onWheelMoved: direction => {
                        var p = root.player
                        if (!p || !p.positionSupported || !p.canSeek) return
                        p.seek(direction > 0 ? 5000000 : -5000000)
                    }
                }
            }

            Item {
                id: controlsRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.bottomMargin: 8
                height: 36

                PillButton {
                    id: playersBtn
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    size: 32
                    customRadius: height / 2
                    label: root.playerLabel
                    customContainerColor: "transparent"
                    customTextColor: Style.on_surface
                    onClicked: root._plOpen = !root._plOpen
                }

                    MprisControl {
                        id: controls
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        customRadius: -1
                        toggleRadius: 8
                    playing: root.player ? root.player.isPlaying : false
                    prevAction: function() { if (root.player) root.player.previous() }
                    toggleAction: function() { if (root.player) root.player.togglePlaying() }
                    nextAction: function() { if (root.player) root.player.next() }
                    toggleColor: Style.primary
                    toggleTextColor: Style.on_primary
                    toggleHoverColor: Qt.darker(Style.primary, 1.2)
                    prevColor: Style.on_surface_variant
                    nextColor: Style.on_surface_variant
                    prevHoverColor: Style.interactive_bg
                    nextHoverColor: Style.interactive_bg
                }
            }
        }

        // Fallback: sin track activo
        Row {
            visible: !root.hasPlayer
            anchors.centerIn: parent
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.musicNoteOff
                font.pixelSize: Config.fontSizeIconLg
                font.family: Icons.font
                color: Style.on_surface_variant
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Sin reproducción"
                font.pixelSize: Config.fontSizeBodySm
                font.family: Config.uiFont
                color: Style.on_surface_variant
            }
        }

        // ── Lista de players (dentro del popup → mask) ─────────────────
        Item {
            id: plOverlay
            anchors.fill: parent
            z: 10
            // Visible mientras la lista está abierta o terminando de salir.
            visible: root._plOpen || plPanel.opacity > 0.001

            // Clic fuera de la lista: cierra
            Mouse {
                anchors.fill: parent
                cursorShape: Qt.ArrowCursor
                onClicked: root._plOpen = false
            }

                Rectangle {
                    id: plPanel
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 60   // arriba de la fila de controles
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 250
                    height: Math.min(root.players.length * 46 + 8, parent.height - 76)
                    radius: 10
                    color: Style.surface_container_low
                    clip: true

                // Entrada/salida: crece desde abajo, pegado al botón.
                transformOrigin: Item.Bottom
                opacity: root._plOpen ? 1.0 : 0.0
                scale: root._plOpen ? 1.0 : 0.88
                transform: Translate {
                    y: root._plOpen ? 0 : 8
                    Behavior on y {
                        NumberAnimation {
                            duration: root._plOpen ? 220 : 140
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: root._plOpen ? 220 : 140
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: root._plOpen ? 220 : 140
                        easing.type: Easing.OutCubic
                    }
                }

                    ListView {
                        id: plList
                        anchors.fill: parent
                        anchors.margins: 4
                        model: root.players
                        spacing: 2
                        clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height

                    delegate: Item {
                        id: plRow
                        required property var modelData
                        width: plList.width
                        height: 44

                        readonly property bool isActive: modelData.dbusName === MprisState.musicPlayer

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: Style.interactive_bg
                            opacity: plRowHover.hovered ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                        }

                        Row {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Item {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 28; height: 28

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    color: Style.surface_container_highest
                                    visible: plArt.status !== Image.Ready
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: plArt.status !== Image.Ready
                                    text: Icons.musicNote
                                    font.pixelSize: Config.fontSizeBodySm
                                    font.family: Icons.font
                                    color: Style.on_surface_variant
                                }
                                RoundedImage {
                                    id: plArt
                                    anchors.fill: parent
                                    radius: 6
                                    source: plRow.modelData.trackArtUrl || ""
                                    visible: status === Image.Ready
                                }
                            }

                            Column {
                                width: parent.width - 28 - 8 - (plCheck.visible ? plCheck.width + 8 : 0)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0

                                Text {
                                    width: parent.width
                                    text: plRow.modelData.identity
                                    font.pixelSize: Config.fontSizeBodySm
                                    font.family: Config.uiFont
                                    font.weight: Font.DemiBold
                                    color: Style.on_surface
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: plRow.modelData.trackTitle || ""
                                    font.pixelSize: Config.fontSizeCaption
                                    font.family: Config.uiFont
                                    color: Style.on_surface_variant
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                id: plCheck
                                anchors.verticalCenter: parent.verticalCenter
                                visible: plRow.isActive
                                text: Icons.check
                                font.pixelSize: Config.fontSizeBodySm
                                font.family: Icons.font
                                color: Style.primary
                            }
                        }

                        HoverHandler { id: plRowHover }

                        Mouse {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                MprisState.musicSetActivePlayer(plRow.modelData.dbusName)
                                root._plOpen = false
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Cola MPD (se despliega a la derecha del player) ────────────────
    Item {
        id: queuePane
        anchors.left: playerPane.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.viewWidth - root._baseW
        clip: true
        visible: root.showQueue

        // Separador con el reproductor
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: parent.height - 32
            color: Style.outline_variant
            opacity: Math.min(1, queuePane.width / 24)
        }

        Item {
            id: queueHead
            x: 16
            y: 16
            width: parent.width - 32
            height: 18

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Cola"
                font.pixelSize: Config.fontSizeCaption
                font.family: Config.uiFont
                font.weight: Font.DemiBold
                font.letterSpacing: 0.6
                color: Style.on_surface_variant
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: MpdState.playlist.length
                font.pixelSize: Config.fontSizeCaption
                font.family: Config.uiFont
                color: Style.on_surface_variant
                opacity: 0.7
            }
        }

        Text {
            anchors.centerIn: parent
            visible: MpdState.playlist.length === 0
            text: MpdState.daemonRunning ? "Cola vacía" : "Conectando con MPD…"
            font.pixelSize: Config.fontSizeBodySm
            font.family: Config.uiFont
            color: Style.on_surface_variant
            opacity: 0.7
        }

        ListView {
            id: queueList
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: queueHead.bottom
            anchors.bottom: parent.bottom
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.topMargin: 6
            anchors.bottomMargin: 10
            clip: true
            model: MpdState.playlist
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            delegate: Item {
                id: qRow
                required property var modelData
                required property int index
                width: queueList.width
                height: 42

                readonly property bool isCurrent: qRow.modelData
                    ? qRow.modelData.pos === MpdState.playlistPos
                    : false

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: qRow.isCurrent ? Qt.alpha(Style.primary, 0.14) : Style.interactive_bg
                    opacity: qRow.isCurrent ? 1.0 : (qHover.hovered ? 0.7 : 0.0)
                    Behavior on opacity {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                }

                Text {
                    id: qIndex
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    horizontalAlignment: Text.AlignRight
                    text: qRow.modelData ? qRow.modelData.pos + 1 : ""
                    font.pixelSize: Config.fontSizeCaption
                    font.family: Config.uiFont
                    color: qRow.isCurrent ? Style.primary : Style.on_surface_variant
                }

                Text {
                    id: qDur
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: qRow.modelData ? MpdState.fmtTime(qRow.modelData.duration || 0) : ""
                    font.pixelSize: Config.fontSizeCaption
                    font.family: Config.uiFont
                    color: Style.on_surface_variant
                    opacity: qRow.isCurrent ? 0 : 1
                }

                Column {
                    anchors.left: qIndex.right
                    anchors.leftMargin: 8
                    anchors.right: qDur.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: qRow.modelData ? (qRow.modelData.title || qRow.modelData.file || "") : ""
                        font.pixelSize: Config.fontSizeBodySm
                        font.family: Config.uiFont
                        font.weight: qRow.isCurrent ? Font.DemiBold : Font.Normal
                        color: qRow.isCurrent ? Style.primary : Style.on_surface
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: qRow.modelData ? (qRow.modelData.artist || "") : ""
                        font.pixelSize: Config.fontSizeCaption
                        font.family: Config.uiFont
                        color: Style.on_surface_variant
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                HoverHandler { id: qHover }

                Mouse {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (qRow.modelData) MpdState.playFromPosition(qRow.modelData.pos)
                }
            }
        }
    }
}
