// HubPopup.qml — Hub: Música + Calc, layout estilo Caelestia.
// Marco en PopupShell (heredado); acá solo contenido + lógica de vistas.
// Vistas congeladas: enter() corre solo la primera vez, al cerrar nada se resetea.

import QtQuick
import Quickshell
import "../state"

import "../components"
import "../components/settings"
import "../components/hub"
import "../components/mpd"

PopupShell {
    id: root

    flag: TaskbarState.activePopup === "hub"
    onDismissed: TaskbarState.activePopup = ""
    panelW: Math.min(screen.width  - 32, 1024)
    panelH: Math.min(screen.height - Config.taskbarHeight - 32, 620)
    drawerSections: [{ header: "", titles: ["Música", "Calc"],
        icons: [Icons.musicNote, Icons.calculator] }]
    // Fuente única: quien abre (IPC/drawer) pone TaskbarState.hubTab.
    activeTab: TaskbarState.hubTab
    onTabSelected: index => TaskbarState.hubTab = index

    // ── Drawer fijo expandido (estado en el shell) ──

    // ── Freeze: enter una sola vez por vista ──
    property bool _mpdInit: false

    function _enterTab(i) {
        if (i === TaskbarState.hubTabMpd) {
            if (!root._mpdInit) { mpdView.enter(); root._mpdInit = true }
            Qt.callLater(function() { mpdView.focusSearch() })
        } else {
            Qt.callLater(function() { calcPanel.focusInput() })
        }
    }

    onIsOpenChanged: {
        if (isOpen) _enterTab(activeTab)
        _updateMpdPolling()
    }
    onActiveTabChanged: {
        if (isOpen) _enterTab(activeTab)
        _updateMpdPolling()
    }

    // ── MPD polling ──
    Timer {
        id: syncRetryTimer
        interval: 700
        repeat: false
        onTriggered: {
            if (root._mpdLive() && MpdConnection.connected) MpdState.enterMpd()
        }
    }

    function _mpdLive() {
        return root.isOpen && root.activeTab === TaskbarState.hubTabMpd
    }

    function _updateMpdPolling() {
        var inMpd = root._mpdLive()
        MpdConnection.setPollingConsumer("hub", inMpd)
        if (inMpd) {
            MpdConnection.ensureConnected()
            if (MpdConnection.connected) {
                Qt.callLater(function() { MpdState.enterMpd() })
            } else {
                syncRetryTimer.restart()
            }
        } else {
            syncRetryTimer.stop()
        }
    }

    Connections {
        target: MpdConnection
        function onConnectedChanged() {
            if (MpdConnection.connected && root._mpdLive()) {
                Qt.callLater(function() { MpdState.enterMpd() })
            }
        }
    }

    function _close() { TaskbarState.activePopup = "" }

    // ── Páginas (hijas directas → slot del shell) ──

    TabTransition { index: 0; activeTab: root.activeTab
        CpMpdView {
            id: mpdView
            anchors.fill: parent; clip: true
            active: root.isOpen && root.activeTab === TaskbarState.hubTabMpd
            running: root.isOpen && root.activeTab === TaskbarState.hubTabMpd
            onEscapeEmpty: root._close()
            onBackToRoot: root._close()
            onFocusWrapper: mpdView.focusSearch()
        }
    }

    TabTransition { index: 1; activeTab: root.activeTab
        CpCalcPanel {
            id: calcPanel
            anchors.fill: parent; clip: true
            onCancelled: root._close()
        }
    }
}
