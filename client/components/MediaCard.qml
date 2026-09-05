pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Ryoku.Ui.Singletons
import "../"
import "../lib/ids.js" as Ids
import "../lib/browse.js" as Browse

// A shelf card, ported from MediaCard.svelte. Square artwork (a circle for an artist), title and
// subtitle, and a hover-revealed play button on everything but an artist. A primary click opens the
// item (a song plays; a collection routes to its page); the play button plays the whole thing
// without leaving Home. Hover is a Tokens.tint5 wash and the button's fade — no transform scaling,
// which the CSS build dropped for scroll cost anyway.
Item {
    id: root

    property var item: null
    property int cardWidth: Style.sp(40)
    readonly property bool round: root.item && root.item.kind === "artist"

    width: cardWidth
    implicitHeight: col.implicitHeight

    function open() {
        if (!root.item)
            return;
        if (root.item.kind === "song")
            Playback.play(Browse.asSong(root.item));
        else
            Router.push(root.item.kind, { id: root.item.id, title: root.item.title });
    }

    function playNow() {
        var it = root.item;
        if (!it)
            return;
        if (it.kind === "song") {
            Playback.play(Browse.asSong(it));
            return;
        }
        if (it.kind === "album") {
            Daemon.call("get_album", { id: it.id })
                .then((a) => Daemon.call("play_playlist", { items: a.items, sourceId: a.playlistId, sourceName: it.title }))
                .catch(() => Playback.toast("Could not play — try opening it", "error"));
        } else {
            Daemon.call("get_playlist", { id: it.id })
                .then((p) => Daemon.call("play_playlist", {
                    items: p.items,
                    sourceId: Ids.isSmartPlaylistId(it.id) ? undefined : it.id,
                    sourceName: it.title,
                    continuation: p.continuation
                }))
                .catch(() => Playback.toast("Could not play — try opening it", "error"));
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -Style.sp(1.5)
        radius: Style.radius
        z: -1
        color: cardHover.hovered ? Tokens.tint5 : "transparent"
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.open()
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: Style.sp(2)

        Item {
            Layout.fillWidth: true
            implicitHeight: width

            Artwork {
                anchors.fill: parent
                url: root.item && root.item.thumbnail ? root.item.thumbnail : ""
                px: root.cardWidth
                round: root.round
                placeholderIcon: root.round ? "user"
                    : (root.item && Ids.isOnRepeatId(root.item.id)) ? "on-repeat" : "music"
            }

            Rectangle {
                visible: !root.round && cardHover.hovered
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Style.sp(2)
                width: Style.sp(9)
                height: width
                radius: Style.radius
                color: Tokens.paper
                border.width: 1
                border.color: Tokens.line
                Icon {
                    anchors.centerIn: parent
                    name: "play"
                    size: Style.fs.md
                    color: Tokens.ink
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.playNow()
                }
            }
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: root.round ? Text.AlignHCenter : Text.AlignLeft
            text: root.item ? root.item.title : ""
            color: Tokens.ink
            font.family: Style.fontUi
            font.pixelSize: Style.fs.md
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true
            visible: !!(root.item && root.item.subtitle)
            horizontalAlignment: root.round ? Text.AlignHCenter : Text.AlignLeft
            text: root.item && root.item.subtitle ? root.item.subtitle : ""
            color: Tokens.inkMuted
            font.family: Style.fontUi
            font.pixelSize: Style.fs.sm
            elide: Text.ElideRight
        }
    }

    HoverHandler { id: cardHover }
}
