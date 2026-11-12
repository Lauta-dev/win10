// KeybindsPopup.qml — Hoja de atajos de labwc como panel "keybinds" de
// PanelPopupHost. Grilla de tarjetas de 2 columnas: cada tarjeta es una
// sección con filas [descripción — keycaps]. Los datos vienen de
// KeybindsState, que corre bin/keybinds (Go) al entrar al popup: ese
// binario parsea ~/.config/labwc/rc.xml (labels + interpretación de chips
// y sección; A=Alt, C=Ctrl, S=Shift, W=Super). Se abre por IPC (target
// "keybinds" u openKeybinds en command-palette) con
// TaskbarState.openPanel("keybinds"). Sticky (default).

import QtQuick
import "../state"
import "../components"

Item {
    id: root

    // ── API de PanelPopupHost ──
    width: viewWidth
    height: viewHeight
    readonly property real viewWidth: 980
    // Contenido: dos columnas de ~910px de alto → scrollea dentro del box.
    readonly property real viewHeight: 640
    readonly property real viewX: 0
    readonly property bool viewExclusiveFocus: true
    readonly property bool viewOpen: TaskbarState.panel === "keybinds"

    onViewOpenChanged: if (viewOpen) {
        clearTimer.stop()
        KeybindsState.reload()
        Qt.callLater(root.forceActiveFocus)
    } else clearTimer.restart()

    // Limpia el filtro tras cerrar (500ms): reabrir antes lo conserva.
    Timer {
        id: clearTimer
        interval: 500; repeat: false
        onTriggered: if (!root.viewOpen) searchInput.clear()
    }

    function _close() { TaskbarState.closePanel("keybinds") }

    // Escape cierra; texto imprimible cae al filtro (type-to-search).
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) { root._close(); event.accepted = true; return }
        if (event.text.length > 0 && !(event.modifiers & Qt.ControlModifier)
                && event.key !== Qt.Key_Backspace && event.key !== Qt.Key_Delete) {
            searchInput.forceActiveFocus()
            searchInput.appendText(event.text)
            event.accepted = true
        }
    }

    // ── Filtro (header): por label, key crudo o chips ───────────────────
    property string _q: ""
    readonly property string _needle: _q.trim().toLowerCase()

    function _rowMatches(row) {
        if (root._needle === "") return true
        var hay = (row.desc + " " + (row.raw || "") + " " + (row.keys || []).join(" ")).toLowerCase()
        return hay.indexOf(root._needle) >= 0
    }

    // ── Reparto de columnas por título (contrato con bin/keybinds) ──────
    readonly property var _leftTitles: ["Sistema", "Ventanas", "Mouse"]
    readonly property var leftSections: KeybindsState.sections
        .filter(s => _leftTitles.indexOf(s.title) >= 0)
        .map(s => ({ title: s.title, rows: s.rows.filter(r => root._rowMatches(r)) }))
        .filter(s => s.rows.length > 0)
    readonly property var rightSections: KeybindsState.sections
        .filter(s => _leftTitles.indexOf(s.title) < 0)
        .map(s => ({ title: s.title, rows: s.rows.filter(r => root._rowMatches(r)) }))
        .filter(s => s.rows.length > 0)

    readonly property int _total: KeybindsState.sections.reduce(
        (a, s) => a + s.rows.length, 0)
    readonly property int _matchCount: leftSections.reduce(
        (a, s) => a + s.rows.length, 0) + rightSections.reduce(
        (a, s) => a + s.rows.length, 0)

    function iconFor(title) {
        if (title === "Sistema") return Icons.monitor
        if (title === "Ventanas") return Icons.windowMaximize
        if (title === "Mouse") return Icons.drag
        if (title === "Apps") return Icons.launcher
        if (title === "Escritorios") return Icons.displayDual
        if (title === "Menús") return Icons.window
        return Icons.key
    }

    // Header: título + filtro por tecla o acción
    Item {
        id: head
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 14
        height: 54

        Text {
            id: headIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.key
            font.pixelSize: Config.fontSizeTitle
            font.family: Icons.font
            color: Style.primary
        }
        Text {
            id: headTitle
            anchors.left: headIcon.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "Atajos"
            font.pixelSize: Config.fontSizeBody
            font.weight: Font.DemiBold
            font.family: Config.uiFont
            color: Style.on_surface
        }

        SmartSearchInput {
            id: searchInput
            anchors.left: headTitle.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            inputHeight: 36
            placeholder: "Filtrar por tecla o acción…"
            bgColor: Style.surface_container_low
            counterText: root._needle === "" ? "" : root._matchCount + " / " + root._total
            onQueryChanged: value => root._q = value
            onEscapePressed: {
                if (text === "") root._close()
                else clear()
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Style.outline_variant
            opacity: 0.4
        }
    }

    // Estados: cargando / error / sin resultados (EmptyState, como PanelList)
    EmptyState {
        anchors.centerIn: flick
        visible: KeybindsState.loading && root._total === 0
        icon: Icons.refresh
        title: "Cargando…"
    }
    EmptyState {
        anchors.centerIn: flick
        visible: KeybindsState.failed && root._total === 0
        icon: Icons.error
        title: "No se pudieron leer los atajos"
        subtitle: "~/.config/labwc/rc.xml"
        customContainerColor: Style.error_container
        customIconColor: Style.on_error_container
    }
    EmptyState {
        anchors.centerIn: flick
        visible: root._total > 0 && root._matchCount === 0
        icon: Icons.search
        title: "Sin resultados"
        subtitle: "Nada matchea el filtro"
    }

    // ── Grilla: dos columnas de tarjetas, scroll por la más alta ────────
    Flickable {
        id: flick
        anchors.top: head.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        clip: true
        contentWidth: width
        contentHeight: Math.max(leftCol.height, rightCol.height) + 12
        boundsBehavior: Flickable.StopAtBounds

        readonly property real cardW: (width - 14 * 3) / 2

        // Tarjeta de sección: encabezado (icono + título) + filas.
        component SectionCard: Rectangle {
            id: card
            property string title
            property string icon
            property var rows: []

            width: flick.cardW
            radius: Style.popup_radius_sm
            color: Style.surface_container_low
            height: cardCol.implicitHeight + 22

            Column {
                id: cardCol
                x: 12
                y: 10
                width: parent.width - 24
                spacing: 0

                // Encabezado de la tarjeta
                Item {
                    width: parent.width
                    height: 32

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: card.icon
                            font.pixelSize: Config.fontSizeTitle
                            font.family: Icons.font
                            color: Style.primary
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: card.title.toUpperCase()
                            font.pixelSize: Config.fontSizeLabel
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.2
                            font.family: Config.uiFont
                            color: Style.on_surface_variant
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: Style.outline_variant
                        opacity: 0.4
                    }
                }

                // Filas: descripción a la izquierda, keycaps a la derecha
                Repeater {
                    model: card.rows

                    delegate: Item {
                        id: rowDel
                        required property var modelData
                        width: parent.width
                        height: 36

                        Text {
                            anchors.left: parent.left
                            anchors.right: keysRow.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: rowDel.modelData.desc
                            font.pixelSize: Config.fontSizeBody
                            font.family: Config.uiFont
                            color: Style.on_surface
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Row {
                            id: keysRow
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Repeater {
                                model: rowDel.modelData.keys

                                // Keycap: modificadores apagados, tecla resaltada.
                                Rectangle {
                                    id: chip
                                    required property var modelData
                                    readonly property bool _mod:
                                        ["Super", "Ctrl", "Alt", "Shift", "Fn"].indexOf(modelData) >= 0

                                    height: 26
                                    width: chipTxt.implicitWidth + 14
                                    radius: Style.radius_sm
                                    color: chip._mod ? Style.surface_container : Style.surface_container_high

                                    Text {
                                        id: chipTxt
                                        anchors.centerIn: parent
                                        text: chip.modelData
                                        font.pixelSize: Config.fontSizeLabel
                                        font.weight: Font.Medium
                                        font.family: Config.uiFont
                                        color: chip._mod ? Style.on_surface_variant : Style.on_surface
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Column {
            id: leftCol
            x: 14
            y: 6
            width: flick.cardW
            spacing: 14

            Repeater {
                model: root.leftSections

                delegate: SectionCard {
                    required property var modelData
                    title: modelData.title
                    icon: root.iconFor(modelData.title)
                    rows: modelData.rows
                }
            }
        }

        Column {
            id: rightCol
            x: 14 * 2 + flick.cardW
            y: 6
            width: flick.cardW
            spacing: 14

            Repeater {
                model: root.rightSections

                delegate: SectionCard {
                    required property var modelData
                    title: modelData.title
                    icon: root.iconFor(modelData.title)
                    rows: modelData.rows
                }
            }
        }
    }
}
