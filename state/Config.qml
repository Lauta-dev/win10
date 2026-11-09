// Config.qml — Material Design 3 tokens desde matugen
// La paleta la lee Style (único watcher de ~/.cache/matugen-active.json);
// acá solo se espeja para exponerla en formato camelCase + defaults.
pragma Singleton
import Quickshell
import QtQuick

Singleton {

    // ── Matugen — espejo de Style (sin FileView propio) ─────────────────
    // Un solo watch del JSON (Style): antes había dos FileView + dos
    // timers de 50ms al mismo path + un refresh extra vía WallpaperState.
    readonly property var _activeMd3: Style._activeMd3

    property bool dark: TaskbarState.darkMode

    // ── Default theme (sin matugen) ───────────────────────────────────────
    readonly property var _defaultDark: {
        "primary": "#8AB4F8", "on_primary": "#003566", "primary_container": "#004A93",
        "on_primary_container": "#D3E3FD", "secondary": "#A8C7FA", "on_secondary": "#062E6F",
        "secondary_container": "#1B4B91", "on_secondary_container": "#D3E3FD",
        "tertiary": "#78D9EC", "on_tertiary": "#003640", "tertiary_container": "#004F5C",
        "on_tertiary_container": "#BEEAF8", "error": "#F28B82", "on_error": "#601410",
        "error_container": "#8C1D18", "on_error_container": "#F2DEDE",
        "surface": "#1C1C1C", "on_surface": "#E8EAED", "surface_variant": "#1E2433",
        "on_surface_variant": "#9AA0A6", "surface_container_lowest": "#141414",
        "surface_container_low": "#1A1A1A", "surface_container": "#1C1C1C",
        "surface_container_high": "#222222", "surface_container_highest": "#2A2A2A",
        "surface_dim": "#1C1C1C", "surface_bright": "#383838",
        "outline": "#5F6368", "outline_variant": "#3C4043", "inverse_surface": "#E8EAED",
        "inverse_on_surface": "#1C1C1C", "inverse_primary": "#004A93",
        "scrim": "#000000", "shadow": "#000000"
    }
    readonly property var _defaultLight: {
        "primary": "#1A73E8", "on_primary": "#FFFFFF", "primary_container": "#D3E3FD",
        "on_primary_container": "#001D36", "secondary": "#1A73E8", "on_secondary": "#FFFFFF",
        "secondary_container": "#D3E3FD", "on_secondary_container": "#001D36",
        "tertiary": "#007B83", "on_tertiary": "#FFFFFF", "tertiary_container": "#BEEAF8",
        "on_tertiary_container": "#002020", "error": "#C5221F", "on_error": "#FFFFFF",
        "error_container": "#F9DEDC", "on_error_container": "#410002",
        "surface": "#F8F9FA", "on_surface": "#202124", "surface_variant": "#E8F0FE",
        "on_surface_variant": "#5F6368", "surface_container_lowest": "#FFFFFF",
        "surface_container_low": "#F8F9FA", "surface_container": "#F1F3F4",
        "surface_container_high": "#E8EAED", "surface_container_highest": "#DADCE0",
        "surface_dim": "#DADCE0", "surface_bright": "#F8F9FA",
        "outline": "#DADCE0", "outline_variant": "#E8EAED", "inverse_surface": "#202124",
        "inverse_on_surface": "#F1F3F4", "inverse_primary": "#A8C7FA",
        "scrim": "#000000", "shadow": "#000000"
    }

    // ── md3 tokens — matugen o ChromeOS default ───────────────────────────
    readonly property var md3: {
        if (_activeMd3) {
            var modeData = dark ? _activeMd3.dark : _activeMd3.light
            if (modeData && modeData.md3) return modeData.md3
        }
        return dark ? _defaultDark : _defaultLight
    }

    // ── MD3 Surface ────────────────────────────────────────────────────────
    readonly property string surfaceContainerLowest:  md3.surface_container_lowest
    readonly property string surfaceContainerLow:     md3.surface_container_low
    readonly property string surfaceContainer:        md3.surface_container
    readonly property string surfaceContainerHigh:    md3.surface_container_high
    readonly property string surfaceContainerHighest: md3.surface_container_highest
    readonly property string surfaceVariant:          md3.surface_variant
    readonly property string surfaceDim:              md3.surface_dim
    readonly property string surfaceBright:           md3.surface_bright

    // ── MD3 On-surface ─────────────────────────────────────────────────────
    readonly property string onSurface:           md3.on_surface
    readonly property string onSurfaceVariant:    md3.on_surface_variant

    // ── MD3 Primary ────────────────────────────────────────────────────────
    readonly property string primary:              md3.primary
    readonly property string onPrimary:            md3.on_primary
    readonly property string primaryContainer:     md3.primary_container
    readonly property string onPrimaryContainer:   md3.on_primary_container

    // ── MD3 Secondary ──────────────────────────────────────────────────────
    readonly property string secondary:            md3.secondary
    readonly property string onSecondary:          md3.on_secondary
    readonly property string secondaryContainer:   md3.secondary_container
    readonly property string onSecondaryContainer: md3.on_secondary_container

    // ── MD3 Tertiary ───────────────────────────────────────────────────────
    readonly property string tertiary:             md3.tertiary
    readonly property string onTertiary:           md3.on_tertiary
    readonly property string tertiaryContainer:    md3.tertiary_container
    readonly property string onTertiaryContainer:  md3.on_tertiary_container

    // ── MD3 Error ──────────────────────────────────────────────────────────
    readonly property string error:               md3.error
    readonly property string onError:             md3.on_error
    readonly property string errorContainer:      md3.error_container
    readonly property string onErrorContainer:    md3.on_error_container

    // ── MD3 Outline / Scrim ────────────────────────────────────────────────
    readonly property string outline:             md3.outline
    readonly property string outlineVariant:      md3.outline_variant
    readonly property string scrim:               md3.scrim

    // ── MD3 Inverse ────────────────────────────────────────────────────────
    readonly property string inverseSurface:      md3.inverse_surface
    readonly property string inverseOnSurface:    md3.inverse_on_surface
    readonly property string inversePrimary:      md3.inverse_primary

    // ── MD3 State layer opacities ──────────────────────────────────────────
    readonly property real stateLayerHoverOpacity:  0.08
    readonly property real stateLayerPressedOpacity: 0.12
    readonly property real stateLayerDraggedOpacity: 0.16

    // ── Base text tokens ───────────────────────────────────────────────────
    readonly property string textWithBg:    onPrimary
    readonly property string textWithoutBg: onSurface

    // ── MD3 Elevation ──────────────────────────────────────────────────────
    readonly property color  idleBg:        dark ? Qt.rgba(0.082,0.082,0.082,0) : Qt.rgba(0.945,0.949,0.961,0)
    readonly property string pressBg:       Qt.alpha(md3.primary, 0.22)
    readonly property string activeBg:      Qt.alpha(md3.primary, 0.18)

    // ── Interactive (buttons, chips) ───────────────────────────────────────
    readonly property string interactiveBg:        Qt.alpha(primary, 0.20)
    readonly property string interactiveBgHover:   Qt.alpha(primary, 0.90)
    readonly property string interactiveFg:        primary
    readonly property string interactiveFgHover:   textWithBg

    // ── Selected (active indicator) ────────────────────────────────────────
    readonly property string selectedBg:   primary
    readonly property string selectedFg:   _contrastOn(primary)

    // ── Contraste automático sobre bg ──────────────────────────────────────
    function _contrastOn(hex) {
        var c = String(hex).replace("#", "")
        if (c.length === 3) c = c[0]+c[0]+c[1]+c[1]+c[2]+c[2]
        var r = parseInt(c.substr(0,2),16) / 255
        var g = parseInt(c.substr(2,2),16) / 255
        var b = parseInt(c.substr(4,2),16) / 255
        function lin(v) { return v <= 0.04045 ? v/12.92 : Math.pow((v+0.055)/1.055, 2.4) }
        var L = 0.2126*lin(r) + 0.7152*lin(g) + 0.0722*lin(b)
        var contrastWhite = (1.05) / (L + 0.05)
        var contrastBlack = (L + 0.05) / (0.05)
        return contrastWhite >= contrastBlack ? "#FFFFFF" : "#1a1a1a"
    }

    // ── Colores semánticos ─────────────────────────────────────────────────
    readonly property string red:    md3.error
    readonly property string green:  md3.tertiary
    readonly property string yellow: md3.secondary
    readonly property string blue:   md3.primary
    readonly property string teal:   md3.tertiary_container
    readonly property string peach:  md3.secondary_container
    readonly property string mauve:  md3.primary_container

    // ── Aliases legacy (usados en componentes) ─────────────────────────────
    readonly property string primaryColor:         primary
    readonly property string bgColor:             surfaceContainerLowest
    readonly property string surface1:            surfaceContainerHigh
    readonly property string surface2:            surfaceContainerHighest
    readonly property string textPrimary:         textWithoutBg
    readonly property string textSecondary:       onSurfaceVariant
    readonly property string textHint:            outline
    readonly property string outlineColor:        outline
    readonly property string divider:             outlineVariant
    readonly property string hoverBg:             surfaceContainerHigh
    readonly property string hoverBgStrong:       surfaceContainerHighest
    readonly property string popupBg:             surfaceContainerLow
    readonly property string popupBorder:         outlineVariant
    readonly property string popupItem:           surfaceContainerHigh
    readonly property string popupItemHv:         surfaceContainerHighest
    readonly property string tooltipBg:           surfaceContainerHighest
    readonly property string tooltipBorder:       "transparent"
    readonly property string tooltipText:         textWithoutBg

    // ── Mapa appId → iconPath ─────────────────────────────────────────────
    readonly property var _iconMap: ThemeState.iconMap

    // ── Fuentes ────────────────────────────────────────────────────────────
    property string uiFont:   "Roboto"
    property string ibmPlexMono: "IBM Plex Mono"
    property string mdiFont:  "Material Design Icons Desktop"

    // ── Tipografía — tokens configurables desde Settings ──────────────────
    readonly property int fontSizeBadge:    SettingsState.fontSizeBadge    ?? 10
    readonly property int fontSizeCaption:  SettingsState.fontSizeCaption  ?? 11
    readonly property int fontSizeLabelSm:  SettingsState.fontSizeLabelSm  ?? 12
    readonly property int fontSizeLabel:    SettingsState.fontSizeLabel    ?? 13
    readonly property int fontSizeBodySm:   SettingsState.fontSizeBodySm   ?? 14
    readonly property int fontSizeBody:     SettingsState.fontSizeBody     ?? 16
    readonly property int fontSizeTitleSm:  SettingsState.fontSizeTitleSm  ?? 17
    readonly property int fontSizeTitle:    SettingsState.fontSizeTitle    ?? 19
    readonly property int fontSizeHeadline: SettingsState.fontSizeHeadline ?? 21
    readonly property int fontSizeDisplay:  SettingsState.fontSizeDisplay  ?? 31
    readonly property int fontSizeIcon:     SettingsState.fontSizeIcon     ?? 19
    readonly property int fontSizeIconLg:   SettingsState.fontSizeIconLg   ?? 23

    // ── Font weights — tokens configurables ─────────────────────────
    readonly property int fontWeightNormal:  SettingsState.fontWeightNormal  ?? Font.Normal
    readonly property int fontWeightMedium:  SettingsState.fontWeightMedium  ?? Font.Medium
    readonly property int fontWeightBold:    SettingsState.fontWeightBold    ?? Font.Bold

    // ── Dimensiones ────────────────────────────────────────────────────────
    property int taskbarHeight: SettingsState.taskbarHeight > 0 ? SettingsState.taskbarHeight : 40
    property int iconSize:      Config.taskbarHeight - 18

    // ── Radius personalizados ────────────────────────────────────────────
    //SettingsState.radiusCustom: { taskbar: "medium", popups: "medium", buttons: "medium" }
    readonly property var _radiusPresets: ({
        "none":    { radius: 0,   radiusMd: 0,   radiusLg: 0,   radiusPill: 0,   radiusSm: 0,   radiusXs: 0   },
        "small":   { radius: 4,   radiusMd: 4,   radiusLg: 6,   radiusPill: 30,  radiusSm: 2,   radiusXs: 1   },
        "medium":  { radius: 8,   radiusMd: 6,   radiusLg: 12,  radiusPill: 60,  radiusSm: 4,   radiusXs: 2   },
        "large":   { radius: 12,  radiusMd: 10,  radiusLg: 16,  radiusPill: 80,  radiusSm: 6,   radiusXs: 3   },
        "full":    { radius: 100, radiusMd: 100, radiusLg: 100, radiusPill: 100, radiusSm: 50, radiusXs: 20 }
    })

    // Custom del usuario desde SettingsState
    readonly property var _custom: {
        var c = SettingsState.radiusCustom || {}
        return {
            taskbar: c.taskbar || "medium",
            popups:  c.popups  || "medium",
            buttons: c.buttons || "medium"
        }
    }

    // El preset base (global) - retrocompatibilidad
    readonly property var _currentPreset: {
        var p = (SettingsState.radiusPreset || "medium")
        return _radiusPresets[p] || _radiusPresets["medium"]
    }

    // Para cada tipo de elemento
    readonly property var _taskbarPreset:   _radiusPresets[_custom.taskbar] || _radiusPresets["medium"]
    readonly property var _popupPreset:     _radiusPresets[_custom.popups]  || _radiusPresets["medium"]
    readonly property var _buttonPreset:    _radiusPresets[_custom.buttons] || _radiusPresets["medium"]

    // Radius para Taskbar y elementos del shell
    readonly property int radius:     _taskbarPreset.radius
    readonly property int radiusMd:    _taskbarPreset.radiusMd
    readonly property int radiusLg:    _taskbarPreset.radiusLg
    readonly property int radiusPill:  _taskbarPreset.radiusPill
    readonly property int radiusSm:    _taskbarPreset.radiusSm
    readonly property int radiusXs:    _taskbarPreset.radiusXs

    // Radius específicos para popups (usar Config.radiusPopup, etc.)
    readonly property int radiusPopup:     _popupPreset.radius
    readonly property int radiusPopupMd:   _popupPreset.radiusMd
    readonly property int radiusPopupLg:   _popupPreset.radiusLg

    // Radius para botones pequeños y tiles
    readonly property int radiusButton:    _buttonPreset.radius
    readonly property int radiusButtonMd: _buttonPreset.radiusMd
    readonly property int radiusButtonSm: _buttonPreset.radiusSm
    readonly property int radiusButtonLg: _buttonPreset.radiusLg

    // Radio fijo para contenedores de configuración - no depende de presets
    // Valor fijo de 12px para mantener consistencia visual
    readonly property int radiusContainer: 12

    // Lista de presets disponibles para el UI
    readonly property var radiusPresetsList: [
        { val: "none",   label: "Sin borde" },
        { val: "small",  label: "Pequeño" },
        { val: "medium", label: "Medio" },
        { val: "large",  label: "Grande" },
        { val: "full",   label: "Redondo" }
    ]

    // Labels para los tipos
    readonly property var radiusTypes: [
        { id: "taskbar",  label: "Shell y Taskbar" },
        { id: "popups",   label: "Popups y Paneles" },
        { id: "buttons",  label: "Botones y Tiles" }
    ]

    // ── Resolución de íconos ───────────────────────────────────────────────
    // Lookup centralizado de DesktopEntry dado un appId de Wayland.
    // Cubre reverse-domain, lutris, steam, sufijos numéricos.
    // Memoizado por sesión: el fallback O(apps) corre una sola vez por appId.
    // Se invalida ante cambios en los .desktop: sin esto un null cacheado en
    // el arranque (índice aún vacío) rompía launch() toda la sesión.
    property var _entryCache: ({})
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { Config._entryCache = ({}) }
    }
    function _resolveEntry(appId) {
        if (!appId || appId === "") return null
        if (Object.prototype.hasOwnProperty.call(_entryCache, appId)) return _entryCache[appId]

        var entry = DesktopEntries.heuristicLookup(appId)
               ?? DesktopEntries.byId(appId)
               ?? DesktopEntries.byId(appId.toLowerCase())

        // reverse-domain: re.sonny.Breve → buscar por "Breve"
        if (!entry) {
            var parts = appId.split(".")
            if (parts.length > 1) {
                var last = parts[parts.length - 1]
                entry = DesktopEntries.heuristicLookup(last)
                     ?? DesktopEntries.byId(last)
                     ?? DesktopEntries.byId(last.toLowerCase())
            }
        }

        // Lutris: net.lutris.celeste-24 → buscar por "celeste"
        if (!entry && appId.startsWith("net.lutris.")) {
            var gamePart = appId.replace("net.lutris.", "").replace(/-\d+$/, "")
            entry = DesktopEntries.heuristicLookup(gamePart)
                 ?? DesktopEntries.byId("net.lutris." + gamePart)
        }

        // Sufijo numérico genérico: app-name-42 → app-name
        if (!entry) {
            var stripped = appId.replace(/-\d+$/, "")
            if (stripped !== appId) {
                entry = DesktopEntries.heuristicLookup(stripped)
                     ?? DesktopEntries.byId(stripped)
            }
        }

        // Fallback final: Wine/Lutris con .exe → buscar por includes
        if (!entry) {
            var lower = appId.toLowerCase().replace(/\.exe$/, "").replace(/[^a-z0-9]/g, "")
            var all = DesktopEntries.applications.values
            for (var i = 0; i < all.length; i++) {
                var entryId = all[i].id?.toLowerCase().replace(/[^a-z0-9]/g, "") ?? ""
                if (entryId.includes(lower) || lower.includes(entryId)) {
                    entry = all[i]; break
                }
            }
        }

        return _entryCache[appId] = entry ?? null
    }

    property var _iconCache: ({})
    function resolveIcon(appId) {
        if (!appId || appId === "") return ""
        if (Object.prototype.hasOwnProperty.call(_iconCache, appId)) return _iconCache[appId]
        return _iconCache[appId] = _resolveIconInner(appId)
    }
    // Una pasada batch para precalentar pins ("de una").
    function warmupPins(appIds) {
        if (!appIds) return
        for (var i = 0; i < appIds.length; i++) resolveIcon(appIds[i])
    }
    Connections {
        target: ThemeState
        function onIconMapChanged() { _iconCache = ({}) }
        function onIconThemeChanged() { _iconCache = ({}) }
    }
    function _resolveIconInner(appId) {
        function try_(name) {
            if (!name || name === "") return ""
            // Si ya es un path absoluto (generado por resolve-icons), devolverlo directo
            if (name.startsWith("/") || name.startsWith("file://")) return name
            return Quickshell.iconPath(name, true)
        }

        // Intenta Quickshell primero; el mapa _iconMap ya tiene paths absolutos de Papirus
        function resolve(name) {
            if (!name || name === "") return ""
            return try_(name)
        }

        // 0. Mapa pre-calculado por resolve-icons
        var mapped = Config._iconMap[appId] || Config._iconMap[appId.toLowerCase()]
        if (mapped) {
            var pm = resolve(mapped)
            if (pm !== "") return pm
        }

        // 1. DesktopEntry centralizado
        var entry = _resolveEntry(appId)

        if (entry && entry.icon && entry.icon !== "") {
            var p = resolve(entry.icon)
            if (p !== "") return p
        }

        // 2. appId directamente como nombre de ícono
        var p = resolve(appId);              if (p !== "") return p
        p = resolve(appId.toLowerCase());    if (p !== "") return p

        // 3. Sufijos comunes: -browser, -desktop
        var base = appId.toLowerCase()
        p = resolve(base + "-browser");      if (p !== "") return p
        p = resolve(base + "-desktop");      if (p !== "") return p
        p = resolve(base + "browser");       if (p !== "") return p

        // 4. Todas las partes del reverse-domain
        var segs = appId.split(".")
        for (var i = segs.length - 1; i >= 0; i--) {
            p = resolve(segs[i]);               if (p !== "") return p
            p = resolve(segs[i].toLowerCase()); if (p !== "") return p
        }

        // 5. Strip prefijos reverse-domain y sufijos
        var clean = appId.toLowerCase()
            .replace(/^re\./, "").replace(/^io\./, "")
            .replace(/^org\./, "").replace(/^com\./, "").replace(/^net\./, "")
            .replace(/^app\./, "").replace(/^dev\./, "")
            .replace(/\.\w+\.\w+$/, "")
            .replace(/-\d+$/, "")
            .replace(/-browser$/, "")
            .replace(/-desktop$/, "")
        p = resolve(clean);                     if (p !== "") return p
        p = resolve(clean.replace(/\./g, "-")); if (p !== "") return p

        // 6. Steam: steam_app_12345 → steam
        if (appId.startsWith("steam_app_")) {
            p = resolve("steam"); if (p !== "") return p
        }

        // 7. Lutris fallback genérico
        if (appId.startsWith("net.lutris.")) {
            p = resolve("net.lutris.Lutris"); if (p !== "") return p
            p = resolve("lutris");            if (p !== "") return p
        }

        // 8. Wine
        if (appId.toLowerCase().includes("wine")) {
            p = resolve("wine"); if (p !== "") return p
        }

        return ""
    }

    // ── withAlpha(hex, alpha) ─────────────────────────────────────────────
    // Convierte un color hex "#RRGGBB" a Qt.rgba con alpha dado.
    // Reemplaza el patrón Qt.rgba(parseInt(hex.slice(1,3),16)/255, …) disperso en el código.
    function withAlpha(hex, a) {
        var c = (hex || "#000000").replace("#", "")
        if (c.length === 3) c = c[0]+c[0]+c[1]+c[1]+c[2]+c[2]
        return Qt.rgba(
            parseInt(c.substr(0,2),16)/255,
            parseInt(c.substr(2,2),16)/255,
            parseInt(c.substr(4,2),16)/255,
            a)
    }

    // Tokens M3 — aliases para compatibilidad con componentes de bar-claude
    readonly property int shapeFull:           100
    readonly property int shapeMedium:         radiusMd
    readonly property int typeLabelMedium:     11
    readonly property int typeLabelSmall:      10

    function resolveAppName(appId) {
        if (!appId || appId === "") return ""
        var entry = _resolveEntry(appId)
        if (entry && entry.name && entry.name !== "") return entry.name
        // Fallback: última parte del reverse-domain, capitalizada
        var segs = appId.split(".")
        var s = segs[segs.length - 1].replace(/-\d+$/, "").replace(/-/g, " ")
        return s.charAt(0).toUpperCase() + s.slice(1)
    }
}
