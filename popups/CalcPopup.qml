// CalcPopup.qml — Vista Calculadora como panel "calc" de PanelPopupHost.
// Se abre por IPC (target "calc" y command-palette/openCalc) con
// TaskbarState.openPanel("calc"); NO crea ventana propia: comparte la
// superficie del host. Sticky (default): input y último resultado quedan
// congelados al cerrar.

import QtQuick
import "../state"
import "../components/calc"

Item {
    id: root
    // ── API de PanelPopupHost ──
    width: viewWidth
    height: viewHeight
    readonly property real viewWidth: 400
    // Contenido real: display 96 + input 44 + teclado 6×64+5×8 = 424
    // + spacing 16 → 580. Box 620 = 20px de aire por lado.
    readonly property real viewHeight: 620
    readonly property real viewX: 0
    readonly property bool viewExclusiveFocus: true
    readonly property bool viewOpen: TaskbarState.panel === "calc"

    onViewOpenChanged: {
        if (viewOpen) Qt.callLater(function() { calcPanel.focusInput() })
    }

    function _close() { TaskbarState.closePanel("calc") }

    CpCalcPanel {
        id: calcPanel
        anchors.fill: parent; clip: true
        onCancelled: root._close()
    }
}
