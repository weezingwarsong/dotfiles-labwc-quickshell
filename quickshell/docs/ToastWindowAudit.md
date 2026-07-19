# ToastWindow Audit

Pre-build audit of the current ToastWindow stack against the requirements from `NotificationDiscussion.md`. NotificationToast is the champion — ScreenshotPreview and ScreenrecToast adapt to fit around it.

---

## Current State

### ToastWindow.qml

```
PanelWindow
  anchors: bottom-right
  margins: Screen.height * 0.02 (both axes)
  implicitWidth:  Screen.width * 0.15
  implicitHeight: _col.implicitHeight
  mask: Region { item: _col }
  exclusiveZone: 0
  visible: _ssLoader.shouldShow || _srLoader.shouldShow

  ColumnLayout (_col, anchors.bottom)
    Loader _ssLoader  → ScreenshotPreview   (layout index 0, top)
    Loader _srLoader  → ScreenrecToast      (layout index 1, bottom/screen edge)

  function dismiss(id)
    "screenshot" → _ssLoader.item._dismiss()
    "screenrec"  → _srLoader.item._dismiss()

  Injected: screenshotProcess, screenrecProcess
```

**Stacking note:** ColumnLayout is `anchors.bottom`. Items are laid top-to-bottom in the layout; the last item sits at the screen edge. Current order: ScreenshotPreview above ScreenrecToast, ScreenrecToast at corner.

### ToastController.qml

`QtObject` that aggregates `shouldShow` from screenshotPreview + screenrecToast. **Currently orphaned** — ToastWindow computes `visible` directly from loaders and does not instantiate ToastController. Ignore it.

### FifoListener.qml

Has `dismissToast:<id>` prefix → emits `dismissToastRequested(id)` signal. `shell.qml` wires this to `toastWindow.dismiss(id)`. The dismiss path already exists; it just needs a new id value ("notification") handled in `dismiss()`.

### shell.qml

```qml
NotificationServer { id: notifServer }   // already instantiated
LocalTimerProcess  { id: localTimer }    // already instantiated

ToastWindow {
    id: toastWindow
    screenshotProcess: screenshot
    screenrecProcess:  screenrec
    // notificationServer and localTimerProcess NOT yet wired
}

onDismissToastRequested: (id) => toastWindow.dismiss(id)
```

### module-toasts/qmldir

Registers only `ScreenshotPreview` and `ScreenrecToast`. `NotificationToast` not yet registered.

---

## What's Already Correct

| Item | Status |
|---|---|
| `PanelWindow` anchoring (bottom-right, margins) | Correct, no change needed |
| `exclusiveZone: 0` | Correct — toast must not push other windows |
| `implicitWidth: Screen.width * 0.15` | Keep for now (deferred per OQ-S) |
| `mask: Region { item: _col }` | Correct — passthrough outside column. NotificationToast lives inside `_col` so it will receive input automatically |
| ColumnLayout + Loader pattern | Correct, just needs a third Loader |
| `dismiss(id)` dispatch pattern | Correct pattern, needs "notification" case added |
| `notifServer` instantiated in shell.qml | Already there |
| `localTimer` instantiated in shell.qml | Already there |
| FifoListener `dismissToast:` prefix path | Already wired end-to-end |
| ScreenshotPreview and ScreenrecToast | No code changes needed — position in stack shifts but their logic is self-contained |

---

## Gaps

### 1. ToastWindow.qml — new Loader for NotificationToast

Add `_ntLoader` in the ColumnLayout between ScreenshotPreview and ScreenrecToast:

```
ColumnLayout (_col)
  Loader _ssLoader  → ScreenshotPreview    (top)
  Loader _ntLoader  → NotificationToast    (middle)   ← NEW
  Loader _srLoader  → ScreenrecToast       (bottom/edge)
```

This preserves ScreenrecToast at the screen edge (OQ-T: index 0) and puts NotificationToast above it (OQ-T: index 1). ScreenshotPreview stays at the top.

The Loader wires both injected processes:
```qml
Loader {
    id: _ntLoader
    Layout.fillWidth: true
    source: Qt.resolvedUrl("../module-toasts/NotificationToast.qml")
    onLoaded: {
        item.notificationServer  = Qt.binding(function() { return root.notificationServer })
        item.localTimerProcess   = Qt.binding(function() { return root.localTimerProcess })
    }
}
```

### 2. ToastWindow.qml — new injected properties

```qml
property var notificationServer: null
property var localTimerProcess:  null
```

### 3. ToastWindow.qml — `visible` computation

Include notification toast:

```qml
visible: (_ssLoader.item ? _ssLoader.item.shouldShow : false) ||
         (_ntLoader.item ? _ntLoader.item.shouldShow : false) ||
         (_srLoader.item ? _srLoader.item.shouldShow : false)
```

### 4. ToastWindow.qml — `dismiss()` function

Add "notification" case:

```qml
function dismiss(id) {
    if (id === "screenshot"   && _ssLoader.item) _ssLoader.item._dismiss()
    if (id === "notification" && _ntLoader.item) _ntLoader.item._dismiss()
    if (id === "screenrec"    && _srLoader.item) _srLoader.item._dismiss()
}
```

### 5. ToastWindow.qml — `WlrLayershell.keyboardFocus`

OQ-H originally flagged this as required. However, the dismiss keybind is implemented via FIFO (OQ-L resolution) — not by the window capturing key events. **No keyboard focus change needed.**

### 6. shell.qml — wire new properties to ToastWindow

```qml
ToastWindow {
    id: toastWindow
    screenshotProcess:   screenshot
    screenrecProcess:    screenrec
    notificationServer:  notifServer    // ← ADD
    localTimerProcess:   localTimer     // ← ADD
}
```

### 7. FifoListener.qml — `dismissNotification` command

Add to the FIFO dispatch:

```qml
else if (cmd === "dismissNotification") root.dismissToastRequested("notification")
```

This reuses the existing `dismissToastRequested` → `toastWindow.dismiss("notification")` path. No new signal needed.

### 8. module-toasts/qmldir — register NotificationToast

```
NotificationToast 1.0 NotificationToast.qml
```

Add once the file is created.

---

## Change Summary (file by file)

| File | Changes |
|---|---|
| `ToastWindow.qml` | Add `notificationServer` + `localTimerProcess` props; add `_ntLoader`; update `visible`; update `dismiss()` |
| `shell.qml` | Wire `notificationServer` + `localTimerProcess` into `ToastWindow` |
| `FifoListener.qml` | Add `dismissNotification` command |
| `module-toasts/qmldir` | Register `NotificationToast` (after file is created) |
| `ScreenshotPreview.qml` | No changes |
| `ScreenrecToast.qml` | No changes |
| `ToastController.qml` | No changes — remains orphaned, ignore |

---

## NotificationToast contract

What ToastWindow provides to NotificationToast (via Loader injection):

| Property | Source | Notes |
|---|---|---|
| `notificationServer` | `notifServer` in shell.qml | Provides `newNotification(notif)` signal and `notifications` model |
| `localTimerProcess` | `localTimer` in shell.qml | Dismiss timer + visual bar |

What ToastWindow expects from NotificationToast:

| Property / Function | Purpose |
|---|---|
| `shouldShow: bool` | Drives `ToastWindow.visible` |
| `_dismiss()` | Called by `ToastWindow.dismiss("notification")` and FIFO path |
