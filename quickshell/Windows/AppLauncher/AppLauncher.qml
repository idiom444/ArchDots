import Quickshell
import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets
import Quickshell.Hyprland
import QtQuick.Controls
import Quickshell.Io
import "../../lib/" as Libs

PopupWindow {
    id: launcher
    visible: false

    // ---- Single source of truth for sizing/styling knobs
    QtObject {
        id: ui

        // geometry
        readonly property real r: 20
        readonly property real stroke: 2
        readonly property real margin: 2

        readonly property real searchH: 35
        readonly property real iconBoxW: 50
        readonly property real dividerW: 2
        readonly property real rowH: 51

        // dropdown sizing
        readonly property int maxVisibleRows: 10
        readonly property real listTopInset: r

        // colors
        readonly property color outline: Qt.rgba(Libs.Theme.barBg.r, Libs.Theme.barBg.g, Libs.Theme.barBg.b, Libs.Theme.barBg.a * Libs.Theme.barOpacity)
        readonly property color surfaceOuter: Qt.rgba(Libs.Theme.barBg.r, Libs.Theme.barBg.g, Libs.Theme.barBg.b, Libs.Theme.barBg.a * Libs.Theme.barOpacity)
        readonly property color surface: Qt.rgba(Libs.Theme.primary_container.r, Libs.Theme.primary_container.g, Libs.Theme.primary_container.b, Libs.Theme.primary_container.a * Libs.Theme.barOpacity)
    }

    // ---- Active monitor anchoring support
    // PopupWindow must anchor relative to a window; we make a tiny "host" window
    // that always lives on the focused monitor, then anchor the popup to it.
    PanelWindow {
        id: anchorHost
        // keep it effectively invisible and non-intrusive
        color: "transparent"
        implicitHeight: 1

        anchors {
            top: true
            left: true
            right: true
        }
    }

    function focusedScreen() {
        const m = Hyprland.focusedMonitor;
        if (!m)
            return Quickshell.screens.length ? Quickshell.screens[0] : null;

        // HyprlandMonitor.name matches ShellScreen.name (e.g. "eDP-1", "DP-1")
        const s = Quickshell.screens.filter(sc => sc.name === m.name)[0];
        return s || (Quickshell.screens.length ? Quickshell.screens[0] : null);
    }

    // ---- Focus + IPC (your original behavior)
    HyprlandFocusGrab {
        id: grab
        windows: [launcher]
    }

    function showLauncher() {
        // move the anchor host (and popup) to the currently focused monitor
        const s = focusedScreen();
        if (s) {
            anchorHost.screen = s;
            launcher.screen = s; // not strictly required, but keeps intent obvious
        }

        launcher.visible = true;
        Qt.callLater(function () {
            query.forceActiveFocus();
            grab.active = true;
            launcher.requestActivate();
        });
    }

    function hideLauncher() {
        grab.active = false;
        launcher.visible = false;
        query.text = "";
        list.currentIndex = 0;
    }

    Connections {
        target: grab
        function onCleared() {
            launcher.hideLauncher();
        }
    }

    IpcHandler {
        target: "launcher" // must be unique
        function toggle(): void {
            if (launcher.visible)
                launcher.hideLauncher();
            else
                launcher.showLauncher();
        }
        function show(): void {
            launcher.showLauncher();
        }
        function hide(): void {
            launcher.hideLauncher();
        }
    }

    // ---- Show dropdown only when something is typed
    readonly property bool hasQuery: (query.text || "").trim().length > 0

    // keep sane implicit sizing (dropdown overlaps border by r)
    implicitWidth: border.implicitWidth
    implicitHeight: border.implicitHeight + (hasQuery ? (dropdown.height - ui.r) : 0)

    color: "transparent"

    // Anchor popup to the host window on the focused monitor
    anchor.window: anchorHost
    anchor.rect.x: (anchorHost.width - implicitWidth) / 2
    anchor.rect.y: (anchorHost.screen ? (anchorHost.screen.height - border.implicitHeight) / 2 - 360 : 0)

    // ---- Fuzzy scoring helper
    // Returns -1 if no match. Higher is better.
    function fuzzyScore(candidate, q) {
        if (!candidate)
            return -1;
        if (!q)
            return 0;

        const s = candidate.toLowerCase();
        const t = q.toLowerCase();

        let si = 0;
        let ti = 0;
        let score = 0;
        let lastMatch = -10;
        let firstMatch = -1;

        while (si < s.length && ti < t.length) {
            if (s[si] === t[ti]) {
                if (firstMatch < 0)
                    firstMatch = si;

                score += 10;

                const gap = si - lastMatch;
                if (gap === 1)
                    score += 15;
                else if (gap <= 3)
                    score += 5;

                const prev = si > 0 ? s[si - 1] : "";
                if (si === 0 || prev === " " || prev === "-" || prev === "_" || prev === ".")
                    score += 8;

                lastMatch = si;
                ti++;
            }
            si++;
        }

        if (ti !== t.length)
            return -1;

        score += Math.max(0, 40 - firstMatch);
        return score;
    }

    // ---- Search bar container
    WrapperRectangle {
        id: border
        margin: ui.margin
        radius: ui.r
        color: ui.surfaceOuter

        Row {
            Rectangle {
                id: searchChild
                implicitWidth: 300 - (searchIcon.implicitWidth + divider.implicitWidth)
                implicitHeight: ui.searchH
                bottomLeftRadius: ui.r
                topLeftRadius: ui.r
                color: ui.surface

                TextField {
                    id: query
                    anchors.fill: parent
                    background: null
                    focus: true
                    placeholderText: "Search Apps..."
                    font.family: Libs.Theme.uiFont
                    color: Libs.Theme.on_primary_container
                    placeholderTextColor: Libs.Theme.on_primary_container

                    onTextChanged: {
                        list.currentIndex = 0;
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            launcher.hideLauncher();
                            event.accepted = true;
                            return;
                        }

                        if (event.key === Qt.Key_Down) {
                            list.currentIndex = Math.min(list.currentIndex + 1, list.count - 1);
                            event.accepted = true;
                            return;
                        }

                        if (event.key === Qt.Key_Up) {
                            list.currentIndex = Math.max(list.currentIndex - 1, 0);
                            event.accepted = true;
                            return;
                        }

                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (filteredApps.values.length > 0) {
                                const idx = Math.max(0, Math.min(list.currentIndex, filteredApps.values.length - 1));
                                filteredApps.values[idx].execute();
                                launcher.hideLauncher();
                            }
                            event.accepted = true;
                            return;
                        }
                    }
                }
            }

            Rectangle {
                id: divider
                width: ui.dividerW
                height: ui.searchH
                color: ui.outline
            }

            Rectangle {
                id: searchIcon
                implicitWidth: ui.iconBoxW
                implicitHeight: ui.searchH
                topRightRadius: ui.r
                bottomRightRadius: ui.r
                color: ui.surface

                Text {
                    anchors.fill: parent
                    text: String.fromCodePoint(0xF0C42)
                    font.family: Libs.Theme.uiFont
                    font.pixelSize: 25
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 10
                    color: Libs.Theme.on_primary_container
                }
            }
        }
    }

    // ---- Filtered + ranked model (updates as query.text changes)
    ScriptModel {
        id: filteredApps
        values: {
            const q = (query.text || "").trim();

            // IMPORTANT: empty query => no dropdown at all
            if (q.length === 0)
                return [];

            const all = [...DesktopEntries.applications.values];

            const scored = [];
            for (let i = 0; i < all.length; i++) {
                const e = all[i];
                const s = launcher.fuzzyScore(e.name || "", q);
                if (s >= 0)
                    scored.push({
                        entry: e,
                        score: s
                    });
            }

            scored.sort((a, b) => {
                if (b.score !== a.score)
                    return b.score - a.score;
                const an = (a.entry.name || "").toLowerCase();
                const bn = (b.entry.name || "").toLowerCase();
                if (an < bn)
                    return -1;
                if (an > bn)
                    return 1;
                return 0;
            });

            return scored.map(x => x.entry);
        }
    }

    // ---- Dropdown background (shape)
    Shape {
        id: dropdown
        visible: launcher.hasQuery

        readonly property int visibleRows: Math.min(list.count, ui.maxVisibleRows)
        readonly property real contentH: visibleRows * ui.rowH
        readonly property real dropH: contentH

        x: border.x
        width: border.width
        y: border.y + border.height - ui.r
        height: dropH + ui.r

        antialiasing: true
        z: 0

        ShapePath {
            fillRule: ShapePath.OddEvenFill
            strokeWidth: ui.stroke
            strokeColor: ui.outline
            fillColor: ui.surface

            startX: dropdown.width
            startY: 0

            PathLine {
                x: dropdown.width
                y: dropdown.height - ui.r
            }
            PathArc {
                x: dropdown.width - ui.r
                y: dropdown.height
                radiusX: ui.r
                radiusY: ui.r
                direction: PathArc.Clockwise
            }
            PathLine {
                x: ui.r
                y: dropdown.height
            }
            PathArc {
                x: 0
                y: dropdown.height - ui.r
                radiusX: ui.r
                radiusY: ui.r
                direction: PathArc.Clockwise
            }
            PathLine {
                x: 0
                y: 0
            }

            PathMove {
                x: dropdown.width
                y: 0
            }
            PathArc {
                x: dropdown.width - ui.r
                y: ui.r
                radiusX: ui.r
                radiusY: ui.r
                direction: PathArc.Clockwise
            }
            PathLine {
                x: ui.r
                y: ui.r
            }
            PathArc {
                x: 0
                y: 0
                radiusX: ui.r
                radiusY: ui.r
                direction: PathArc.Clockwise
            }
        }
    }

    // ---- Content overlay
    Rectangle {
        id: listArea
        visible: launcher.hasQuery
        color: "transparent"
        clip: true
        z: dropdown.z + 1

        anchors.left: dropdown.left
        anchors.right: dropdown.right
        anchors.bottom: dropdown.bottom
        anchors.top: dropdown.top
        anchors.topMargin: ui.listTopInset

        ListView {
            id: list
            anchors.fill: parent
            model: filteredApps

            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: 0

            currentIndex: 0
            highlightFollowsCurrentItem: true

            highlight: Rectangle {
                radius: ui.r
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            delegate: Item {
                width: list.width
                height: ui.rowH

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10

                    Text {
                        text: modelData.name
                        color: Libs.Theme.on_primary_container
                        font.family: Libs.Theme.uiFont
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        width: parent.width - dividerRect.width - iconBox.width
                        height: parent.height
                    }

                    Rectangle {
                        id: dividerRect
                        width: ui.dividerW
                        height: parent.height
                        color: ui.outline
                    }

                    Item {
                        id: iconBox
                        width: ui.iconBoxW
                        height: parent.height
                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 25
                            source: Quickshell.iconPath(modelData.icon, true)
                        }
                    }
                }

                Rectangle {
                    height: 1
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    color: ui.outline
                    visible: index < (ListView.view.count - 1)
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        modelData.execute();
                        launcher.hideLauncher();
                    }
                    onEntered: list.currentIndex = index
                }
            }
        }
    }
}
