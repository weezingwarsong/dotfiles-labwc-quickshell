# LocalTimer — Design Discussion

Two pieces: `LocalTimerProcess` (root process, tracks all active timers) and `LocalTimer` (reusable element, drop-in visual for any module).

---

## Goals

- **Drop-in timer**: any module can instantiate a `LocalTimer` without owning any timer logic
- **Centralized tracking**: the process holds all active timers; callers can query status by ID from anywhere
- **No persistent state**: timers are ephemeral — when they complete, they are removed from the process

---

## LocalTimerProcess

Lives in `root-processes/`. Instantiated once in `shell.qml`, injected into any module that needs it.

### Internal model

A JS object map: `_timers: { [id]: { durationMs, startedAt, pausedRemaining, status } }`

`status` is one of three values:
- `"started"` — timer is running
- `"paused"` — timer is paused; `pausedRemaining` holds the ms left at the moment of pause
- `"completed"` — timer has fired; entry is removed immediately after the signal

### API

| Function | Description |
|---|---|
| `register(id, durationMs)` | Creates a new timer entry. If `id` already exists, restarts the timer with the new `durationMs` (resets `startedAt`, clears `pausedRemaining`). |
| `kill(id)` | Removes entry immediately. No `timerCompleted` signal is emitted. |
| `pause(id)` | Saves `remaining(id)` into `pausedRemaining`, sets `status = "paused"`. Tick loop skips paused entries — they do not fire `timerCompleted`. No-op if not found or already paused. |
| `resume(id)` | Resets `startedAt = Date.now() - (durationMs - pausedRemaining)` so elapsed computation resumes from the frozen point. Clears `pausedRemaining`, sets `status = "started"`. No-op if not found or not paused. |
| `status(id)` | Returns `"started"` \| `"paused"` \| `"completed"` \| `null` (null = not found). |
| `elapsed(id)` | Returns ms elapsed. For paused entries: `durationMs - pausedRemaining`. |
| `remaining(id)` | Returns ms remaining, clamped to 0. For paused entries: returns `pausedRemaining` (frozen). This means visual bars naturally hold their position without any special-case logic. |

### Signals

| Signal | When |
|---|---|
| `timerCompleted(string id)` | Fires when `remaining(id)` reaches 0. Entry is removed from the map immediately after. |

### Tick loop

A single `Timer { interval: 50; repeat: true }` drives all registered timers. Each tick walks `_timers`, skips paused entries, computes remaining for running entries, fires `timerCompleted` and removes entries that have elapsed. The tick loop stops automatically when `_timers` is empty and restarts on the next `register()` call.

---

## LocalTimer (reusable element)

Lives in `module-reusable-elements/`. Accepts a `localTimerProcess` property (injected by the caller's parent chain).

### Properties

| Property | Type | Description |
|---|---|---|
| `timerId` | `string` | Caller-provided unique key. Required. |
| `duration` | `int` | Duration in milliseconds. |
| `variant` | `int` | 1–5. Controls visual output. |
| `color` | `color` | Bar fill color. Defaults to `Style.accentColor`. Two intended semantic values: `Style.accentColor` and `Style.criticalColor`. |
| `localTimerProcess` | `var` | Injected process reference. |

### Lifecycle

- `Component.onCompleted` → calls `localTimerProcess.register(timerId, duration)`
- `Component.onDestruction` → **does not auto-kill**. The process-side timer keeps running independently of the element's lifetime. If the element is destroyed and the timer should stop, the caller must call `kill()` explicitly before destruction.
- Connects to `localTimerProcess.timerCompleted(id)` → emits own `completed()` signal when `id === timerId`

### Functions

| Function | Description |
|---|---|
| `kill()` | Calls `localTimerProcess.kill(timerId)`. Stops and removes the timer with no `completed` signal. |
| `pause()` | Calls `localTimerProcess.pause(timerId)`. Visual bar freezes at its current fill position automatically — `remaining()` returns the frozen value while paused. |
| `resume()` | Calls `localTimerProcess.resume(timerId)`. Timer and visual bar resume from the frozen position. |

### Signal

`signal completed()` — fires once when the timer reaches zero. Caller can connect to this to trigger their own logic.

---

## Variants

All bar variants use `localTimerProcess.elapsed(timerId)` and `duration` to compute a fill ratio `[0.0, 1.0]`.

### Variant 1 — Process only

No visual output. `Item {}` with zero implicit size. Useful when the caller only needs the `completed()` signal or wants to query `status()`/`remaining()` themselves.

### Variant 2 — Horizontal elapsed bar

```
┌─────────────────────────────────────┐  ← RowLayout, fillWidth, implicitHeight: 2
│████████████████░░░░░░░░░░░░░░░░░░░░│  ← filled = elapsed / duration
└─────────────────────────────────────┘
```

- `RowLayout`, `Layout.fillWidth: true`, `implicitHeight: 2`
- One `Rectangle`: `height: 2`, `width: parent.width * fillRatio`
- No padding, no border, no radius
- Anchored to the left edge; grows rightward as time passes
- `Behavior on width { SmoothedAnimation { } }` for continuous easing

### Variant 3 — Vertical elapsed bar

```
┌──┐  ← ColumnLayout, implicitWidth: 2, fillHeight
│  │  ← unfilled (remaining)
│██│  ← filled = elapsed / duration
│██│
└──┘
```

- `ColumnLayout`, `Layout.fillHeight: true`, `implicitWidth: 2`
- One `Rectangle`: `width: 2`, `height: parent.height * fillRatio`
- Anchored to the bottom edge; grows upward as time passes
- `Behavior on height { SmoothedAnimation { } }`

### Variant 4 — Horizontal remaining bar

Mirror of Variant 2, but fill ratio = `remaining / duration` (bar shrinks as time passes).

```
┌─────────────────────────────────────┐
│████████████████████████░░░░░░░░░░░░│  ← filled = remaining / duration
└─────────────────────────────────────┘
```

- Same layout as Variant 2; bar collapses from right to left
- `Behavior on width { SmoothedAnimation { } }`

### Variant 5 — Vertical remaining bar

Mirror of Variant 3, fill ratio = `remaining / duration` (bar shrinks as time passes).

```
┌──┐
│██│  ← filled = remaining / duration
│██│
│  │  ← unfilled (elapsed)
└──┘
```

- Same layout as Variant 3; bar collapses from top to bottom
- `Behavior on height { SmoothedAnimation { } }`

---

## Resolved decisions

| Question | Decision |
|---|---|
| Bar color | `Style.accentColor` default; caller overrides via `color` property. Two semantic values expected: `accentColor` and `criticalColor`. |
| Animation | Smooth — `Behavior on width/height { SmoothedAnimation { } }` on all bar variants. |
| Duplicate `timerId` | Restart: resets `startedAt`, clears `pausedRemaining`, updates `durationMs`. No warning. |
| Duration unit | Milliseconds throughout. |
| Element destruction | Does **not** auto-kill. Timer outlives the element. Caller must call `kill()` explicitly if early termination is needed. |
| Pause/resume | `pause(id)` freezes `remaining` at current value; tick loop skips the entry. `resume(id)` restores `startedAt` so elapsed computation picks up from the frozen point. Visual bars hold their fill position during pause with no special-case logic — `remaining()` returns the frozen value naturally. First callers: NotificationToast (hover) and CalendarPanel timer (rework, future). |
