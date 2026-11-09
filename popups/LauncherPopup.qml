// LauncherPopup.qml — Lanzador único: AppMenu o Clipboard por modo.
// Vista del panel "launcher" en PanelPopupHost; el modo lo pone quien
// abre (IPC/widgets); con el panel visible, cambiar de modo solo
// actualiza contenido (enter + foco) sin reabrirse.
import QtQuick
import QtQuick.Layouts
import "../state"
import "../components"
import "../components/appmenu"
import "../components/clipboard"

Item {
    id: root
    // ── API de PanelPopupHost ──
    // El shell ya no da el tamaño: la vista mide lo que informa al host.
    width: viewWidth
    height: viewHeight
    readonly property real viewWidth: 640
    readonly property real viewHeight: 520
    readonly property real viewX: 0
    readonly property bool viewExclusiveFocus: true
    readonly property bool viewOpen: TaskbarState.panel === "launcher"

    readonly property bool isApp: TaskbarState.launcherMode === "app"
    onIsAppChanged: if (root.viewOpen) root._activateMode()

    // Activa la vista del modo actual (al abrir y al cambiar de modo en
    // caliente): enter + foco en el buscador.
    function _activateMode() {
        ClipboardState.isOpen = root.viewOpen && !root.isApp
        if (!root.viewOpen) return
        if (root.isApp) menuView.enter()
        else clipView.enter()
        Qt.callLater(function() {
            if (!root.viewOpen) return
            if (root.isApp) menuView.focusSearch()
            else clipView.focusSearch()
        })
    }
    onViewOpenChanged: {
        if (root.viewOpen) {
            clearTimer.stop()
            root._activateMode()
        } else {
            clearTimer.restart()
        }
    }

    // Limpia el buscador del AppMenu tras cerrar (500ms): si se reabre antes, no hace nada.
    Timer {
        id: clearTimer; interval: 500; repeat: false
        onTriggered: { if (!root.viewOpen) menuView.clearSearch() }
    }

    ColumnLayout {
        anchors.fill: parent; spacing: 0
        anchors.margins: 2

        AppMenuView {
            id: menuView
            visible: root.isApp
            Layout.fillWidth: true; Layout.fillHeight: true
            onCloseRequested: TaskbarState._hideLauncher()
        }
        ClipView {
            id: clipView
            visible: !root.isApp
            Layout.fillWidth: true; Layout.fillHeight: true
            onEscapeEmpty: TaskbarState._hideLauncher()
        }
    }
}
