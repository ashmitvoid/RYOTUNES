pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Ryoku.Ui.Singletons
import "../"
import "../components"
import "../lib/ids.js" as Ids

// The persistent transport, ported from ui/src/lib/components/PlayerBar.svelte. It holds no truth:
// every control is a Playback method (a daemon call) and every readout is Playback state. The two
// exceptions are the design's sanctioned optimism — the held seek thumb (Playback.seekDrag) and the
// volume slider while dragged (Playback.volDrag) — so a mid-drag daemon echo can never yank either
// out from under the pointer. Queue / Lyrics / Now-Playing / mini toggles raise signals the App
// owns; their surfaces arrive in later tasks.
Rectangle {
    id: root

    signal toggleQueue()
    signal toggleLyrics()
    signal toggleNowPlaying()
    signal miniClicked()
    property bool queueOpen: false
    property bool lyricsOpen: false
    property bool nowPlayingOpen: false

    // Volume level to return to when un-muting (mute is just volume 0).
    property int preMute: 100

    readonly property var now: Playback.now
    readonly property bool live: !Playback.paused && !!Playback.now
    readonly property bool hasYouTubeTrack: !!Playback.now
        && !Ids.isLocalId(Playback.now.videoId) && !Ids.isRadioId(Playback.now.videoId)
    readonly property bool isRadioNow: !!Playback.now && Ids.isRadioId(Playback.now.videoId)
    readonly property bool autoplayTrack: {
        var q = Playback.queue;
        var cur = (q && q.items) ? q.items[q.currentIndex] : null;
        return !!(cur && cur.autoplay && Playback.now && cur.video_id === Playback.now.videoId);
    }

    implicitHeight: Style.sp(15)
    color: Tokens.paper

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

    function nudgeVolume(delta) {
        var v = Math.max(0, Math.min(100, Playback.volume + delta));
        Playback.volume = v;
        Playback.setVolume(v);
        volSettle.restart();
    }

    // Persist the level once a run of wheel notches settles (one fsync per gesture, like the Svelte).
    Timer {
        id: volSettle
        interval: 400
        onTriggered: Daemon.call("set_setting", { key: "volume", value: String(Playback.volume) }).catch(() => {})
    }

    Hairline { anchors.top: parent.top; width: parent.width; height: 1 }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.sp(6)
        anchors.rightMargin: Style.sp(6)
        spacing: Style.sp(4)

        // ── now playing (left) ───────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            spacing: Style.sp(3)

            Artwork {
                url: root.now && root.now.thumbnail ? root.now.thumbnail : ""
                px: Style.sp(12)
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.sp(1.5)
                    Text {
                        Layout.fillWidth: true
                        text: root.now && root.now.title ? root.now.title : "Nothing playing"
                        color: Tokens.ink
                        font.family: Style.fontUi
                        font.pixelSize: Style.fs.md
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: !!Playback.pendingVideoId
                        text: "RESOLVING"
                        color: Tokens.inkFaint
                        font.family: Style.fontMono
                        font.pixelSize: Style.fs.xs
                        font.letterSpacing: 1
                    }
                    Icon {
                        visible: root.autoplayTrack
                        name: "infinity"
                        size: Style.fs.sm
                        color: Tokens.inkMuted
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: root.now && root.now.artists ? root.now.artists : ""
                    color: Tokens.inkMuted
                    font.family: Style.fontUi
                    font.pixelSize: Style.fs.sm
                    elide: Text.ElideRight
                }
            }

            IconButton {
                visible: root.hasYouTubeTrack
                icon: "heart"
                iconSize: Style.fs.md
                diameter: Style.sp(8)
                active: Playback.rating === "like"
                iconColor: Playback.rating === "like" ? Tokens.sun : Tokens.inkMuted
                onClicked: root.toggleLike()
            }
        }

        // ── transport + seek (centre) ────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1.5
            Layout.maximumWidth: Style.sp(120)
            spacing: Style.sp(1)

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Style.sp(1)
                IconButton {
                    icon: "shuffle"
                    iconSize: Style.fs.md
                    diameter: Style.sp(8)
                    active: !!(Playback.queue && Playback.queue.shuffle)
                    onClicked: Playback.toggleShuffle()
                }
                IconButton {
                    icon: "previous"
                    iconSize: Style.fs.lg
                    diameter: Style.sp(8)
                    onClicked: Playback.prev()
                }
                IconButton {
                    icon: Playback.paused ? "play" : "pause"
                    iconSize: Style.fs.lg
                    diameter: Style.sp(9)
                    primary: true
                    onClicked: Playback.togglePause()
                }
                IconButton {
                    icon: "next"
                    iconSize: Style.fs.lg
                    diameter: Style.sp(8)
                    onClicked: Playback.next()
                }
                IconButton {
                    icon: (Playback.queue && Playback.queue.repeat === "one") ? "repeat-one" : "repeat"
                    iconSize: Style.fs.md
                    diameter: Style.sp(8)
                    active: !!(Playback.queue && Playback.queue.repeat && Playback.queue.repeat !== "off")
                    onClicked: Playback.cycleRepeat()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.sp(2)
                Text {
                    text: Style.fmtTime(Playback.shownPosition)
                    color: Tokens.inkFaint
                    font.family: Style.fontMono
                    font.pixelSize: Style.fs.xs
                }

                // The wave seek: a flat rest line, a sine played portion clipped to the elapsed
                // fraction, a thumb, and a visuals-off Slider on top for the drag itself.
                Item {
                    id: seek
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    implicitHeight: Style.sp(4)
                    readonly property real pct: seekSlider.pct
                    property var wavePts: buildWave(width, height)

                    function buildWave(w, h) {
                        var pts = [];
                        if (w <= 0)
                            return pts;
                        var amp = h * 0.32;
                        var mid = h / 2;
                        var period = Style.sp(4);
                        for (var x = 0; x <= w; x += 2)
                            pts.push(Qt.point(x, mid - amp * Math.sin((2 * Math.PI * x) / period)));
                        return pts;
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: seek.width * seek.pct
                        width: Math.max(0, seek.width * (1 - seek.pct))
                        height: 1
                        color: Tokens.lineStrong
                    }

                    Item {
                        width: seek.width * seek.pct
                        height: parent.height
                        clip: true
                        Shape {
                            width: seek.width
                            height: seek.height
                            ShapePath {
                                strokeColor: root.live ? Tokens.sun : Tokens.ink
                                strokeWidth: 1.5
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                joinStyle: ShapePath.RoundJoin
                                PathPolyline { path: seek.wavePts }
                            }
                        }
                    }

                    Rectangle {
                        width: Style.sp(2.5)
                        height: width
                        radius: width / 2
                        color: Tokens.ink
                        anchors.verticalCenter: parent.verticalCenter
                        x: seek.width * seek.pct - width / 2
                    }

                    Slider {
                        id: seekSlider
                        anchors.fill: parent
                        visualTrack: false
                        from: 0
                        to: Playback.duration > 0 ? Playback.duration : 1
                        value: Playback.shownPosition
                        onMoved: (v) => Playback.seekDrag = v
                        onCommitted: (v) => { Playback.seek(v); Playback.seekDrag = NaN; }
                    }
                }

                Text {
                    text: Style.fmtTime(Playback.duration)
                    color: Tokens.inkFaint
                    font.family: Style.fontMono
                    font.pixelSize: Style.fs.xs
                }
            }
        }

        // ── volume + surface toggles (right) ─────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            layoutDirection: Qt.RightToLeft
            spacing: Style.sp(1)

            IconButton {
                icon: root.nowPlayingOpen ? "arrow-down" : "arrow-up"
                iconSize: Style.fs.lg
                diameter: Style.sp(8)
                onClicked: root.toggleNowPlaying()
            }
            IconButton {
                icon: "queue"
                iconSize: Style.fs.lg
                diameter: Style.sp(8)
                active: root.queueOpen
                onClicked: root.toggleQueue()
            }
            IconButton {
                icon: "mic"
                iconSize: Style.fs.lg
                diameter: Style.sp(8)
                enabled: !root.isRadioNow
                active: root.lyricsOpen
                onClicked: root.toggleLyrics()
            }
            IconButton {
                icon: "minimize"
                iconSize: Style.fs.lg
                diameter: Style.sp(8)
                onClicked: root.miniClicked()
            }

            Item { Layout.preferredWidth: Style.sp(2) }

            // volume group
            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: Style.sp(1)
                layoutDirection: Qt.LeftToRight

                IconButton {
                    icon: Playback.volume === 0 ? "volume-mute" : "volume"
                    iconSize: Style.fs.md
                    diameter: Style.sp(8)
                    onClicked: root.toggleMute()
                }
                Slider {
                    id: volSlider
                    Layout.preferredWidth: Style.sp(24)
                    Layout.alignment: Qt.AlignVCenter
                    from: 0
                    to: 100
                    value: Playback.volume
                    onPressedChanged: Playback.volDrag = pressed
                    onMoved: (v) => {
                        var iv = Math.round(v);
                        Playback.volume = iv;
                        Playback.setVolume(iv);
                    }
                    onCommitted: (v) => {
                        var iv = Math.round(v);
                        Playback.volume = iv;
                        Playback.setVolume(iv);
                        Daemon.call("set_setting", { key: "volume", value: String(iv) }).catch(() => {});
                        Playback.volDrag = false;
                    }
                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: (e) => root.nudgeVolume(e.angleDelta.y > 0 ? 5 : -5)
                    }
                }
            }
        }
    }
}
