# win10 — Windows 10 Taskbar para labwc / Wayland

Barra de tareas estilo Windows 10 / ChromeOS Material You construida en **QuickShell + QML**.
Compositor objetivo: **labwc** (Wayland, `wlr-layer-shell`).

---

## Punto de entrada

```
shell.qml       ← ShellRoot — instancia todos los módulos, controla carga diferida
manifest.json   ← { name: "win10", version: "1.0.0" }
```

`shell.qml` importa `./state`, `./components`, `./taskbar`, `./popups`, `./tray`, `./widgets`.
`PanelPopupHost` es la superficie global única de los paneles grandes (Launcher, JumpList, Music, Control Center);
el resto de los popups y menús se instancian con `AutoLazyLoader` la primera vez que se abren.


---

## Árbol de archivos

```
shell_refactored/
│
├── shell.qml                          # ShellRoot — punto de entrada. Instancia Taskbar
│                                      # y PanelPopupHost siempre. El resto se
│                                      # carga con AutoLazyLoader (carga diferida).
├── manifest.json                      # Metadata del paquete: name, description, version
│
├── logic/                             # Módulos JS puros (sin dependencias de QML ni singletons).
│   ├── time.js                        # formato de tiempo, clamp.
│   ├── mpd.js                         # parseo/filtrado MPD.
│   ├── startmenu.js                   # filtrado de apps, comandos, iconos por extensión.
│   │
├── state/                             # Singletons globales. pragma Singleton + Singleton {}.
│   │                                  # Accesibles por nombre desde cualquier QML sin import path.
│   ├── TaskbarState.qml               # Bus central de eventos UI (panel, activePopup, volumeSliderOpen, popupX…).
│   ├── SettingsState.qml              # Persistencia unificada → ~/.config/qs-settings.json
│   ├── Style.qml                      # Paleta activa (surface, primary, outline…). Sin hardcodear colores.
│   ├── AudioState.qml                 # Volumen global + por player.
│   ├── MprisState.qml                 # Player MPRIS activo (título, artista, arte).
│   ├── ClipboardState.qml             # Historial cliphist + thumbs en /tmp/quickshell-clipboard/.
│   ├── Config.qml                     # Tokens de diseño: colores, tamaños, radios, fuentes.
│   ├── DirBrowserState.qml            # Listado de directorios/archivos (centraliza Process list-dirs).
│   └── qmldir
│
├── taskbar/                           # Barra principal y toda la lógica de ventanas/tareas.
│   ├── Taskbar.qml                    # PanelWindow anclado bottom+left+right.
│   ├── groups/
│   │   ├── TaskList.qml               # ListView horizontal. Modelo: pinnedApps + unpinnedOpen.
│   │   └── TaskButton.qml             # Botón unificado (launcher / ventanas / ambas).
│   ├── jumplist/
│   │   ├── JumpList.qml               # Jump List estilo Windows 10 (vista del panel "jumplist").
│   │   └── JumpListItem.qml           # Ítem individual de la JumpList.
│   └── qmldir
│
├── widgets/                           # Widgets de la barra (lado izquierdo/derecho).
│   │                                  # State layer en accent (hover 10%, pressed 18%).
│   ├── DashWidget.qml                 # Trigger del Control Center. Muestra wifi y hora/fecha.
│   ├── VolumeWidget.qml               # Ícono + slider inline (se revela con hover, sin popup).
│   └── qmldir
│
├── popups/                            # Paneles flotantes. Carga diferida via AutoLazyLoader.
│   │                                  # Los 4 grandes (Launcher/JumpList/Music/CC) son vistas Item de
│   │                                  # components/PanelPopupHost (superficie única, slot TaskbarState.panel).
│   │                                  # El resto usa components/WipePopupShell (wipe estilo minflair)
│   │                                  # + fusión convex con la barra (ConvexPopupShape, flares, overscan 16px).
│   ├── ControlCenterNew.qml           # Vista "controlcenter" del host (right): usuario, tiles, brillo, calendario/notif/pomodoro, wifi.
│   ├── HubPopup.qml                   # Hub con tabs: Música (MPD) + Calc.
│   ├── MpdPopup.qml                   # Panel MPD (PanelPopupHost): CpMpdView
│   │                                  # (cola sobre PanelList, focus único hover/teclado + fila sonando con bg sólido).
│   ├── LauncherPopup.qml              # Vista "launcher": AppMenu/Clipboard por modo (sin reabrirse).
│   ├── MusicPopup.qml                 # Vista "music": player MPRIS (+ cola MPD expandible a la derecha).
│   ├── OsdSliderPopup.qml            # OSD único vol/brillo/power (modo por IPC, sin reabrirse).
│   │                                  # power: botones uniformes + highlight deslizante + nav ←/→/Enter/Esc.
│   │                                  # IPC: vol (adjust/toggle), power (toggle/logout/reboot/off).
│   ├── NotesSidebar.qml               # Bloc de notas (ventana SSD, autoguardado, resaltado, slash commands).
│   ├── SettingsPopup.qml              # Panel principal de ajustes. 4 tabs.
│   ├── PolkitPopup.qml                # Diálogo de autenticación polkit (centrado).
│   └── qmldir
│
├── components/                        # Primitivos UI reutilizables. Sin lógica de negocio.
│   ├── ConvexPopupShape.qml           # Shape convexo para fusión popup↔barra (radios direccionales + flares).
│   ├── WipePopupShell.qml             # Shell genérico: superficie fija + wipe estilo minflair (flag, position, contentWidth/Height).
│   ├── PanelPopupHost.qml             # Superficie global única de Launcher/JumpList/Music/CC/Mpd (API viewWidth/Height/X, _CONFIGS, retención en cierre).
│   ├── SeekBar.qml / MprisControl.qml  # Piezas MPRIS (seek, prev/play/next).
│   ├── ValueSlider.qml                # Slider con ícono para popups (volumen global).
│   ├── SmartSearchInput.qml           # Buscador con contador integrado (showSearchCounter).
│   ├── AppTextInput.qml               # Input base con estilo único (bg + borde de foco).
│   ├── AppIcon.qml                    # Imagen con fallback de inicial coloreada.

│   ├── AutoLazyLoader.qml             # LazyLoader que no se destruye una vez cargado.
│   ├── DismissOverlay.qml             # Rectángulo fullscreen transparente para cerrar popups.

│   ├── WindowCountBadge.qml           # Badge circular con número de ventanas.
│   ├── SectionLabel.qml               # Etiqueta uppercase para secciones.

│   ├── PanelList.qml                  # Lista scrollable genérica reutilizable: modelo externo, delegate externo,
│   │                                  # estado vacío/cargando configurable, buscador opcional, nav por teclado.
│   │                                  # Hover = selección por norma (focus único); opt-out con hoverSelects: false.
│   ├── DropdownMenu.qml                # Menú flotante reutilizable (dropdown): items {id,label,icon,danger},
│   │                                  # selectedId, hover + bg de selección; pointer solo en las filas.
│   │                                  # rowDelegate para filas custom (ej. players con carátula en MusicPopup).
│   ├── clipboard/                     # Submódulo del portapapeles (lógica + vista ClipView/ClipDelegate).
│   │   ├── ClipEntry.qml              # Parsea una línea raw de cliphist en un objeto enriquecido (tipo, preview, etc.).
│   │   ├── ClipFilter.qml             # Filtrado estilo fzf con debounce de 120 ms. Expone results[].
│   │   ├── ClipProcesses.qml          # Encapsula todos los procesos cliphist (listar, copiar, borrar, wipe).
│   │   ├── ClipItemDelegate.qml       # Delegate visual de cada entrada: texto, imagen preview, tipo.
│   │   ├── ClipView.qml               # Vista clipboard del LauncherPopup: buscar + pegar.
│   │   ├── ClipDelegate.qml           # Delegate de la vista clipboard.
│   │   └── qmldir
│   ├── appmenu/                       # Lanzador de apps.
│   │   ├── AppMenuView.qml            # Vista apps del LauncherPopup: buscar, abrir y comandos (`>b`, `>ia`, `>sf`).
│   │   ├── AppDelegate.qml            # Delegate de apps.
│   │   └── qmldir
│   ├── hub/                           # Vistas del Hub que quedaron acá (Calc).
│   │   ├── CpCalcPanel.qml            # Calculadora del Hub.
│   │   ├── CpCalcFraction.qml / CpCalcPie.qml
│   │   └── qmldir
│   ├── mpd/                           # Vista Música MPD (compartida: Hub tab + panel "mpd").
│   │   ├── CpMpdView.qml              # Cola única sobre PanelList (sin subvistas `>`, sin restaurar posición),
│   │   │                              # recientes persistentes, cover full-bleed tintado, focus único.
│   │   ├── CpMpdDelegate.qml          # Fila de canción (wash/pill sonando, sin hover propio).
│   │   ├── CpRecentStrip.qml          # Tira horizontal de agregados recientes (click reproduce).
│   │   └── qmldir
│   ├── pomodoro/                      # Pomodoro (Hub + centro de control).
│   │   ├── PomodoroPanel.qml          # Ring + controles + ajustes.
│   │   └── qmldir
│   └── qmldir
│
├── tray/                              # Bandeja del sistema.
│   ├── SystemTrayArea.qml             # Row con: Repeater(SystemTray.items → TrayIconPill) + DashWidget.
│   ├── TrayIconPill.qml               # Ítem individual del tray con tooltip y menú contextual.
│   └── qmldir
│
└── services/                         # Modulos Go (cada carpeta es un módulo propio).
    ├── calc/                         # Calculadora.
    ├── daemons/                      # Un binario: service/mpd, bright, search (NDJSON stdio).
    ├── list-dirs/                     # JSON para DirBrowser (files = sniff texto) / monitores.
    ├── list-monitors/                # Lista de monitores.
    ├── resolve-icons/                # Genera { appId: "/path/icon.svg" } desde el icon theme.
    ├── theming/                      # GTK-apply, shell-theme, matugen-apply.
    │   ├── cmd/gtk-apply/            # GTK-apply
    │   ├── cmd/shell-theme/          # Shell-theme
    │   ├── cmd/matugen-apply/        # Matugen-apply
    │   └── internal/                 # Lógica compartida
    └── qsipc/                        # IPC client for quickshell
        └── main.go                 # qsipc binary

└── bin/                              # Binarios compilados (ignorado por git)
    ├── daemon                         # daemons binary
    ├── calc-eval                     # calculator
    ├── list-dirs                     # directory lister
    ├── list-monitors                 # monitor lister
    ├── resolve-icons                 # icon resolver
    ├── gtk-apply                     # GTK theme applier
    ├── shell-theme                   # shell theme applier
    ├── matugen-apply                 # matugen theme applier
    └── qsipc                         # quickshell IPC client
    ```

