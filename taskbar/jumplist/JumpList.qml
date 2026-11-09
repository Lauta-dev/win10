// JumpList.qml — Jump List estilo Windows 10.
// Vista única del panel "jumplist" en PanelPopupHost: toma todo del
// singleton TaskbarState (el glue que estaba en JumpListPopup); todos los
// ítems de la barra reutilizan la misma superficie y el mismo contenido.
import QtQuick
import QtQuick.Window
import "../../state"
import "../../components"

Item {
    id: root
    // ── API de PanelPopupHost ──
    // El shell ya no da el tamaño: la vista mide lo que informa al host.
    width: viewWidth
    height: viewHeight
    readonly property real viewWidth: 240
    readonly property real viewHeight: Math.max(1, Math.min(root._cachedHeight, root._surfaceH))
    readonly property bool viewOpen: TaskbarState.panel === "jumplist"
    readonly property real viewX: root._animX
    // positionX (left): el box se centra en la x del botón. Slide de
    // 160 ms al pasar el mouse de un ítem a otro con el popup abierto.
    property real _animX: TaskbarState.jumpListX
    Behavior on _animX { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    // ── Datos (antes los aportaba JumpListPopup) ──
    readonly property string appId: TaskbarState.activeJumpList
    readonly property var   toplevels: (function() {
        if (!OpenAppsState.toplevelsFor) return []
        var key = (OpenAppsState._norm ? OpenAppsState._norm(root.appId) : root.appId)
        return OpenAppsState.toplevelsFor[key] || []
    })()
    readonly property var    entry: Config._resolveEntry(root.appId)
    readonly property string label: root.entry ? (root.entry.name ?? root.appId)
                                              : root.appId
    readonly property bool   isPinned: TaskbarState.isPinned(root.appId)
    readonly property bool   hasWin: root.toplevels.length > 0
    readonly property int    winCount: root.toplevels.length

    // ── Acciones (antes señales conectadas por JumpListPopup) ──
    function _closeList() { TaskbarState.closeJumpList() }
    function _pin() {
        TaskbarState.closeJumpList()
        TaskbarState.togglePin(root.appId)
    }
    function _closeAll() {
        TaskbarState.closeJumpList()
        for (var i = 0; i < root.toplevels.length; i++)
            root.toplevels[i].close()
    }

    readonly property string iconSrc: Config.resolveIcon(root.appId)
    readonly property color  primary: Style.primary
    // Superficie fija: acompaña la altura máxima posible sin redimensionar.
    readonly property real _surfaceH: Screen.height - Config.taskbarHeight - 20

    // ── Cache de toplevels — mantiene contenido durante animación de cierre
    property var  _cachedToplevels: []
    property real _cachedHeight:    1

    function _syncCache() {
        _cachedToplevels = toplevels ? toplevels.slice() : []
        _cachedHeight    = _calcHeight(_cachedToplevels.length)
    }

    // Mientras está abierto, sigue el alto real (incluye apps sin ventanas);
    // cerrado se conserva el cache para no colapsar durante el wipe.
    onToplevelsChanged: if (viewOpen) _syncCache()
    onViewOpenChanged:  if (viewOpen) _syncCache()
    Component.onCompleted: _syncCache()

    function _calcHeight(n) {
        var h = 44 + 8              // header + separador
        if (n > 0) h += n * 50 + Math.max(0, n - 1) * 2 + 8  // ventanas + sep
        h += (n > 0 ? 4 : 0) + 1 + 4 + 30 + 4  // spacer(si hay wins) + sep + spacer + anclar + padding
        if (n > 0) h += 1 + 30    // sep + cerrar
        h += 8                     // padding bottom
        return h
    }

    // Toplevels a mostrar: cuando está cerrado usa cache para mantener durante animación
    readonly property var _displayToplevels: viewOpen ? toplevels : _cachedToplevels

    // ── Hover coordinado con el botón (gracias en TaskbarState) ───────────
    Component.onDestruction: TaskbarState.jumpListPanelHovered = false

    // ── Contenido ─────────────────────────────────────────────────────
    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 0

        HoverHandler {
            onHoveredChanged: {
                TaskbarState.jumpListPanelHovered = hovered
                TaskbarState.notifyJumpListHover()
            }
        }

                // ── Header ────────────────────────────────────────────
                Item {
                    width: parent.width; height: 44

                    Row {
                        anchors.fill: parent; anchors.leftMargin: 4; spacing: 8

                        Item {
                            width: 28; height: 44
                            Image {
                                id: appIcon
                                anchors.centerIn: parent
                                width: 22; height: 22; source: root.iconSrc
                                visible: root.iconSrc !== "" && status === Image.Ready
                                sourceSize.width: width * 2
                                sourceSize.height: height * 2
                                asynchronous: true
                                cache: true
                                smooth: true; mipmap: true
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                width: 22; height: 22; radius: 6
                                visible: appIcon.status !== Image.Ready || root.iconSrc === ""
                                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.18)
                                Text {
                                    anchors.centerIn: parent
                                    text: root.label.charAt(0).toUpperCase()
                                    font.pixelSize: Config.fontSizeBodySm; font.family: Config.uiFont
                                    font.weight: Config.fontWeightMedium; color: Style.on_primary
                                }
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter; spacing: 1
                            Text {
                                text: root.label
                                font.pixelSize: Config.fontSizeBody; font.weight: Config.fontWeightMedium
                                font.family: Config.uiFont; color: Style.on_surface
                                width: root.width - 60; elide: Text.ElideRight
                            }
                            Text {
                                visible: root.hasWin
                                text: root.winCount === 1 ? "1 ventana" : root.winCount + " ventanas"
                                font.pixelSize: Config.fontSizeLabelSm; font.family: Config.uiFont
                                color: Style.on_surface
                            }
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.margins: 4; height: 1
                        color: Style.outline_variant; opacity: 0.6
                    }
                }

                // ── Lista de ventanas ──────────────────────────────────
                Repeater {
                    model: root._displayToplevels.length

                    delegate: Item {
                        id: winRow
                        width: parent.width; height: 50

                        readonly property var    tl:       root._displayToplevels[index]
                        readonly property string winTitle: tl
                            ? ((tl.title ?? "").length > 0 ? tl.title : root.label) : ""
                        readonly property bool isActive: tl ? tl.activated : false
                        property bool ph: false

                        Rectangle {
                          anchors.fill: parent; anchors.margins: 1
                            radius: Style.button_radius
                            color: winRow.isActive
                                   ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.12)
                                   : winRow.ph ? Qt.rgba(1,1,1, 0.06) : Qt.rgba(1,1,1, 0)
                            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b,
                                                  winRow.isActive ? 0.70 : 0)
                            border.width: 1
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: winRow.tl && winRow.tl.minimized ? Icons.taskGroup
                                    : winRow.isActive ? Icons.windowActive : Icons.windowInactive
                                font.pixelSize: Config.fontSizeBody; font.family: Icons.font
                                color: Style.on_surface
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: winRow.winTitle
                                font.pixelSize: Config.fontSizeBodySm; font.family: Config.uiFont
                                font.weight: winRow.isActive ? Font.Medium : Font.Normal
                                color: Style.on_surface
                                width: parent.width - 30; elide: Text.ElideRight
                                opacity: (winRow.tl && winRow.tl.minimized) ? 0.45 : 1.0
                            }
                        }

                        Mouse {
                            anchors.fill: parent; hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onEntered: winRow.ph = true
                            onExited:  winRow.ph = false
                            onClicked: (mouse) => {
                                var tl = winRow.tl
                                if (!tl) return
                                if (mouse.button === Qt.RightButton) {
                                    // Cerrar ventana individual — NO cerrar el JumpList
                                    tl.close()
                                } else {
                                    if (tl.activated && !tl.minimized) tl.minimized = true
                                    else { tl.minimized = false; tl.activate() }
                                    root._closeList()
                                }
                            }
                        }
                    }
                }

                // ── Separador + acciones ───────────────────────────────
                Item { width: 1; height: 4; visible: root.hasWin }
                Rectangle {
                    visible: root.hasWin
                    width: parent.width - 8; height: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Style.outline_variant; opacity: 0.6
                }
                Item { width: 1; height: 4 }

                JumpListItem {
                    width: parent.width
                    icon:  root.isPinned ? Icons.unpin : Icons.pin
                    label: root.isPinned ? "Desanclar de la barra" : "Anclar a la barra"
                    onActivated: root._pin()
                }

                Rectangle {
                    visible: root.hasWin
                    width: parent.width - 8; height: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Style.outline_variant; opacity: 0.6
                }
                JumpListItem {
                    visible: root.hasWin
                    width: parent.width
                    icon:  Icons.close
                    label: root.winCount > 1 ? "Cerrar todas (" + root.winCount + ")" : "Cerrar ventana"
                    danger: true
                    onActivated: root._closeAll()
                }
            }
}
