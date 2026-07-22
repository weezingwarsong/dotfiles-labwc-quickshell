# Window Switcher — Layout Stack Discussion

## Tier

Window switcher is its own tier — not a panel. Lives in `module-window-switcher/`, has its own `PanelWindow` (`WindowSwitcher.qml`), its own `isOpen` bool, and its own `toggle()`. Mutually exclusive with the panel tier (shell.qml `Connections` enforces this).

---

## Layout Stack

```
PanelWindow (WindowSwitcher.qml)
│   fullscreen transparent overlay, WlrKeyboardFocus.Exclusive when open
│   ESC shortcut + click-outside dismiss
│
└── Item _container
│       owns position (centered) and geometry
│       width:  Screen.width * 0.22
│       height: min(CL.implicitHeight, Screen.height * 0.6)   ← height cap
│
    ├── Rectangle _bg
    │       anchors.fill: parent
    │       panelBgColor, panelRadius, elementBorderWidth, panelBorderColor, clip: true
    │       visual chrome only — owns no children
    │
    └── ColumnLayout  ←────────────────────────── "mother CL" (WindowSwitcherView starts here)
            anchors.fill: parent                   same level as _bg, sits on top
            anchors.margins: 8                     owns all padding / inset
            spacing: 4

            ├── [row 1]  FilterBar
            │       Layout.fillWidth: true
            │       implicitHeight: Style.buttonHeight
            │       Rectangle (surfaceMidColor, panelElementRadius, border)
            │         ├── Text  placeholder "Filter…"  (hidden when input has text)
            │         └── TextInput filterInput        keyboard nav ↑ ↓ Enter Esc
            │
            └── [row 2]  Flickable
                    Layout.fillWidth:  true
                    Layout.fillHeight: true          ← fills remaining height when capped
                    implicitHeight: <content height> ← required so mother CL knows natural size
                    contentHeight: <content.implicitHeight>
                    clip: true

                    └── ColumnLayout  ←────────────── content CL (inside Flickable)
                            anchors left + right + top only (no height anchor)
                            spacing: 8

                            ├── PanelCard   ← Windows section
                            │   └── [inner CL — PanelCard default alias]
                            │         ├── SectionLabel  "Windows"
                            │         └── Repeater  filteredWindows
                            │               └── SelectableRow           ← reusable module
                            │                     RowLayout
                            │                       ├── Text glyph       Layout.preferredWidth: parent.width * 0.10  fontNerd
                            │                       ├── Text appId        Layout.preferredWidth: parent.width * 0.25  elide right
                            │                       └── Text title        Layout.fillWidth                            elide right
                            │
                            └── PanelCard   ← App Launcher section (visible only when filter text non-empty)
                                └── [inner CL]
                                      ├── SectionLabel  "App Launcher"
                                      └── Repeater  filteredApps
                                            └── SelectableRow
                                                  RowLayout
                                                    ├── Text glyph       Layout.preferredWidth: parent.width * 0.1  fontNerd
                                                    └── Text name         Layout.fillWidth                          elide right
```

---

## SelectableRow

New reusable module: `module-window-switcher/SelectableRow.qml`

```
Item
  Layout.fillWidth: true
  implicitHeight: Style.buttonHeight

  Properties:
    glyph      string   nerd font codepoint string
    label1     string   primary label (appId or app name)
    label2     string   secondary label (window title — empty string hides it)
    isSelected bool
    isHovered  bool     (driven externally by HoverHandler on this Item)
    isActive   bool     (currently focused window)

  Signals:
    activated()

  Children:
    Rectangle  anchors.fill  highlight layer  (accentBgColor / surfaceLowColor / transparent)
    HoverHandler
    TapHandler → activated()
    RowLayout  anchors fill + l/r margins: 6
      Text glyph    fontNerd, Layout.preferredWidth: parent.width * 0.10
      Text label1   fontMono, Layout.preferredWidth: parent.width * 0.25, elide right
      Text label2   fontMono, Layout.fillWidth, elide right  (visible: label2 !== "")
```

---

## Open Questions

| # | Question | Options |
|---|---|---|
| 1 | SectionHeader or SectionLabel? | ✅ **SectionLabel** — plain label, no collapsible behavior |
| 2 | appId column width | ✅ **Three columns** — glyph 10% / appId 25% / title fill. Glyph column reserved for real icons later. |
| 3 | App Launcher section visibility | ✅ **Hidden when no filter text** — default state shows open windows only |
| 4 | SelectableRow location | ✅ **`module-window-switcher/`** — local to switcher, keeps WindowSwitcherView.qml readable |

---

## Height Cap Logic

```
_container.height = min(motherCL.implicitHeight, Screen.height * 0.6)

motherCL.implicitHeight = FilterBar.implicitHeight
                        + spacing
                        + Flickable.implicitHeight      ← = content CL implicitHeight
                        + margins * 2

When content is short:  _container shrinks to fit, no scrolling
When content is tall:   _container caps at 60vh, Flickable scrolls via Layout.fillHeight
```

The Flickable must declare `implicitHeight: contentCL.implicitHeight` so the mother CL can
compute its own `implicitHeight` correctly before the cap is applied. Without it the mother CL
collapses to just the FilterBar height.
