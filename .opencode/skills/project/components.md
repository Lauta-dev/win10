# Skill: components — Componentes UI, Taskbar, Widgets, Popups, Scripts

## Descripción
Esta skill cubre todos los componentes UI, la barra de tareas, widgets, popups flotantes y scripts auxiliares.

## taskbar/ — Barra y gestión de ventanas

### Taskbar.qml
`PanelWindow` anclado `bottom + left + right`. Layout en 3 bloques:
```
MusicWidget (slot fijo izq) | TaskList centrada | VolumeWidget + SystemTrayArea (slot fijo der)
```
- `exclusiveZone = Config.taskbarHeight`
- Borde superior de 1px con `Config.outlineColor` al 60%

### TaskList.qml
- `ScriptModel` con apps abiertas + apps pineadas
- `ListView` horizontal con scroll suavizado (SmoothedAnimation velocity:600)
- Delegate: `TaskButton`

### TaskButton.qml
Recibe `appId`, `isPinned`, `toplevels[]`. Decide qué renderizar:
- Pineado + sin ventana → launcher (click abre app)
- Pineado + con ventana → `TaskGroup`
- No pineado + con ventana → `TaskGroup`

### TaskGroup.qml
- Propiedades: `count`, `grouped`, `anyActive`, `allMinimized`, `isPinned`, `isPopupOpen`
- Ancho animado: `Math.min(160, 46 + titleText.implicitWidth + 8)`
- Click izq: 1 ventana → toggle minimize/activate. >1 → abre `TaskGroupPopup`
- Click der: abre `JumpList`
- Menú: Pinar/Desanclar + Cerrar todas

### PinnedItem.qml
- Sin ventana: ancho fijo 46px, click lanza via `DesktopEntry.launch()`
- Con ventana: igual que `TaskGroup`

### JumpList.qml
Vista `Item` del panel `"jumplist"` en `components/PanelPopupHost` (ya no es una ventana propia). Toma todos los datos de `TaskbarState` (`activeJumpList`):
- Header con ícono + nombre
- Lista de ventanas abiertas (click → activate)
- Acciones: Pinar/Desanclar, Cerrar todas
- Cache de toplevels + alto propio (`viewWidth`/`viewHeight`)
- Items: `JumpListItem.qml`

## widgets/ — Widgets de la barra

| Widget | Trigger | Abre |
|---|---|---|
| MusicWidget | Click en título / controles MPRIS | `TaskbarState.openPanel("music")` / play-pause-prev-next |
| VolumeWidget | Click / rueda | `activePopup = "volume"` / volumen ±5 |
| DashWidget | Click | `TaskbarState.openPanel("controlcenter")` (toggle con `closePanel`) |
| ClipboardWidget | Click | `TaskbarState._showLauncher("clip")` / `_hideLauncher()` (toggle) |

## popups/ — Paneles flotantes

Dos familias:

**Paneles grandes → `components/PanelPopupHost.qml`** (una sola superficie layer-shell para los 4).
`TaskbarState.panel` es el slot único: `"launcher" | "jumplist" | "music" | "controlcenter" | ""`.
- Exclusividad *last-wins*: abrir uno reemplaza al anterior; cambiar de panel con la superficie abierta cambia el contenido en seco (sin re-wipe).
- Cada panel es un `Item` con API de vista: `viewWidth`, `viewHeight`, `viewX`, `viewExclusiveFocus`, `viewOpen`; el tamaño propio de la raíz es `width: viewWidth; height: viewHeight`.
- Los statics por panel (position, sideMargin, radius, openMs/closeMs) viven en `_CONFIGS` del host.
- El panel se retiene `_lastPanel` + `closeHold` (500 ms) durante el wipe de salida.

**Popups con superficie propia** (OSD, Notificaciones) y **Hub/Settings**: siguen con `AutoLazyLoader` en `shell.qml` y patrón de animación:
```qml
property bool _animReady: false
property bool isOpen: _animReady && TaskbarState.activePopup === "volume"
Component.onCompleted: Qt.callLater(function() { _animReady = true })
Region { id: emptyMask }
mask: root.isOpen ? null : emptyMask
```

| Popup | Condición | Scripts |
|---|---|---|
| LauncherPopup | `panel === "launcher"` + `launcherMode` (`"app"`/`"clip"`) | DesktopEntries nativo / cliphist |
| MusicPopup | `panel === "music"` | MPRIS nativo / MpdConnection |
| ControlCenterNew | `panel === "controlcenter"` | WifiState, BrightState |
| HubPopup | `activePopup === "hub"` (+ `hubTab`) | MPD/Keepass vía daemons Go |
| SettingsPopup | `activePopup === "settings"` | wp-helper, list-monitors, list-dirs, resolve-icons |

Todos flotan separados de la barra (gap 10px) con tarjeta redondeada + borde `outline_variant`.

### LauncherPopup.qml
- Vista 640×520 del panel `"launcher"`, centrada abajo. Sin menú root ni submenús: cada vista (`AppMenuView` / `ClipView`) es dueña de su lista + buscador + teclado.
- Apps recientes (máx 5) siempre al tope del AppMenu, con badge "Reciente".

### SettingsPopup.qml
- Tamaño: `Math.min(screen.width - 32, 1020)` × `Math.min(screen.height - taskbarHeight - 32, 560)`
- Tabs: Apariencia (wallpaper + colores + GTK/iconos), Monitores

## components/ — Primitivos UI

| Componente | Props | Descripción |
|---|---|---|
| AppIcon | source, appId, size | Imagen con fallback de inicial coloreada |
| DiscArt | artUrl, isPlaying, active, discSize, fallbackIcon | Arte cuadrado con fallback (Volume: disc, MPD: musicNoteOff); click = toggled() |
| SeekBar | ratio, animations | Seek unificado estilo volume (Volume rows + MPD); seekAt(ratio)/wheelMoved |
| MprisControl | playing, prev/toggle/nextAction | Prev/toggle/next (default MPRIS; MPD sobreescribe acciones) |
| AutoLazyLoader | condition, sticky, unloadDelay | LazyLoader que no se destruye una vez cargado; expone `item` |
| DismissOverlay | — | Click fuera cierra popups |
| TooltipOverlay | — | Tooltip global único |
| DotIndicator | active, hovered | Punto animado |
| WindowCountBadge | count, active | Badge circular |
| SectionLabel | text | Etiqueta uppercase |
| SegmentedControl | model, currentIndex | Pill row |
| ToggleSwitch | checked | Switch on/off animado |
| WipePopupShell | flag, position, contentWidth/Height, radius | Shell layer-shell con wipe estilo minflair (base de PanelPopupHost, OSD, toasts) |
| PanelPopupHost | — (lee TaskbarState.panel) | Superficie global única de Launcher/JumpList/Music/CC; API de vista `viewWidth/viewHeight/viewX/viewExclusiveFocus/viewOpen` |

## Control Center

### popups/ControlCenterNew.qml
Vista `Item` del panel `"controlcenter"` en `PanelPopupHost` (posición right). Se abre con `TaskbarState.openPanel("controlcenter")`.
- Tiles Quick Settings estilo Android: grilla de 2 columnas, pill de 64px, ícono en círculo al estar activos
- Brillo, card de calendario / notificaciones / pomodoro
- Subvista WiFi (lista + contraseña inline) sobre `WifiState`

## tray/ — Bandeja del sistema

### SystemTrayArea.qml
`Row` con:
1. Repeater sobre `SystemTray.items` → TrayIconPill

## services/ — Módulos Go

Todos via `Process{}` — nunca síncronos.

| Script | Salida |
|---|---|---|
| daemon | Bridge Go MPD (`services/daemons/service/mpd/`, cmd+idle, NDJSON stdio): MpdConnection reenvía push a la UI |
| resolve-icons | JSON { appId: "/path/icon.svg" } |
| wp-helper | scan de wallpapers + path thumbnail ~/.cache/qs-wallpapers/<md5>.jpg |
| list-monitors | JSON con monitores y modos (via wlr-randr --json) |
| list-dirs | JSON {path, entries[]} para DirBrowser (vía `DirBrowserState`) |


## Dependencias entre archivos
```
shell.qml
  ├── state/*
  ├── taskbar/Taskbar
  │     └── taskbar/TaskList → TaskButton → TaskGroup
  ├── components/TooltipOverlay, DismissOverlay
  ├── tray/SystemTrayArea → DashWidget
  ├── [lazy] popups/LauncherPopup → appmenu/AppMenuView + clipboard/ClipView
  ├── [lazy] taskbar/TaskGroupPopup
  ├── [lazy] popups/HubPopup (mpd/ + keepass/ + hub/Calc + pomodoro/)
  └── [lazy] popups/SettingsPopup
```