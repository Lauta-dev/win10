// ClipItemDelegate.qml — Delegate lista: filas de texto/archivo de 56px,
// filas de imagen con banner grande a todo el ancho (186px).
// NOTA: la altura de imagen (186) se repite en ClipDelegate y en el
// Loader de ClipView: mantener los tres en sync.

import QtQuick
import "../../state"

Rectangle {
    id: root

    // ── API ───────────────────────────────────────────────────────────────────
    required property var entry      // objeto de ClipEntry.parse()
    property int itemHeight: 56
    property bool highlighted: false
    property bool keyboardActive: false
    signal copyRequested()
    signal hovered()
    signal mouseLeft()

    // compat: viejos callers pasaban cellWidth/cellHeight
    property int cellWidth: 0
    property int cellHeight: 0

    // Fila de imagen con thumbnail grande: solo paths locales (raw !== "").
    // Binarios y URLs usan la fila clásica con glifo.
    readonly property bool bigImage: entry.isImage === true && (entry.raw ?? "") !== ""

    // ── Geometría ─────────────────────────────────────────────────────────────
    width: parent ? parent.width : 0
    height: bigImage ? 186 : itemHeight
    radius: Style.radius_md
    clip: true
    color: "transparent"

    // ── Hover overlay ─────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Style.surface_container_highest
        opacity: root._ph && !root.keyboardActive && !root.highlighted ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
    }

    // Selección: la dibuja el highlight del ListView (deslizante);
    // acá solo hover. Se conserva la prop `highlighted` por compat.
    property bool _ph: false

    // ── Contenido: banner de imagen ───────────────────────────────────────────
    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6
        visible: root.bigImage

        Item {
            width: parent.width
            height: 148
            clip: true
            Rectangle { anchors.fill: parent; radius: 8; color: Qt.alpha(Style.outline_variant, 0.15) }
            Image {
                id: imgBanner
                anchors.fill: parent
                source: root.bigImage ? ("file://" + entry.raw) : ""
                fillMode: Image.PreserveAspectCrop
                // Banner: decodificar al tamaño mostrado, no el archivo completo.
                sourceSize.width: width * 2
                sourceSize.height: height * 2
                asynchronous: true
                smooth: true
                mipmap: true
                visible: status === Image.Ready
            }
            Rectangle {
                anchors.fill: parent; radius: 8; color: "transparent"
                border { color: Qt.alpha(Style.outline_variant, 0.35); width: 1 }
            }
            Text {
                anchors.centerIn: parent
                visible: imgBanner.status !== Image.Ready
                text: imgBanner.status === Image.Error ? "?" : "…"
                font.pixelSize: 16
                font.family: Config.uiFont
                color: Style.outline
            }
        }

        Text {
            width: parent.width
            text: entry.label
            font { pixelSize: 12; weight: Font.Medium; family: Config.uiFont }
            color: Style.on_surface
            elide: Text.ElideRight
            maximumLineCount: 1
            wrapMode: Text.NoWrap
        }
    }

    // ── Contenido: fila clásica 56px (texto / archivo / imagen sin thumb) ────
    Row {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        spacing: 12
        visible: !root.bigImage

        // Icon / thumbnail
        Item {
            width: 40; height: 40
            anchors.verticalCenter: parent.verticalCenter

            // Icono para imagen sin thumbnail local (binario u online)
            Item {
                anchors.fill: parent
                visible: entry.isImage
                clip: true
                Rectangle { anchors.fill: parent; radius: 6; color: Qt.alpha(Style.outline_variant, 0.15) }
                Text {
                    anchors.centerIn: parent
                    text: entry.icon
                    font.pixelSize: 20
                    font.family: Icons.font
                    color: entry.iconColor
                }
            }

            // Icon file no-imagen
            Rectangle {
                anchors.fill: parent
                radius: 8
                color: entry.isFile && !entry.isImage ? Qt.alpha(entry.iconColor, 0.12) : "transparent"
                visible: entry.isFile && !entry.isImage
                Text {
                    anchors.centerIn: parent
                    text: entry.icon
                    font { pixelSize: 20; family: Icons.font }
                    color: entry.iconColor
                }
            }

            // Icon texto plano
            Rectangle {
                anchors.fill: parent
                radius: 8
                color: !entry.isFile ? Qt.alpha(Style.primary, 0.10) : "transparent"
                visible: !entry.isFile
                Text {
                    anchors.centerIn: parent
                    text: "\uDB80\uDC6B" // text icon
                    font { pixelSize: 18; family: Icons.font }
                    color: Style.primary
                }
            }
        }

        // Textos
        Column {
            width: parent.width - 40 - 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            // Primary: label (filename o texto recortado)
            Text {
                width: parent.width
                text: entry.label
                font { pixelSize: 13; weight: Font.Medium; family: Config.uiFont }
                color: Style.on_surface
                elide: Text.ElideRight
                maximumLineCount: entry.isFile ? 1 : 3
                wrapMode: Text.Wrap
                lineHeight: 1.1
            }

            // Secondary: sub solo para file, para texto muestra nada extra
            Text {
                width: parent.width
                visible: entry.isFile && entry.sub !== ""
                text: entry.sub
                font.pixelSize: 11; font.family: Config.uiFont
                color: Style.outline
                elide: Text.ElideRight
                maximumLineCount: 1
                wrapMode: Text.NoWrap
            }

            // Preview: snippet congelado para archivos de texto
            Text {
                width: parent.width
                visible: (entry.preview ?? "") !== ""
                text: entry.preview ?? ""
                font.pixelSize: 11; font.family: Config.uiFont
                color: Style.on_surface_variant
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
                lineHeight: 1.1
            }
        }
    }

    HoverHandler { onHoveredChanged: { root._ph = hovered && !root.keyboardActive; if (hovered) root.hovered(); else root.mouseLeft() } }
    TapHandler   { onTapped: root.copyRequested() }
}
