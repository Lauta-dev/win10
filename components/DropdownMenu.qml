// DropdownMenu.qml — Menú flotante (dropdown) reutilizable.
//
// Unifica los menús flotantes hechos a mano (ctxMenu/layMenu del CC):
// superficie tonal con fade+scale, filas con ícono + label + check, y un
// Rectangle por estado en cada fila (hover / seleccionado, qml-gotchas #2).
//
// Uso:
//   DropdownMenu {
//       x: root._menuX; y: root._menuY        // el consumidor posiciona
//       open: root._menuVisible               // binding al estado del caller
//       items: [{ id: "a", label: "Uno", icon: Icons.x },
//               { id: "b", label: "Dos", icon: Icons.y, danger: true }]
//       selectedId: "a"                       // "" = sin selección
//       onPicked: (id) => { ...; root._menuVisible = false }
//       onDismissed: root._menuVisible = false // click en la superficie
//   }
//
// Contratos:
//   - El menú NUNCA escribe `open`: el consumidor cierra desde su estado
//     (escribirlo adentro rompería el binding del caller). picked() y
//     dismissed() son solo notificaciones.
//   - Instanciar DENTRO del contenido del popup (wrapper del CC, etc.)
//     para que la máscara Region del host incluya al menú.
//   - Cursor: Arrow en la superficie, PointingHand SOLO en las filas.
//   - Filas custom (contenido rico, ej. players con carátula): property
//     rowDelegate. El delegate custom es dueño de sus filas (hover,
//     pointer, selección); width desde parent (la Column contenedora),
//     modelData inyectado y selectedId vía el id de la instancia.
//   - Menús cortos (3-5 filas). Para selects anclados con scroll (listas
//     largas dentro de paneles con clip) está SettingsCombo.

import QtQuick
import "../state"

Rectangle {
    id: menu

    // ── API ──
    property var items: []              // [{id, label, icon, danger?}]
    property string selectedId: ""      // item marcado (bg + check)
    property real itemHeight: 44        // filas compactas (ctx): 32
    property real iconPixelSize: Config.fontSizeBody
    property bool open: false
    // Delegate de fila. Default (defRow): icono + label + check con el
    // contrato estándar. Custom: ver MusicPopup (filas ricas).
    property Component rowDelegate: defRow

    signal picked(string id)
    signal dismissed()                  // click en la superficie (fuera de filas)

    // ── Superficie ──
    implicitWidth: 200
    implicitHeight: menuCol.implicitHeight + 8
    // Plain Item no aplica implicit sizes solo: width/height siguen a
    // implicit* salvo que el caller fije width (ctx usa 180).
    width: implicitWidth
    height: implicitHeight
    visible: opacity > 0
    opacity: open ? 1.0 : 0.0
    scale: open ? 1.0 : 0.96
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    radius: 12
    color: Style.surface_container_low
    z: 1000

    // Superficie: Arrow (el pointer es SOLO de las filas) y notifica, no cierra.
    Mouse {
        anchors.fill: parent
        cursorShape: Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: menu.dismissed()
    }

    Column {
        id: menuCol
        anchors.fill: parent
        anchors.margins: 4
        spacing: 2

        Repeater {
            model: menu.items
            delegate: menu.rowDelegate
        }
    }

    // Delegate por defecto: icono + label + check con el contrato estándar
    // (pointer solo en la fila, hover, bg de selección). Instantiado desde
    // este documento: ve `menu` y `menuCol`.
    Component {
        id: defRow

        Item {
            id: row
            required property var modelData
            width: menuCol.width
            height: menu.itemHeight

            readonly property bool selected: menu.selectedId !== "" && modelData.id === menu.selectedId
            readonly property color fg: modelData.danger ? Style.danger
                : selected ? Style.on_secondary_container : Style.on_surface

            // Un Rectangle por estado, cada uno con su Behavior.
            Rectangle {
                anchors.fill: parent
                radius: 10
                color: Style.secondary_container
                opacity: row.selected ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
            }
            Rectangle {
                anchors.fill: parent
                radius: 10
                color: Style.interactive_bg
                opacity: rowMouse.containsMouse && !row.selected ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
            }

            Text {
                id: icon
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.icon || ""
                font.pixelSize: menu.iconPixelSize
                font.family: Icons.font
                color: row.fg
            }

            Text {
                anchors.left: icon.right
                anchors.leftMargin: 10
                anchors.right: check.visible ? check.left : parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.label
                font.pixelSize: Config.fontSizeBodySm
                font.family: Config.uiFont
                font.weight: row.selected ? Font.Medium : Font.Normal
                color: row.fg
                elide: Text.ElideRight
            }

            Text {
                id: check
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                visible: row.selected
                text: Icons.check
                font.pixelSize: Config.fontSizeBodySm
                font.family: Icons.font
                color: row.fg
            }

            Mouse {
                id: rowMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: menu.picked(row.modelData.id)
            }
        }
    }
}
