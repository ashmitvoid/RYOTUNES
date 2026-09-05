pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Ryoku.Ui.Singletons
import "../"
import "../lib/ids.js" as Ids

// A track row, ported from TrackRow.svelte. The whole row is the play target; the leading slot
// shows the track number, swapping to a play glyph on hover. The compact variant (Home's song
// shelves and Forgotten favourites) folds the duration onto the artist line and keeps a single like
// heart. Rating is optimistic and hidden for local files and radio, which YouTube cannot rate.
Rectangle {
    id: root

    property var song: null
    property int index: -1
    property bool active: false
    property bool compact: false
    signal play()

    // Seeded from the row's own snapshot; a rating call updates it optimistically. Reset when the
    // delegate is reused for a different song.
    property string rated: (song && song.rating) ? song.rating : "indifferent"
    onSongChanged: rated = (song && song.rating) ? song.rating : "indifferent"

    readonly property bool canRate: !!song && !Ids.isLocalId(song.video_id) && !Ids.isRadioId(song.video_id)
    readonly property string duration: (song && song.duration && /^[\d:]+$/.test(song.duration)) ? song.duration : ""

    implicitHeight: Style.sp(11)
    radius: Style.radius
    color: root.active ? Tokens.tint10 : rowHover.hovered ? Tokens.tint5 : "transparent"

    function toggleLike() {
        if (!root.canRate || !root.song)
            return;
        var next = root.rated === "like" ? "indifferent" : "like";
        root.rated = next;
        Daemon.call("rate", { videoId: root.song.video_id, rating: next })
            .catch((e) => Playback.toast((e && e.message) ? e.message : "Could not rate", "error"));
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.play()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.sp(2)
        anchors.rightMargin: Style.sp(2)
        spacing: Style.sp(3)

        // index / play-on-hover
        Item {
            visible: root.index >= 0
            Layout.preferredWidth: root.index >= 0 ? Style.sp(5) : 0
            Layout.preferredHeight: Style.sp(5)
            Text {
                anchors.centerIn: parent
                visible: !rowHover.hovered
                text: root.index + 1
                color: root.active ? Tokens.sun : Tokens.inkMuted
                font.family: Style.fontMono
                font.pixelSize: Style.fs.sm
            }
            Icon {
                anchors.centerIn: parent
                visible: rowHover.hovered
                name: "play"
                size: Style.fs.sm
                color: Tokens.ink
            }
        }

        // thumbnail
        Artwork {
            url: root.song && root.song.thumbnail ? root.song.thumbnail : ""
            px: Style.sp(10)
        }

        // title + artist(+duration)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: root.song ? root.song.title : ""
                color: root.active ? Tokens.sun : Tokens.ink
                font.family: Style.fontUi
                font.pixelSize: Style.fs.md
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: {
                    var a = root.song && root.song.artists ? root.song.artists : "";
                    return (root.compact && root.duration) ? (a + " · " + root.duration) : a;
                }
                color: Tokens.inkMuted
                font.family: Style.fontUi
                font.pixelSize: Style.fs.sm
                elide: Text.ElideRight
            }
        }

        // like (compact) or duration (full)
        IconButton {
            visible: root.compact && root.canRate
            icon: "heart"
            iconSize: Style.fs.md
            diameter: Style.sp(8)
            active: root.rated === "like"
            iconColor: root.rated === "like" ? Tokens.sun : Tokens.inkMuted
            onClicked: root.toggleLike()
        }
        Text {
            visible: !root.compact && root.duration !== ""
            text: root.duration
            color: Tokens.inkFaint
            font.family: Style.fontMono
            font.pixelSize: Style.fs.sm
        }
    }

    HoverHandler { id: rowHover }
}
