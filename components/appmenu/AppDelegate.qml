// AppDelegate.qml — Delegate del appmenu (buscar + abrir apps).
// Layout: [ICON] Name [Reciente]
//         Description (si existe)

import QtQuick
import Quickshell
import "../../state"
import ".."

Item {
    property var  itemData:  ({})
    property int  itemIndex: 0
    property bool isSelected: false
    property int  panelWidth: 520
    property bool isCategory: false

    signal appLaunched(var app)
    signal pinRequested(var app)

    height: 56

    // Ítems sintéticos del menú: comandos (">b") y archivos (">sf").
    readonly property bool isSpecial: !!(itemData.isCommand || itemData.isFile)
    readonly property string specialIcon: {
        if (itemData.isFile) return StartmenuState.fileIconFor(itemData.path ?? "")
        var c = itemData.cmd ?? ""
        if (c === "ia") return Icons.star
        if (c === "sf") return Icons.folderOutline
        return Icons.search
    }

    readonly property bool itemHasDescription: !isCategory && (itemData.comment ?? "") !== ""
    // Pineada: binding en vivo a TaskbarState (el badge se refresca in place
    // al pin/unpin sin reconstruir la lista).
    readonly property bool isAppPinned: !isCategory && !isSpecial
        && TaskbarState.isPinnedFuzzy(itemData.id ?? "")
    readonly property bool isRecent: itemData.isRecent === true

    Rectangle {
        anchors.fill: parent
        radius: 10
        property bool ph: false
        color: "transparent"

        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: Style.surface_container_highest
            opacity: parent.ph && !isSelected ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        }

        // Icon
        Item {
            id: iconItem
            width: 28; height: 28
            anchors { left: parent.left; leftMargin: 12 }
            anchors.verticalCenter: parent.verticalCenter

            // Category: folder icon
            Rectangle {
                anchors.fill: parent; radius: 6
                visible: isCategory
                color: Qt.alpha(Style.primary, 0.12)
                Text {
                    anchors.centerIn: parent
                    text: Icons.folder
                    font.pixelSize: Config.fontSizeBody; font.family: Icons.font
                    color: Style.on_primary
                }
            }

            // Comando / archivo: glifo propio (no ícono de app).
            Rectangle {
                anchors.fill: parent; radius: 6
                visible: isSpecial
                color: Qt.alpha(Style.primary, 0.12)
                Text {
                    anchors.centerIn: parent
                    text: specialIcon
                    font.pixelSize: Config.fontSizeBody; font.family: Icons.font
                    color: Style.primary
                }
            }

            // App icon
            Image {
                id: appIcon; anchors.fill: parent
                source: {
                    if (isCategory || isSpecial || (itemData.icon ?? "") === "") return ""
                    var resolved = Config.resolveIcon(itemData.icon)
                    return resolved !== "" ? resolved : Quickshell.iconPath(itemData.icon, true)
                }
                sourceSize.width: iconItem.width * 2
                sourceSize.height: iconItem.height * 2
                asynchronous: true
                smooth: true; mipmap: true; fillMode: Image.PreserveAspectFit
                visible: !isCategory && !isSpecial && source !== "" && status === Image.Ready
            }
            Rectangle {
                anchors.fill: parent; radius: 6
                visible: !isCategory && !isSpecial && (appIcon.source === "" || appIcon.status !== Image.Ready)
                color: Qt.hsla(((itemData.name ?? "A").charCodeAt(0) * 53 % 360) / 360, 0.55, 0.42, 1.0)
                Text {
                    anchors.centerIn: parent
                    text: (itemData.name ?? "?")[0].toUpperCase()
                    color: Style.on_primary
                    font.pixelSize: Config.fontSizeBodySm; font.weight: Config.fontWeightMedium; font.family: Config.uiFont
                }
            }
        }

        // Text area: name + optional description
        Column {
            id: textCol
            anchors { left: iconItem.right; leftMargin: 10; right: parent.right; rightMargin: 12 }
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            // Name row with badge
            Row {
                id: nameRow
                width: parent.width
                spacing: 8

                Text {
                    id: nameText
                    text: itemData.name ?? ""
                    font.pixelSize: Config.fontSizeBodySm; font.weight: Config.fontWeightMedium; font.family: Config.uiFont
                    color: isSelected ? Style.on_secondary_container : Style.on_surface
                    elide: Text.ElideRight
                    width: parent.width - (isRecent ? 64 : 0) - (isAppPinned ? 20 : 0)
                }

                Text {
                    visible: isAppPinned
                    text: Icons.pin
                    font.family: Icons.font; font.pixelSize: Config.fontSizeBodySm
                    color: isSelected ? Style.on_secondary_container : Style.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Badge {
                  text: "Reciente"
                  active: true
                    visible: isRecent
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Text {
                text: itemData.comment ?? ""
                font.pixelSize: Config.fontSizeLabelSm; font.family: Config.uiFont
                color: isSelected ? Style.on_secondary_container : Style.on_surface_variant
                opacity: isSelected ? 0.8 : 1.0
                elide: Text.ElideRight
                width: parent.width
                visible: itemHasDescription
            }
        }

        HoverHandler { onHoveredChanged: parent.ph = hovered }
        Mouse {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    if (!isCategory && !isSpecial) pinRequested(itemData)
                } else {
                    appLaunched(itemData)
                }
            }
        }
    }
}
