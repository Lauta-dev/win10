import QtQuick
import Quickshell
import "../state"
import "../components"

Row {
  id: controlsRow
  height: 28
  spacing: 5

  property int iconSize: 20
  property int customRadius: 12

  property int toggleRadius: -1

  property int prevH: 28
  property int prevW: 26

  property int toggleH: 28
  property int toggleW: 32

  property int nextH: 28
  property int nextW: 26

  // Origen de estado y acciones (default MPRIS; MPD los sobreescribe)
  property bool playing: MprisState.musicPlaying
  property var prevAction: function() { MprisState.musicPrev() }
  property var toggleAction: function() { MprisState.musicPlayPause() }
  property var nextAction: function() { MprisState.musicNext() }

  // Color del botón toggle (default: tema global; el palette MPD lo tiñe)
  property color toggleColor: Style.primary
  property color toggleTextColor: Style.on_primary
  property color toggleHoverColor: Qt.darker(Style.primary, 1.2)

  // Color de Prev/Next ghost (default: tema; sobre cover se pasan claros)
  property color prevColor: Style.on_surface_variant
  property color nextColor: Style.on_surface_variant
  property color prevHoverColor: Style.surface_container_highest
  property color nextHoverColor: Style.surface_container_highest

    // Prev / Next — M3 icon button: fondo transparente, hover sólido visible
    PillButton {
      width: controlsRow.prevW; height: controlsRow.prevH
      radius: controlsRow.customRadius >= 0 ? controlsRow.customRadius : height / 2
      icon: Icons.musicPrev
      iconSize: controlsRow.iconSize
      customContainerColor: "transparent"
      customTextColor: controlsRow.prevColor
      customHoverColor: controlsRow.prevHoverColor
      onClicked: controlsRow.prevAction()
    }

    // Toggle — M3 FAB: primary siempre lleno, hover primary oscurecido
    PillButton {
      width: controlsRow.toggleW; height: controlsRow.toggleH
      radius: controlsRow.toggleRadius >= 0 ? controlsRow.toggleRadius
              : (controlsRow.customRadius >= 0 ? controlsRow.customRadius : height / 2)
      icon: controlsRow.playing ? Icons.musicPause : Icons.musicPlay
      iconSize: controlsRow.iconSize

      customContainerColor: controlsRow.toggleColor
      customTextColor: controlsRow.toggleTextColor
      customHoverColor: controlsRow.toggleHoverColor

      onClicked: controlsRow.toggleAction()
    }

    //Next
    PillButton {
      width: controlsRow.nextW; height: controlsRow.nextH
      radius: controlsRow.customRadius >= 0 ? controlsRow.customRadius : height / 2
      icon: Icons.musicNext
      iconSize: controlsRow.iconSize

      customContainerColor: "transparent"
      customTextColor: controlsRow.nextColor
      customHoverColor: controlsRow.nextHoverColor
      onClicked: controlsRow.nextAction()
    }
}
