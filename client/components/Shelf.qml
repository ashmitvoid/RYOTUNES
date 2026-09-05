pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../"
import "../lib/browse.js" as Browse

// A horizontal shelf, ported from Shelf.svelte. It picks a form from what it holds: a "mostly songs"
// shelf becomes columns of four readable rows paged sideways; everything else is a row of cards
// (artists drawn as circles by MediaCard). The rail is a reused horizontal ListView with a bounded
// cache, so a long feed of shelves never mounts more than a couple of screenfuls of delegates.
ColumnLayout {
    id: root

    property var section: null
    readonly property var items: (section && section.items) ? section.items : []
    readonly property string mode: Browse.shelfMode(items)
    readonly property var songs: mode === "song" ? items.filter((i) => i.kind === "song") : []
    readonly property var columns: mode === "song" ? Browse.columnize(songs, 4) : []
    readonly property string icon: mode === "song" ? "music"
        : mode === "album" ? "cd"
        : mode === "artist" ? "artists"
        : mode === "playlist" ? "playlist" : ""

    spacing: Style.sp(3)

    function playFromShelf(start) {
        Daemon.call("play_playlist", {
            items: root.songs.map(Browse.asSong),
            start: start,
            sourceName: root.section ? root.section.title : null
        }).catch((e) => Playback.toast((e && e.message) ? e.message : "Could not play", "error"));
    }

    SectionHeading {
        Layout.fillWidth: true
        title: root.section ? root.section.title : ""
        icon: root.icon
        more: !!(root.section && root.section.moreBrowseId)
        onMoreClicked: Router.push("list", {
            id: root.section.moreBrowseId,
            title: root.section.title,
            params: root.section.moreParams
        })
    }

    ListView {
        id: rail
        Layout.fillWidth: true
        Layout.preferredHeight: root.mode === "song" ? Style.sp(48) : Style.sp(66)
        orientation: ListView.Horizontal
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        snapMode: ListView.SnapOneItem
        reuseItems: true
        clip: true
        cacheBuffer: Math.round(width)
        spacing: root.mode === "song" ? Style.sp(6) : Style.sp(3)
        model: root.mode === "song" ? root.columns : root.items
        delegate: root.mode === "song" ? songColumn : cardDelegate
    }

    Component {
        id: cardDelegate
        MediaCard {
            required property var modelData
            item: modelData
            cardWidth: Style.sp(40)
        }
    }

    Component {
        id: songColumn
        Item {
            id: colItem
            required property var modelData
            required property int index
            width: Style.sp(80)
            height: ListView.view ? ListView.view.height : 0

            ColumnLayout {
                anchors.fill: parent
                spacing: Style.sp(0.5)

                Repeater {
                    model: colItem.modelData
                    delegate: Item {
                        id: rowWrap
                        required property var modelData
                        required property int index
                        readonly property int globalIndex: colItem.index * 4 + index
                        Layout.fillWidth: true
                        implicitHeight: songRow.implicitHeight

                        TrackRow {
                            id: songRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            song: rowWrap.modelData
                            index: rowWrap.globalIndex
                            compact: true
                            active: !!(Playback.now && rowWrap.modelData
                                && Playback.now.videoId === rowWrap.modelData.video_id)
                            onPlay: root.playFromShelf(rowWrap.globalIndex)
                        }
                    }
                }
            }
        }
    }
}
