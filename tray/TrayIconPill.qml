import QtQuick
import Quickshell.Services.SystemTray
import "../state"
import "../components"

Rectangle {
    id: root
    width: 32
    required property SystemTrayItem trayItem
    property var panelWindow: null

    radius: Style.button_radius
    color: hoverHandler.hovered ? Style.surface_container_high : Qt.alpha(Style.surface_container_high, 0)
    Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutCubic } enabled: hoverHandler.hovered }

    Image {
        anchors.centerIn: parent; width: 18; height: 18
        source: root.trayItem.icon; smooth: true; mipmap: true
        sourceSize.width: width * 2
        sourceSize.height: height * 2
        asynchronous: true
        opacity: hoverHandler.hovered ? 1.0 : 0.82
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } enabled: hoverHandler.hovered }
    }

    HoverHandler {
        id: hoverHandler
        onHoveredChanged: {
            if (hovered) {
                var tip = root.trayItem.tooltipTitle !== "" ? root.trayItem.tooltipTitle : root.trayItem.title
                if (tip.length > 0) TaskbarState.showTip(tip, root.mapToItem(null, root.width/2, 0).x)
            } else {
                TaskbarState.hideTip()
            }
        }
    }

    Mouse {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            TaskbarState.hideTip()
            var pos = root.mapToGlobal(root.width / 2, 0)
            if (mouse.button === Qt.RightButton) {
                if (root.trayItem.hasMenu && root.panelWindow)
                    root.trayItem.display(root.panelWindow, pos.x, pos.y)
                else
                    root.trayItem.secondaryActivate()
            } else {
                // Algunas apps (Lutris, etc) solo tienen menú y no responden a activate()
                // Si onlyMenu está disponible usamos display(), sino intentamos activate()
                if (root.trayItem.hasMenu && root.panelWindow && root.trayItem.onlyMenu)
                    root.trayItem.display(root.panelWindow, pos.x, pos.y)
                else
                    root.trayItem.activate()
            }
        }
    }
}
