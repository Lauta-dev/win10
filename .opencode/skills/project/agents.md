# Skill: AGENTS - Hub de documentación

## Descripción
Este es el hub central de documentación para el proyecto shell_refactored (Windows 10 Taskbar para labwc/Wayland). Antes de hacer cualquier cambio en el proyecto, DEBES leer esta documentación.

## Proyecto
Windows 10 Taskbar estilo ChromeOS Material You construida en **QuickShell + QML** para el compositor **labwc** (Wayland).

## Punto de entrada
- `shell.qml` — ShellRoot que instancia todos los módulos
- `manifest.json` — Metadata del paquete

## Mapa rápido

| Si vas a tocar… | Skill a usar |
|---|---|
| `state/TaskbarState`, `Config`, `SettingsState`, `ColorThemes` | state |
| Lanzar apps, watchdog de apertura, match fuzzy, pin smart | state |
| Flujo de datos, arranque, persistencia, dark mode | state |
| `components/`, `taskbar/`, `widgets/`, `popups/`, `tray/`, `services/`, `bin/` | components |
| `PanelList`, `ClipItemDelegate`, `AppIcon`, `SegmentedControl`, etc. | components |
| Sistema de portapapeles | features |
| Sistema de notificaciones | features |
| Pomodoro Timer | features |
| AppMenu | features |
| Bugs de color/hover, salto de altura en popups, convenciones globales, reglas de modificación | conventions |
| Añadir toggle al DashWidget o ítem al SystemTray | conventions |
| IPC | conventions |

## Regla de oro

**No hacer ningún cambio que no haya sido explícitamente pedido.**
- Colores siempre via `Config`
- Estado compartido en singletons de `state/`: `TaskbarState` (UI efímero), `AudioState` (volumen), `MprisState` (música), `SettingsState` (persistencia)
- Preferir APIs nativas de Quickshell antes que `Process{}` — ej: Pipewire, Mpris, Networking, Bluetooth
- Si no hay API nativa → `Process{}` — nunca síncronos
- Popups siempre via `AutoLazyLoader`; los paneles grandes (Launcher/JumpList/Music/CC) son vistas del `PanelPopupHost` único y se abren con `TaskbarState.openPanel(name)`

## Organizarse
Usa la skill `todowrite` para crear una lista de tareas antes de hacer cambios significativos.