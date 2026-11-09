// SectionLabel.qml — Etiqueta de sección uppercase usada en SettingsPopup y DashWidget.
// Uso: SectionLabel { text: "APARIENCIA" }
import QtQuick
import "../state"

Text {
    font.pixelSize:    Config.fontSizeCaption
    font.weight:       Config.fontWeightMedium
    font.family:       Config.uiFont
    color:             Style.on_surface
    font.letterSpacing: 1.2
}
