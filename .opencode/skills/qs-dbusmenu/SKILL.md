# QuickShell v0.3.0 — Quickshell.DBusMenu

`import Quickshell.DBusMenu`

Types related to DBusMenu (used in system tray).

---

## DBusMenuHandle (uncreatable)

Handle to a menu tree provided by a remote process.

### Properties
- `menu: DBusMenuItem` (readonly)

---

## DBusMenuItem (inherits QsMenuEntry, uncreatable)

Menu item shared by an external program via the DBusMenu specification.

### Properties
- `menuHandle: DBusMenuHandle` (readonly) — Handle to the root of this menu.

### Functions
- `updateLayout()` — Refresh menu contents. `layoutUpdated()` signal sent when response received.

### Signals
- `layoutUpdated()`
