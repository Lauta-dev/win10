import QtQuick
import "../state"

Item {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""

    // Acciones opcionales: [{label, icon}] → fila de botones.
    property var actions: []
    signal actionTriggered(int index)

    // Colores custom ("" = tema). Misma convención que PillButton.
    // Para errores: customContainerColor: Style.error_container,
    // customIconColor: Style.on_error_container.
    property string customContainerColor: ""
    property string customIconColor: ""

    Column {
        anchors.centerIn: parent
        spacing: 10

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 56; height: 56; radius: 28
            color: root.customContainerColor !== "" ? root.customContainerColor : Style.interactive_bg

            Text {
                anchors.centerIn: parent
                text: root.icon
                font.pixelSize: Config.fontSizeIconLg
                font.family: Icons.font
                color: root.customIconColor !== "" ? root.customIconColor : Style.primary
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.title
            font.pixelSize: Config.fontSizeBody
            font.weight: Config.fontWeightMedium
            font.family: Config.uiFont
            color: Style.on_surface
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.subtitle
            font.pixelSize: Config.fontSizeLabel
            font.family: Config.uiFont
            color: Style.on_surface
            visible: text !== ""
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            visible: root.actions.length > 0
            Repeater {
                model: root.actions
                delegate: PillButton {
                    required property var modelData
                    required property int index
                    label: modelData.label ?? ""
                    icon: modelData.icon ?? ""
                    onClicked: root.actionTriggered(index)
                }
            }
        }
    }
}
