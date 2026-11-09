---
name: features
description: Cómo funcionan las features de la shell (clipboard, AppMenu con comandos >b >ia >sf, notificaciones, notas, WiFi, MPD) y qué archivos las implementan. Usar solo al tocar una de esas features.
---

# Features

## Clipboard (cliphist)
- `components/clipboard/`: `ClipEntry` (parsea línea de `cliphist list` → objeto; instanciar UNA vez en `state/ClipboardState`), `ClipFilter` (estilo fzf, debounce 120 ms), `ClipProcesses` (todos los `Process{}`: `reload/copyEntry/deleteEntry/wipe`), `ClipView` + `ClipDelegate`/`ClipItemDelegate`.
- Watcher persistente `wl-paste --watch cliphist store`; copiar por pipe `decode | wl-copy`.
- Regla: parsing solo en `ClipEntry`, I/O solo en `ClipProcesses`, nunca en el delegate.
- IPC: `qs ipc call clipboard toggle|open|close`.

## AppMenu / Launcher
- `popups/LauncherPopup.qml` (640×520, abajo-centro, modo `app` o `clip`; cambia de modo sin reabrir) + `components/appmenu/` (`AppMenuView`, `AppDelegate`). Apps vía `DesktopEntries` nativo.
- IPC: target `command-palette` (`toggle/open/close/openStartmenu`). Lógica en `state/StartmenuState.qml`.
- Recientes: máx 5 en `SettingsState.recentApps` (`addRecentApp`), siempre al tope, badge "Reciente". Click derecho = `togglePinSmart(app.id)`.
- Categorías: `>` lista; `>Categoría texto` filtra.
- Comandos: `>b <txt>` DuckDuckGo · `>ia [gpt|claude|gemini] <prompt>` · `>sf <nombre>` busca archivos en `$HOME`.
- `>sf`: daemon Go `services/daemons/service/search/` (índice en memoria + caché `$XDG_CACHE_HOME/qs-fileindex.txt`, NDJSON, `bin/daemon search run`). Protocolo en su `doc.md`. QML lo arranca bajo demanda y lo apaga a los 20 s de inactividad. Es el único que trae ítems `isFile` (sin pin ni badge).
- Vistas: datos en `enter()` (no en `onCompleted`), filtro vía `onSearchChanged`, ESC con búsqueda vacía cierra.

## Notificaciones
- `state/NotificationState.qml`: `notifications` (ListModel), `add(app,title,body,icon)`, `dismiss(id)`, `clear()`, señal `notificationAdded`. IPC `notify send(app,title,body,icon)` vive acá.
- `popups/NotificationPopup.qml` sobre `WipePopupShell`; máx 3 toasts, 5000 ms, hover pausa (un solo tick de 50 ms; no bindear `Timer.running` al hover: reinicia el tiempo). Click derecho expande el body.

## Notas
`popups/NotesSidebar.qml` + `state/NotesState.qml` (autoguardado) + `components/NoteTextArea.qml` (slash commands `/b /c /cjs`, Tab/Shift+Tab, continuación de listas). IPC `notes toggle|open|close`.

## WiFi
`state/WifiState.qml` sobre `Quickshell.Networking` (nativo) + subvista en `ControlCenterNew`/`popups/views/NetworkView.qml`. Flujo: `connect()` → si falla con NoSecrets, pedir clave inline (`WifiState.inlineSsid`) → `connectWithPsk()`; otros errores se muestran. Click derecho: conectar/olvidar.

## MPD
- Daemon Go `services/daemons/service/mpd/` (dueño del socket, conexión cmd+idle, NDJSON; protocolo en su `doc.md`). Ver también skill `mpd`.
- `state/MpdConnection.qml` = bridge (`Process` atado al popup: nace con debounce 50 ms al entrar, muere a 100 ms al salir); `state/MpdState.qml` = estado reactivo; UI en `components/mpd/CpMpdView.qml` (tab Música del Hub). El arte sale por MPRIS (`MprisState.mpdArtUrl`).
- IPC `mpd`: `open|toggle|close|play|pause|next|prev|seek <s>|volume <0-100>`.
