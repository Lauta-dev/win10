import QtQuick
import Quickshell
import Quickshell.Wayland
import "../state"
import "../components"

Item {
  id: root
  width: parent.width
  height: itemHeight

  property real   itemHeight: 71
  property real   value:       0
  property string iconChar:    Icons.volume
  property bool   iconActive:     true
  property bool   showLabel:      true
  property bool   showOverlayLabel:  false
  property bool   showIconToggle: true   // false = solo el icono, sin PillButton
  property color  overlayLabelColor: Style.on_surface
  property string labelText:         value + "%"
  property color  activeColor: Style.primary
  // Apaga las animaciones al cambiar de modo/contenido: el salto discreto
  // (p. ej. brillo→vol) debe pintar directo, no interpolarse a la vista.
  property bool   animations:   false

  signal changeRequested(real newValue)
  signal iconClicked()

  // Icono al lado del track: PillButton (clickeable) o solo el icono (decorativo)
  Item {
    id: iconContainer
    width: 36; height: 36
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left; anchors.leftMargin: 12

    PillButton {
      visible: root.showIconToggle
      anchors.fill: parent
      size: 36
      icon: root.iconChar
      active: root.iconActive
      onClicked: root.iconClicked()
    }

    Text {
      visible: !root.showIconToggle
      anchors.centerIn: parent
      text: root.iconChar
      font.pixelSize: Config.fontSizeIcon
      font.family: Icons.font
      color: root.iconActive ? Style.primary : Style.on_surface_variant
    }
  }

    Item {
      id: trackArea
      anchors.left: iconContainer.right; anchors.leftMargin: 10
      anchors.right: root.showLabel ? sliderLabel.left : parent.right; anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      height: parent.height

      Rectangle {
        id: trackBg
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left; anchors.leftMargin: 8
        anchors.right: parent.right; anchors.rightMargin: 8
        height: 4; radius: 2
        color: Style.surface_container_highest
      }

      Text {
        anchors.right: trackBg.right; anchors.rightMargin: 6
        anchors.verticalCenter: trackBg.verticalCenter
        text: root.labelText
        font.pixelSize: Config.fontSizeLabel; font.weight: Config.fontWeightMedium
        font.family: Config.uiFont
        color: root.overlayLabelColor
        visible: root.showOverlayLabel
      }

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: trackBg.left
        height: 4; radius: 2
        width: trackBg.width * root.value / 100
        color: root.activeColor
      }

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: trackBg.x + trackBg.width * (root.value / 100) - width / 2
        width: 12; height: 12; radius: 6
        color: root.activeColor
      }

      Mouse {
        anchors.fill: parent
        preventStealing: true
        onPressed:         (m) => apply(m.x)
        onPositionChanged: (m) => { if (pressed) apply(m.x) }
        onWheel: (w) => {
          var v = Math.max(0, Math.min(100, root.value + (w.angleDelta.y > 0 ? 5 : -5)))
          root.changeRequested(v)
        }
        function apply(mx) {
          var v = Math.round(Math.max(0, Math.min(mx - trackBg.x, trackBg.width)) / trackBg.width * 100)
          root.changeRequested(v)
        }
      }
    }

  Item {
    id: sliderLabel
    width: 36; height: parent.height
    anchors.right: parent.right; anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    visible: root.showLabel

      Text {
        anchors.centerIn: parent
        text: root.labelText
        font.pixelSize: Config.fontSizeLabel; font.weight: Config.fontWeightMedium
        font.family: Config.uiFont
        color: root.activeColor
      }
  }
}
