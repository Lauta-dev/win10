import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../state"
import "../../components"

// DirBrowser — Reusable directory/file browser overlay
// Modes:
//   "directories" — only folders, "Usar este directorio" button in header
//   "files"       — folders + texto; la fila elige el archivo; sin header button
//   "images"      — folders + imágenes; la fila elige la imagen

Rectangle {
    id: root
    visible: false
    color: Style.surface_container_lowest
    border.color: Style.outline_variant; border.width: 1
    radius: root.dialogRadius
    z: 10
    opacity: 0

    // ── Esquinas: 20 por defecto; Notas lo pone en 0 (todo cuadrado) ──
    property real dialogRadius: 20

    // ── Configuration ──────────────────────────────────────────────
    property string mode: "directories"     // "directories" | "files" | "images"
    property bool   showHeaderUseButton: mode === "directories"
    property string headerUseButtonLabel: "Usar este directorio"
    property bool   showHidden: false

    // ── Signals ────────────────────────────────────────────────────
    signal directorySelected(string path)   // header "Usar" clicked
    signal fileSelected(string path)        // fila de archivo (files|images)

    // ── State ──────────────────────────────────────────────────────
    property string currentPath: ""
    property var    entries: []

    // ── Methods ────────────────────────────────────────────────────
        function open(startPath) {
        if (startPath === undefined) startPath = "~"
        root.entries = []
        root.navigate(startPath)
        root.visible = true
        root.opacity = 1
    }
    function navigate(path) {
        DirBrowserState.listDir(path, root.mode, root.showHidden)
    }

    function close() {
        root.opacity = 0
        root.visible = false
    }

        function goUp() {
        if (currentPath === "" || currentPath === "/") return
        root.navigate(currentPath.substring(0, currentPath.lastIndexOf("/")) || "/")
    }

    // ── Conexión con el singleton de listado ─────────────────────
    Connections {
        target: DirBrowserState
        function onLoaded(path, entries) {
            root.entries = entries
            root.currentPath = path
        }
    }

    // ── Fondo modal: cursor flecha y traga clicks en zonas vacías para
    // que no lleguen a lo de abajo (ej: el TextEdit con I-beam en Notas).
    // Va primero (detrás de la lista): las filas siguen recibiendo todo.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.ArrowCursor
    }

    // ── UI ─────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        // Header row
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            // Close button
            Rectangle {
                width: 28; height: 28; radius: Style.radius_md
                color: dbCloseH.containsMouse ? Style.surface_container_highest : Style.surface_container_low
                Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
                Text {
                    anchors.centerIn: parent
                    text: Icons.close
                    font.pixelSize: Config.fontSizeLabel; font.family: Icons.font
                    color: Style.on_surface
                }
                HoverHandler { id: dbCloseH }
                TapHandler { onTapped: root.close() }
            }

            // Up button
            Rectangle {
                width: 28; height: 28; radius: Style.radius_md
                color: dbUpH.containsMouse ? Style.surface_container_highest : Style.surface_container_low
                Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
                opacity: root.currentPath !== "/" ? 1.0 : 0.3
                Text {
                    anchors.centerIn: parent
                    text: Icons.folderOutline
                    font.pixelSize: Config.fontSizeBodySm; font.family: Icons.font
                    color: Style.primary
                }
                HoverHandler { id: dbUpH }
                TapHandler { onTapped: root.goUp() }
            }

            // Show hidden toggle
            Rectangle {
                width: 28; height: 28; radius: Style.radius_md
                color: dbHiddenH.containsMouse ? Style.surface_container_highest : (root.showHidden ? Style.primary_container : Style.surface_container_low)
                Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
                Text {
                    anchors.centerIn: parent
                    text: root.showHidden ? Icons.eye : Icons.eyeOff
                    font.pixelSize: Config.fontSizeBodySm; font.family: Icons.font
                    color: root.showHidden ? Style.primary : Style.on_surface
                }
                HoverHandler { id: dbHiddenH }
                                TapHandler {
                    onTapped: {
                        root.showHidden = !root.showHidden
                        root.navigate(root.currentPath)
                    }
                }
            }

            // Current path
            Text {
                text: (mode === "directories" ? Icons.folderOutline
                     : mode === "images" ? Icons.image
                     : Icons.file) + "  " + root.currentPath
                font.pixelSize: Config.fontSizeBodySm; font.family: Config.uiFont
                color: Style.on_surface
                Layout.fillWidth: true
                elide: Text.ElideMiddle
            }

            // "Usar este directorio" button (directories mode only)
            Rectangle {
                visible: root.showHeaderUseButton
                height: 28; width: dbUseRow.implicitWidth + 16; radius: Style.radius_md
                color: dbUseH.containsMouse ? Style.primary : Style.primary_container
                Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
                RowLayout {
                    id: dbUseRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: Icons.checkBold
                        font.pixelSize: Config.fontSizeLabel; font.family: Icons.font
                        color: dbUseH.containsMouse ? Style.on_primary : Style.primary
                        Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
                    }
                    Text {
                        text: root.headerUseButtonLabel
                        font.pixelSize: Config.fontSizeLabel; font.family: Config.uiFont
                        color: dbUseH.containsMouse ? Style.on_primary : Style.primary
                        Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
                    }
                }
                HoverHandler { id: dbUseH }
                TapHandler {
                    onTapped: root.directorySelected(root.currentPath)
                }
            }
        }

        // Divider
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Style.outline_variant
        }

        // Grid de carpetas/archivos/imágenes
        GridView {
            id: dbGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.entries
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 150
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            readonly property int cols: Math.max(2, Math.floor(width / 140))
            cellWidth: Math.floor(width / cols)
            cellHeight: cellWidth

            delegate: Item {
                id: dbCell
                required property var modelData
                width: GridView.view ? GridView.view.cellWidth : 0
                height: GridView.view ? GridView.view.cellHeight : 0

                readonly property bool isParent: modelData.isParent
                readonly property bool isImage: modelData.isImage ?? false
                readonly property bool isMd: modelData.isMd ?? false
                readonly property string cellName: dbCell.isParent ? ".." : (modelData.name ?? "")

                // Miniatura: se decodifica el archivo real a la escala de la
                // celda (Qt cachea el pixmap entre recreaciones).
                // (loadPreviews del dir actual; thumbSource es sólo lectura).

                // Celda clickeable: archivo (files|images) elige; carpeta entra.
                // Hover con border + overlay y cursor pointer (Mouse.qml).
                Rectangle {
                    id: dbCard
                    anchors.fill: parent
                    anchors.margins: 5
                    radius: Style.radius_md
                    clip: true
                    color: Style.surface_container_low
                    border.color: dbCellMouse.containsMouse ? Style.primary : Style.outline_variant
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }

                    // Miniatura (modo images) — decodifica el archivo real
                    // a la escala de la celda (Qt cachea el pixmap).
                    RoundedImage {
                        id: dbThumb
                        anchors.fill: parent
                        radius: dbCard.radius
                        source: dbCell.isImage ? dbCell.modelData.path : ""
                        sourceSize: Qt.size(300, 300)
                        visible: status === Image.Ready
                    }

                    // Scrim + nombre sobre la miniatura
                    Rectangle {
                        visible: dbThumb.status === Image.Ready
                        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                        height: 34
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0) }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
                        }
                        Text {
                            anchors.left: parent.left; anchors.leftMargin: 8
                            anchors.right: parent.right; anchors.rightMargin: 8
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                            text: dbCell.cellName
                            font.pixelSize: Config.fontSizeLabelSm; font.family: Config.uiFont
                            font.weight: Config.fontWeightMedium
                            color: "white"
                            elide: Text.ElideMiddle
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    // Icono + nombre (carpetas, ".." y archivos sin miniatura)
                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        spacing: 6
                        visible: dbThumb.status !== Image.Ready

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dbCell.isParent ? Icons.folderOutline
                                : dbCell.isImage ? Icons.image
                                : dbCell.isMd ? Icons.file
                                : Icons.folder
                            font.pixelSize: Config.fontSizeIconLg; font.family: Icons.font
                            color: dbCell.isParent ? Style.outline
                                 : (dbCell.isImage || dbCell.isMd) ? Style.primary
                                 : Style.on_surface_variant
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            text: dbCell.cellName
                            font.pixelSize: Config.fontSizeLabelSm; font.family: Config.uiFont
                            color: dbCell.isParent ? Style.outline : Style.on_surface
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }

                    // Overlay hover
                    Rectangle {
                        anchors.fill: parent
                        radius: dbCard.radius
                        color: Style.overlay_tint(0.10)
                        opacity: dbCellMouse.containsMouse ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                    }
                }

                Mouse {
                    id: dbCellMouse
                    anchors.fill: parent
                                        onClicked: {
                        if (dbCell.isImage || dbCell.isMd) root.fileSelected(modelData.path)
                        else root.navigate(modelData.path)
                    }
                }
            }
        }
    }
}
