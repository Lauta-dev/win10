// PopupShell.qml — marco de Settings (ventana FloatingWindow con drawer de tabs).
//
// Ventana NORMAL (FloatingWindow: toplevel xdg): labwc le pone sus
// decoraciones (título + minimizar/maximizar/cerrar) y la posiciona.
// Se cierra con ×, ESC o toggle — como cualquier ventana. NO hay cierre
// por click-fuera: el DismissOverlay (layer-shell) taparía la ventana.
// El host HEREDA (root: PopupShell) y aporta flag, tamaño, tabs del
// drawer y páginas (hijas directas). La lógica queda en el host.
//
// Unifica: sin animación de ventana, sin borde ni radio, drawer fijo
// expandido con botones [ICON] [LABEL].
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../state"

FloatingWindow {
    id: shell

    // ── API del host ──
    property bool flag: false
    signal dismissed()
    property int panelW: 800
    property int panelH: 600
    property var drawerSections: []
    property bool drawerCompact: false
    property int activeTab: 0
    signal tabSelected(int index)
    default property alias pages: pagesHost.data

    // Títulos aplanados (sección tras sección) para el título SSD.
    function _flatTitles() {
        var out = []
        for (var i = 0; i < shell.drawerSections.length; i++) {
            var t = shell.drawerSections[i] ? shell.drawerSections[i].titles : null
            if (t) for (var j = 0; j < t.length; j++) out.push(t[j])
        }
        return out
    }

    // ── Estado interno ──
    property bool _animReady: false
    readonly property bool isOpen: _animReady && flag
    Component.onCompleted: Qt.callLater(function() { _animReady = true })

    title: {
        var flat = shell._flatTitles()
        return shell.activeTab < flat.length && flat[shell.activeTab] !== undefined
            ? String(flat[shell.activeTab]) : ""
    }    visible: shell.isOpen
    onClosed: shell.dismissed()
    implicitWidth: panelW
    implicitHeight: panelH
    color: "transparent"

    Item {
        id: enterWrap
        anchors.fill: parent
        visible: shell.isOpen

        Rectangle {
            id: dialog
            anchors.fill: parent
            color: Style.surface_container_lowest

            RowLayout {
                anchors.fill: parent
                spacing: 0

                PopupDrawer {
                    Layout.leftMargin: 12
                    Layout.topMargin: 12
                    Layout.rightMargin: 12
                    Layout.bottomMargin: 12
                    sections: shell.drawerSections
                    compact: shell.drawerCompact
                    activeTab: shell.activeTab
                    onTabSelected: index => shell.tabSelected(index)
                }

                // Separador sidebar | contenido
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    color: Style.outline_variant
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Style.surface_container_low
                    clip: true

                    Item {
                        id: pagesHost
                        anchors.fill: parent
                        clip: true
                    }
                }
            }
        }
    }
}
