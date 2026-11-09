// Style.qml — Fuente única de verdad visual.
//
// DE DÓNDE VIENEN LOS COLORES:
//   wallpaper → bin/matugen-apply → ~/.cache/matugen-active.json
//   Style lee ese JSON y expone cada rol MD3 tal cual lo genera matugen.
//   Sin paletas propias, sin remaps.
//
// Acceso directo por binding: cada token evalúa dark + JSON en una sola
// expresión (sin objetos intermedios) para que el rebind sea inmediato.
// Si aún no cargó el JSON → MAGENTA (#ff00ff): centinela visible.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // ═══════════════ MODO ═══════════════
    property bool dark: TaskbarState.darkMode

    // ═══════════════ MATUGEN ═══════════════
    property var _activeMd3: null
    property int _rev: 0  // se incrementa en cada carga → fuerza re-eval de todos los tokens

    FileView {
        id: matugenFile
        path: Quickshell.env("HOME") + "/.cache/matugen-active.json"
        watchChanges: true
        preload: true
        onFileChanged: reloadTimer.restart()
        onLoaded: root._applyMatugen()
    }

    Timer {
        id: reloadTimer
        interval: 50; repeat: false
        onTriggered: matugenFile.reload()
    }

    function _applyMatugen() {
        var raw = matugenFile.text()
        if (!raw || raw.trim() === "") return
        try {
            var data = JSON.parse(raw)
            if (data && data.dark && data.dark.md3) _activeMd3 = data
        } catch (e) {}
    }

    Component.onCompleted: _applyMatugen()

    // Paleta del modo activo (null hasta que carga el JSON)
    function _m() {
        if (!_activeMd3) return null
        return dark ? _activeMd3.dark.md3 : _activeMd3.light.md3
    }

    function _c(key) {
        var m = _m()
        return (m && m[key] !== undefined) ? String(m[key]) : "transparent"
    }

    // Todas las claves del modo activo (para inspección/lab)
    readonly property var all_keys: {
        var m = _m()
        return m ? Object.keys(m).sort() : []
    }

    // Valor crudo por nombre de clave (para el lab)
    function raw(key) {
        var m = _m()
        return m && m[key] !== undefined ? String(m[key]) : ""
    }

    // ═══════════════ ROLES MD3 CRUDOS (passthrough de matugen) ═══════════════

    // Primary
    readonly property string primary:            _c("primary")
    readonly property string on_primary:          _c("on_primary")
    readonly property string primary_container:  _c("primary_container")
    readonly property string on_primary_container: _c("on_primary_container")

    // Secondary
    readonly property string secondary:            _c("secondary")
    readonly property string on_secondary:          _c("on_secondary")
    readonly property string secondary_container:   _c("secondary_container")
    readonly property string on_secondary_container: _c("on_secondary_container")

    // Tertiary
    readonly property string tertiary:            _c("tertiary")
    readonly property string on_tertiary:          _c("on_tertiary")
    readonly property string tertiary_container:   _c("tertiary_container")
    readonly property string on_tertiary_container: _c("on_tertiary_container")

    // Error
    readonly property string error:            _c("error")
    readonly property string on_error:          _c("on_error")
    readonly property string error_container:   _c("error_container")
    readonly property string on_error_container: _c("on_error_container")

    // Surface ladder
    readonly property string surface:                 _c("surface")
    readonly property string surface_dim:              _c("surface_dim")
    readonly property string surface_bright:           _c("surface_bright")
    readonly property string surface_container_lowest:  _c("surface_container_lowest")
    readonly property string surface_container_low:     _c("surface_container_low")
    readonly property string surface_container:        _c("surface_container")
    readonly property string surface_container_high:    _c("surface_container_high")
    readonly property string surface_container_highest: _c("surface_container_highest")
    readonly property string surface_variant:          _c("surface_variant")

    // On-surface / outline
    readonly property string on_surface:        _c("on_surface")
    readonly property string on_surface_variant: _c("on_surface_variant")
    readonly property string outline:          _c("outline")
    readonly property string outline_variant:   _c("outline_variant")


    // ═══════════════ DERIVADOS ═══════════════
    readonly property string danger: error
    readonly property string interactive_bg: Qt.alpha(primary, 0.20)

    // Bordes y sombras (negro con alpha — estructural)
    readonly property int   border_width:       1
    readonly property int   border_width_strong: 2
    readonly property color shadow_border: dark ? Qt.rgba(0,0,0,0.14) : Qt.rgba(0,0,0,0.16)
    readonly property color scrim_solid:   Qt.rgba(0,0,0,0.80)

    // ═══════════════ RADIUS ═══════════════
    property string radius_mode: "medium"
    readonly property var _radius_presets: ({
        "none":   { xs:0, sm:2,  md:4,  lg:6,  xl:12, pill:30,  full:100 },
        "small":  { xs:1, sm:2,  md:4,  lg:6,  xl:10, pill:30,  full:100 },
        "medium": { xs:2, sm:4,  md:6,  lg:12, xl:16, pill:60,  full:100 },
        "large":  { xs:3, sm:6,  md:10, lg:16, xl:20, pill:80,  full:100 },
        "full":   { xs:20,sm:50, md:100,lg:100,xl:100,pill:100, full:100 }
    })
    property var radius_area_overrides: ({})

    function radius_for(area, size) {
        var name = radius_area_overrides[area] || radius_mode
        var p = _radius_presets[name] || _radius_presets["medium"]
        return p[size] ?? p["md"]
    }

    readonly property int radius_xs:        radius_for("taskbar","xs")
    readonly property int radius_sm:        radius_for("taskbar","sm")
    readonly property int radius_md:        radius_for("taskbar","md")
    readonly property int radius_lg:        radius_for("taskbar","lg")
    readonly property int radius_pill:      radius_for("taskbar","pill")
    readonly property int popup_radius:      radius_for("popups","lg")
    readonly property int popup_radius_md:    radius_for("popups","md")
    readonly property int popup_radius_sm:    radius_for("popups","sm")
    readonly property int button_radius:     radius_for("buttons","md")
    readonly property int button_radius_sm:   radius_for("buttons","sm")
    readonly property int button_radius_lg:   radius_for("buttons","lg")
    readonly property int container_radius: 12

    // ═══════════════ SPACING / MOTION ═══════════════
    readonly property int sp2: 2
    readonly property int sp4: 4
    readonly property int sp8: 8
    readonly property int sp12: 12
    readonly property int sp16: 16
    readonly property int sp24: 24
    readonly property int anim_fast:   120
    readonly property int anim_normal: 180
    readonly property int anim_slow:   280

    // ═══════════════ HELPERS ═══════════════
    function tint(color, alpha) { return Qt.alpha(color, alpha) }
    function overlay_tint(alpha) {
        return dark ? Qt.rgba(1,1,1,alpha) : Qt.rgba(0,0,0,alpha)
    }
}
