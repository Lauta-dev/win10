import QtQuick
import QtQuick.Controls
import "../"
import "../../state"

// SettingsCombo — ComboBox con el estilo de los menús del CC: panel tonal,
// filas altas con icono opcional, hover y check en la opción elegida.
ComboBox {
    id: control

    implicitWidth: 150
    implicitHeight: 32

    readonly property int itemHeight: 40
    readonly property int popupMinWidth: 170
    readonly property int popupMaxHeight: 320
    readonly property int hPad: 8
    readonly property int popupPad: 4
    readonly property int rowPad: 10
    readonly property int rowGap: 8
    readonly property int rowCheckSpace: 30

    // Animación de apertura/cierre del popup
    readonly property int animOpenMs: 140
    readonly property int animCloseMs: 90
    readonly property int scaleExtraMs: 20
    readonly property real scaleFrom: 0.96

    contentItem: Text {
        text: control.displayText
        font.pixelSize: Config.fontSizeLabelSm
        font.family: Config.uiFont
        font.weight: Config.fontWeightMedium
        color: Style.on_surface
        verticalAlignment: Text.AlignVCenter
        leftPadding: control.hPad
        rightPadding: control.indicator.width + control.hPad
        elide: Text.ElideRight
    }

    indicator: Text {
        text: Icons.chevronDown
        font.pixelSize: Config.fontSizeLabelSm
        font.family: Icons.font
        color: Style.on_surface_variant
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: control.hPad
    }

    background: Rectangle {
        radius: 8
        color: Style.surface_container_highest
    }

    // Delegate como Item + Mouse propio: sin AbstractButton Qt no recibe el
    // click y NO cierra el popup al elegir. El click cambia la selección
    // manualmente y deja el menú abierto.
    delegate: Item {
        id: item

        required property int index
        required property var modelData

        readonly property bool isSelected: index === control.currentIndex
        readonly property bool isHovered: rowMouse.containsMouse
        readonly property bool isPressed: rowMouse.pressed

        width: ListView.view ? ListView.view.width : control.popup.width
        height: control.itemHeight

        // Click: encoge y vuelve (feedback)
        scale: isPressed ? 0.98 : 1.0
        Behavior on scale {
            NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
        }

        // Fondo de seleccionada (primary fuerte) con crossfade
        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Style.primary
            opacity: item.isSelected ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
        }

        // Fondo de hover (aparece/desaparece animado)
        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Style.interactive_bg
            opacity: item.isHovered && !item.isSelected ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }

        Text {
            id: rowCheck
            anchors.right: parent.right
            anchors.rightMargin: control.rowPad
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.check
            font.pixelSize: Config.fontSizeBodySm
            font.family: Icons.font
            color: Style.on_primary
            // El check entra con fade + scale al seleccionar
            opacity: item.isSelected ? 1.0 : 0.0
            scale: item.isSelected ? 1.0 : 0.6
            Behavior on opacity {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: 120; easing.type: Easing.OutBack }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: control.rowPad
            anchors.right: parent.right
            anchors.rightMargin: control.rowCheckSpace
            anchors.verticalCenter: parent.verticalCenter
            text: item.modelData
            font.pixelSize: Config.fontSizeBodySm
            font.family: Config.uiFont
            font.weight: item.isSelected ? Config.fontWeightMedium : Font.Normal
            elide: Text.ElideRight
            color: item.isSelected ? Style.on_primary : Style.on_surface
            Behavior on color {
                ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }

        Mouse {
            id: rowMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                control.currentIndex = item.index
                control.activated(item.index)
            }
        }
    }

    popup: Popup {
        id: pop
        y: control.height + 4
        width: Math.max(control.width, control.popupMinWidth)
        padding: control.popupPad
        transformOrigin: Item.Top

        // Abrir con la opción elegida a la vista (listas largas de temas).
        onOpened: list.positionViewAtIndex(control.currentIndex, ListView.Contain)

        // Fade + scale chico al abrir/cerrar (patrón C de qs-animations).
        enter: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"; from: 0; to: 1
                    duration: control.animOpenMs; easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    property: "scale"; from: control.scaleFrom; to: 1
                    duration: control.animOpenMs + control.scaleExtraMs
                    easing.type: Easing.OutCubic
                }
            }
        }
        exit: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"; from: 1; to: 0
                    duration: control.animCloseMs; easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    property: "scale"; from: 1; to: control.scaleFrom
                    duration: control.animCloseMs; easing.type: Easing.OutCubic
                }
            }
        }

        background: Rectangle {
            radius: Style.popup_radius_sm
            color: Style.surface_container_high
            border.color: Style.outline_variant
            border.width: 1
        }

        contentItem: ListView {
            id: list
            clip: true
            implicitHeight: Math.min(list.contentHeight, control.popupMaxHeight)
            model: control.delegateModel
            currentIndex: control.highlightedIndex
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
        }
    }
}
