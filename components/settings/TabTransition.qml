import QtQuick
import "../../state"

// TabTransition — motion M3 shared-axis X + fade
Item {
    id: root
    property int index: 0
    property int activeTab: 0
    default property alias content: slideItem.data

    width: parent.width; height: parent.height
    // Sin animación: visibilidad instantánea (experimento sin-animaciones)
    x: 0
    opacity: activeTab === index ? 1.0 : 0.0
    visible: opacity > 0
    scale: 1.0

    Item {
        id: slideItem
        anchors.fill: parent
        clip: true
    }
}
