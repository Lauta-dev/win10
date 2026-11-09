// ToggleSwitch.qml — Switch con contorno M3
import QtQuick
import "../state"

Item {
    id: root
    property real size: 1.0
    width: 52 * size; height: 32 * size

    property bool checked: false
    signal toggled(bool val)

    // Track
    Rectangle {
        id: track
        anchors.centerIn: parent
        width: 52 * root.size; height: 32 * root.size
        radius: Style.button_radius_lg
        color: root.checked ? Style.primary : Style.surface_container_highest
        // Contorno: en apagado es el outline; en encendido toma el color del
        // relleno (se "funde" con el track, no se ve un aro encima).
        border.color: root.checked ? Style.primary : Style.outline
        border.width: 2 * root.size

        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    // Thumb
    Rectangle {
        id: thumb
        width:  24 * root.size
        height: width; radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        color: root.checked ? "white" : Style.outline
        x: root.checked ? track.x + track.width - width - 4 * root.size
                        : track.x + 4 * root.size

        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    Mouse {
        id: _ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
