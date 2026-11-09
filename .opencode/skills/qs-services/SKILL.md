# QuickShell v0.3.0 — Quickshell.Services

All service modules: Pipewire, Mpris, Notifications, UPower, SystemTray, Greetd, Pam, Polkit.

---

# Quickshell.Services.Pipewire

`import Quickshell.Services.Pipewire`

## Pipewire (singleton)

### Properties
- `ready: bool` (readonly) — True if quickshell completed initial sync with pipewire server. If true, nodes, links and preferences are in good state.
- `nodes: ObjectModel<PwNode>` (readonly) — All nodes on the system.
- `links: ObjectModel<PwLink>` (readonly) — All links. One link per channel between nodes.
- `linkGroups: ObjectModel<PwLinkGroup>` (readonly) — Deduplicated links. One entry per source→target pair.
- `defaultAudioSink: PwNode` (readonly) — Default audio sink (output) or null. May briefly be null when default changes.
- `defaultAudioSource: PwNode` (readonly) — Default audio source (input) or null. May briefly be null when default changes.
- `preferredDefaultAudioSink: PwNode` — Hint to pipewire for preferred default sink.
- `preferredDefaultAudioSource: PwNode` — Hint to pipewire for preferred default source.

## PwNode (uncreatable)

A node in the pipewire connection graph.

### Properties
- `id: int` (readonly) — Pipewire object id. Inspect with `pw-cli i <id>`.
- `name: string` (readonly) — Corresponds to `node.name`.
- `nickname: string` (readonly) — Corresponds to `node.nickname`. May be empty.
- `description: string` (readonly) — Corresponds to `node.description`. May be empty.
- `type: unknown` (readonly) — Reflects Pipewire's media.class.
- `isSink: bool` (readonly) — If true, node accepts audio input (sink). If false, outputs audio (source).
- `isStream: bool` (readonly) — If true, likely a program. If false, likely a hardware device.
- `ready: bool` (readonly) — Fully bound and ready to use.
- `audio: PwNodeAudio` (readonly) — Extra info if audio node. Non-null = audio node.
- `properties: unknown` (readonly) — Key-value pairs. Notable: `application.name`, `application.icon-name`, `media.name`, `media.title`, `media.artist`. WARNING: Invalid unless bound via PwObjectTracker.

## PwNodeAudio (uncreatable)

Extra properties of a PwNode if it's an audio node. See PwNode.audio.

### Properties
- `volume: real` — Average volume over all channels. Setting modifies all channels proportionately. WARNING: Invalid unless bound.
- `volumes: list<real>` — Per-channel volumes. Same length as channels. WARNING: Invalid unless bound.
- `muted: bool` — Currently muted. Setting changes mute state. WARNING: Invalid unless bound.
- `channels: list<PwAudioChannel>` (readonly) — Audio channels present. WARNING: Invalid unless bound.

## PwAudioChannel (enum)

Mono, FrontLeft, FrontRight, FrontCenter, RearLeft, RearRight, RearCenter, LowFrequencyEffects, SideLeft, SideRight, TopCenter, TopFrontLeft, TopFrontRight, TopFrontCenter, TopRearLeft, TopRearRight, TopRearCenter, FrontLeftCenter, FrontRightCenter, RearLeftCenter, RearRightCenter, FrontLeftWide, FrontRightWide, FrontLeftHigh, FrontRightHigh, FrontCenterHigh, BottomCenter, BottomLeftCenter, BottomRightCenter, TopFrontLeftCenter, TopFrontRightCenter, TopSideLeft, TopSideRight, LowFrequencyEffectsLeft, LowFrequencyEffectsRight, LowFrequencyEffects2, NA, Unknown
- AuxRangeStart..AuxRangeEnd (aux channel range)
- CustomRangeStart+ (custom channel range)

## PwLink (uncreatable)

One link per channel between nodes. Usually want PwLinkGroup instead.

### Properties
- `id: int` (readonly) — Pipewire object id.
- `source: PwNode` (readonly) — Node sending information.
- `target: PwNode` (readonly) — Node receiving information (the sink).
- `state: PwLinkState` (readonly) — Current state. WARNING: Invalid unless bound via PwObjectTracker.

## PwLinkGroup (uncreatable)

One entry per source→target pair.

### Properties
- `source: PwNode` (readonly) — Node sending.
- `target: PwNode` (readonly) — Node receiving (the sink).
- `state: PwLinkState` (readonly) — Current state. WARNING: Invalid unless bound.

## PwLinkState (enum)
- `Init`, `Allocating`, `Negotiating`, `Active`, `Paused`, `Unlinked`, `Error`

## PwNodeLinkTracker

Tracks non-monitor link connections to a given node.

### Properties
- `node: PwNode` — The node to track.
- `linkGroups: list<PwLinkGroup>` (readonly) — Link groups connected to the node, excluding monitors. If sink, tracks links targeting it. If source, tracks links sourcing from it.

## PwNodePeakMonitor

Tracks volume peaks for a node across all channels. Binds nodes similarly to PwObjectTracker when enabled.

### Properties
- `node: PwNode` — The node to monitor. Must be an audio node.
- `enabled: bool` — If monitor is actively capturing (default true).
- `peak: real` (readonly) — Maximum value of peaks.
- `peaks: list<real>` (readonly) — Per-channel peak levels (0.0-1.0). Channel volume does not affect this.
- `channels: list<PwAudioChannel>` (readonly) — Channel positions for captured format.

## PwObjectTracker

Binds every node in its objects list. By default, pipewire objects are unbound with only a subset of info available. Binding makes all properties available.

### Properties
- `objects: list<QtObject>` — Objects to bind. May contain nulls.

## PwNodeType (singleton)

Use bitwise comparisons to filter for audio, video, sink, source or stream nodes.

### Functions
- `toString(type): string`

---

# Quickshell.Services.Mpris

`import Quickshell.Services.Mpris`

## Mpris (singleton)

### Properties
- `players: ObjectModel<MprisPlayer>` (readonly) — All connected MPRIS players.

## MprisPlayer (uncreatable)

A media player exposed over MPRIS.

### Properties
- `dbusName: string` (readonly) — DBus service name.
- `identity: string` (readonly) — Human readable name.
- `desktopEntry: string` (readonly) — Desktop entry name, or empty.
- `playbackState: MprisPlaybackState` — Current playback state.
- `isPlaying: bool` — True if playbackState == Playing. Setting is equivalent to play()/pause().
- `canPlay: bool` (readonly)
- `canPause: bool` (readonly)
- `canTogglePlaying: bool` (readonly)
- `canGoNext: bool` (readonly)
- `canGoPrevious: bool` (readonly)
- `canSeek: bool` (readonly)
- `canQuit: bool` (readonly)
- `canRaise: bool` (readonly)
- `canSetFullscreen: bool` (readonly)
- `canControl: bool` (readonly)
- `shuffleSupported: bool` (readonly)
- `shuffle: bool` — If play queue is being shuffled.
- `loopSupported: bool` (readonly)
- `loopState: MprisLoopState` — Loop state, or None if loopSupported is false.
- `volumeSupported: bool` (readonly)
- `volume: real` — Volume from 0.0 to 1.0.
- `positionSupported: bool` (readonly)
- `position: real` — Current position in seconds, with millisecond precision. Writable if canSeek and positionSupported.
- `lengthSupported: bool` (readonly)
- `length: real` (readonly) — Track length in seconds.
- `minRate: real` (readonly), `maxRate: real` (readonly)
- `rate: real` — Playback speed multiplier.
- `metadata: unknown` (readonly) — Current track metadata.
- `uniqueId: int` (readonly) — Opaque track identifier unique within current player.
- `trackTitle: string` (readonly) — Track title, or "".
- `trackArtist: string` (readonly) — Track artist, or "".
- `trackArtists: string` (readonly) — Deprecated, use trackArtist.
- `trackAlbum: string` (readonly) — Track album, or "".
- `trackAlbumArtist: string` (readonly) — Track album artist, or "".
- `trackArtUrl: string` (readonly) — Track art URL, or "".
- `fullscreen: bool` — If player is shown in fullscreen.
- `supportedUriSchemes: list<string>` (readonly) — URI schemes supported by openUri().
- `supportedMimeTypes: list<string>` (readonly) — Mime types supported by openUri().

### Functions
- `play()` — Equivalent to setting playbackState to Playing.
- `pause()` — Equivalent to setting playbackState to Paused.
- `stop()` — Equivalent to setting playbackState to Stopped.
- `togglePlaying()` — Toggle play/pause.
- `next()` — Play next song.
- `previous()` — Play previous song.
- `seek(offset)` — Change position by offset.
- `quit()` — Quit the media player.
- `raise()` — Bring to front.
- `openUri(uri)` — Open URI in the media player.

### Signals
- `trackChanged()` — Track has changed.
- `postTrackChanged()` — Sent after track info properties updated.

## MprisPlaybackState (enum)
- `Stopped`, `Playing`, `Paused`

## MprisLoopState (enum)
- `None`, `Track`, `Playlist`

---

# Quickshell.Services.Notifications

`import Quickshell.Services.Notifications`

## NotificationServer

Implementation of the Desktop Notifications Specification.

### Properties
- `trackedNotifications: ObjectModel<Notification>` (readonly) — All notifications currently tracked.
- `bodySupported: bool` — Advertise body support (default true).
- `bodyMarkupSupported: bool` — Advertise markup support (default false).
- `bodyHyperlinksSupported: bool` — Advertise hyperlink support (default false).
- `bodyImagesSupported: bool` — Advertise body image support (default false).
- `actionsSupported: bool` — Advertise action support (default false).
- `actionIconsSupported: bool` — Advertise action icon support (default false).
- `imageSupported: bool` — Advertise image support (default false).
- `inlineReplySupported: bool` — Advertise inline reply support (default false).
- `persistenceSupported: bool` — Advertise persistence support (default false).
- `extraHints: list<string>` — Extra hints to expose to clients.
- `keepOnReload: bool` — Re-emit notifications on reload (default true).

### Signals
- `notification(notification: Notification)` — Sent when a notification is received.

## Notification (uncreatable, Retainable)

### Properties
- `id: int` (readonly) — Notification id.
- `appName: string` (readonly) — Sending application's name.
- `appIcon: string` (readonly) — Sending application's icon.
- `desktopEntry: string` (readonly) — Sender's desktop entry, or "".
- `summary: string` (readonly) — Summary, or "".
- `body: string` (readonly)
- `image: string` (readonly) — Associated image.
- `urgency: NotificationUrgency` (readonly)
- `actions: list<NotificationAction>` (readonly)
- `hasActionIcons: bool` (readonly) — If actions have icons available.
- `hasInlineReply: bool` (readonly) — If has inline reply action.
- `inlineReplyPlaceholder: string` (readonly) — Placeholder text for inline reply.
- `expireTimeout: real` (readonly) — Time in seconds notification should be valid.
- `transient: bool` (readonly) — If true, should skip persistence.
- `resident: bool` (readonly) — If true, not destroyed after action invoked.
- `tracked: bool` — If tracked by the notification server.
- `lastGeneration: bool` (readonly) — If carried over from last generation on reload.
- `hints: unknown` (readonly) — All hints as JS object.

### Functions
- `dismiss()` — Destroy and hint to remote that it was explicitly closed.
- `expire()` — Destroy and hint that it timed out.
- `sendInlineReply(replyText)` — Send inline reply.

### Signals
- `closed(reason: NotificationCloseReason)`

## NotificationAction (uncreatable)

### Properties
- `identifier: string` (readonly) — Action identifier. When hasActionIcons is true, this is an icon name.
- `text: string` (readonly) — Localized button text.

### Functions
- `invoke()` — Invoke the action. If resident is false, notification will be dismissed.

## NotificationCloseReason (enum)
- `Expired` — Timed out.
- `Dismissed` — Explicitly dismissed by user.
- `CloseRequested` — Remote application requested removal.

## NotificationUrgency (enum)
- `Low`, `Normal`, `Critical`

---

# Quickshell.Services.UPower

`import Quickshell.Services.UPower`

## UPower (singleton)

Interface to the UPower daemon for battery and power statistics. NOTE: UPower daemon must be installed.

### Properties
- `devices: ObjectModel<UPowerDevice>` (readonly) — All connected UPower devices.
- `displayDevice: UPowerDevice` (readonly) — Aggregate display device. Not found in devices. May not be initialized (check ready).
- `onBattery: bool` (readonly) — If system is running on battery power.

## UPowerDevice (uncreatable)

### Properties
- `nativePath: string` (readonly) — OS-specific native path.
- `model: string` (readonly) — Model name.
- `type: UPowerDeviceType` (readonly)
- `state: UPowerDeviceState` (readonly)
- `percentage: real` (readonly) — Charge level as percentage (energy / energyCapacity).
- `energy: real` (readonly) — Current energy in watt-hours.
- `energyCapacity: real` (readonly) — Maximum energy capacity in watt-hours.
- `changeRate: real` (readonly) — Rate of energy change in watts (positive=charging, negative=discharging).
- `timeToEmpty: real` (readonly) — Estimated seconds until fully discharged. 0 if charging.
- `timeToFull: real` (readonly) — Estimated seconds until fully charged. 0 if discharging.
- `iconName: string` (readonly) — Icon name for current state, or empty.
- `isLaptopBattery: bool` (readonly) — Equivalent to type == Battery && powerSupply == true.
- `powerSupply: bool` (readonly) — If device can provide charge.
- `isPresent: bool` (readonly) — If power source is present. Only valid for Battery type.
- `ready: bool` (readonly) — If device statistics have been queried.
- `healthPercentage: real` (readonly) — Health as percentage of original.
- `healthSupported: bool` (readonly)

## UPowerDeviceState (enum)
- `Unknown`, `Charging`, `Discharging`, `Empty`, `FullyCharged`, `PendingCharge`, `PendingDischarge`

## UPowerDeviceType (enum)
Unknown, LinePower, Battery, Ups, Monitor, Mouse, Keyboard, Pda, Phone, Modem, OtherAudio, Headset, Speakers, Headphones, Video, Camera, BluetoothGeneric, Tablet, Pen, Touchpad, GamingInput, RemoteControl, Scanner, Printer, Network, Wearable, Other, GamingInput, Pen, Headphones, RemoteControl, Pda, Video, Printer, Network, Keyboard, Ups, Monitor, Camera, Tablet, Computer, MediaPlayer, Wearable, BluetoothGeneric, Unknown, Mouse, Scanner, Touchpad, Toy, Speakers, LinePower, Phone, Modem, Battery, Headset

## PowerProfiles (singleton)

Interface to the UPower power profiles daemon. NOTE: power-profiles-daemon must be installed separately.

### Properties
- `profile: PowerProfile` — Current power profile. Cannot be set to Performance unless hasPerformanceProfile is true.
- `hasPerformanceProfile: bool` (readonly) — If system has a performance profile.
- `degradationReason: PerformanceDegradationReason` (readonly) — Reason for degraded performance.
- `holds: list` (readonly) — Profile holds by other applications. Each has: `profile`, `applicationId`, `reason`. Only Performance and PowerSaver may be held. PowerSaver wins over Performance if multiple apps request.

## PowerProfile (enum)
- `PowerSaver` — Limit performance to save power.
- `Balanced` — Default, balance performance and power.
- `Performance` — Maximize performance at cost of power.

## PerformanceDegradationReason (enum)
- `None` — Not degraded.
- `HighTemperature` — Reduced due to high temps.
- `LapDetected` — Reduced due to lap detection.

---

# Quickshell.Services.SystemTray

`import Quickshell.Services.SystemTray`

## SystemTray (singleton)

Referencing this singleton starts tracking system tray contents.

### Properties
- `items: ObjectModel<SystemTrayItem>` (readonly) — All system tray icons.

## SystemTrayItem (uncreatable)

Roughly conforms to kde/freedesktop system tray spec.

### Properties
- `id: string` (readonly) — Unique name, such as app name.
- `title: string` (readonly) — Text describing the application.
- `status: Status` (readonly)
- `category: Category` (readonly)
- `icon: string` (readonly) — Icon source string, usable as Image source.
- `tooltipTitle: string` (readonly)
- `tooltipDescription: string` (readonly)
- `hasMenu: bool` (readonly) — If has associated menu accessible via display() or menu.
- `onlyMenu: bool` (readonly) — If only offers a menu, activation does nothing.
- `menu: unknown` (readonly) — Handle to associated menu. Display with QsMenuAnchor or QsMenuOpener.

### Functions
- `activate()` — Primary activation (usually left click).
- `secondaryActivate()` — Secondary activation (usually middle click).
- `scroll(delta, horizontal)` — Scroll action, e.g. volume change.
- `display(parentWindow, relativeX, relativeY)` — Display platform menu at location relative to parent window.

### Signals
- `ready()`

## Status (enum)
- `Passive` — Not important, can be considered idle. May want to hide.
- `Active` — Has important information, probably don't want to hide.
- `NeedsAttention` — Very important information (e.g. low battery).

## Category (enum)
- `ApplicationStatus` — Fallback for general applications.
- `Communications` — IM, email, etc.
- `Hardware` — Battery indicators, volume control.
- `SystemServices` — IMEs, disk indexing.

---

# Quickshell.Services.Greetd

`import Quickshell.Services.Greetd`

## Greetd (singleton)

Access to a running greetd instance for user authentication and session launch.

### Properties
- `available: bool` (readonly) — If greetd socket is available.
- `user: string` (readonly) — Currently authenticating user.
- `state: GreetdState` (readonly)

### Functions
- `createSession(user: string)` — Create session for given user.
- `respond(response: string)` — Respond to auth message. Only call when authMessage has responseRequired=true.
- `cancelSession()` — Cancel active greetd session.
- `launch(command: list)` — Launch session, exiting quickshell. state must be ReadyToLaunch.
- `launch(command: list, environment: list)` — Launch with environment.
- `launch(command: list, environment: list, quit: bool)` — Launch with environment and optional quit.

### Signals
- `error(error: string)` — Greetd encountered an error.
- `authFailure(message: string)` — Auth failed, session terminated.
- `authMessage(message: string, error: bool, responseRequired: bool, echoResponse: bool)` — Auth message from greetd.
- `readyToLaunch()` — Auth finished, greetd can now launch.
- `launched()` — Greetd acknowledged launch request, greeter should quit.

## GreetdState (enum)
- `Inactive`, `Authenticating`, `ReadyToLaunch`, `Launching`, `Launched`

---

# Quickshell.Services.Pam

`import Quickshell.Services.Pam`

## PamContext

Connection to PAM.

### Properties
- `active: bool` — If actively performing authentication. Setting behaves like start()/abort().
- `user: string` — User to authenticate as. If unset, current user. Cannot be set while active.
- `config: string` — PAM config to use (default "login"). Must name a file inside configDirectory. Cannot be set while active.
- `configDirectory: string` — PAM config directory (default "/etc/pam.d"). Resolved relative to current file. Ignored on FreeBSD. Cannot be set while active.
- `message: string` (readonly) — Last message from PAM.
- `messageIsError: bool` (readonly) — If last message should be shown as error.
- `responseRequired: bool` (readonly) — If PAM currently wants a response.
- `responseVisible: bool` (readonly) — If user's response should be visible. Only valid when responseRequired is true.

### Functions
- `start(): bool` — Start auth session. Returns if started successfully.
- `respond(response)` — Respond to PAM. Cannot call unless responseRequired is true.
- `abort()` — Abort running auth session.

### Signals
- `pamMessage()` — Emitted when PAM sends new message, after change signals for message, messageIsError, responseRequired.
- `completed(result: PamResult)` — Auth completed.
- `error(error: PamError)` — PAM failed to perform auth normally. A completed(PamResult.Error) follows.

## PamResult (enum)
- `Success`, `Failed`, `Error`, `MaxTries`

## PamError (enum)
- `StartFailed` — Failed to start PAM session.
- `TryAuthFailed` — Failed to try authenticating (not the same as user failing).
- `InternalError` — Error inside quickshell's PAM interface.

---

# Quickshell.Services.Polkit

`import Quickshell.Services.Polkit`

## PolkitAgent

### Properties
- `path: string` — D-Bus path for agent listener (default /org/quickshell/Polkit).
- `isRegistered: bool` (readonly) — If agent registered successfully and in use.
- `isActive: bool` (readonly) — If ongoing auth request. If true, flow properties are populated.
- `flow: AuthFlow` (readonly) — Current auth state if request active. Null when no request.

## AuthFlow (uncreatable)

### Properties
- `actionId: string` (readonly) — Machine-readable action ID being authorized.
- `message: string` (readonly) — Main message to present.
- `inputPrompt: string` (readonly) — Prompt for required input.
- `iconName: string` (readonly) — Icon name per FreeDesktop spec.
- `cookie: string` (readonly) — Internal identifier for auth request.
- `supplementaryMessage: string` (readonly) — Additional message (errors or supplementary info).
- `supplementaryIsError: bool` (readonly) — If supplementary message is an error.
- `isResponseRequired: bool` (readonly) — If user response is required (e.g. password).
- `responseVisible: bool` (readonly) — If user's response should be visible (false for passwords).
- `isCompleted: bool` (readonly) — If auth request completed.
- `isSuccessful: bool` (readonly) — If auth request successful.
- `isCancelled: bool` (readonly) — If auth request cancelled.
- `failed: bool` (readonly) — If auth attempt failed at least once.
- `identities: list` (readonly) — Identities that may be used to authenticate (users or groups).
- `selectedIdentity: unknown` — Identity to use. Changing aborts ongoing conversation and starts new one.

### Functions
- `submit(value)` — Submit response (typically password).
- `cancelAuthenticationRequest()` — Cancel ongoing auth request from user side.
