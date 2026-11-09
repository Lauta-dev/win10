# QuickShell v0.3.0 — Quickshell.Wayland

`import Quickshell.Wayland`

---

## WlrLayershell (extends PanelWindow)

Decorationless window attached to screen edges using the zwlr_layer_shell_v1 protocol.

Use as an attached object of PanelWindow. Prefer PanelWindow directly if you can, as it is platform independent.

### Properties
- `layer: WlrLayer` — Shell layer the window sits in (default Top).
- `keyboardFocus: WlrKeyboardFocus` — Degree of keyboard focus taken (default None).
- `namespace: string` — Similar to window class. Identifies the window to external tools. Cannot be set after windowConnected.

---

## WlrLayer (enum)
- `Background` — Below bottom.
- `Bottom` — Above background, usually below windows.
- `Top` — Commonly used for panels, app launchers, and docks. Usually renders over normal windows and below fullscreen windows.
- `Overlay` — Usually renders over fullscreen windows.

---

## WlrKeyboardFocus (enum)
- `None` — No keyboard input will be accepted.
- `OnDemand` — Access to the keyboard as determined by the OS. WARNING: On some systems, OnDemand may cause the shell window to retain focus over another window unexpectedly. Try None if you experience issues.
- `Exclusive` — Exclusive access to the keyboard, locking out all other windows. WARNING: You CANNOT use this to make a secure lock screen. Use WlSessionLock.

---

## WlSessionLock (extends Reloadable)

Wayland session lock using the ext_session_lock_v1 protocol.

Creates an instance of its surface component for every screen when locked is true. The surface component must create a WlSessionLockSurface.

WARNING: If destroyed or quickshell exits without setting locked to false, conformant compositors will leave the screen locked and painted with a solid color.

### Properties
- `locked: bool` — Controls the lock state. WARNING: Only one WlSessionLock may be locked at a time.
- `secure: bool` (readonly) — Compositor lock state. True once compositor confirmed all screens are covered.
- `surface: Component` (default) — Surface created for each screen. Must create a WlSessionLockSurface.

---

## WlSessionLockSurface (extends Reloadable)

Surface displayed by a WlSessionLock when locked.

### Properties
- `screen: ShellScreen` (readonly) — Screen the surface is displayed on.
- `width: int` (readonly), `height: int` (readonly)
- `color: color` — Background color (default white). WARNING: Transparent colors behave weirdly on some systems.
- `visible: bool` (readonly) — If surface has been made visible. Note: surfaces will never become invisible, only destroyed.
- `contentItem: Item` (readonly)
- `data: list<QtObject>` (default, readonly)

---

## ToplevelManager (singleton)

Exposes windows from other applications as Toplevels via zwlr-foreign-toplevel-management-v1.

### Properties
- `toplevels: ObjectModel<Toplevel>` (readonly) — All toplevel windows exposed by the compositor.
- `activeToplevel: Toplevel` (readonly) — Active toplevel or null. If multiple active, the most recently activated one.

---

## Toplevel (uncreatable)

A window/toplevel from another application, from ToplevelManager.

### Properties
- `title: string` (readonly)
- `appId: string` (readonly)
- `activated: bool` (readonly) — If currently activated/focused.
- `fullscreen: bool` — If currently fullscreen. Can be requested, may be ignored by compositor.
- `maximized: bool` — If currently maximized. Can be requested, may be ignored.
- `minimized: bool` — If currently minimized. Can be requested, may be ignored.
- `parent: Toplevel` (readonly) — Parent if modal/dialog, otherwise null.
- `screens: list<ShellScreen>` (readonly) — Screens the toplevel is visible on. NOTE: Some compositors only list a single screen.

### Functions
- `activate()` — Request activation. May be ignored.
- `close()` — Request close. May be ignored.
- `fullscreenOn(screen: ShellScreen)` — Request fullscreen on specific screen. May be ignored.
- `setRectangle(window: QtObject, rect: rect)` — Hint to compositor where visual representation is relative to a quickshell window.
- `unsetRectangle()`

### Signals
- `closed()`

---

## ScreencopyView (extends Item)

Displays live video streams or single captured frames from valid capture sources.

### Properties
- `captureSource: QtObject` — Object to capture from. Accepts: null (clears), ShellScreen (requires wlr-screencopy-unstable or ext-image-copy-capture-v1 + ext-capture-source-v1), Toplevel (requires hyprland-toplevel-export-v1).
- `live: bool` — If true, live video feed instead of still image (default false).
- `paintCursor: bool` — Paint system cursor on image (default false).
- `hasContent: bool` (readonly) — If view has content ready to display.
- `sourceSize: size` (readonly) — Size of the source image. Valid when hasContent is true.
- `constraintSize: unknown` — If nonzero, constrains implicit size maintaining aspect ratio.

### Functions
- `captureFrame()` — Capture a single frame. No effect if live is true.

### Signals
- `stopped()` — Compositor ended the video stream.

---

## IdleInhibitor

Prevents a wayland session from being marked as idle. Compositor usually considers PanelWindow or focused FloatingWindow important.

Requires idle-inhibit-unstable-v1 protocol.

### Properties
- `window: QtObject` — Window to associate with. Must be non-null to enable.
- `enabled: bool` — If inhibitor should be enabled (default false).

---

## IdleMonitor

Detects when user stops providing input for a period of time.

Requires ext-idle-notify-v1 protocol.

### Properties
- `enabled: bool` — If monitor should be enabled (default true).
- `timeout: real` — Time in seconds before reporting idle (default 0 = immediately).
- `isIdle: bool` (readonly) — True if user has been idle for at least timeout.
- `respectInhibitors: bool` — If true, isIdle depends on both user interaction and active idle inhibitors. When false, depends solely on user interaction (default true).

---

## ShortcutInhibitor

Prevents compositor from processing its own keyboard shortcuts for the focused surface.

Requires keyboard-shortcuts-inhibit-unstable-v1 protocol.

### Properties
- `window: QtObject` — Window to associate with. Inhibits shortcuts only while this window has keyboard focus. Must be non-null to enable.
- `enabled: bool` — If inhibitor should be enabled (default false).
- `active: bool` (readonly) — Whether inhibitor is currently active. Only active if enabled=true, window has focus, and compositor grants request. Compositor may deactivate at any time and cannot be programmatically reactivated.

### Signals
- `cancelled()` — Sent if compositor cancels the inhibitor while active.

---

## BackgroundEffect (uncreatable)

Applies background blur behind a QsWindow or subclass, as an attached object, using ext-background-effect-v1.

Requires compositor support for ext-background-effect-v1.

### Properties
- `blurRegion: Region` — Region to blur behind the surface. Set to null to remove blur.

### Example
```qml
PanelWindow {
  id: root
  color: "#80000000"
  BackgroundEffect.blurRegion: Region { item: root.contentItem }
}
```
