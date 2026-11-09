# QuickShell v0.3.0 — Quickshell.Networking

`import Quickshell.Networking`

---

## Networking (singleton)

Interface to a network backend (currently only NetworkManager). View, configure, and connect to networks.

### Properties
- `backend: NetworkBackendType` (readonly) — Backend powering the Network service.
- `devices: ObjectModel<NetworkDevice>` (readonly) — All network devices. Networks exposed through their devices.
- `connectivity: NetworkConnectivity` (readonly) — Result of last connectivity check.
- `canCheckConnectivity: bool` (readonly) — If backend supports connectivity checks.
- `connectivityCheckEnabled: bool` — If connectivity checking is enabled.
- `wifiEnabled: bool` — Switch for rfkill software block of all wireless devices.
- `wifiHardwareEnabled: bool` (readonly) — State of rfkill hardware block of all wireless devices.

### Functions
- `checkConnectivity()` — Re-check connectivity state immediately. Invoke after dismissing captive portal browser.

---

## NetworkBackendType (enum)
- `NetworkManager`
- `None`

---

## NetworkConnectivity (enum)
- `Unknown` — Connectivity checks disabled or not run yet.
- `None` — Not connected to any network.
- `Limited` — Connected but cannot reach full internet.
- `Full` — Connected and can reach full internet.
- `Portal` — Connection hijacked by captive portal. Should open sandboxed browser for authentication.

---

## NetworkDevice (uncreatable)

The `type` property determines if this is a WifiDevice or WiredDevice.

### Properties
- `type: DeviceType` (readonly) — When Wifi, the device object is a WifiDevice. When Wired, it's a WiredDevice.
- `state: ConnectionState` (readonly) — Connection state of the device.
- `name: string` (readonly) — Name of the device's control interface.
- `address: string` (readonly) — Hardware address in XX:XX:XX:XX:XX:XX format.
- `connected: bool` (readonly) — If the device is connected.
- `autoconnect: bool` — If device is allowed to autoconnect.
- `networks: ObjectModel<Network>` (readonly) — Available or connected networks. For WifiDevice, only contains WifiNetwork.

### Functions
- `disconnect()` — Disconnects device and prevents automatic activation of further connections.

---

## DeviceType (enum)
- `None`
- `Wifi`
- `Wired`

---

## WifiDevice (extends NetworkDevice)

### Properties
- `scannerEnabled: bool` — When true, scanner populates device with available wifi networks.
- `mode: WifiDeviceMode` (readonly) — The 802.11 mode.

---

## WifiDeviceMode (enum)
- `Unknown`
- `Station` — Can connect to networks.
- `AccessPoint` — Local hotspot/access point.
- `AdHoc` — Ad-Hoc network without central access point.
- `Mesh` — 802.11s mesh point.

---

## WiredDevice (extends NetworkDevice)

### Properties
- `hasLink: bool` (readonly) — If physical link exists (cable plugged in).
- `linkSpeed: int` (readonly) — Max speed of physical device link, in megabits per second.
- `network: Network` (readonly) — The wired network for this device or null. Only available when hasLink is true.

---

## Network (uncreatable)

A network. Networks from a WifiDevice are WifiNetwork instances.

### Properties
- `name: string` (readonly) — Name of the network.
- `state: ConnectionState` (readonly) — Connectivity state.
- `connected: bool` (readonly) — If connected.
- `stateChanging: bool` (readonly) — If currently connecting or disconnecting.
- `known: bool` (readonly) — If wifi network has saved connection settings.
- `device: NetworkDevice` (readonly) — Device this network belongs to.
- `nmSettings: list<NMSettings>` (readonly) — NetworkManager connection settings profiles. WARNING: Only valid for NetworkManager backend.

### Functions
- `connect()` — Attempt to connect. NOTE: If WifiNetwork requiring secrets, connectionFailed will emit with NoSecrets. Use connectWithPsk().
- `disconnect()` — Disconnect from the network.
- `forget()` — Forget all connection settings.
- `connectWithSettings(settings: NMSettings)` — Connect with specific nmSettings entry. WARNING: Only valid for NetworkManager.

### Signals
- `connectionFailed(reason: ConnectionFailReason)`

---

## WifiNetwork (extends Network)

### Properties
- `security: WifiSecurityType` (readonly)
- `signalStrength: real` (readonly) — 0.0 to 1.0.

### Functions
- `connectWithPsk(psk: string)` — Connect with given PSK. If wrong, connectionFailed emits NoSecrets. Only use when security is WpaPsk, Wpa2Psk, or Sae.

---

## WifiSecurityType (enum)
- `Unknown`
- `Open`
- `WpaPsk`
- `Wpa2Psk`
- `WpaEap`
- `Wpa2Eap`
- `Sae`
- `Wpa3SuiteB192`
- `Owe`
- `DynamicWep`
- `StaticWep`
- `Leap`

---

## ConnectionState (enum)
- `Unknown`
- `Disconnected`
- `Connecting`
- `Connected`
- `Disconnecting`

---

## ConnectionFailReason (enum)
- `Unknown`
- `NoSecrets` — Secrets were required but not provided.
- `WifiAuthTimeout` — Wi-Fi authentication took too long.
- `WifiClientDisconnected` — Wi-Fi supplicant disconnected.
- `WifiNetworkLost` — Wi-Fi network could not be found.
- `WifiClientFailed` — Wi-Fi supplicant failed.

---

## NMSettings (uncreatable)

A NetworkManager connection settings profile.

### Properties
- `id: string` (readonly) — Human-readable unique identifier.
- `uuid: string` (readonly) — Universally unique identifier.

### Functions
- `read(): unknown` — Get settings map. NOTE: Never includes secrets.
- `write(settings: unknown)` — Update connection with new settings and save. Writing a setting to null removes/resets it. NOTE: Secrets may be part of the update.
- `clearSecrets()` — Clear all secrets belonging to the settings.
- `forget()` — Delete the settings.

### Signals
- `loaded()`
- `settingsChanged(settings: unknown)`
