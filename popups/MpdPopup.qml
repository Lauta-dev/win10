// MpdPopup.qml — Vista MPD (cola) como panel "mpd" de PanelPopupHost.
// Se abre por IPC (target "mpd" / openMpd) con TaskbarState.openPanel("mpd");
// NO crea ventana propia: comparte la superficie del host.
//
// El fondo sale del cover (CpMpdView tiñe con el arte del disco) y la fila
// en reproducción lleva bg sólido (playingRowBg) para distinguirse del
// resto de la lista.

import QtQuick
import "../state"
import "../components/mpd"

Item {
    id: root
    // ── API de PanelPopupHost ──
    width: viewWidth
    height: viewHeight
    readonly property real viewWidth: 900
    readonly property real viewHeight: 560
    readonly property real viewX: 0
    readonly property bool viewExclusiveFocus: true
    readonly property bool viewOpen: TaskbarState.panel === "mpd"

    property bool _init: false

    onViewOpenChanged: {
        if (viewOpen) {
            if (!root._init) { mpdView.enter(); root._init = true }
            Qt.callLater(function() { mpdView.focusSearch() })
        }
        _updateMpdPolling()
    }

    // ── MPD polling (consumidor "mpd") ──
    Timer {
        id: syncRetryTimer
        interval: 700
        repeat: false
        onTriggered: {
            if (root.viewOpen && MpdConnection.connected) MpdState.enterMpd()
        }
    }

    function _updateMpdPolling() {
        var inMpd = root.viewOpen
        MpdConnection.setPollingConsumer("mpd", inMpd)
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
            if (MpdConnection.connected && root.viewOpen) {
                Qt.callLater(function() { MpdState.enterMpd() })
            }
        }
    }

    function _close() { TaskbarState.closePanel("mpd") }

    CpMpdView {
        id: mpdView
        anchors.fill: parent; clip: true
        active: root.viewOpen
        running: root.viewOpen
        playingRowBg: true
        onEscapeEmpty: root._close()
        onBackToRoot: root._close()
        onFocusWrapper: mpdView.focusSearch()
    }
}
