import QtQuick

// Aggregates shouldShow across all toast modules (OR — no mutual exclusion).
// Mirrors PillController's role but for the toast tier.
QtObject {
    id: root

    property var screenshotPreview: null
    property var screenrecToast:    null

    readonly property bool shouldShow:
        (screenshotPreview ? screenshotPreview.shouldShow : false) ||
        (screenrecToast    ? screenrecToast.shouldShow    : false)
}
