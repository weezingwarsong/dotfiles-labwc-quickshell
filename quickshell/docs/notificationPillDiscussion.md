# Notification Pill Revamp — Design Log

## Status: Built ✓ — pending further testing

---

## Summary of Decisions

**Architecture:** Option B — pill shows content passively, panel handles actions. Fits the shell's deliberate-interaction philosophy. Toast overlay (Option A) deferred indefinitely.

**Layout:** Three-column row. Col 1: thumbnail (collapses if no image). Col 2: two-row text stack (app name small/muted on top, summary/body scrolling below). Col 3: blinking dot if notification has actions.

**Sizing:** PillWindow `implicitHeight` made content-driven (was fixed). Both width and height now flow upward from content. Thumbnail size derived from `Style.fontSizePill + Style.pillPaddingV - 8` directly (avoids circular dependency with parent.height).

**Critical treatment:** `criticalBgColor` background + `textCritical` summary + one-shot scale thump on arrival (1.0→1.04→1.0, 300ms total) + faster dot blink (250ms vs 600ms half-cycle) in `mat3OnErrorContainer`.

**Count display:** Removed from pill entirely. Deferred to notification panel header (future task).

---

## Files Changed

| File | Change |
|---|---|
| `module-pills/NotificationPill.qml` | Full rewrite — rich layout replacing count string |
| `module-reusable-elements/PillWindow.qml` | `implicitHeight` now content-driven |

---

## Pill Sizing Chain (reference)

**Width** — upward from content: `RowLayout.implicitWidth` → `Loader.width` → `PillWindow.implicitWidth (+40px padding)` → Wayland surface.

**Height** — now also upward from content: `RowLayout.implicitHeight` → `PillWindow.implicitHeight (+pillPaddingV)` → Wayland surface. Other pills unaffected — their `Text { height: parent.height }` doesn't change `implicitHeight`, so they stay at `fontSizePill + pillPaddingV`.

**Pill width at defaults (1920px):** ~278px (40 padding + 25 thumbnail + 6 + 192 col2 + 6 + ~9 dot).

**Pill height at defaults:** ~45px notification (25px thumbnail + 20px paddingV) vs 33px other pills (13px text + 20px paddingV).

---

## To-Do / Further Testing

- [ ] Test with a real rich notification (Discord, WhatsApp) that sends an image — verify thumbnail renders and sizes correctly
- [ ] Test with a real critical notification — verify thump fires, dot blinks fast, criticalBgColor shows
- [ ] Test notification with actions — verify dot appears and blinks at normal rate
- [ ] Test peek expiry with 0 notifications — verify pill hides cleanly
- [ ] Test rapid arrivals (multiple in quick succession) — verify pill updates to newest and timer restarts

---

## On Hold

1. **App icon fallback (`image://theme/`)** — verify `appIcon` property exists on Quickshell `Notification` object and that `image://theme/` resolves correctly in this Wayland setup. If it works, add as Col 1 fallback source behind `notif.image`.

2. **Unread count in notification panel** — count was removed from pill; a badge/count in the panel header is the right home for it. Deferred.
