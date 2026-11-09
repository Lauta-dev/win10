# QuickShell v0.3.0 — Quickshell.Bluetooth

`import Quickshell.Bluetooth`

Exposes Bluetooth management via BlueZ DBus interface. Both DBus and BlueZ must be running.

---

## Bluetooth (singleton)

### Properties
- `adapters: ObjectModel<BluetoothAdapter>` (readonly) — All bluetooth adapters.
- `devices: ObjectModel<BluetoothDevice>` (readonly) — All connected devices across all adapters.
- `defaultAdapter: BluetoothAdapter` (readonly) — Default adapter. Usually only one exists.

---

## BluetoothAdapter (uncreatable)

A Bluetooth adapter.

### Properties
- `adapterId: string` (readonly) — Internal ID (e.g. "hci0").
- `dbusPath: string` (readonly) — DBus path under org.bluez.
- `name: string` (readonly) — System provided name.
- `enabled: bool` — If adapter is currently enabled.
- `state: BluetoothAdapterState` (readonly) — Detailed power state.
- `pairable: bool` — If adapter accepts incoming pairing requests (default true).
- `pairableTimeout: int` — Seconds adapter stays pairable. 0 = forever.
- `discoverable: bool` — If adapter can be discovered by other devices.
- `discoverableTimeout: int` — Seconds adapter stays discoverable.
- `discovering: bool` — If adapter is scanning for new devices.
- `devices: ObjectModel<BluetoothDevice>` (readonly) — Devices connected to this adapter.

---

## BluetoothAdapterState (enum)
- `Enabled` — Powered on.
- `Disabled` — Powered off.
- `Enabling` — Transitioning from off to on.
- `Disabling` — Transitioning from on to off.
- `Blocked` — Blocked by rfkill.

---

## BluetoothDevice (uncreatable)

A tracked Bluetooth device.

### Properties
- `address: string` (readonly) — MAC address.
- `dbusPath: string` (readonly) — DBus path under org.bluez.
- `name: string` — Device name (writable for alias).
- `deviceName: string` (readonly) — Device name ignoring aliases.
- `icon: string` (readonly) — System icon for device type.
- `adapter: BluetoothAdapter` (readonly) — Adapter this device belongs to.
- `connected: bool` — Currently connected.
- `paired: bool` (readonly) — If paired.
- `bonded: bool` (readonly) — If pairing info is stored.
- `pairing: bool` (readonly) — If currently pairing.
- `trusted: bool` — If device is trusted.
- `blocked: bool` — If device is blocked from connecting.
- `wakeAllowed: bool` — If device can wake up the host system.
- `battery: real` (readonly) — Battery level 0.0 to 1.0.
- `batteryAvailable: bool` (readonly) — If device reports battery.
- `state: BluetoothDeviceState` (readonly) — Connection state.

### Functions
- `connect()` — Connect to device.
- `disconnect()` — Disconnect from device.
- `pair()` — Attempt to pair.
- `cancelPair()` — Cancel active pairing.
- `forget()` — Forget the device.

---

## BluetoothDeviceState (enum)
- `Disconnected` — Not connected.
- `Connecting` — Connecting.
- `Connected` — Connected.
- `Disconnecting` — Disconnecting.
