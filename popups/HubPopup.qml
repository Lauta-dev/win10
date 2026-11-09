// HubPopup.qml — Hub: Música + Calc + Claves, layout estilo Caelestia.
// Marco en PopupShell (heredado); acá solo contenido + lógica de vistas.
// Vistas congeladas: enter() corre solo la primera vez, al cerrar nada se resetea.

import QtQuick
import Quickshell
import "../state"

import "../components"
import "../components/settings"
import "../components/hub"
import "../components/mpd"
import "../components/keepass"

PopupShell {
    id: root

    flag: TaskbarState.activePopup === "hub"
    onDismissed: TaskbarState.activePopup = ""
    panelW: Math.min(screen.width  - 32, 1024)
    panelH: Math.min(screen.height - Config.taskbarHeight - 32, 620)
    drawerSections: [{ header: "", titles: ["Música", "Calc", "Claves"],
        icons: [Icons.musicNote, Icons.calculator, Icons.lock] }]
    // Fuente única: quien abre (IPC/drawer) pone TaskbarState.hubTab.
    activeTab: TaskbarState.hubTab
    onTabSelected: index => TaskbarState.hubTab = index

    // ── Drawer fijo expandido (estado en el shell) ──

    // ── Freeze: enter una sola vez por vista ──
    property bool _mpdInit: false
    property bool _keepassInit: false

    // ── Form keepass (el Hub dueña el flag) ──
    property bool _keepassFormOpen: false

    function _enterTab(i) {
        if (i === TaskbarState.hubTabMpd) {
            if (!root._mpdInit) { mpdView.enter(); root._mpdInit = true }
            Qt.callLater(function() { mpdView.focusSearch() })
        } else if (i === TaskbarState.hubTabKeepass) {
            if (!root._keepassInit) { keepassView.enter(); root._keepassInit = true }
            else Qt.callLater(function() { keepassView.focusSearch() })
        } else {
            Qt.callLater(function() { calcPanel.focusInput() })
        }
    }

    onIsOpenChanged: {
        if (isOpen) _enterTab(activeTab)
        else mpdView.savePos()
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

    Connections {
        target: KeePassState
        function onAddingEntryChanged() {
            if (!KeePassState.addingEntry) root._keepassFormOpen = false
        }
    }

    // ── Keepass: form en aside ──
    // submitAdd/submitEdit cierran el form por dentro (closeAddForm):
    // el espejo de abajo apaga el flag en ese caso.
    function _toggleKeepassForm() {
        if (root._keepassFormOpen) {
            root._keepassFormOpen = false
            keepassView.cancelAdd()
        } else {
            KeePassState.openAddForm()
            root._keepassFormOpen = true
            Qt.callLater(function() { keepassView.openForm() })
        }
    }
    // Scrim: cancela (la lista depende de addingEntry, no se puede
    // conservar lo tipeado).
    function _closeKeepassForm() {
        root._keepassFormOpen = false
        keepassView.cancelAdd()
    }
    function _saveKeepassForm(form) {
        if (form.isEdit) KeePassState.submitEdit(form)
        else KeePassState.submitAdd(form)
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

    TabTransition { index: 2; activeTab: root.activeTab
        CpKeepassView {
            id: keepassView
            anchors.fill: parent; clip: true
            active: root.isOpen && root.activeTab === TaskbarState.hubTabKeepass
            formOpen: root._keepassFormOpen
            onBackToRoot: root._close()
            onBackToMain: root._close()
            onCloseRequested: root._close()
            onFocusWrapper: keepassView.focusSearch()
            onToggleFormRequested: root._toggleKeepassForm()
            onCloseFormRequested: root._closeKeepassForm()
            onFormEditRequested: item => {
                root._keepassFormOpen = true
                Qt.callLater(function() { keepassView.openFormEdit(item) })
            }
            onFormSaved: form => root._saveKeepassForm(form)
            onFormCancelled: root._closeKeepassForm()
        }
    }
}
