# Control Panel — Design Discussion

Reference document for building the control panel. Captures decisions and technical direction agreed on before implementation.

---

## Scope (Desktop, not laptop)

Brightness and battery controls are excluded — desktop machine. DND toggle excluded — the notification system is already quiet by design (7s peek, no persistent pill).

**What the control panel will contain:**

1. **Audio** — output volume/mute, input (mic) volume/mute
2. **Network** — local IP display, connectivity status, toggle on/off
3. **Session** — lock, logout, reboot, shutdown

---

## Layout

```
┌─────────────────────────────────────────┐
│  PanelNavBar                            │
├──────────────────┬──────────────────────┤
│  Volume          │  Network             │
├──────────────────┴──────────────────────┤
│                                         │
│  System graphs (CPU / MEM)              │
│  [ not implemented in v1 — space        │
│    reserved for future pretty graphs ]  │
│                                         │
├─────────────────────────────────────────┤
│                    [ Session buttons ]  │
└─────────────────────────────────────────┘
```

Volume and network sit in a two-column `RowLayout` at the top. System graphs fill the middle (placeholder in v1). Session buttons are bottom-right aligned.

---

## Audio

### Implementation: `Quickshell.Services.Pipewire` (native)

Quickshell has first-class PipeWire bindings — no subprocess, no polling.

Key types:
- `PwNode` — an audio node (sink, source, stream). Exposes `audio.volume` (read/write `real`) and `audio.muted` (read/write `bool`)
- `PipeWire` singleton — full node graph; enumerate sinks/sources by node type
- `PwNodeLinkGroup` — for routing between nodes

**Reactive:** bindings update in real time as PipeWire state changes. Same pattern as MPRIS — no subprocess needed.

**Caveat:** the PipeWire node graph is low-level. It does not expose a clean "default sink" abstraction — you identify it by filtering node types and cross-referencing WirePlumber's default sink designation. Requires graph traversal logic.

### Volume UI

Two buttons side by side in the left column — one for the input (source / mic), one for the output (sink / speaker). Both behave identically:

**Label priority (highest wins):**
1. **Muted** → `"MUTED"` (always shown while muted, overrides everything)
2. **Scrolling** → volume percentage e.g. `"72%"` — shown during and briefly after a scroll event
3. **Idle** → device name, truncated if too long

**Interactions:**
- **Scroll up/down** — adjust volume ±5%. Triggers a local `_showVol` bool for 1.5s via `Timer`; resets on each new scroll tick (rapid scrolls extend the window). Label switches to percentage during this window.
- **Click** — toggle mute. Label immediately switches to `"MUTED"` / back to device name (or percentage if still in peek window).
- **Right-click** — launch `pavucontrol-qt` via short-lived `Process`.

**Label state machine:**
```
muted:         [ MUTED ]              ← highest priority, always wins
scroll peek:   [ 72%   ]              ← _showVol true, timer running
idle:          [ Starship Intrepid… ] ← truncated device name
```

Same pattern as the MPRIS panel volume button, extended with device name and the scroll-peek timer.

### Data layer

New file: `root-processes/AudioProcess.qml` (or `PipeWireProcess.qml`)

Will own:
- Default sink node reference + volume/mute
- Default source (mic) node reference + mute
- Sink list (for output switcher)

### What Qt's audio APIs (`QtMultimedia`) give you

`QMediaDevices`, `QAudioDevice` — for playback/capture within your own app only. Not useful for system-level volume control. Not the approach here.

### subprocess alternative (rejected)

`pactl` / `wpctl` work but are not reactive — requires polling Timer or parsing `pactl subscribe`. PipeWire native bindings are clearly superior.

---

## Network

### What the user actually needs

Two real-world use cases:
1. **LAN gaming** — need local IP to share with others on the network
2. **No internet** — need to see that connection is down and attempt to fix it

Everything else (VPN, wifi picker, advanced config) is a one-time task handled by `nm-connection-editor` as an external tool.

### Network UI

A single display element in the right column:

```
[ 192.168.1.42 ]   ← textSuccess color when connected
[ No connection ]  ← textCritical color when disconnected
```

**Interactions:**
- **Click** — toggle networking on/off. "Try to reconnect" when down, quick disable when up.
- **Right-click** — launch `nm-connection-editor` via Process for any advanced config.

### Implementation: subprocess (not D-Bus)

The original plan was D-Bus for reactivity. Reconsidered — for a status display checked occasionally, **subprocess polling is sufficient and far simpler**. The full NetworkManager D-Bus API (nested object paths, graph traversal) is not justified for showing an IP address.

**Data layer:** `NetworkProcess.qml` in `root-processes/`
- `ip -4 route get 1.1.1.1` — returns the local IP of the outbound interface. Fails/empty when disconnected. Fast, no NM dependency.
- `nmcli networking on` / `nmcli networking off` — toggle via short-lived Process
- Poll every 30s via `Timer` + immediate re-poll after toggle
- Exposes: `property string localIp` (empty = disconnected), `property bool connected`

---

## Session

No dedicated process needed — short-lived `Process` instances inlined in the panel.

**Button row (right-aligned, normal state):**
```
[ Reconfigure ] [ Exit ] [ Reboot ] [ Shutdown ]
```

| Button | Command | Confirm? |
|---|---|---|
| Reconfigure | `labwc --reconfigure` | No — low stakes, fires immediately |
| Exit | `labwc --exit` | Yes |
| Reboot | `systemctl reboot` | Yes |
| Shutdown | `systemctl poweroff` | Yes |

**Confirm state (replaces button row in-place):**
```
[ Shutting down in 3s... ]                [ Cancel ]
```

- Row swaps immediately on click — no modal, no separate panel
- Countdown is live realtime decrement: `"Exiting in 3s..."` → `"2s..."` → `"1s..."`
- Full sentence label: `"Exiting in Xs..."` / `"Rebooting in Xs..."` / `"Shutting down in Xs..."`
- After 3s, command fires and panel closes
- Cancel restores the button row, aborts countdown
- 3s hardcoded for now
- `_pendingAction` string (`""` | `"exit"` | `"reboot"` | `"shutdown"`) drives label text and which command fires
- Countdown via `Timer { interval: 100 }` + `Date.now()` delta (same drift-free pattern as TimerProcess)

---

## What's NOT in the control panel

- **DND** — notification system is already quiet; not needed
- **Brightness** — desktop, no backlight
- **Battery** — desktop
- **Wifi network picker** — systray (nm-applet) already covers this

---

## Panel identity

Keybind: TBD (W-7 is a natural next slot)

No pill planned — session/audio/network are intentional actions, not ambient state that needs a transient indicator.
