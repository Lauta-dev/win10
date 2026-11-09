# Skill: state — Singletons globales y gestión de estado

## Descripción
Todos los singletons viven en `state/` y usan `pragma Singleton` de Quickshell. Se acceden por nombre desde cualquier QML sin importar el path.

## Archivos

### TaskbarState.qml — Bus central de eventos UI
Todo el estado efímero de la UI vive aquí. Ningún componente guarda estado local que otro componente necesite leer.

**Propiedades principales:**
- `ready` — `false` hasta que `SettingsState` termina de leer el JSON
- `activePopup` — Popup con superficie propia: `"hub" | "settings" | ""`
- `panel` — Slot único de la superficie global (`PanelPopupHost`): `"launcher" | "jumplist" | "music" | "controlcenter" | ""`; abrir/cerrar con `openPanel(name)` / `closePanel(name)`
- `popupX` — Coordenada X del ícono que abrió el popup
- `settingsTab` — Tab a abrir cuando `activePopup = "settings"`
- `showControlCenterNew`, `showLauncher`, `jumpListOpen` — Flags **readonly derivados** de `panel` (para lecturas); las escrituras van por `openPanel` / `closePanel`
- `launcherMode` — `"app"`/`"clip"` dentro del panel launcher
- `activeJumpList` — appId del JumpList abierto (click derecho)
- `volume`, `muted` — Estado de audio (vía `AudioState` + Pipewire nativo)
- `darkMode` — Modo oscuro activo
- `brightness` — Brillo
- `musicTitle`, `musicArtist`, `musicPlayer`, `musicPlaying` — MPRIS
- `wifiEnabled`, `wifiSsid`, `wifiIface` — WiFi
- `activeLayout` — Layout de pantallas: `"netbook" | "dual" | "monitor"`

**Funciones:**
- `showTip(text, x)` / `hideTip()` — Tooltip con debounce 200ms
- `applyDarkMode(dark)` — Cambia darkMode, aplica GTK theme + icon theme + gsettings
- `musicPlayPause()` / `musicPrev()` / `musicNext()` — delegan en `MprisState` (MPRIS nativo)
- `audioMute()` / `audioSetVolume(v)` — delegan en `AudioState` (Pipewire nativo)

### Config.qml — Paleta, dimensiones y resolución de íconos
Punto único de acceso a todos los tokens de diseño. Ningún componente hardcodea colores o tamaños.

**Colores (solo lectura):**
- `primaryColor` — Color de acento activo
- `primaryContainer` — Acento con alpha 0.18–0.22
- `onPrimary` — Blanco o negro según contraste WCAG
- `bgColor` — Fondo de la barra
- `surface`, `surface1`, `surface2` — Superficies anidadas
- `textPrimary`, `textSecondary`, `textHint` — Jerarquía de texto
- `hoverBg`, `hoverBgStrong` — Hover states
- `pressBg`, `activeBg` — Press/activo
- `popupBg`, `popupBorder`, `popupItem`, `popupItemHv` — Popups
- `tooltipBg`, `tooltipText` — Tooltip
- `red`, `green`, `yellow`, `blue`, `teal`, `peach`, `mauve` — Semánticos

**Layout:**
- `taskbarHeight` — Default 48, configurable
- `iconSize` — `taskbarHeight - 26`
- `radius` / `radiusMd` / `radiusLg` / `radiusPill` — 8 / 12 / 20 / 100
- `uiFont`, `nerdFont` — Fuentes

**Funciones:**
- `resolveIcon(appId)` — Resolución de íconos en 8 pasos
- `resolveAppName(appId)` — Nombre legible
- `withAlpha(hex, a)` — Convierte hex a Qt.rgba
- `_contrastOn(hex)` — WCAG 2.1 contrast

### SettingsState.qml — Persistencia unificada
Escribe en `~/.config/qs-settings.json` con debounce de 300ms.

**Propiedades persistidas:**
- `colorTheme` — ID del tema activo (`chromeos` | `matugen`)
- `accentDark`, `accentLight` — Accent custom
- `taskbarHeight` — 40 | 48 | 56
- `iconMap` — { appId: "/ruta/icono.svg" }
- `wallpaper`, `wallpaperMode`, `wallpaperDir`
- `gtkTheme`, `iconTheme`
- `outputModes`
- `recentApps` — Array de `{exec, name}`, máximo 5 (apps más recientes del AppMenu)

**Funciones:**
- `markDirty()` — Reinicia timer de 300ms → escribe JSON
- `save()` — Alias de markDirty()
- `rebuildIconMap(theme)` — Regenera iconMap
- `addRecentApp(exec, name)` — Agrega app al frente de recentApps, trunca a 5

### AudioState.qml — Estado de audio (vía Pipewire nativo)

Wrapper singleton sobre `Quickshell.Services.Pipewire`. Expone volumen y mute del sink por defecto como propiedades reactivas. Sin polling.

**Propiedades (solo lectura):**
- `volume` — Volumen 0–100
- `muted` — ¿Silenciado?

**Funciones:**
- `audioMute()` — Toggle mute
- `audioSetVolume(v)` — Set volumen 0–100

### MprisState.qml — Estado de música (vía MPRIS nativo)

Wrapper singleton sobre `Quickshell.Services.Mpris`. Sin `playerctl` ni `Process`.

**Propiedades (solo lectura):**
- `musicPlayer` — D-Bus name del player activo
- `musicPlaying` — ¿Reproduciendo?
- `musicTitle`, `musicArtist`, `musicArtUrl` — Metadata del tema actual
- `musicLength`, `musicPosition` — Duración/posición en segundos
- `musicPlayerList` — Lista de todos los players con estado
- `_mpdPlayer` — Player MPD filtrado para popup nativo

**Funciones:**
- `musicPlayPause()` / `musicPrev()` / `musicNext()` — Control nativo
- `musicSetActivePlayer(dbusName)` — Forzar player activo
- `musicStartPos()` / `musicStopPos()` — Iniciar/detener timer de posición

### ColorThemes.qml — Catálogo de paletas
Sin estado mutable. API:
- `themes` — Array de objetos con id, label, accent_dark, accent_light, dark{...}, light{...}
- `palette(id, dark)` — Objeto con todos los tokens de color
- `defaultAccent(id, dark)` — String hex del accent por defecto

### AppLaunchState.qml — Lanzador centralizado con watchdog

Todo lanzamiento desde la taskbar pasa por `launch(appId)`: prefiere `DesktopEntry.execute()`, fallback a `Process` estático con `run()`. Watchdog cada 500ms sobre `ToplevelManager`: ventana aparecida (match fuzzy) → resuelve silencioso; sin ventana en 15s → `NotificationState.add(..., Icons.error)`.

- `launching: []` — appIds pendientes (reactivo, lo lee `TaskButton` para el visual "abriendo": overlay `primary_container` con respiración + dot pulsante)
- `_matches(a, b)` — match fuzzy (exacto → case-insensitive → misma DesktopEntry → último segmento reverse-domain). Reusado por `TaskList` para agrupar y dedupicar.
- `TaskbarState.togglePinSmart(appId)` / `isPinnedFuzzy(appId)` — pin con dedup fuzzy (usado por el click derecho del AppMenu).

## Ciclo de vida al arrancar

1. `Component.onCompleted` → lanza `readProc` (lee ~/.config/qs-settings.json)
2. `SplitParser.onRead` → parsea JSON, hidrata propiedades, restaura wallpaper y GTK theme
3. Emite `loaded()` → pone `TaskbarState.ready = true` → la UI aparece
4. `Qt.callLater` → lanza `iconMapProc` (regenera iconMap en background)

## DirBrowserState.qml — Listado de directorios/archivos

Singleton que centraliza el `Process` de `list-dirs` (binario Go) para `DirBrowser`.
Expone `listDir(path, mode, showHidden)` y emite `loaded(path, entries)`.

## Lógica pura (`logic/`)

Funciones JavaScript sin dependencias de QML ni singletons, reutilizables y testeables:

- `text.js` — `trimLower`, `fuzzyScore`, `subFor`, `resolveSub`, `prettyPath`.
- `time.js` — `fmtTime`, `clamp`.
- `collections.js` — `dedupeByKey`, `sortByField`, `filterByFields`.
- `mpd.js` — parseo MPD, filtros de playlist/artistas/álbumes, transformaciones.
- `startmenu.js` — filtrado de apps, comandos, iconos por extensión.
- `keepass.js` — filtrado KeePass, acciones de detalle, `visibleRows`, `placeholderFor`.

## Notificaciones
Usa `NotificationState.add(app, title, body, icon)` desde cualquier QML.
- `NotificationState.notifications` — ListModel con id, app, title, body, icon, time, timestamp
- `NotificationState.count` — Conteo de notificaciones
- `NotificationState.dismiss(id)`, `NotificationState.clear()`
- Escuchar `notificationAdded` para mostrar toasts