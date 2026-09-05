pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Ryoku.Ui.Singletons
import "../"
import "../components"

// The Now Playing surface, ported from ui/src/lib/components/NowPlaying.svelte (tabbed mode). It is
// artwork-first: the playing cover fills the left column over a single blurred wash of a 64 px source
// (the one MultiEffect this surface spends, gated on Style.blurEnabled), and the right column carries
// the Queue / Lyrics tabs. It holds no state of its own beyond the flash on the artwork; the open
// state and active tab are App's three flags (nowPlayingOpen / queueOpen / lyricsOpen), which it
// reads through bound properties and writes back through tabRequested / closeRequested so the player
// bar toggles and this surface stay in lockstep. Both panels stay instantiated across a tab switch
// (their timers gate on visible) so the lyrics keep their scroll and the queue its position.
Item {
    id: root

    // App's coupling flags, one-way in; writes go back as signals so App owns the mutation.
    property bool nowPlayingOpen: false
    property bool queueOpen: false
    property bool lyricsOpen: false
    signal tabRequested(string tab)
    signal closeRequested()

    readonly property bool open: root.nowPlayingOpen || root.queueOpen || root.lyricsOpen
    readonly property string tab: root.lyricsOpen ? "lyrics" : "queue"
    readonly property bool previewVisible: root.width > Style.sp(200)

    visible: root.open && !!Playback.now

    // --- artwork play/pause flash -----------------------------------------------------------
    property string flash: ""
    Timer { id: flashTimer; interval: 240; onTriggered: root.flash = "" }
    function toggle() {
        root.flash = Playback.paused ? "play" : "pause";
        flashTimer.restart();
        Playback.togglePause();
    }

    // Opaque base + click swallow, so the routed page behind never takes a stray click.
    Rectangle {
        anchors.fill: parent
        color: Tokens.paper
        MouseArea { anchors.fill: parent }
    }

    // The wash: a 64 px cover stretched to fill and blurred once. Static between track changes.
    Image {
        id: washSource
        anchors.fill: parent
        source: (Playback.now && Playback.now.thumbnail) ? Style.thumb(Playback.now.thumbnail, 64) : ""
        sourceSize: Qt.size(64, 64)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: washSource
        visible: Style.blurEnabled && washSource.status === Image.Ready
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        opacity: 0.28
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Style.sp(4)
        spacing: Style.sp(4)

        // ── artwork preview (left) ──────────────────────────────────────────────────────
        Item {
            id: previewCell
            visible: root.previewVisible
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 5

            Text {
                id: previewHead
                anchors.top: parent.top
                anchors.left: parent.left
                text: "// LIVE PREVIEW"
                color: Tokens.inkFaint
                font.family: Style.fontMono
                font.pixelSize: Style.fs.xs
                font.letterSpacing: 1.3
            }
            Text {
                anchors.top: parent.top
                anchors.right: parent.right
                text: "PLAYBACK · LOCAL"
                color: Tokens.inkFaint
                font.family: Style.fontMono
                font.pixelSize: Style.fs.xs
                font.letterSpacing: 1.3
            }

            Item {
                id: artHolder
                anchors.top: previewHead.bottom
                anchors.topMargin: Style.sp(2)
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                Artwork {
                    id: bigArt
                    anchors.centerIn: parent
                    px: Math.max(Style.sp(30), Math.min(artHolder.width, artHolder.height))
                    url: (Playback.now && Playback.now.thumbnail) ? Playback.now.thumbnail : ""
                    placeholderIcon: "music"

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggle()
                    }

                    // Flash the action taken, over the cover, so the click visibly did something.
                    Rectangle {
                        anchors.centerIn: parent
                        visible: root.flash !== ""
                        width: Style.sp(14)
                        height: width
                        radius: width / 2
                        color: Qt.rgba(0, 0, 0, 0.55)
                        Icon {
                            anchors.centerIn: parent
                            name: root.flash === "play" ? "play" : "pause"
                            size: Style.fs.xl
                            color: "#ffffff"
                        }
                    }
                }
            }
        }

        // ── detail column (right) ───────────────────────────────────────────────────────
        Rectangle {
            id: detailCell
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 7
            radius: Style.radiusCard
            color: Tokens.paper
            border.width: 1
            border.color: Tokens.line

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Style.sp(2)
                spacing: Style.sp(2)

                // Tab strip + close ------------------------------------------------------
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.sp(2)

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: Style.sp(9)
                        radius: Style.radius
                        color: Tokens.paperLift
                        border.width: 1
                        border.color: Tokens.line
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Style.sp(0.75)
                            spacing: Style.sp(0.75)
                            Repeater {
                                model: [
                                    { key: "queue", label: "Queue", icon: "queue" },
                                    { key: "lyrics", label: "Lyrics", icon: "mic" }
                                ]
                                delegate: Rectangle {
                                    id: tabBtn
                                    required property var modelData
                                    readonly property bool selected: root.tab === tabBtn.modelData.key
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: Style.radius - 1
                                    color: tabBtn.selected ? Tokens.bone
                                        : (tabHover.hovered ? Tokens.tint5 : "transparent")
                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: Style.sp(1.5)
                                        Icon {
                                            name: tabBtn.modelData.icon
                                            size: Style.fs.sm
                                            color: tabBtn.selected ? Tokens.inkOnBone : Tokens.inkMuted
                                        }
                                        Text {
                                            text: tabBtn.modelData.label
                                            color: tabBtn.selected ? Tokens.inkOnBone : Tokens.inkMuted
                                            font.family: Style.fontUi
                                            font.pixelSize: Style.fs.sm
                                            font.weight: Font.Medium
                                        }
                                    }
                                    HoverHandler { id: tabHover }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.tabRequested(tabBtn.modelData.key)
                                    }
                                }
                            }
                        }
                    }

                    IconButton {
                        icon: "arrow-down"
                        iconSize: Style.fs.lg
                        diameter: Style.sp(9)
                        onClicked: root.closeRequested()
                    }
                }

                // Panels (both kept alive across tab switches) ---------------------------
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    QueuePanel {
                        anchors.fill: parent
                        visible: root.tab === "queue"
                    }
                    LyricsPanel {
                        anchors.fill: parent
                        visible: root.tab === "lyrics"
                    }
                }
            }
        }
    }
}
