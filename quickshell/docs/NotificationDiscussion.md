# Notification System — Discussion

## Background

The first iteration of the notification system used the **pill** as the notification surface. When a notification arrived, the pill would briefly show it — a "news flash" pattern where the pill content switched to display the notification summary.

This worked at the time because the toast system did not yet exist. It has two fundamental problems now that the shell has matured:

1. **The pill is passive.** The pill stack is 100% non-interactive by design — no user input, no click targets, no actions. Notifications in the freedesktop spec carry action buttons (e.g. "Reply", "Dismiss", "Open"). The pill cannot surface these. The previous workaround was to require the user to open the Notification panel to interact with any notification — an extra step that breaks the expected UX flow.

2. **The pill is the wrong surface.** A news-flash notification is a transient overlay that appears, demands brief attention, and disappears. That is exactly what the toast system was built for. The pill is meant for persistent, ambient status — the current time, active window, media track. Interrupting that with a notification flash is a category mismatch.

3. **SysTray has no home yet.** The system tray (`SysTrayBar`) currently lives inside the Notification panel as a temporary placeholder. It does not belong there conceptually — it ended up there because there was no better surface at the time. Its final resting place is undecided and out of scope for this discussion, but the constraint must be kept in mind: any rework of the Notification panel must not strand the systray.

## Direction

The notification system needs to be rethought from the surface up before the panel can be reconsidered. Work proceeds in two phases:

---

### Toast and Bank — Core Functions and Relationship

These two surfaces are **fully independent**. Neither knows nor cares what the other is doing. They share a data source (`trackedNotifications`) but have no direct coupling.

**Toast — serves the user in the moment.**
Its only concern is its relationship with the user right now. It shows whatever the app requested. If the user finds it in the way, it dismisses. If the user wants more time to read, it stays open. It does not know whether the bank exists, does not write to the bank, and does not read from it. When the toast hides, it is done.

**Bank — stores everything for the session.**
Its only concern is that the user can find any notification they need, at any point in the session. It does not know what the toast showed, how long it was visible, or whether the user interacted with it. It simply tracks every notification that arrived and holds it until the user explicitly removes it. If a notification is in the bank, the user can read it, act on its actions, or delete it.

**How they interact — through the data layer, not each other:**
- A new notification arrives → Quickshell adds it to `trackedNotifications` → toast shows it → bank holds it. Both happen independently from the same event.
- User right-clicks Row1 of the toast, or presses the dismiss keybind → toast hides. Bank is untouched. The notification is still there.
- User clicks "Skip bank & dismiss" (dustbin button) on the toast → `notif.dismiss()` is called → notification is removed from `trackedNotifications` → bank never shows it (or loses it immediately if it was already there). Toast hides.
- User dismisses a notification in the bank → `notif.dismiss()` called → gone from `trackedNotifications`. Toast is unaffected — if it happened to be showing that notification, it now holds a stale reference (handle gracefully).

**Transient notifications** are the one case where the bank opts out by design — respecting the `transient` hint means the notification is shown in the toast but never stored in `trackedNotifications`. The bank never sees it. This is explicit spec compliance, not a special case of the toast/bank relationship.

**The dustbin button on the toast** is the user's escape hatch: "I saw this in the toast and I don't want it in history." It gives the user bank-level control without having to open the bank. It is the only path where the toast has any effect on bank state — and even then, the toast isn't talking to the bank; it's calling `notif.dismiss()` on the shared data layer.

---

### Phase 1 — Notification Toast

Design and build a dedicated toast surface for incoming notifications. Only after the toast is defined does it become clear what the panel needs to do.

#### 1.1 — Look and Behaviour

##### freedesktop Desktop Notifications Spec — What a notification carries

Before designing behaviour, we need to know what data a notification can carry. The spec defines the D-Bus interface that `notify-send`, apps, and system services all use. Our `NotificationServer` implements this same interface.

**Core fields every notification has:**

| Field | Type | Notes |
|---|---|---|
| `app_name` | string | Human-readable sender name (e.g. "Firefox", "Slack") |
| `app_icon` | string | Icon name (freedesktop icon theme) or absolute file path |
| `summary` | string | One-line title. Always present. |
| `body` | string | Detail text. Optional. May contain basic HTML markup (`<b>`, `<i>`, `<u>`, `<a>`). Support is optional per spec. |
| `actions` | string[] | Flat list of alternating key/label pairs: `["default", "Open", "reply", "Reply", ...]`. `"default"` is the primary click action. |
| `expire_timeout` | int (ms) | `-1` = daemon decides; `0` = never auto-dismiss; positive = exact ms |
| `replaces_id` | uint | If non-zero, this notification replaces an existing one with that ID |

**Hints — optional metadata sent alongside:**

| Hint | Values | Meaning |
|---|---|---|
| `urgency` | `0` Low, `1` Normal, `2` Critical | Critical notifications **must not** auto-dismiss per spec |
| `category` | `email.arrived`, `im.received`, `transfer.complete`, `device.added`, etc. | Machine-readable notification type |
| `desktop-entry` | string | `.desktop` filename of the sending app — useful for icon fallback |
| `image-data` | raw ARGB | Inline image (e.g. album art, contact avatar) — takes priority over `app_icon` |
| `image-path` | string | File path to image — second priority after `image-data` |
| `transient` | bool | Hint: don't persist in history, just flash and go |
| `resident` | bool | Hint: don't auto-dismiss even if timeout elapses — stay until user acts |
| `sound-name` | string | freedesktop sound theme cue |
| `action-icons` | bool | If true, action keys are icon names rather than display labels |

**Urgency is the most important hint for behaviour:**
- `Low` (0) — background info. Can be subtle, smaller, shorter timeout.
- `Normal` (1) — default. Standard display duration.
- `Critical` (2) — must not auto-dismiss. Must stay until the user explicitly acts or closes it. Errors, battery critical, calls.

**Close reasons (emitted on `NotificationClosed` signal):**
- `1` = expired (timeout elapsed)
- `2` = dismissed by user
- `3` = closed by the sending application
- `4` = undefined

**What this means for design:**
- Every toast has at minimum: an icon, a summary, and an urgency.
- Body and actions are optional but common.
- Image hints (inline avatar, album art) are common from messaging apps and media players.
- The daemon is responsible for deciding timeout when `expire_timeout = -1`.
- Critical notifications break the normal auto-dismiss flow entirely.

##### Category hint — what it is

The `category` hint is a machine-readable dot-notation string that classifies the notification type. Apps send it optionally. It is not visible to the user — it tells the daemon what kind of event this is so it can respond appropriately (choose a fallback icon, apply different rules, group in history, etc.).

Common categories from the spec:

| Category | Meaning |
|---|---|
| `email` / `email.arrived` | New email |
| `im` / `im.received` | Instant message |
| `call` | Incoming call (common extension, not in original spec) |
| `transfer` / `transfer.complete` / `transfer.error` | File transfers, downloads |
| `network.connected` / `network.disconnected` | Network state changes |
| `device` / `device.added` / `device.removed` | Hardware events |
| `presence.online` / `presence.offline` | Contact presence |

For our purposes, `category` is the basis for the **fallback glyph** shown in the app icon slot when no `app_icon` is provided. Each category maps to a Nerd Font glyph. If no category is provided either, a generic bell glyph is used.

---

##### Guiding Principle

> **The toast fires only when an app requests it via D-Bus.** The shell never re-surfaces a notification on its own initiative. If the user missed a notification, the Bank is where they go to find it. This is a deliberate alignment with the freedesktop spec, which defines the notification daemon as a passive receiver of app-initiated events — not an autonomous scheduler.

Consequences enforced by this principle:
- No counter on the toast. The bank exists precisely to show what was missed.
- No snooze. Snooze would require the shell to re-trigger a toast for a notification the app did not re-send — a violation.
- No shell-side "remind me later" of any kind in Phase 1 or Phase 2.

##### Behaviour

- A notification toast **slides in from the screen edge** side of the ToastWindow when a notification arrives. Currently the ToastWindow is right-edge, bottom-justified. This will be user-configurable in the future.
- **Timeout** respects the caller's `expire_timeout` first. If the caller sends `-1` (no preference), we default to **5 seconds** (user-adjustable in Settings).
- **Critical urgency** (`urgency = 2`) notifications never auto-dismiss **unless the app explicitly provides a timeout** (`expireTimeout > 0`). In that case the app's timeout wins — start the timer as normal. If `expireTimeout` is `-1` (no preference) or `0` (never), the Critical rule holds and no timer starts.
- **Only one toast is shown at a time.** When a new notification arrives while one is already showing, it **replaces the current toast immediately** with no counter or visual indicator of what was displaced. The displaced notification remains in the Bank.
- **Transient notifications** (`transient = true`) use the default 5s timeout regardless of the caller's `expire_timeout`, and are **not stored in the notification bank** (history panel). They flash and disappear.
- **Left-click on the content area** (Col1 icon, Col2 text, Col3 thumbnail) fires the `default` action and hides the toast — unless `resident = true`, in which case the toast stays and the auto-dismiss timer is killed and not restarted. The app owns the lifecycle.
- **Left-click on buttons** (caller action row, Skip bank & dismiss) — handled by each button's own handler. Do not interact with the content area tap.
- **Right-click on Row1** (the main content row — covers Col1 through Col4) — hides toast, keeps in bank.
- **Hover** — pauses the auto-dismiss timer via `LocalTimerProcess.pause(timerId)`. The LocalTimer visual bar freezes at its current fill position. On hover exit, `LocalTimerProcess.resume(timerId)` restarts from where it left off. Critical notifications have no timer to pause.
- **Keybind** — hides toast only, keep in bank. Handled via FIFO (see OQ-L).

##### Appearance

- The toast is a **rectangle container** styled with the existing panel chrome (radius, border).
- **Urgency drives the color scheme** and should be immediately distinguishable at a glance. MD3 color roles apply:
  - `Low` — subdued, surface-level treatment. Muted text.
  - `Normal` — standard panel colors.
  - `Critical` — uses the critical/error color role (`criticalBgColor`, `textCritical`). Hard to miss.
- Layout is **uniform across all categories** — category only affects the fallback icon glyph, not the structure.

##### Layout (left → right, top → bottom)

```
Option A — timer bar at bottom (preferred)
┌────────────────────────────────────────────────────────┐
│ [icon]  Summary (scrolling)            [thumbnail?] [X] │
│         Body — one row, scrolling                       │
│ ────────────────────────────────────────────────────── │
│ [ action 1 ]  [ action 2 ]  [ action 3 ]  [ action 4 ] │
│████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│  ← LocalTimer
└────────────────────────────────────────────────────────┘

Option B — timer bar as right-edge vertical strip (alternative)
┌──────────────────────────────────────────────────────┬──┐
│ [icon]  Summary (scrolling)             [thumbnail?] │  │
│         Body — one row, scrolling       [X]          │██│
│ ──────────────────────────────────────────────────── │██│
│ [ action 1 ]  [ action 2 ]  [ action 3 ]             │██│
└──────────────────────────────────────────────────────┴──┘
                                                         ↑ 2px LocalTimer
```
Position is **TBD** — both options use the same LocalTimer variant (4 or 5 respectively). Timer bar is not shown for Critical notifications (no timer starts).

- **App icon** — top-left. Shows `app_icon` when available. Falls back to category glyph. Falls back to generic bell.
- **Summary** — to the right of the icon. Larger text (`fontSizeHeading`). Scrolls when clipped.
- **Body** — below the summary, same column. Normal text size (`fontSizeBody`). Single row, scrolls when clipped. Text color varies by urgency.
- **Thumbnail** — right side, fixed size. Shows the notification image when the caller provides `image-data` (inline raw image, e.g. contact avatar, album art). Collapses to zero width when absent. `image-path` (file path) is **not** shown here — only inline `image-data`. `app_icon` is never shown in the thumbnail slot. Sits left of the service action column.
- **Service action column** — far right, vertical. One fixed action provided by our notification service, always present regardless of caller:
  - **Skip bank & dismiss** — dismisses the toast and does not store it in the notification bank (history). User-initiated only — the shell never calls this on its own.
- **Caller action row** — bottom, horizontal. Action buttons from the caller's `actions` field, up to **4 buttons total**. The `default` action **is shown as a button** here as well — intentional redundancy, since left-click on Col1–Col3 is a shortcut and the button makes it explicit. Each button owns its own click handler.

##### Open Questions (deferred to section 1.2)

1. ~~**Counter format**~~ — **Scrapped.** Counter removed per guiding principle. Bank handles "what you missed."
2. ~~**replaces_id**~~ — **Resolved** (see OQ-J). Quickshell handles in C++; toast never re-triggers.
3. **Dismiss keybind** — which key? Where configured in Settings? Does it hide-only or also dismiss from bank (same as right-click)?
4. ~~**Snooze + Critical**~~ — **Scrapped.** Snooze removed per guiding principle.
5. ~~**Snooze + transient**~~ — **Scrapped.** Snooze removed per guiding principle.
6. **Transient bank-skip mechanism** — "not stored in bank" could mean: (a) never set `notif.tracked = true` for transient, or (b) always track but call `notif.dismiss()` when toast hides. Which path does `NotificationServer.qml` use?

#### 1.2 — Technical Specification

##### Part 1 — Layout Stack

```
Rectangle (toast root)
│   urgency-colored bg + border + radius
│   NumberAnimation on x (slide-in from screen edge on show)
│   HoverHandler (onHoveredChanged: pause/resume auto-dismiss timer — deferred)
│
└─ CR (ColumnLayout, spacing: 8, anchors.fill: parent, padding: panelCardHpadding/Vpadding)
   │
   ├─ RL (main content row — Row1, spacing: 8)
   │  │   TapHandler (Right → hide toast, keep in bank)
   │  │     acceptedButtons: Qt.RightButton
   │  │     covers entire Row1 (Col1 + Col2 + Col3 + Col4)
   │  │
   │  ├─ Col1: Icon slot
   │  │    Item (preferredWidth: ~40px, alignment: AlignTop, content centered)
   │  │      Image (app_icon — resolved from icon theme name or file path)
   │  │        OR
   │  │      Text  (category glyph — Nerd Font, mapped from category hint)
   │  │        OR
   │  │      Text  (generic bell glyph — final fallback)
   │  │      TapHandler (Left → invoke default action + hide toast)
   │  │        acceptedButtons: Qt.LeftButton
   │  │
   │  ├─ Col2: Text section (fillWidth, alignment: AlignTop)
   │  │    CR (ColumnLayout, spacing: 4)
   │  │      ScrollingText  (summary — fontSizeHeading, fillWidth)
   │  │      ScrollingText  (body — fontSizeBody, fillWidth, single row, color by urgency)
   │  │    TapHandler (Left → invoke default action + hide toast)
   │  │      acceptedButtons: Qt.LeftButton
   │  │
   │  ├─ Col3: Thumbnail slot
   │  │    Item (preferredWidth: thumbSize OR 0, clip: true, Behavior on preferredWidth)
   │  │      Image (source: notif.image, fillMode: PreserveAspectCrop)
   │  │    TapHandler (Left → invoke default action + hide toast)
   │  │      acceptedButtons: Qt.LeftButton
   │  │      visible only when Col3 width > 0
   │  │
   │  └─ Col4: Service actions (alignment: AlignTop)
   │       Item (fixed width)
   │         IconButton  (Skip bank & dismiss — owns its own click handler)
   │
   ├─ PanelDivider (visible: caller actions present)
   │
   ├─ RL (caller action row, spacing: 4, visible: actions.length > 0)
   │    Repeater (model: up to 4 actions — including "default")
   │      PanelButton (fillWidth, label: action.text, onClicked: action.invoke() + hide toast)
   │      — each button owns its own click handler, no propagation to Row1
   │
   └─ LocalTimer (Variant 4 — horizontal remaining bar, position Option A)
        Layout.fillWidth: true, implicitHeight: 2
        timerId: "notif-toast"   ← single toast at a time, fixed ID is fine
        duration: resolvedDurationMs
        color: Style.accentColor  (no Critical case — timer never registered for Critical)
        visible: _timerActive     ← false for Critical and when timer not running
        — OR —
        LocalTimer (Variant 5 — vertical remaining bar, position Option B)
        implicitWidth: 2, Layout.fillHeight: true, anchored outside CR padding
        [Position TBD — see layout diagram above]
```

**Notes on specific items:**

- **"Hide toast" vs "dismiss from bank"** — two distinct operations. Hiding collapses the UI only; the notification stays in `trackedNotifications`. Dismissing from bank calls `notif.dismiss()`, removing it from `trackedNotifications`. Right-click on Row1 = hide toast only. "Skip bank & dismiss" button = `notif.dismiss()` + hide toast.
- **No propagation problem** — left-click TapHandlers are placed only on Col1, Col2, Col3 (content area). Col4's button and the caller action row own their own handlers. Their click areas do not overlap with the content area TapHandlers, so double-fire cannot occur. Right-click TapHandler sits on Row1 as a whole — right-clicking a button is an uncommon gesture and triggers dismiss, which is acceptable.
- **Auto-dismiss Timer** — `interval` resolves as: `notif.expireTimeout > 0 ? notif.expireTimeout : Prefs.notificationTimeout`. For Critical urgency: timer never starts.
- **Caller action row** — includes the `default` action as a button (intentional redundancy with left-click). Actions filtered to max 4 total.
- **Slide animation** — `x` or `y` offset animates from off-screen to resting position on show. Direction depends on ToastWindow anchor edge (currently right → slides from x = width to x = 0).
- **Urgency background colors:**
  - `Low` → `surfaceLowColor`
  - `Normal` → `surfaceMidColor`
  - `Critical` → `criticalBgColor` (or MD3 error role with alpha)

---

##### Part 2 — Technical Requirements Per Element

**App icon (Col1)**
- Source: `notif.appIcon` — a freedesktop icon theme name (e.g. `"firefox"`) or absolute file path.
- Qt has no built-in QML component for resolving freedesktop icon names to images. Options: `Image { source: "image://icon/" + iconName }` via a custom Quickshell image provider, or fallback to a `Process` calling a lookup tool.
- The existing `NotificationPanel` does not display `appIcon` at all — this is new work.
- `[OQ-A]` **Does Quickshell provide an image provider for freedesktop icon names?** If not, icon display may need to fall back to category glyph always, and `appIcon` support is deferred.

**Category glyph (Col1 fallback)**
- Source: `notif.hints["category"]` — a dot-notation string, e.g. `"email.arrived"`.
- Implementation: a JS mapping object from category prefix to Nerd Font codepoint, similar to `WMO_ICONS` in `weather-fetch`. We build this ourselves.
- Fallback chain: `appIcon` → category glyph → generic bell (``).
- Already have `Style.fontNerd` for rendering.

**Summary (Col2)**
- Source: `notif.summary` — always present per spec.
- Component: `ScrollingText` — already exists in `module-reusable-elements/`.

**Body (Col2)**
- Source: `notif.body` — optional, may be empty string.
- Component: `ScrollingText` with `wrapMode: Text.NoWrap` — single row.
- Body may contain HTML markup (`<b>`, `<i>`, `<a>`). `ScrollingText` uses a plain `Text` element. If we want to render markup, we'd need `Text { textFormat: Text.RichText }` which doesn't scroll. `[OQ-C]` **Do we render body markup or strip it?** Safest default: strip (plain text only). Revisit in 1.3.

**Thumbnail (Col3)**
- Source: `notif.image` — Quickshell resolves both `image-data` and `image-path` hints to a URL usable as `Image.source`. Confirmed by existing `NotificationPanel` usage (`_card.modelData.image`).
- Section 1.1 specifies thumbnail for `image-data` only (not `image-path`). `[OQ-B]` **Does Quickshell expose a flag to distinguish `image-data` from `image-path`?** If not, we show the thumbnail for any non-empty `notif.image` and document the deviation from spec.
- Collapse: `Layout.preferredWidth` animates between `thumbSize` and `0` via `Behavior`.

**Service actions — Skip bank & dismiss (Col4)**
- Calls `notif.dismiss()` which removes from `_server.trackedNotifications`. Then hides toast.
- `notif.dismiss()` is already used in `NotificationPanel`. No new API needed.

**Caller action row (bottom)**
- Source: `notif.actions` — array of objects with `.identifier` and `.text`. The `default` identifier is included as a visible button (unlike in `NotificationPanel` which filters it out).
- `action.invoke()` method available (used in `NotificationPanel`). After invoke, hide toast.
- Cap at 4 total. If more than 4, truncate. `[OQ-E]` **Which 4 to show when > 4 actions?** Options: first 4, or `default` + first 3 non-default. Assume first 4 for now.

**Urgency colors**
- `Critical` background: existing panel uses `Qt.rgba(Style.mat3Error.r, .g, .b, 0.15)`. Toast needs a stronger treatment.
- `[OQ-F]` **Does `criticalBgColor` exist in Style?** Check `Style.qml` — if not, define it. MD3 error container role applies.

**Auto-dismiss Timer**

LocalTimerProcess replaces a standalone Qt `Timer`. It is both the authoritative dismiss clock and the data source for the LocalTimer visual bar — one registration drives both.

- **Duration resolution:** `notif.expireTimeout > 0 ? notif.expireTimeout * 1000 : Prefs.notificationTimeout`. Sentinels: `-1` → `Prefs.notificationTimeout`; `0` → never auto-dismiss (treat same as Critical).
- **On toast show:** `localTimerProcess.register("notif-toast", resolvedDurationMs)`. Connect `localTimer.completed` → hide toast. Fixed ID `"notif-toast"` is safe since only one toast is visible at a time.
- **`expireTimeout = 0`:** do not call `register`. Timer bar is not shown (`_timerActive = false`).
- **Critical urgency + `expireTimeout < 0`:** do not call `register`. App did not request a timeout; spec compliance wins.
- **Critical urgency + `expireTimeout > 0`:** app explicitly requested a timeout — register and show timer bar. App wins over spec default.
- **Transient:** register with `Prefs.notificationTimeout` regardless of `expireTimeout`.
- **On manual dismiss** (right-click, keybind, button): call `localTimerProcess.kill("notif-toast")` before hiding to stop the process-side timer cleanly. No `completed` signal fires.
- **Hover pause:** `HoverHandler.onEntered` → `localTimerProcess.pause("notif-toast")`. Visual bar freezes. `HoverHandler.onExited` → `localTimerProcess.resume("notif-toast")`. Timer and bar resume from the frozen position.
- **Resident rule:** if `notif.resident === true` and an action is invoked, call `localTimerProcess.kill("notif-toast")` and do not re-register. The app owns the lifecycle.

**Toast window surface**
- The notification toast is interactive (click handlers, buttons) and needs slide animation. The existing `ToastWindow` hosts `ScreenshotPreview` and `ScreenrecToast` in a passive `ColumnLayout`.
- `[OQ-H]` **Does the notification toast live inside the existing `ToastWindow`, or does it get its own `PanelWindow`?** Leaning toward its own window: independent positioning, animation, and input handling. Coexistence with screenshot/screenrec toasts must be considered.

**Transient notifications**
- `notif.hints["transient"]` — check if Quickshell exposes hints map or a dedicated `transient` property.
- If transient: use `Prefs.notificationTimeout` (5s) regardless of `expireTimeout`; skip bank (don't set `notif.tracked = true`, or call `notif.dismiss()` after hide).
- `[OQ-I]` **Does Quickshell expose `Notification.transient` or must we read `hints["transient"]`?**

---

##### Open Questions

| ID | Question | Blocks |
|---|---|---|
| ~~OQ-A~~ | ~~Does Quickshell provide a freedesktop icon name → image resolver?~~ | **Resolved.** Use `"image://icon/" + iconName` — Qt Quick Controls registers this provider (already imported). File paths used directly. Glyph fallback on `Image.Error`. Built as `AppIcon.qml` in `module-reusable-elements/`. |
| ~~OQ-B~~ | ~~Can we distinguish `image-data` from `image-path` in `notif.image`?~~ | **Resolved.** Show thumbnail for any non-empty `notif.image`. The data/path distinction is a transport detail — both carry "contextual visual" intent (avatar, album art, preview). Minor spec deviation accepted. |
| ~~OQ-C~~ | ~~Render HTML markup in body, or strip to plain text?~~ | **Resolved.** Detect and branch: if `notif.body.includes("<")` → `Text { textFormat: RichText; wrapMode: WordWrap; onLinkActivated: Qt.openUrlExternally(link) }`. Otherwise → `ScrollingText`. RichText branch allows the body row to wrap and expand the toast height. |
| ~~OQ-D~~ | ~~How does snooze re-trigger the toast without a new D-Bus event?~~ | **Scrapped.** Snooze feature removed entirely per guiding principle — the shell never re-surfaces a notification the app did not re-send. |
| ~~OQ-E~~ | ~~Which 4 actions to show when caller sends > 4?~~ | **Resolved.** `default` + first 3 non-default, in order. All actions are buttons only. Inline-reply extension deferred indefinitely. |
| ~~OQ-F~~ | ~~Does `criticalBgColor` exist in Style? Is MD3 error container defined?~~ | **Resolved.** `Style.criticalBgColor` = `mat3ErrorContainer`. `Style.textCritical` = `mat3Error`. No new tokens needed. |
| ~~OQ-G~~ | ~~Confirm `Notification.expireTimeout` property name in Quickshell API~~ | **Resolved.** Property is `notif.expireTimeout`, type `real`, unit **milliseconds** (raw D-Bus passthrough — freedesktop spec sends ms, Quickshell exposes as-is). Use directly: `durMs = notif.expireTimeout`. Sentinels: `-1` → use `Prefs.notificationTimeout`; `0` → never auto-dismiss. Also confirmed: `notif.transient` is first-class bool (resolves OQ-I). `notif.appIcon` already resolved by Quickshell via desktop entry fallback — non-empty means usable. `notif.resident`: if true, toast does not hide after action invoked. |
| ~~OQ-H~~ | ~~Own `PanelWindow` or inside existing `ToastWindow`?~~ | **Resolved.** NotificationToast lives in ToastWindow and is the **champion** — it defines ToastWindow's architecture. ScreenshotPreview and ScreenrecToast adapt. ToastWindow requires: (1) `notificationServer` injected, (2) `mask: Region` reworked to track active content areas per item, (3) `WlrLayershell.keyboardFocus` added. ToastController can be revived or folded in. |
| ~~OQ-I~~ | ~~Is `Notification.transient` a first-class property or a hints map entry?~~ | **Resolved** (via OQ-G). First-class `bool`. Use `notif.transient` directly. |
| ~~OQ-J~~ | ~~`replaces_id` handling — update in place + restart timer, treat as new + counter, or silent update?~~ | **Resolved.** Quickshell handles `replaces_id` entirely in C++ before QML sees it. Confirmed from Quickshell source (`server.cpp`): when a notification arrives with a non-zero `replaces_id` that maps to an existing tracked notification, `updateProperties()` is called on the **same `Notification` object** — same C++ pointer, same QML object, stays in `trackedNotifications`. `emit this->notification(notification)` is inside `if (!old)`, so **`onNotification` does NOT fire for replacements**. Our `newNotification` signal and the toast are never triggered. All `Notification` properties use `Q_OBJECT_BINDABLE_PROPERTY` with NOTIFY signals (`summaryChanged`, `bodyChanged`, etc.) — QML bindings react automatically when `updateProperties()` runs. Consequence for toast: **no re-animation, no counter increment, no re-show**. Consequence for bank: live notifications (e.g. download progress) update in place in `trackedNotifications` with zero extra work — the bank Repeater/ListView reacts automatically. If `replaces_id` points to an ID not in `idMap` (notification was dismissed or never tracked), Quickshell falls through and creates a brand-new notification — `onNotification` fires, toast triggers normally. `replacesId` is **not exposed to QML** — consumed internally and discarded. |
| ~~OQ-K~~ | ~~Counter display format — "+N", "N more", or "N total"?~~ | **Scrapped.** Counter removed per guiding principle. Bank handles "what you missed." |
| ~~OQ-L~~ | ~~Dismiss keybind — which key, where configured, hide-only or also dismiss from bank?~~ | **Resolved.** Add a FIFO entry in `FifoListener.qml` (e.g. `dismissNotification`). Wired to whatever key the user wants in `rc.xml` — no Settings UI needed. Behaviour: hide toast only, keep in bank — identical to right-click. The keybind has no opinion about the bank; it just tells the toast to go away. |
| ~~OQ-M~~ | ~~Should Snooze be hidden for Critical notifications?~~ | **Scrapped.** Snooze removed per guiding principle. |
| ~~OQ-N~~ | ~~Should Snooze be hidden for transient notifications?~~ | **Scrapped.** Snooze removed per guiding principle. |
| ~~OQ-O~~ | ~~Transient bank-skip mechanism — never set `tracked`, or set then call `dismiss()` on hide?~~ | **Resolved.** Never set `tracked` — option (a). Check `notif.transient` in `onNotification` before setting `notif.tracked = true`. The notification never enters `trackedNotifications`; the bank never sees it. Fix is one line in `NotificationServer.qml`: `if (!notif.transient) notif.tracked = true`. |
| ~~OQ-P~~ | ~~Root TapHandler vs button TapHandlers — event propagation control to prevent double-fire~~ | **Resolved.** Eliminated by design. Left-click TapHandlers are placed on Col1, Col2, Col3 individually — not on the root. Col4 (Skip button) and the caller action row own their own handlers and do not overlap with the content area. No propagation conflict is possible. Right-click TapHandler on Row1 covers the whole row; right-clicking a button triggers dismiss, which is acceptable. |
| ~~OQ-Q~~ | ~~Slide animation in layer-shell — content at `x = implicitWidth` may be compositor-clipped. Clip wrapper, opacity, or y-offset instead?~~ | **Deferred.** Animation added after initial build is working. |
| ~~OQ-R~~ | ~~Rich text body max height — `WordWrap` on long body makes toast arbitrarily tall. Cap needed?~~ | **Resolved.** Cap at 8 lines. Implementation: `maximumLineCount: 8` on the `Text` element (works for both plain and RichText modes). Content beyond 8 lines clips silently — full body is always available in the bank. |
| ~~OQ-S~~ | ~~ToastWindow width — `Screen.width * 0.15` ≈ 288px. Does NotificationToast drive a wider window?~~ | **Deferred.** Keep `Screen.width * 0.15` for now. Width wired to Prefs after build. |
| ~~OQ-T~~ | ~~ToastWindow stacking order — NotificationToast, ScreenshotPreview, ScreenrecToast. Which sits closest to corner?~~ | **Resolved.** ToastWindow uses an index system where 0 = bottom-most (nearest screen edge). ScreenrecToast = 0, NotificationToast = 1. Order wired to Prefs after build. |
| ~~OQ-U~~ | ~~ScreenrecToast is persistent (whole recording). NotificationToast is transient. When both visible, how do they coexist in the ColumnLayout?~~ | **Resolved.** The index system handles it — ScreenrecToast at 0, NotificationToast at 1. ColumnLayout stacks them naturally. No special handling needed. |
| ~~OQ-V~~ | ~~`Prefs.notificationTimeout` units — ms (consistent with Qt Timer) or seconds (consistent with `notif.expireTimeout`)?~~ | **Resolved.** Milliseconds throughout in code. Settings panel displays seconds to the user (`Prefs.notificationTimeout / 1000`) — that conversion is a Settings UI concern, handled after build. |
| ~~OQ-W~~ | ~~`notif.hints["category"]` null-safety — who guards undefined hints: AppIcon.qml or NotificationToast.qml?~~ | **Resolved.** `AppIcon.qml` guards it — the null check lives alongside the fallback chain logic. `NotificationToast.qml` passes `notif.hints["category"]` through as-is; `AppIcon` treats undefined/empty as a cache miss and falls back to the generic bell. |
| ~~OQ-X~~ | ~~`action-icons` hint — if true, action keys are icon names not labels. Defer or handle?~~ | **Deferred.** Always use `.text` as button label. `action-icons = true` is rare in practice — revisit only when a real app requires it. |
| ~~OQ-Y~~ | ~~Screenshot/Screenrec toasts after Phase 2 — do transient toasts still exist, or does everything move to the Bank?~~ | **Resolved.** Both coexist. Toasts serve the moment (immediate confirmation); Bank tabs serve history. Same principle as notifications — toast and bank are independent surfaces with different jobs. |

#### 1.3 — Inventory and Gaps

##### What We Have (reuse as-is)

| Component | Location | Role in toast |
|---|---|---|
| `NotificationServer.qml` | `root-processes/` | Notification data source. `newNotification(notif)` signal is the toast trigger. |
| `ScrollingText.qml` | `module-reusable-elements/` | Summary and body display. |
| `PanelButton.qml` | `module-reusable-elements/` | Caller action row buttons. Has `default`, `accent`, `critical` variants. |
| `IconButton.qml` | `module-reusable-elements/` | Service action icon (Skip bank & dismiss). Has `critical` variant. |
| `PanelDivider.qml` | `module-reusable-elements/` | Visual separator between content and action row. |
| `ToastWindow.qml` | `module-reusable-elements/` | Existing bottom-right PanelWindow. Architecture decision needed — see OQ-H. |
| `Style.criticalBgColor` | `Style.qml` | `mat3ErrorContainer` — **exists**. OQ-F resolved. |
| `Style.textCritical` | `Style.qml` | `mat3Error` — exists. |
| `Style.fontNerd` | `Style.qml` | Nerd Font for category glyphs. |
| `NotificationPanel.qml` | `module-panels/` | Reference for how `notif.*` properties are accessed in QML. |
| `AppIcon.qml` *(new, build first)* | `module-reusable-elements/` | Resolves `app_icon` to an image. Height-driven by layout; `width: height` keeps it square. Falls back to a Nerd Font glyph. See design note below. |
| `LocalTimerProcess.qml` *(new — see LocalTimerDiscussion.md)* | `root-processes/` | Authoritative dismiss clock and data source for the LocalTimer visual. Replaces standalone Qt Timer. Provides `register`, `kill`, `pause`, `resume`, `remaining`. Injected into ToastWindow via `shell.qml`. |
| `LocalTimer.qml` *(new — see LocalTimerDiscussion.md)* | `module-reusable-elements/` | Visual timer bar. Used as Variant 4 (horizontal, bottom row) or Variant 5 (vertical, screen edge) — position TBD. Receives `localTimerProcess` injection from parent chain. |

**AppIcon design:** No `size` property — height is provided by the parent layout (`Layout.fillHeight: true` on the Col1 Item in the toast RowLayout). `width: height` keeps it square. `Image.fillMode: PreserveAspectFit`. Glyph fallback uses `font.pixelSize: parent.height * 0.7`. Icon resolution: if `iconName` starts with `/` or `file://`, use as `Image.source` directly; otherwise use `"image://icon/" + iconName` (Qt Quick Controls registers this provider — resolves freedesktop icon theme names via `QIcon::fromTheme()`). `Image.status !== Image.Ready` triggers the glyph.

**Build sequence:** LocalTimerProcess + LocalTimer → AppIcon → NotificationToast → ToastWindow rework → shell.qml wiring.

**Note on `ToastController.qml`**: Currently aggregates `shouldShow` from `screenshotPreview` + `screenrecToast`. In `shell.qml`, `ToastWindow` directly computes its own `visible` from loaders — ToastController appears unused/orphaned. Can be ignored or extended later.

---

##### What Needs Extension

| Component | What to add |
|---|---|
| `Prefs.qml` | `notificationTimeout: 5000` (default dismiss ms). Not present; new entry needed. |
| `ToastWindow.qml` | **Rework as champion window.** Add `notificationServer` injection. Add third Loader for `NotificationToast.qml`. Rework `mask: Region` to track active content areas per item. Add `WlrLayershell.keyboardFocus` logic tied to NotificationToast visibility. Update `visible` computation to include notification toast. ScreenshotPreview and ScreenrecToast adapt to the new layout. |
| `shell.qml` | Wire `notificationServer` and `localTimerProcess` to the new toast window, same pattern as existing `ToastWindow` wiring. |
| `module-toasts/qmldir` | Register `NotificationToast` once the file is created. |

---

##### What Needs to Be Built New

| Item | What it is |
|---|---|
| `NotificationToast.qml` | The toast item. New file in `module-toasts/`. Receives a `notif` object and `localTimerProcess` (injected). Renders the layout from 1.2. Uses LocalTimerProcess for dismiss timing (no standalone Qt Timer). Handles TapHandlers, HoverHandler, and button signals. |
| Category glyph map | A JS property object mapping freedesktop category prefix → Nerd Font codepoint. Inline in `NotificationToast.qml` (similar to WMO_ICONS in weather-fetch). Start with the 10 most common categories (email, im, call, network, device, transfer, presence, file, sound, volume). |
| Slide animation | `x`-offset animation on the toast container. Start at `x = toastWidth` (off right), animate to `x = 0` on show. `Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }`. |

---

### Phase 1.5 — Two-Surface Toast Architecture

#### Decision

Testing revealed a fundamental conflict: a single toast surface cannot cleanly serve both Critical and Normal notifications. If one surface handles both:
- Critical can be displaced by a low-priority Normal or Transient notification that arrives while it is showing.
- Preventing displacement requires priority-check logic inside `onNewNotification`, which creates a special-case path that grows over time.

The solution is two independent toast surfaces — one per urgency tier — each following the same simple replacement rule within its tier.

---

#### Architecture

**Two surfaces, two jobs:**

| Surface | File | Urgency tier | Timer behaviour |
|---|---|---|---|
| `UrgentToast.qml` | `module-toasts/` | Critical (`urgency = 2`) | No timer unless app explicitly provides `expireTimeout > 0`. Stays until user acts. |
| `NotificationToast.qml` | `module-toasts/` | Normal + Low + Transient (`urgency ≤ 1`) | Timer always runs. Duration: `expireTimeout > 0` → app value; otherwise `Prefs.notificationTimeout`. Transient uses the same path — no special case needed. |

**Replacement rule — last win, within tier:**
Each surface independently applies "new notification replaces current." A Critical arriving while another Critical is showing replaces it immediately — the urgent toast resets. Same for Normal. The two surfaces never interact with each other.

**Routing in `NotificationServer`:**
`newNotification(notif)` is emitted for all notifications as today. The two toasts each connect to this signal and filter by urgency:
- `UrgentToast`: responds only when `notif.urgency === NotificationUrgency.Critical`
- `NotificationToast`: responds only when `notif.urgency !== NotificationUrgency.Critical`

No routing logic lives in NotificationServer. Each toast is self-selecting.

**ToastWindow stacking order:**

```
ToastWindow (bottom-right, bottom-justified)
│
├─ ScreenshotPreview   index 3 — top, furthest from corner
├─ NotificationToast   index 2
├─ UrgentToast         index 1
└─ ScreenrecToast      index 0 — bottom, nearest corner (persistent)
```

Urgent sits below Normal — closer to the screen edge — so it is spatially distinct and harder to miss. Both can be visible simultaneously.

**Timer behaviour, fully specified:**

*UrgentToast (Critical):*
- `expireTimeout <= 0` (no explicit app timeout): no timer. Toast stays until user right-clicks, presses keybind, or clicks action/dismiss button.
- `expireTimeout > 0` (app explicitly requested timeout): timer starts. App wins over the Critical-must-not-expire default. Timer bar is shown.

*NotificationToast (Normal / Low / Transient):*
- `expireTimeout > 0`: use app-provided duration. Timer bar shown.
- `expireTimeout <= 0`: use `Prefs.notificationTimeout` (default 5s). Timer bar shown.
- Transient flag: no effect on timer logic — transient notifications go to the Normal surface and auto-dismiss via the standard path. The `transient` flag only controls bank storage (never tracked), not display duration.

**What stays the same:**
- `LocalTimer` embedded directly in each toast — no process injection.
- Hover pauses the timer (both surfaces, where applicable).
- Right-click row1 = hide toast, keep in bank.
- Dustbin / skip-bank button = `notif.dismiss()` + hide.
- Action buttons invoke and hide (unless `resident = true`).

---

### Phase 2 — The Bank

The existing "Notification panel" is renamed the **Bank**. It is the persistent view — history, inbox, and media archive — and becomes relevant only after the toast (Phase 1) is complete.

**Three tabs:**
- **Notifications** — notification history. All tracked notifications live here until the user explicitly dismisses them.
- **Screenshots** — screenshot history, fed by `ScreenshotPreview` events. Replaces the current passive toast-only model.
- **Recordings** — screenrec history, fed by `ScreenrecToast` events. Same migration.

**SysTray** remains in the Bank for now, pending a final home.

---

#### The Bank's Data Layer — Intent and Architecture

**The bank does not need its own notification tracker.** `_server.trackedNotifications` (Quickshell's `UntypedObjectModel`) is the single source of truth. Every `Notification` object in that model is live — its properties update in place when the sending app replaces the notification via `replaces_id`. The bank is a Repeater or ListView over `notificationServer.notifications`; reactive bindings handle updates with no polling, no diffing, no custom state.

**Core intent:** the bank shows every currently tracked notification in its latest state, always. The toast shows only the most recent *new* notification. These two surfaces read from the same data layer but serve different roles:

- **Toast** — triggered by `newNotification(notif)` signal (new notifications only, never replacements). Shows one notification at a time. Transient — hides after timeout or user action.
- **Bank** — always-available panel. Shows all tracked notifications. A notification that has been superseded in the toast (App A's download pushed aside by App B's track change) is still visible and live in the bank, updating automatically as App A continues to send `replaces_id` progress updates.

**The canonical scenario this design must handle:**

> App A is downloading a file. It sends progress notifications using `replaces_id` (same notification ID, content updated every few seconds: "Downloading… 40%", "60%", "80%"). A few seconds in, App B (media player) sends a new track-change notification. The toast switches to App B — this is correct, App B fired `onNotification`, App A's `replaces_id` updates never did. The user opens the bank and sees App A's download notification, currently showing "72%" and counting up in real time. They also see App B's track notification. Both are live.

**Why this works without extra infrastructure:**

- Quickshell's `updateProperties()` fires `NOTIFY` signals on the existing `Notification` QObject when a `replaces_id` update arrives.
- The bank's Repeater/ListView binds to those properties. The update propagates automatically through QML's binding system.
- No timer, no polling, no shadow copy, no JS object tracking. The C++ model does the work.

**What the bank must NOT do:**

- Do not maintain a separate JS array or object map of notifications. `trackedNotifications` is authoritative; a shadow copy will drift.
- Do not try to detect `replaces_id` in QML — it is not exposed. Trust that the existing object in `trackedNotifications` is already updated by the time any QML runs.
- Do not call `notif.tracked = true` again for replacement notifications — `onNotification` never fires for them, so this is not a risk, but the principle stands.

**Ordering in the bank:**

`trackedNotifications` order is insertion order (Quickshell does not re-order on replacement). For the bank UI, display in reverse-insertion order (newest at top) using a sort proxy or by reversing the model index. Timestamps for sort are stored in `NotificationServer.qml`'s `_timestamps` map, keyed by `notif.id`, written only on `onNotification` (i.e. only for genuinely new notifications — replacements keep the original arrival timestamp, which is correct: a download progress update does not become "newer" than App B's track change just because it updated in place).

---

---

#### Phase 2.1 — Notifications Tab Layout Stack

The Notifications tab follows the standard panel hierarchy and uses a flat list — no nested cards.

**Panel hierarchy:**
```
PanelSurface (managed by PanelController)
└─ NotificationPanel.qml
   └─ TabBar (tabs: Notifications | Screenshots | Recordings)
      └─ [Notifications tab]
         └─ PanelCard  ← no margins (PanelSurface's PanelContainer already provides inset)
            │           ← no extra padding (PanelCard has built-in content padding)
            └─ ColumnLayout (the list)
               │  Layout.fillWidth: true
               │  no anchors (already inside PanelCard's ColumnLayout)
               │  no margins (already padded by PanelCard)
               │  height driven by content
               │
               ├─ NotifEntry (delegate 0)
               ├─ PanelDivider
               ├─ NotifEntry (delegate 1)
               ├─ PanelDivider
               └─ ...
```

No card inside card. Each `NotifEntry` is transparent — the section `PanelCard` is the only background surface. The delegate `ColumnLayout` follows the exact same layout rules as the toast — no extra padding or margins declared at any level.

---

**Repeater delegate — `NotifEntry`:**

```
Repeater (model: notificationServer.notifications)
  delegate: ColumnLayout (variable height — driven by content)
    │
    ├─ PanelDivider (visible: index > 0)
    │
    ├─ RowLayout (main content — Row1, spacing: 8)
    │  │   TapHandler (Right → notif.dismiss() — remove from bank)
    │  │   TapHandler (Left → invoke default action)
    │  │
    │  ├─ Col1: AppIcon (same component as toast)
    │  │
    │  ├─ Col2: Text section (fillWidth, AlignTop)
    │  │    ColumnLayout (spacing: 4)
    │  │      Text (summary)
    │  │        wrapMode: WordWrap, maximumLineCount: 8, elide: ElideRight
    │  │        font.pixelSize: fontSizeHeading
    │  │        HoverHandler + ToolTip (visible: truncated)
    │  │      Text (body — plain) OR Text (body — RichText)
    │  │        wrapMode: WordWrap, maximumLineCount: 8, elide: ElideRight
    │  │        font.pixelSize: fontSizeBody, color: textSecondary
    │  │        HoverHandler + ToolTip (visible: truncated)
    │  │        visible: body !== ""
    │  │
    │  ├─ Col3: Thumbnail (same as toast — collapses to 0 when no image)
    │  │
    │  └─ Col4: IconButton (×)
    │         onClicked: modelData.dismiss()
    │
    ├─ PanelDivider (visible: actions present)
    │
    └─ RowLayout (action row — same as toast, visible: actions.length > 0)
         Repeater (model: filteredActions — default + up to 3 non-default)
           PanelButton (label: action.text, onClicked: action.invoke())
```

---

**Differences from the toast:**

| Toast | Bank entry |
|---|---|
| `ScrollingText` (single-line, marquee) | `Text` (multiline, `wrapMode: WordWrap`, max 8 lines, tooltip on truncate) |
| `LocalTimer` bar at bottom | Absent — no auto-dismiss in bank |
| `HoverHandler` pauses timer | Absent — no timer to pause |
| Right-click = hide toast, keep in bank | Right-click = `notif.dismiss()` — removes from bank |
| `root._notif` | `modelData` |
| urgency background color | No background — entry is transparent against section `PanelCard` |

**Ordering:** newest at top. Reverse-insertion order via index mapping (`count - 1 - index`) or `ListView.verticalLayoutDirection: ListView.BottomToTop`. `NotificationServer._timestamps` holds arrival time per `notif.id` if explicit sort is needed later.

**Empty state:** when `notificationServer.notifications` is empty, show a centered muted label ("No notifications") in place of the Repeater.

**Clear all:** a button (top-right of the tab header or bottom of the list) calls `notificationServer.clearAll()`. Removes all entries from `trackedNotifications` in one pass.
