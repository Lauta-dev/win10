// ClipboardWidget.qml — M3 Icon Button
import QtQuick
import Quickshell
import "../state"

Item {
    id: root
    property bool _ph:      false
    property bool _pressed: false

    // M3 state layer
    Rectangle {
        anchors.fill: parent; anchors.margins: 2
        radius: Style.button_radius
        color: Qt.alpha(Style.primary, _pressed ? 0.18 : _ph ? 0.10 : 0.0)
        Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
    }

    Text {
        anchors.centerIn: parent
        text: Icons.clipboard
        font.pixelSize: Config.iconSize
        font.family:    Icons.font
        color: Style.on_surface
    }



    HoverHandler {
        onHoveredChanged: {
            root._ph = hovered
            if (hovered)
                TaskbarState.showTip("Portapapeles", root.mapToItem(null, root.width / 2, 0).x)
            else
                TaskbarState.hideTip()
        }
    }

    Mouse {
        anchors.fill: parent; hoverEnabled: false
        acceptedButtons: Qt.LeftButton
        property bool _wasOpen: false
        onPressed:  { root._pressed = true;  _wasOpen = TaskbarState.clipOpen }
        onReleased: { root._pressed = false }
        onCanceled: { root._pressed = false }
        onClicked: {
            if (_wasOpen) TaskbarState._hideLauncher()
            else TaskbarState._showLauncher("clip")
        }
    }
}
