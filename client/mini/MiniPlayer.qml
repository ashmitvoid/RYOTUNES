pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Ryoku.Ui.Singletons
import "../"
import "../components"
import "../chrome"
import "../lib/ids.js" as Ids

// The mini player, ported from ui/src/lib/components/MiniPlayer.svelte. It lives in its own
// "Ryotunes Mini" FloatingWindow (shell.qml) and, like every surface, holds no truth: it renders
// Playback state and calls Playback methods. Three tabs — Now / Lyrics / Queue — reuse the same
// LyricsPanel and TrackList the main window uses. The lyrics word-timer is gated on this surface's
// real visibility (`active`, bound to the window) AND the lyrics tab, so a hidden or backgrounded
// mini never wakes it. Seek/volume share Playback.seekDrag/volDrag with the main PlayerBar.
Item {
    id: root

    // True only while the mini window is actually mapped; gates the lyrics timer off when hidden.
    property bool active: true
    // Raised when the user asks to return to the full window.
    signal maximize()

    property string view: "now"   // "now" | "lyrics" | "queue"
    property int preMute: 100

    readonly property var now: Playback.now
    readonly property bool hasYouTubeTrack: !!Playback.now
        && !Ids.isLocalId(Playback.now.videoId) && !Ids.isRadioId(Playback.now.videoId)
    readonly property var nextUp: {
        var q = Playback.queue;
        return (q && q.items) ? (q.items[q.currentIndex + 1] || null) : null;
    }

    function toggleLike() {
        var n = Playback.now;
        if (!n || !root.hasYouTubeTrack)
            return;
        var next = Playback.rating === "like" ? "indifferent" : "like";
        Playback.rating = next;
        Daemon.call("rate", { videoId: n.videoId, rating: next })
            .catch((e) => Playback.toast((e && e.message) ? e.message : "Could not rate", "error"));
    }
    function toggleMute() {
        var muted = Playback.volume === 0;
        if (!muted)
            root.preMute = Playback.volume;
        var v = muted ? (root.preMute || 100) : 0;
        Playback.volume = v;
        Playback.setVolume(v);
        Daemon.call("set_setting", { key: "volume", value: String(v) }).catch(() => {});
    }

    Rectangle { anchors.fill: parent; color: Tokens.paper }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── header: brand + tabs + like + maximize ──────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Style.sp(3)
            Layout.rightMargin: Style.sp(2)
            Layout.topMargin: Style.sp(2)
            Layout.bottomMargin: Style.sp(1)
            spacing: Style.sp(1)

            Text { text: "力"; color: Tokens.inkMuted; font.family: Tokens.jp; font.pixelSize: Style.fs.sm }
            Text {
                text: "RYOTUNES"
                color: Tokens.inkDim; font.family: Style.fontUi; font.pixelSize: Style.fs.xs; font.weight: Font.DemiBold; font.letterSpacing: 1.4
            }
            Item { Layout.preferredWidth: Style.sp(2) }
            IconButton { icon: "music"; iconSize: Style.fs.md; diameter: Style.sp(7); active: root.view === "now"; onClicked: root.view = "now" }
            IconButton { icon: "mic"; iconSize: Style.fs.md; diameter: Style.sp(7); active: root.view === "lyrics"; onClicked: root.view = "lyrics" }
            IconButton { icon: "queue"; iconSize: Style.fs.md; diameter: Style.sp(7); active: root.view === "queue"; onClicked: root.view = "queue" }
            Item { Layout.fillWidth: true }
            IconButton {
                visible: root.hasYouTubeTrack
                icon: "heart"; iconSize: Style.fs.md; diameter: Style.sp(7)
                active: Playback.rating === "like"
                iconColor: Playback.rating === "like" ? Tokens.sun : Tokens.inkMuted
                onClicked: root.toggleLike()
            }
            IconButton { icon: "rail-expand"; iconSize: Style.fs.md; diameter: Style.sp(7); onClicked: root.maximize() }
        }

        Hairline { Layout.fillWidth: true }

        // ── content (one of the three tabs) ─────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // NOW
            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.sp(4)
                anchors.rightMargin: Style.sp(4)
                anchors.topMargin: Style.sp(3)
                anchors.bottomMargin: Style.sp(2)
                visible: root.view === "now"
                spacing: Style.sp(2)

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignHCenter
                    Artwork {
                        anchors.centerIn: parent
                        url: (root.now && root.now.thumbnail) ? root.now.thumbnail : ""
                        px: Math.max(Style.sp(28), Math.min(parent.width, parent.height))
                    }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: (root.now && root.now.title) ? root.now.title : "Nothing playing"
                    color: Tokens.ink; font.family: Style.fontUi; font.pixelSize: Style.fs.md; font.weight: Font.DemiBold; elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: (root.now && root.now.artists) ? root.now.artists : "Ryotunes is ready"
                    color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; elide: Text.ElideRight
                }

                // seek
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.sp(2)
                    Text { text: Style.fmtTime(Playback.shownPosition); color: Tokens.inkFaint; font.family: Style.fontMono; font.pixelSize: Style.fs.xs }
                    Slider {
                        id: miniSeek
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        from: 0
                        to: Playback.duration > 0 ? Playback.duration : 1
                        value: Playback.shownPosition
                        fillColor: (!Playback.paused && !!Playback.now) ? Tokens.sun : Tokens.ink
                        onMoved: (v) => Playback.seekDrag = v
                        onCommitted: (v) => { Playback.seek(v); Playback.seekDrag = NaN; }
                    }
                    Text { text: Style.fmtTime(Playback.duration); color: Tokens.inkFaint; font.family: Style.fontMono; font.pixelSize: Style.fs.xs }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.sp(1)
                    Icon { name: "queue"; size: Style.fs.xs; color: Tokens.inkFaint }
                    Text {
                        Layout.fillWidth: true
                        text: root.nextUp ? ("NEXT · " + root.nextUp.title) : "QUEUE · END"
                        color: Tokens.inkFaint; font.family: Style.fontMono; font.pixelSize: Style.fs.xs; elide: Text.ElideRight
                    }
                }
            }

            // LYRICS — reused chrome panel; timer gated on this surface's real visibility
            LyricsPanel {
                anchors.fill: parent
                compact: true
                visible: root.view === "lyrics" && root.active
            }

            // QUEUE
            TrackList {
                anchors.fill: parent
                visible: root.view === "queue"
                items: (Playback.queue && Playback.queue.items) ? Playback.queue.items : []
                menu: false
                canAdd: false
                onActivated: (i) => Playback.playIndex(i)
            }
        }

        Hairline { Layout.fillWidth: true }

        // ── footer: transport + volume ──────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Style.sp(3)
            Layout.rightMargin: Style.sp(3)
            Layout.topMargin: Style.sp(1.5)
            Layout.bottomMargin: Style.sp(2)
            spacing: Style.sp(1)

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Style.sp(1)
                IconButton {
                    icon: "shuffle"; iconSize: Style.fs.md; diameter: Style.sp(8)
                    active: !!(Playback.queue && Playback.queue.shuffle)
                    onClicked: Playback.toggleShuffle()
                }
                IconButton { icon: "previous"; iconSize: Style.fs.lg; diameter: Style.sp(8); onClicked: Playback.prev() }
                IconButton { icon: Playback.paused ? "play" : "pause"; iconSize: Style.fs.lg; diameter: Style.sp(9); primary: true; onClicked: Playback.togglePause() }
                IconButton { icon: "next"; iconSize: Style.fs.lg; diameter: Style.sp(8); onClicked: Playback.next() }
                IconButton {
                    icon: (Playback.queue && Playback.queue.repeat === "one") ? "repeat-one" : "repeat"
                    iconSize: Style.fs.md; diameter: Style.sp(8)
                    active: !!(Playback.queue && Playback.queue.repeat && Playback.queue.repeat !== "off")
                    onClicked: Playback.cycleRepeat()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.sp(2)
                IconButton {
                    icon: Playback.volume === 0 ? "volume-mute" : "volume"
                    iconSize: Style.fs.md; diameter: Style.sp(7)
                    onClicked: root.toggleMute()
                }
                Slider {
                    id: miniVol
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    from: 0
                    to: 100
                    value: Playback.volume
                    onPressedChanged: Playback.volDrag = pressed
                    onMoved: (v) => { var iv = Math.round(v); Playback.volume = iv; Playback.setVolume(iv); }
                    onCommitted: (v) => {
                        var iv = Math.round(v);
                        Playback.volume = iv;
                        Playback.setVolume(iv);
                        Daemon.call("set_setting", { key: "volume", value: String(iv) }).catch(() => {});
                        Playback.volDrag = false;
                    }
                }
            }
        }
    }
}
