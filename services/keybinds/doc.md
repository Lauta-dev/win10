# keybinds

Parser one-shot de `~/.config/labwc/rc.xml` para el panel "keybinds" de la
shell (`KeybindsState.qml` lo corre cada vez que se entra al popup; no queda
vivo como los daemons).

## Qué hace

- Lee los `<keybind>` de rc.xml con su atributo `label` (metadata propia:
  labwc lo ignora, no es parte del spec — ver `labwc-config(5)`).
- Interpreta cada combinación a "chips" humanas: `W-m` → `["Super","M"]`,
  `C-A-Left` → `["Ctrl","Alt","←"]`, `XF86AudioMute` → `["Fn","F3"]`
  (mapeo físico `fnKeys` de este laptop; un XF86 sin mapeo cae a
  `["Fn","<keysym humano>"]`), `Super_L` (onRelease) → `["Super"]`.
- Clasifica cada atajo en una sección temática por su primera acción:
  `Sistema` (XF86/grim/brillo/volumen/Reconfigure), `Ventanas`
  (NextWindow, Close, ToggleMaximize...), `Escritorios` (Go/SendToDesktop),
  `Apps` (Execute), `Menús` (ShowMenu), `Otros` (fallback).
- Los `<mousebind>` con `label` entran a la sección `Mouse` con chip
  ("Super + arrastre izq", "Clic der · título", "Rueda ↑ · escritorio").
- Deduplica filas idénticas (mismo desc + chips): el clic derecho en
  Titlebar y en las esquinas comparten bloque en rc.xml.

## Protocolo (salida)

```json
{"sections":[
  {"title":"Sistema","rows":[{"desc":"Captura de pantalla completa","keys":["Print"],"raw":"Print"}]}
]}
```

Orden de secciones: Sistema, Ventanas, Mouse, Apps, Escritorios, Menús,
Otros (vacías se omiten). La UI reparte columnas por título: izquierda =
{Sistema, Ventanas, Mouse}; el resto, derecha. Sin secciones = rc.xml sin
atajos o error (exit 1, detalle por stderr).

## Uso

```sh
keybinds [rc.xml]        # sin argumento: XDG_CONFIG_HOME o ~/.config
```

Sin dependencias externas: solo stdlib (encoding/xml + encoding/json).
