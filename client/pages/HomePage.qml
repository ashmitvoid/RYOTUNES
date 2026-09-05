pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Ryoku.Ui.Singletons
import "../"
import "../components"
import "../chrome"
import "../lib/browse.js" as Browse

// Home, ported from ui/src/routes/+page.svelte. One vertical reused ListView of shelves; the header
// carries the greeting, the mood-chip rail, the Shortcuts pinboard and (when the feed supplies it)
// the Forgotten favourites block; the footer carries the loading skeletons, empty/error states and
// the progressive get_home_more pagination. get_home_more fires when the tail comes within 400 px of
// the viewport bottom, exactly like the Svelte sentinel. Every list is a ListView with reuseItems
// and a bounded cache, so scrolling a long feed never mounts more than a screenful or two.
Item {
    id: page

    property var home: null
    property var chips: []
    property var forgotten: null
    property string selected: ""
    property bool loading: true
    property string errorMsg: ""
    property bool loadingMore: false
    property bool moreError: false
    property var blocks: []

    readonly property int pad: Style.sp(8)

    Component.onCompleted: page.load("")

    function greeting() {
        var h = new Date().getHours();
        return h < 5 ? "Still up" : h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : h < 22 ? "Good evening" : "Good night";
    }

    function isForgotten(s) {
        if (!/forgotten/i.test(s.title))
            return false;
        for (var i = 0; i < s.items.length; i++)
            if (s.items[i].kind === "song")
                return true;
        return false;
    }

    function rebuild() {
        var arr = [];
        var fg = null;
        var secs = (page.home && page.home.sections) ? page.home.sections : [];
        for (var i = 0; i < secs.length; i++) {
            if (page.isForgotten(secs[i])) {
                if (!fg)
                    fg = secs[i];
            } else {
                arr.push(secs[i]);
            }
        }
        page.forgotten = fg;
        page.blocks = arr;
    }

    function forgottenSongs() {
        if (!page.forgotten)
            return [];
        return page.forgotten.items.filter((i) => i.kind === "song").slice(0, 15);
    }

    function playForgotten(start) {
        var songs = page.forgottenSongs();
        Daemon.call("play_playlist", {
            items: songs.map(Browse.asSong),
            start: start,
            sourceName: page.forgotten ? page.forgotten.title : null
        }).catch((e) => Playback.toast((e && e.message) ? e.message : "Could not play", "error"));
    }

    function load(params) {
        page.selected = params;
        page.loading = true;
        page.errorMsg = "";
        page.moreError = false;
        Daemon.call("get_home", { params: params ? params : null })
            .then((h) => {
                if (page.selected !== params)
                    return;
                page.home = h;
                if (h.chips && h.chips.length)
                    page.chips = h.chips.filter((c) => c.title !== "Podcasts");
                page.rebuild();
                page.loading = false;
                list.positionViewAtBeginning();
            })
            .catch((e) => {
                if (page.selected !== params)
                    return;
                page.errorMsg = (e && e.message) ? e.message : String(e);
                page.loading = false;
            });
    }

    function loadMore() {
        if (!page.home || !page.home.continuation || page.loadingMore || page.moreError)
            return;
        page.loadingMore = true;
        var token = page.home.continuation;
        var params = page.selected;
        Daemon.call("get_home_more", { token: token })
            .then((more) => {
                if (page.selected !== params || !page.home || page.home.continuation !== token)
                    return;
                page.home = {
                    chips: page.home.chips,
                    sections: page.home.sections.concat(more.sections),
                    continuation: more.sections.length ? more.continuation : undefined
                };
                page.rebuild();
                page.loadingMore = false;
            })
            .catch(() => {
                page.moreError = true;
                page.loadingMore = false;
                Playback.toast("Could not load more", "error");
            });
    }

    function maybeLoadMore() {
        if (!page.home || !page.home.continuation || page.loadingMore || page.moreError)
            return;
        if (list.contentHeight <= 0)
            return;
        if (list.contentY + list.height > list.contentHeight - 400)
            page.loadMore();
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        reuseItems: true
        cacheBuffer: Math.round(height * 1.5)
        boundsBehavior: Flickable.StopAtBounds
        model: page.blocks
        spacing: Style.sp(9)
        onContentYChanged: page.maybeLoadMore()
        onContentHeightChanged: page.maybeLoadMore()

        delegate: Item {
            required property var modelData
            width: list.width
            implicitHeight: shelf.implicitHeight
            Shelf {
                id: shelf
                x: page.pad
                width: parent.width - page.pad * 2
                section: parent.modelData
            }
        }

        header: Item {
            width: list.width
            implicitHeight: headerCol.implicitHeight + Style.sp(9)

            ColumnLayout {
                id: headerCol
                x: page.pad
                width: parent.width - page.pad * 2
                y: Style.sp(6)
                spacing: Style.sp(5)

                // hero
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.sp(2)
                    RowLayout {
                        spacing: Style.sp(2)
                        Rectangle { Layout.preferredWidth: Style.sp(4); Layout.preferredHeight: 1; Layout.alignment: Qt.AlignVCenter; color: Tokens.ink }
                        Text { text: "聴"; color: Tokens.ink; font.family: Tokens.jp; font.pixelSize: Style.fs.sm }
                        Rectangle { Layout.preferredWidth: Style.sp(13); Layout.preferredHeight: 1; Layout.alignment: Qt.AlignVCenter; color: Tokens.lineSoft }
                        Text {
                            text: "RYOKU // MUSIC"
                            color: Tokens.inkFaint
                            font.family: Style.fontMono
                            font.pixelSize: Style.fs.xs
                            font.letterSpacing: 1
                        }
                    }
                    Text {
                        text: page.greeting() + ((Playback.auth && Playback.auth.signedIn && Playback.auth.name) ? (", " + Playback.auth.name) : "")
                        color: Tokens.ink
                        font.family: Tokens.display
                        font.pixelSize: Style.fs.hero
                    }
                    Text {
                        text: "Pick up where you left off, or let the feed find you something new."
                        color: Tokens.inkMuted
                        font.family: Style.fontUi
                        font.pixelSize: Style.fs.md
                    }
                }

                // chip rail
                Flickable {
                    Layout.fillWidth: true
                    implicitHeight: chipRow.implicitHeight
                    contentWidth: chipRow.implicitWidth
                    contentHeight: chipRow.implicitHeight
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    visible: page.chips.length > 0
                    Row {
                        id: chipRow
                        spacing: Style.sp(2)
                        Chip {
                            text: "All"
                            active: page.selected === ""
                            onClicked: page.load("")
                        }
                        Repeater {
                            model: page.chips
                            delegate: Chip {
                                required property var modelData
                                text: modelData.title
                                active: page.selected === modelData.params
                                onClicked: page.load(page.selected === modelData.params ? "" : modelData.params)
                            }
                        }
                    }
                }

                // shortcuts (unfiltered only)
                Shortcuts {
                    Layout.fillWidth: true
                    visible: page.selected === ""
                }

                // forgotten favourites
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: !!page.forgotten
                    spacing: Style.sp(3)
                    SectionHeading {
                        Layout.fillWidth: true
                        title: page.forgotten ? page.forgotten.title : ""
                        icon: "clock"
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.sp(6)
                        Repeater {
                            model: 3
                            delegate: ColumnLayout {
                                id: fgCol
                                required property int index
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                spacing: Style.sp(0.5)
                                Repeater {
                                    model: {
                                        var songs = page.forgottenSongs();
                                        var per = Math.ceil(songs.length / 3);
                                        return songs.slice(fgCol.index * per, fgCol.index * per + per);
                                    }
                                    delegate: Item {
                                        id: fgRow
                                        required property var modelData
                                        required property int index
                                        readonly property int per: Math.ceil(page.forgottenSongs().length / 3)
                                        readonly property int globalIndex: fgCol.index * per + index
                                        Layout.fillWidth: true
                                        implicitHeight: fgTrack.implicitHeight
                                        TrackRow {
                                            id: fgTrack
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            song: fgRow.modelData
                                            compact: true
                                            active: !!(Playback.now && fgRow.modelData
                                                && Playback.now.videoId === fgRow.modelData.video_id)
                                            onPlay: page.playForgotten(fgRow.globalIndex)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Hairline { Layout.fillWidth: true }
            }
        }

        footer: Item {
            width: list.width
            implicitHeight: footerCol.implicitHeight + Style.sp(20)

            ColumnLayout {
                id: footerCol
                x: page.pad
                width: parent.width - page.pad * 2
                y: Style.sp(4)
                spacing: Style.sp(9)

                // loading skeletons
                Repeater {
                    model: page.loading ? 3 : 0
                    delegate: ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.sp(3)
                        Skeleton { Layout.preferredWidth: Style.sp(40); Layout.preferredHeight: Style.sp(4) }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.sp(3)
                            Repeater {
                                model: 6
                                delegate: Skeleton {
                                    required property int index
                                    Layout.preferredWidth: Style.sp(40)
                                    Layout.preferredHeight: Style.sp(50)
                                }
                            }
                        }
                    }
                }

                // error
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    visible: !page.loading && page.errorMsg !== ""
                    spacing: Style.sp(2)
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: page.errorMsg
                        color: Tokens.inkMuted
                        font.family: Style.fontUi
                        font.pixelSize: Style.fs.md
                    }
                    Chip {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Try again"
                        onClicked: page.load(page.selected)
                    }
                }

                // empty
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Style.sp(16)
                    visible: !page.loading && page.errorMsg === "" && page.blocks.length === 0 && !page.forgotten
                    spacing: Style.sp(3)
                    Icon { Layout.alignment: Qt.AlignHCenter; name: "music"; size: Style.fs.hero; color: Tokens.inkFaint }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: Style.sp(90)
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: (Playback.auth && Playback.auth.signedIn)
                            ? "Your home feed came back empty this time."
                            : "Sign in and home fills up with mixes and playlists built from what you listen to."
                        color: Tokens.inkMuted
                        font.family: Style.fontUi
                        font.pixelSize: Style.fs.md
                    }
                    Chip {
                        Layout.alignment: Qt.AlignHCenter
                        text: (Playback.auth && Playback.auth.signedIn) ? "Try again" : "Sign in with Google"
                        active: !(Playback.auth && Playback.auth.signedIn)
                        onClicked: (Playback.auth && Playback.auth.signedIn)
                            ? page.load(page.selected)
                            : Daemon.call("sign_in").catch(() => {})
                    }
                }

                // load-more affordance
                Chip {
                    Layout.alignment: Qt.AlignHCenter
                    visible: !page.loading && !!(page.home && page.home.continuation) && page.moreError
                    text: page.loadingMore ? "Loading…" : "Try again"
                    onClicked: { page.moreError = false; page.loadMore(); }
                }
            }
        }
    }
}
