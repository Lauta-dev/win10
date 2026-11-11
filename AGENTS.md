Sos el ingeniero de este repo: una barra de tareas estilo Windows 10 / ChromeOS Material You para **labwc** (Wayland, `wlr-layer-shell`). Stack: QuickShell + QML (Qt 6.7+), Go 1.24 (`services/`).

## Cómo buscar archivos (leer primero)

**No uses find, glob ni ls recursivo para localizar archivos: están en el mapa de abajo.** Si falta uno, preguntame antes de buscar. `rg` solo para grepear referencias al borrar/renombrar un tipo. No leas `.opencode/skills/` salvo que la tarea lo pida (ver "Skills").

## Mapa de archivos (fuente de verdad)

- Arranque: `shell.qml` (ShellRoot + `PanelPopupHost` + `AutoLazyLoader` para Hub/Settings)
- Barra: `taskbar/Taskbar.qml`; `taskbar/groups/` (TaskList, TaskButton); `taskbar/jumplist/` (JumpList + ítems); `tray/` (SystemTrayArea, TrayIconPill)
- Widgets de barra (`widgets/`): VolumeWidget, MprisWidget, DashWidget
- Lógica pura (`logic/`): módulos JS sin dependencias de QML (`text.js`, `time.js`, `mpd.js`, `startmenu.js`, `keepass.js`)

### Popups (`popups/`, ventanas que se lanzan)
- Lanzador AppMenu/Clipboard: `LauncherPopup.qml` → `components/appmenu/`, `components/clipboard/`, `state/ClipboardState.qml`
- OSD vol/brillo/power: `OsdSliderPopup.qml` (modo lo pone el IPC) → `state/AudioState.qml`, `state/BrightState.qml`
- Hub (música, calc, claves): `HubPopup.qml` → `components/mpd/`, `components/hub/`, `components/keepass/`, `state/MpdState.qml`, `MpdConnection.qml`, `KeePassState.qml`, `CalculatorState.qml`
- Música MPRIS: `MusicPopup.qml` → `state/MprisState.qml`
- Centro de control: `ControlCenterNew.qml` → `state/WifiState.qml`, `BrightState.qml`, `MonitorState.qml`, `components/pomodoro/`
- Ajustes: `SettingsPopup.qml` → `components/settings/`, `state/SettingsState.qml`, `WallpaperState.qml`, `ThemeState.qml`
- Notas: `NotesSidebar.qml` → `state/NotesState.qml`
- Polkit: `PolkitPopup.qml` → `state/PolkitState.qml`

### Base reutilizable (`components/`)
- Marcos de popup: `PopupShell`, `WipePopupShell`, `PanelPopupHost` (superficie global de los paneles grandes), `ConvexPopupShape`, `DismissOverlay`, `PopupDrawer`, `Drawer`
- Carga diferida: `AutoLazyLoader`
- Controles: `PillButton`, `ValueSlider`, `SeekBar`, `Badge`, `AppTextInput`, `SmartSearchInput`, `PanelList`, `Mouse`
- Subcarpetas con su `qmldir`: `appmenu/`, `clipboard/`, `hub/`, `mpd/`, `keepass/`, `pomodoro/`, `settings/`

### Estado y diseño (`state/`, singletons con línea en `state/qmldir`)
- Diseño: `Style.qml` (siempre usarlo), `Config.qml`, `Icons.qml`
- UI efímera: `TaskbarState.qml`. Persistencia: `SettingsState.qml` (`markDirty()`)
- Lanzar apps: `AppLaunchState.qml`. Brillo: `BrightState.qml` + `BrightConnection.qml` (daemon Go)

### IPC (`ipc/`, un archivo por target; no renombrar targets)
`AppMenuIpc` (command-palette), `BrightIpc` (bright), `ClipboardIpc` (clipboard), `MpdIpc` (mpd), `NotesIpc` (notes), `PowerIpc` (power), `VolumeIpc` (vol)

### Go (`services/`, cada carpeta es un módulo propio)
`daemons/` (servicios bright, keepass, mpd, search), `calc/`, `qsipc/`, `theming/` (gtk-apply, shell-theme, matugen-apply)

## Comandos (usarlos para verificar)

```bash
# Lint QML con rutas de import (sin -i da falsos 255 por tipos sin resolver)
qmllint -i . -i ./state -i ./components -i ./popups -i ./taskbar \
  -i ./widgets -i ./tray -i ./ipc <archivo.qml>

# Go: vet + tests por módulo
go vet ./... && go test ./...   # dentro de services/<modulo>/

# IPC en vivo (la shell debe estar corriendo)
qs ipc call command-palette toggle
qs ipc call clipboard toggle
```

## Skills (`.opencode/skills/`): cargar solo si aplica

- `qml-gotchas`: patrones completos de las 5 trampas de arriba. Cargar ante flashes de color, saltos de altura o clicks que no responden.
- `features`: clipboard, AppMenu (`>b`, `>ia`, `>sf`), notas, WiFi, MPD. Cargar solo si la tarea toca esa feature.
- `qs-*` (core, widgets, services, wayland, windowmanager, io, networking, dbusmenu, bluetooth): referencia de APIs de Quickshell; consultar el que corresponda en vez de adivinar firmas.
- `qs-animations`: animaciones de popups. `mpd`: protocolo MPD. `.agents/skills/qt-qml`: buenas prácticas QML.
- Cada módulo Go de `services/` tiene su `doc.md` (protocolo y comandos): leer ese en vez de explorar.

## Estilo

- **Colores, radios, espaciado, animaciones: `Style.*`** (snake_case MD3: `primary`, `surface_container_lowest`, `on_surface`, `outline_variant`, `popup_radius`, `button_radius`, `radius_md`, `sp8`, `anim_fast`).
- **Fuentes y medidas de barra: `Config.*`** (`fontSizeBody`, `taskbarHeight`, `iconSize`). Los colores camelCase de Config (`primaryColor`, `surface1`, `popupBg`...) son legacy: no usarlos.
- Nunca hex ni números sueltos de color/radio.

```qml
// ✅ Rectangle { radius: Style.popup_radius; color: Style.surface_container_lowest; border.color: Style.outline_variant }
// ❌ Rectangle { radius: 12; color: "#2b2b2b" }
```

- Estado compartido solo en singletons de `state/`. Persistencia solo vía `SettingsState.markDirty()`. Procesos: `Process{}` nunca síncronos, solo si no hay API nativa, y siempre centralizados en `state/` (la UI no accede al sistema directamente). Lógica pura reutilizable en `logic/*.js`.
- Popups nuevos con superficie propia (OSD, Notificaciones, Hub, Settings): `AutoLazyLoader` en `shell.qml` + patrón `_animReady` + `mask: isOpen ? <region> : emptyMask`.
- Paneles grandes (Launcher, JumpList, Music, ControlCenter): NO ventana propia. Se agregan como vista `Item` en `components/PanelPopupHost.qml` (API `viewWidth`, `viewHeight`, `viewX`, `viewExclusiveFocus`, `viewOpen`) + entrada en `_CONFIGS`, y se abren con `TaskbarState.openPanel("<nombre>")` (slot único `TaskbarState.panel`, exclusividad last-wins).
- IPC nuevo: un archivo en `ipc/` + línea en `shell.qml`; las funciones devuelven string.
- Al borrar un `.qml`, borrar su línea del `qmldir` y grepear referencias (`rg -n "Nombre"`).
- Respuestas cortas y directas, en español. Al citar código usar `ruta:línea`.

### Trampas QML (detalle en skill `qml-gotchas`)
1. Flash de color: nunca `"transparent"` ni `Qt.alpha(c,0)` como extremo de `ColorAnimation`; mismo RGB, solo alpha.
2. Hover + active a la vez: un `Rectangle` por estado, cada uno con su `Behavior`.
3. `PanelWindow`: nunca `implicitHeight` bindeado a contenido animado; superficie fija + wrapper que anima.
4. Capas superpuestas: todo `MouseArea` + `onClicked`; nunca un `TapHandler` debajo.
5. Máscara de contenido variable: `Region` con `x/y/width/height` bindeados, no `item:`.

## Git

- Antes de commitear: `git status`, `git diff`, `git log --oneline -10`. Stagear solo lo intencionado.
- Mensajes concisos: `Área: qué` (ej: `Limpieza: palette → AppMenu + Clipboard`).
- Nunca pushear, ni `--force`, ni PRs, salvo pedido explícito.

## Límites

- ✅ **Siempre:** `qmllint` tras editar QML, `go vet` tras editar Go; leer el archivo antes de editarlo.
- ⚠️ **Preguntar antes:** borrar features vivas, renombrar targets IPC, cambiar el sistema de diseño.
- 🚫 **Nunca:** cambios no pedidos; commitear secretos; tocar `node_modules/`/`vendor/`; dejar tipos sin registrar en `qmldir`.
