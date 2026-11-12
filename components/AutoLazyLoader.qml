// AutoLazyLoader.qml — carga diferida con descarga opcional al cerrar.
//
// Uso:
//   AutoLazyLoader { condition: someState; source: Component { Foo {} } }
//
// sticky (defecto true): se queda cargado tras la primera apertura
//   (vistas congeladas, cursor preservado).
// sticky: false: descarga unloadDelay ms después de cerrar, con margen
//   para la animación de salida y para que onIsOpenChanged corra antes
//   de destruir (unload en fullyClosed).
//
// Es un Item wrapper (no hereda LazyLoader): los hijos declarativos de
// un LazyLoader viven en otro scope de ids y un Timer hermano nunca
// sería visible desde onConditionChanged.
import Quickshell
import QtQuick

Item {
    id: root
    property bool condition: false
    property bool sticky: true
    property int unloadDelay: 400
    property Component source
    property bool _grace: false
    // Acceso al item cargado (para bindings tipo "la vista activa").
    readonly property alias item: inner.item
    // Sin auto-referencia en el binding de active: QtQuick Loader arranca
    // con active=true por defecto y `active: (... || active)` lo deja
    // cargado siempre. Se recuerda la primera apertura explícitamente.
    property bool _everActive: false

    onConditionChanged: {
        if (condition) {
            _grace = true
            _everActive = true
            graceTimer.stop()
        } else if (!sticky) {
            graceTimer.restart()
        }
    }

    Timer {
        id: graceTimer
        interval: root.unloadDelay
        repeat: false
        onTriggered: {
            if (!root.condition) root._grace = false
        }
    }

    Loader {
        id: inner
        active: root.sticky ? (root.condition || root._everActive) : (root.condition || root._grace)
        sourceComponent: root.source
    }
}
