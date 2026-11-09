// PillButton.qml — Botón MD3 reutilizable (icon + label opcional)
// Unifica IconPill (dash toggles) y PillButton (settings)
import QtQuick
import "../state"

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property int size: 36
    property int minWidth: 0
    property int iconSize: Config.fontSizeHeadline
    property string iconFont: Icons.font
    property bool active: false
    property int customRadius: -1
    // Centra icono+label (por defecto van a la izquierda cuando el botón
    // es más ancho que su contenido).
    property bool centerContent: false

    property string customContainerColor: ""
    property string customHoverColor: ""
    property string customTextColor: ""
    property bool interactive: true
    readonly property bool hovered: mouseArea.containsMouse || root.forceHover
    // Resalta como hover sin mouse (navegación por teclado). Cuando está
    // activo, el overlay propio cede: la selección la dibuja el highlight
    // deslizante del contenedor (patrón AppMenu/PanelList).
    property bool forceHover: false

    signal clicked()
    signal rightClicked()

    width: Math.max(root.label !== "" ? labelRow.implicitWidth + 16 : root.size, root.minWidth)
    height: root.size
    radius: root.customRadius >= 0 ? root.customRadius : Style.button_radius_lg
    color: customContainerColor !== ""
        ? customContainerColor
        : root.active ? Style.primary : Style.surface_container

    Mouse {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: root.interactive
        enabled: root.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                root.clicked()
            } else {
                root.rightClicked()
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: root.active ? Qt.darker(Style.primary, 1.3)
              : customHoverColor !== "" ? customHoverColor
              : Style.interactive_bg
        opacity: root.interactive && root.hovered && !root.forceHover ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
    }

    Row {
        id: labelRow
        anchors.left: (!root.centerContent && root.label !== "" && root.icon !== "") ? parent.left : undefined
        anchors.leftMargin: (!root.centerContent && root.label !== "" && root.icon !== "") ? 8 : 0
        anchors.horizontalCenter: (root.centerContent || root.label === "" || root.icon === "") ? parent.horizontalCenter : undefined
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5
        layoutDirection: Qt.LeftToRight

        Text {
            visible: root.icon !== ""
            text: root.icon
            height: root.height
            font.pixelSize: root.iconSize
            font.family: root.iconFont
            verticalAlignment: Text.AlignVCenter
            color: root.customTextColor !== ""
                ? root.customTextColor
                : root.active ? Style.on_primary : Style.on_surface
        }

        Text {
            visible: root.label !== ""
            text: root.label
            height: root.height
            font.pixelSize: Config.fontSizeLabel
            font.family: Config.uiFont
            font.weight: Config.fontWeightMedium
            verticalAlignment: Text.AlignVCenter
            color: root.customTextColor !== ""
                ? root.customTextColor
                : root.active ? Style.on_primary : Style.on_surface
        }
    }
}
