// Drawer.qml — Drawer inferior M3 reutilizable (patrón sheet).
// La raíz ocupa toda la vista (el consumidor hace anchors.fill):
// scrim de cierre + panel inferior de alto animado. Extensible por
// slots: headerActions (fila del header) y contenido directo.
//   Drawer {
//       anchors.fill: parent
//       open: root.delConfirm
//       sheetHeight: 232; title: "Eliminar entrada"
//       onClosed: root.cancelDel()
//       Text { Layout.fillWidth: true; text: "..." }
//       ...
//   }
import QtQuick
import QtQuick.Layouts
import "../state"

Item {
    id: root

    property bool open: false
    property real sheetHeight: 380
    property real sheetWidth: 600
    property string title: ""
    property bool showHandle: true
    property bool showClose: true
    // Slot de contenido (hijo de una ColumnLayout interna: usar Layout.*).
    default property alias content: body.children
    // Slot de acciones extra en el header (antes del cerrar).
    property alias headerActions: headerExtra.children

    signal closed()

    visible: scrim.opacity > 0 || sheetWrap.height > 0 || root.open

    // Scrim: velo + cierra al click fuera.
    MouseArea {
        id: scrim
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.open ? 1 : 0
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root.closed()
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)
        }
    }

    // Panel: flota abajo, alto animado, se recorta al cerrar.
    Item {
        id: sheetWrap
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.bottomMargin: 12
        height: root.open ? root.sheetHeight : 0
        visible: height > 0 || root.open
        clip: true

        Rectangle {
            height: root.sheetHeight
            width: Math.min(parent.width, root.sheetWidth)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            color: Style.surface_container_low
            radius: 16
            border.color: Style.outline_variant
            border.width: 1
            // Traga clicks del fondo (gaps del contenido).
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                hoverEnabled: true
                onPressed: {}
            }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                // Handle M3: pill centrada de agarre.
                Rectangle {
                    visible: root.showHandle
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 32; Layout.preferredHeight: 4
                    radius: 2
                    color: Style.on_surface_variant
                    opacity: 0.4
                }
                // Header: título + acciones + cerrar.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: root.title
                        font.pixelSize: Config.fontSizeBody; font.weight: Config.fontWeightMedium
                        font.family: Config.uiFont; color: Style.on_surface
                        elide: Text.ElideRight
                    }
                    Row {
                        id: headerExtra
                        spacing: 8
                    }
                    PillButton {
                        visible: root.showClose
                        Layout.alignment: Qt.AlignVCenter
                        size: 32; iconSize: 14
                        icon: Icons.close
                        customRadius: 8
                        onClicked: root.closed()
                    }
                }
                // Contenido del consumidor.
                ColumnLayout {
                    id: body
                    Layout.fillWidth: true; Layout.fillHeight: true
                    spacing: 8
                }
            }
        }
    }
}
