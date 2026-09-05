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
    // Full-variant extras (opt-in so the compact Home shelves are unchanged): the play count from
    // an album page, the album-track number layout with no cover, the ⋯ menu and its two
    // context-specific items. `menuRequested` carries scene coords for the list's shared Menu.
    property bool showPlayCount: false
    property bool hideThumb: false
    property bool menu: false
    property bool canAdd: false
    property bool canRemove: false
    property string removeLabel: "Remove from playlist"
    signal play()
    signal menuRequested(real sx, real sy)

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
        id: playArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: root.menu ? (Qt.LeftButton | Qt.RightButton) : Qt.LeftButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                var p = playArea.mapToItem(null, mouse.x, mouse.y);
                root.menuRequested(p.x, p.y);
                return;
            }
            root.play();
        }
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

        // thumbnail (album track lists hide it — the number is the identity there)
        Artwork {
            visible: !root.hideThumb
            Layout.preferredWidth: root.hideThumb ? 0 : Style.sp(10)
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

        // compact: single like heart
        IconButton {
            visible: root.compact && root.canRate
            icon: "heart"
            iconSize: Style.fs.md
            diameter: Style.sp(8)
            active: root.rated === "like"
            iconColor: root.rated === "like" ? Tokens.sun : Tokens.inkMuted
            onClicked: root.toggleLike()
        }

        // full: play count, explicit mark, like, duration
        Text {
            visible: !root.compact && root.showPlayCount && !!(root.song && root.song.play_count)
            text: (root.song && root.song.play_count) ? (root.song.play_count + " plays") : ""
            color: Tokens.inkFaint
            font.family: Style.fontMono
            font.pixelSize: Style.fs.xs
        }
        Rectangle {
            visible: !root.compact && !!(root.song && root.song.explicit)
            implicitWidth: Style.sp(4)
            implicitHeight: Style.sp(4)
            radius: Style.sp(1)
            color: "transparent"
            border.width: 1
            border.color: Tokens.inkFaint
            Text {
                anchors.centerIn: parent
                text: "E"
                color: Tokens.inkMuted
                font.family: Style.fontUi
                font.pixelSize: Style.fs.xs
                font.weight: Font.DemiBold
            }
        }
        IconButton {
            visible: !root.compact && root.canRate
            icon: "heart"
            iconSize: Style.fs.md
            diameter: Style.sp(8)
            opacity: (rowHover.hovered || root.rated === "like") ? 1 : 0
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

        // ⋯ options trigger (opt-in). Three dots drawn inline — the icon set has no ellipsis glyph.
        Item {
            id: menuBtn
            visible: root.menu
            Layout.preferredWidth: root.menu ? Style.sp(8) : 0
            Layout.preferredHeight: Style.sp(8)
            Rectangle {
                anchors.fill: parent
                radius: Style.radius
                color: menuHover.hovered ? Tokens.tint5 : "transparent"
            }
            Row {
                anchors.centerIn: parent
                spacing: Style.sp(0.75)
                Repeater {
                    model: 3
                    delegate: Rectangle {
                        width: Math.max(2, Style.sp(0.75))
                        height: width
                        radius: width / 2
                        color: menuHover.hovered ? Tokens.ink : Tokens.inkMuted
                    }
                }
            }
            HoverHandler { id: menuHover }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var p = menuBtn.mapToItem(null, 0, menuBtn.height);
                    root.menuRequested(p.x, p.y);
                }
            }
        }
    }

    HoverHandler { id: rowHover }
}
