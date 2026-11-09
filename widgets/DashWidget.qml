// DashWidget.qml — M3 Navigation chip / Quick Settings button
// Muestra wifi, hora y fecha. Click → Control Center. Right-click → Settings.
import QtQuick
import Quickshell
import Quickshell.Networking
import "../state"
import "../components"

Item {
    id: root
    implicitWidth: dashRow.implicitWidth + 20
    height: parent ? parent.height : 48

    // Helper: check if any wifi network is connected
    readonly property bool _wifiHasNet: {
        if (!Networking.wifiEnabled) return false
        var devs = Networking.devices.values
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].type === DeviceType.Wifi) {
                var nets = devs[i].networks.values
                for (var j = 0; j < nets.length; j++) {
                    if (nets[j] && nets[j].connected) return true
                }
            }
        }
        return false
    }

    // M3 container — transparente siempre
    Rectangle {
        anchors.fill: parent; anchors.margins: 2
        radius: Style.button_radius

        color: Qt.rgba(0,0,0,0)

    }

    Row {
        id: dashRow
        anchors.centerIn: parent
        spacing: 6

        // WiFi icon
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: !Networking.wifiEnabled ? Icons.wifiOff
                : !_wifiHasNet  ? Icons.wifiNoNet
                :                 Icons.wifi
            font.pixelSize: Config.iconSize - 2
            font.family: Icons.font
            color: Style.on_surface
        }

        // Separador
        Rectangle {
            width: 3; height: 3; radius: 1.5
            anchors.verticalCenter: parent.verticalCenter
            color: Style.outline_variant
        }

        // Hora + fecha
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                id: dashTime
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(sysClock.date, "hh:mm")
                font.pixelSize: Config.fontSizeLabelSm
                font.weight: Config.fontWeightMedium
                font.family: Config.uiFont
                color: Style.on_surface
            }

            Text {
                id: dashDate
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(sysClock.date, "d MMM")
                font.pixelSize: Config.fontSizeCaption - 1
                font.family: Config.uiFont
                color: Style.on_surface_variant
            }
        }

        // Un tick por minuto (nativo) en vez de Timer de 1s.
        SystemClock { id: sysClock; precision: SystemClock.Minutes }
    }

    Mouse {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: false
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                TaskbarState.closePanel("controlcenter")
                TaskbarState.popupX = root.mapToItem(null, root.width / 2, 0).x
                TaskbarState.activePopup = TaskbarState.activePopup === "settings" ? "" : "settings"
            } else {
                if (TaskbarState.panel === "controlcenter") TaskbarState.closePanel()
                else TaskbarState.openPanel("controlcenter")
            }
        }
    }
}
