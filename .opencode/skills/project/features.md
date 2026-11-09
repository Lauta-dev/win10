# Skill: features — Sistema de Notificaciones y Portapapeles

## Sistema de Notificaciones

### Archivos
- `state/NotificationState.qml` — Singleton, fuente de verdad
- `popups/NotificationPopup.qml` — Toast flotante MD3
- Centro de control (`ControlCenterNew`) — tarjeta notificaciones con badge

`NotificationPopup` se instancia directamente en `shell.qml` (no lazy) para reaccionar sin delay.

### NotificationState.qml

**Propiedades:**
- `notifications` — ListModel con campos: id, app, title, body, icon, time, timestamp
- `count` — Número de notificaciones (alias de notifications.count)

**Señales:**
- `notificationAdded(var entry)` — Emitida al agregar nueva notificación

**Funciones:**
- `add(app, title, body, icon)` — Inserta al tope, emite señal, devuelve id
- `dismiss(id)` — Elimina por id
- `clear()` — Elimina todas

**Tiempos relativos:**
- Timer interno cada 60s actualiza el campo "time" (Ahora → 2 min → 1 h → 1d)

**Ejemplo de uso:**
```qml
NotificationState.add("Firefox", "Descarga completa", "archivo.iso guardado.", "\uF0239")
NotificationState.dismiss(someId)
NotificationState.clear()
Text { text: NotificationState.count }
```

### NotificationPopup.qml

- Escucha `notificationState.notificationAdded` para mostrar toast
- Animación: slide desde derecha + fade in
- Barra de progreso (primaryColor) cuenta regresivamente `displayDuration` ms
- Hover pausa auto-descarte
- Botón ✕ para cerrar manualmente
- Máximo 3 toasts simultáneos

**Constantes:**
- `displayDuration` — 5000ms
- `animDuration` — 240ms (entrada: slide + fade; salida: la misma en reversa + colapso; toast único con animaciones explícitas, sin `ListView`)
- `maxStack` — 3

**Timer (una sola fuente de tiempo):** `remainingMs` con tick de 50ms alimenta barra y auto-cierre. El hover detiene el tick, nunca lo resetea (bindear `Timer.running` al hover lo reinicia completo y suma tiempo — bug ya corregido).

**Click derecho:** expande el body (wrap, máx 8 líneas / 220px, altura animada). Solo layout sin imagen.

**Estilo MD3:**
- Contenedor: popupBg + popupBorder + radiusLg
- Ícono: círculo primaryContainer + glifo primaryColor
- Nombre de app en primaryColor
- Barra de progreso en primaryColor

---

## Sistema de Portapapeles

### Archivos
```
components/clipboard/
    ClipEntry.qml          — Parsea línea raw → objeto { id, raw, display, type, preview, isImage, ... }
    ClipFilter.qml         — Filtrado estilo fzf con debounce 120ms, expone results[]
    ClipProcesses.qml      — Encapsula todos los Process{} de cliphist
    ClipItemDelegate.qml   — Delegate visual: texto, imagen preview, badge de tipo
    ClipView.qml           — Vista del LauncherPopup: buscar + pegar
    ClipDelegate.qml       — Delegate de la vista
```

`LauncherPopup.qml` es solo layout (superficie + máscara + animación).

### ClipEntry.qml
Convierte línea raw de `cliphist list` en objeto enriquecido. Instanciar **UNA SOLA VEZ** en ClipboardState.

```qml
ClipEntry { id: clipEntry }
var obj = clipEntry.parse(rawLine)
// obj → { id, raw, kind, isFile, isImage, label, sub, icon, ... } o null
```

Detecta tipo via regex: image, pdf, archive, video, audio, doc, sheet, slides, text, code, web, data, script, db, cert. Default: "text".
Imágenes con path local (/… o file://…) → thumbnail (`isImage` + `raw` con el path); URLs online y binarios → sin thumbnail, solo glifo.

### ClipFilter.qml
Filtrado incremental estilo fzf con debounce 120ms. Sin UI.

**Props:**
- `entries` — var[] (array de objetos parseados)
- `searchQuery` — string
- `results` — var[] (read-only, filtradas y ordenadas por score)

### ClipProcesses.qml
Encapsula todos los Process{} que interactúan con cliphist. Sin daemon propio:
un watcher persistente (`wl-paste --watch cliphist store`, hijo del shell)
mantiene la DB fresca y las operaciones son one-shot. La copia va por pipe
(`decode | wl-copy`) sin pasar bytes por QML.

**Señales:**
- `entriesLoaded(var entries)` — Al terminar de cargar y parsear
- `loadingChanged(bool)` — Cambio de estado
- `wiped()` — Al completar wipe total

**Funciones:**
- `reload()` — Lanza cliphist list, parsea, emite entriesLoaded
- `copyEntry(id)` — Copia via cliphist decode | wl-copy
- `deleteEntry(id)` — Elimina via cliphist delete, relanza reload()
- `wipe()` — Borra todo via cliphist wipe, emite wiped()

### Convenciones del portapapeles
- Todo el parsing pasa por ClipEntry; todo el I/O por ClipProcesses. Nunca en el delegate.

---

## AppMenu

### Archivos
```
popups/LauncherPopup.qml     # Vista del panel "launcher" en PanelPopupHost (AppMenuView/ClipView por modo).
components/appmenu/
    AppMenuView.qml         # Vista: buscar + abrir
    AppDelegate.qml         # Delegate de apps: [ICON] Name [Reciente] + Description
```

### IPC (target `command-palette` conservado por compatibilidad)

```bash
qs ipc call command-palette toggle    # Abre/cierra AppMenu
qs ipc call command-palette open      # Abre
qs ipc call command-palette close     # Cierra
```

### Comandos del AppMenu (`>`)

Se filtran en `StartmenuState.filterApps` y se despachan con
`activateItem()` (los ítems son sintéticos: `isCommand` / `isFile`).

| Comando | Qué hace |
|---|---|
| `>b <texto>` | Busca en DuckDuckGo con el navegador por defecto (`xdg-open`). |
| `>ia [gpt\|claude\|gemini] <prompt>` | Abre el proveedor con el prompt en la URL (`chatgpt.com/?q=`, `claude.ai/new?q=`, `gemini.google.com/app?q=`). Sin proveedor usa ChatGPT. |
| `>sf <nombre>` | Busca archivos bajo `$HOME` con el daemon Go (`scripts/daemon search`) y los abre con `xdg-open`. |

- Escribir `>` solo (o un prefijo) lista los comandos disponibles con su hint.
- `>sf` mantiene los resultados previos mientras el daemon recorre/consulta; los
  ítems que salen de ese modo se descartan al cambiar el texto.
- `>sf` es el único que trae ítems `isFile`; en el delegate no muestran pin ni
  badge de reciente.

**Búsqueda de archivos (Go):** `scripts/daemons/service/search/` mantiene un
índice en memoria de `$HOME` (poda de `node_modules`, `.cache`, assets, stores
de juegos; cuota por carpeta de primer nivel) con caché en
`$XDG_CACHE_HOME/qs-fileindex.txt`. Protocolo NDJSON en
`scripts/daemons/service/search/doc.md`. QML lo arranca bajo demanda con un
`Process` persistente y lo apaga por inactividad (20 s) o al cerrar el launcher.

### Apps recientes
- Máximo 5 apps recordadas, ordenadas por última apertura (más reciente primero)
- Las apps recientes aparecen **siempre al tope** de cualquier lista filtrada
- Badge "Reciente" inline junto al nombre de la app
- Se registran automáticamente al lanzar una app desde el AppMenu

**Delegate de apps (AppDelegate.qml):**
```
┌──────────────────────────────────────────┐
│ [ICON] Nombre              [Reciente]   │
│        Descripción (si existe)            │
└──────────────────────────────────────────┘
```
- Icono 28×28 con fallback de inicial coloreada
- Nombre con elipsis, ancho dinámico según presencia del badge
- Badge "Reciente": pill de 56×16 con `Config.primaryColor`
- Descripción en segunda línea, solo si `comment` no está vacío

### Scripts

**DesktopEntries nativo:**
- `DesktopEntries.applications` expone `ObjectModel<DesktopEntry>` reactivo
- Cada entry tiene: `name`, `icon`, `execString`, `comment`, `categories`, `runInTerminal`, `noDisplay`
- Sin Python, sin Process, sin polling

### Persistencia de recientes

**SettingsState.qml:**
- `recentApps: []` — array de `{exec, name}`, máximo 5
- `addRecentApp(exec, name)` — agrega al frente, trunca a 5, llama `markDirty()`
- Se persiste en `~/.config/qs-settings.json`

### Convenciones de las vistas
- Cada vista es dueña de su lista + buscador + teclado
- Todos los datos se cargan en `enter()`, nunca en `Component.onCompleted`
- El filtro de texto siempre pasa por `onSearchChanged`
- ESC con búsqueda vacía → cierra

### Pin desde el AppMenu (click derecho)
`AppDelegate` usa `Mouse` (izq lanza, der emite `pinRequested`); el popup hace `togglePinSmart(app.id)` sin cerrar. Insignia `Icons.pin` cuando está pineada. Sin dropdown: `PanelList` tiene `clip: true`, un menú inline se recortaría.

---

## Notas

### Archivos
```
popups/NotesSidebar.qml      # Ventana SSD a la derecha, ancho persistido, autoguardado.
state/NotesState.qml         # Singleton: content + FileView a ~/.cache/qs7/notes.txt.
components/NoteTextArea.qml  # Textarea con resaltado, gutter, slash commands e indentación.
```

### IPC

```bash
qs ipc call notes toggle | open | close
```

### Editor (`NoteTextArea.qml`)

`NotesSidebar` lo configura con `tabSize: 2`, `slashCommands: true`,
`listContinuation: true` y `highlightTheme: "Atom One Dark"`
(KSyntaxHighlighting; si el tema no existe cae al default del sistema).

- **Slash commands** (se disparan con el espacio final):
  `/b ` → `****` con el cursor en el medio · `/c ` → `` `` `` inline ·
  `/cjs ` → bloque ` ```js `.
- **Tab / Shift+Tab**: con selección multilínea sangran / desangran el bloque;
  sin selección insertan una tabulación de 2 espacios (el cursor no salta al
  inicio de línea). Ctrl+> y Ctrl+< (o Ctrl+] / Ctrl+[) hacen lo mismo.
- **Enter**: continúa listas (`- algo` → nueva línea `- `); en un `- ` vacío
  borra el marcador.
- **Atajos**: Ctrl+B/I, Ctrl+K (link), Ctrl+S (`saveRequested`),
  Escape (`escapePressed`), Ctrl+Enter (`accepted`).
- El resaltado, la numeración y el gutter son opt-in por prop (`highlightFileName`,
  `showLineNumbers`, `highlightCurrentLine`).

---

## WiFi — Native Networking API

### Archivos
```
state/WifiState.qml                # Singleton: redes, escaneo, conexión, errores
popups/ControlCenterNew.qml         # Tile WiFi + subvista (lista, contraseña inline, menú contextual)
```

### Arquitectura

**API nativa (Quickshell.Networking):**
- `Networking.wifiEnabled` — toggle directo (bool)
- `Networking.devices` → filtra `DeviceType.Wifi` → `WifiDevice`
- `WifiDevice.scannerEnabled` — activa escaneo nativo
- `WifiDevice.networks` — `ObjectModel<WifiNetwork>` reactivo
- `WifiNetwork.connect()` / `connectWithPsk(psk)` / `disconnect()` / `forget()`
- `WifiNetwork.connectionFailed(reason)` — señal nativa para errores

### Propiedades WifiNetwork (nativas)
| Property | Tipo | Descripción |
|---|---|---|
| `name` | string | SSID de la red |
| `connected` | bool | Si está conectado |
| `stateChanging` | bool | Conectando/desconectando |
| `known` | bool | Red guardada (reemplaza `saved`) |
| `signalStrength` | real | 0.0–1.0 (reemplaza `signal` 0–100) |
| `security` | WifiSecurityType | Open, WpaPsk, Wpa2Psk, Sae, etc. |
| `device` | NetworkDevice | Dispositivo asociado |

### Flujo de conexión
```
User clicks network
  → if known or open: network.connect()
  → if secured + unknown: network.connect() → connectionFailed(NoSecrets) → show password → network.connectWithPsk(pwd)
  → connectionFailed(other) → show error message
```

### Comportamiento en el Control Center
- Click en el tile → abre la subvista WiFi (`currentView = "wifi"`)
- Toggle on/off en la subvista → `WifiState.setWifiEnabled()`
- Red desconocida con clave → campo de contraseña inline (`WifiState.inlineSsid`)
- Right-click sobre una red → menú contextual (conectar / olvidar)

---

## Pendientes

### MPD Integration — Popup nativo con seek interactivo
**Estado:** Completado (tab Música del Hub)
**Archivos:** `state/MpdState.qml` + `state/MpdConnection.qml`, `components/mpd/CpMpdView.qml`

**Solución implementada:**
Socket Unix de MPD propiedad del daemon Go (`scripts/mpd-daemon run`, doble conexión cmd+idle); `MpdConnection.qml` es un bridge NDJSON sobre un `Process` atado al popup (nace con debounce 50ms al entrar al modo mpd, muere a 100ms al cerrar; sin socket QML reutilizado).

**Arquitectura:**
- `scripts/mpd/` (paquete Go, binario `scripts/mpd-daemon`) — Dueño del socket MPD (doble conexión cmd+idle). Comandos tipados: `ping/resync/currentsong/queue/playlists/search/artists/albums/add/addplay/playplaylist/delplaylist/saveplaylist/toggle/syncdb` + passthrough `raw`. Push sin id: `status/song/queue/playlists/conn`. `syncdb` es el seguro de faltantes (diff base−cola por nombre exacto, solo suma; si la cola está vacía y la base llena, la rellena para recuperar una cola perdida; tope 500; corre al pedirlo y solo ante cambios en la base). El arte del panel sale por MPRIS (`MprisState.mpdArtUrl`, el bridge mpd-mpris expone `mpris:artUrl`); el daemon no descarga portadas. Cola siempre completa, posición y versión siempre serializadas (incluido 0).
- `MpdConnection.qml` — Bridge: `sendCommand` (texto, controles simples) + `sendJson` (tipado con match por id) + `daemonEvent` push (status/song/queue/playlists por idle) para UI inmediata
- `MpdState.qml` — Propiedades reactivas; búsquedas, listas, sync y writes van por tipado (sin parseo texto ni escaping en QML). Vacía el estado al caer MPD (`clearMpdState`) y repuebla al reconectar. Filtros locales en memoria intactos
- `components/mpd/CpMpdView.qml` — tab Música del Hub: playlist izq + now-playing der (fondo = cover art oscurecido sin blur, título, `MprisControl`, `SeekBar`). Subvistas `>` a ancho completo
- `ipc/MpdIpc.qml` — `open/toggle/close` abren el modo mpd del palette; resto directo a `MpdState`
- Componentes: `SeekBar` (mismo que Volume), `DiscArt` (arte MPRIS de MPD o disco), `MprisControl` (prev/toggle/next sobre `MpdState`)

**Acceso:**
- IPC: `qs ipc call mpd open` / `qs ipc call mpd toggle` / `qs ipc call mpd play` / etc. (tab Música del Hub)

**Ventajas sobre MPRIS:**
- Seek absoluto funcional (`seekcur` nativo por socket)
- Metadata push vía `idle` (sin polling)
- Playlist completa con `playlistinfo`
- Control de volume, repeat, random, single, consume

**Comandos IPC disponibles:**
- `toggle` / `open` / `close` — control del popup
- `play` / `pause` / `next` / `prev` — reproducción
- `seek <secs>` — seek absoluto en segundos
- `volume <level>` — set volume 0-100