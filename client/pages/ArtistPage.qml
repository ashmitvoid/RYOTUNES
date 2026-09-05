pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Ryoku.Ui.Singletons
import "../"
import "../components"

// The artist page, ported from ui/src/routes/artist/[id]/+page.svelte. get_artist(id) once; the
// page is one TrackList whose header is the photo hero (name, counts, Shuffle / Radio / Subscribe)
// and the "Top songs" heading, whose rows are topSongs, and whose footer is the card carousels
// (music-video shelves filtered out, matching supportedSection). Shuffle prefers the full top-songs
// playlist (topSongsId) so it covers more than the five visible rows.
Item {
    id: page

    readonly property var params: Router.current ? Router.current.params : ({})
    readonly property string artistId: page.params && page.params.id ? page.params.id : ""

    property var artist: null
    property bool loading: true
    property string errorMsg: ""
    property bool expanded: false
    property bool subscribed: false
    property bool subBusy: false

    readonly property bool signedIn: !!(Playback.auth && Playback.auth.signedIn)
    readonly property var sections: {
        if (!page.artist || !page.artist.sections)
            return [];
        return page.artist.sections.filter((s) => !/music\s*videos?|video\s+for\s+you/i.test(s.title));
    }

    onParamsChanged: page.load()
    Component.onCompleted: page.load()

    function asItem() {
        return {
            kind: "artist",
            id: page.artistId,
            title: page.artist ? page.artist.name : "Artist",
            subtitle: page.artist ? page.artist.subscribers : "",
            thumbnail: page.artist ? page.artist.thumbnail : ""
        };
    }

    function load() {
        if (!page.artistId)
            return;
        page.loading = true;
        page.errorMsg = "";
        page.expanded = false;
        var reqId = page.artistId;
        Daemon.call("get_artist", { id: page.artistId })
            .then((a) => {
                if (page.artistId !== reqId)
                    return;
                page.artist = a;
                page.subscribed = !!a.subscribed;
                page.loading = false;
            })
            .catch((e) => {
                if (page.artistId !== reqId)
                    return;
                page.errorMsg = (e && e.message) ? e.message : String(e);
                page.loading = false;
            });
    }

    function playTop(start) {
        if (!page.artist || !page.artist.topSongs.length)
            return;
        Daemon.call("play_playlist", {
            items: page.artist.topSongs,
            start: start,
            sourceName: page.artist.name
        }).catch((e) => Playback.toast((e && e.message) ? e.message : "Could not play", "error"));
    }
    function shuffle() {
        if (!page.artist)
            return;
        var pid = page.artist.topSongsId;
        if (pid) {
            Daemon.call("get_playlist", { id: pid })
                .then((pl) => {
                    if (pl.items && pl.items.length)
                        return Daemon.call("play_playlist", {
                            items: pl.items, start: null, sourceId: pid,
                            sourceName: page.artist.name, shuffle: true, continuation: pl.continuation
                        });
                    return page.shuffleVisible();
                })
                .catch((e) => Playback.toast((e && e.message) ? e.message : "Could not play", "error"));
            return;
        }
        page.shuffleVisible();
    }
    function shuffleVisible() {
        if (!page.artist || !page.artist.topSongs.length)
            return Promise.resolve();
        return Daemon.call("play_playlist", {
            items: page.artist.topSongs, start: null, sourceName: page.artist.name, shuffle: true
        });
    }
    function radio() {
        Playback.toast("Starting radio…", "info");
        Daemon.call("start_radio", { kind: "artist", id: page.artistId, name: page.artist ? page.artist.name : null })
            .catch((e) => Playback.toast((e && e.message) ? e.message : "Could not start radio", "error"));
    }
    function toggleSub() {
        if (!page.artist || page.subBusy)
            return;
        if (!page.signedIn) {
            Playback.toast("Sign in to subscribe", "info");
            return;
        }
        var next = !page.subscribed;
        page.subBusy = true;
        page.subscribed = next;
        Daemon.call("subscribe", { channelId: page.artist.channelId, subscribed: next })
            .then(() => { page.subBusy = false; Playback.toast(next ? ("Subscribed to " + (page.artist.name || "")) : "Unsubscribed", "success"); })
            .catch((e) => {
                page.subscribed = !next;
                page.subBusy = false;
                Playback.toast((e && e.message) ? e.message : "Could not subscribe", "error");
            });
    }
    function share() {
        var url = "https://music.youtube.com/channel/" + encodeURIComponent(page.artistId);
        Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy", "sh", url]);
        Playback.toast("Link copied", "success");
    }
    function showMore(section) {
        Router.push("list", { id: section.moreBrowseId, title: section.title, params: section.moreParams });
    }
    function seeAllTop() {
        if (page.artist && page.artist.topSongsId)
            Router.push("playlist", { id: page.artist.topSongsId, title: "Top songs" });
    }
    function displaySectionTitle(title) {
        var name = page.artist && page.artist.name ? page.artist.name.trim() : "";
        if (name && title.trim().toLowerCase() === name.toLowerCase())
            return "More like " + name;
        return title;
    }

    Rectangle { anchors.fill: parent; color: Tokens.paper }

    Text {
        anchors.centerIn: parent
        visible: page.loading || page.errorMsg !== ""
        text: page.loading ? "Loading artist…" : page.errorMsg
        color: Tokens.inkMuted
        font.family: Style.fontUi
        font.pixelSize: Style.fs.md
    }

    TrackList {
        id: body
        anchors.fill: parent
        visible: !page.loading && page.errorMsg === "" && page.artist !== null
        items: (page.artist && page.artist.topSongs) ? page.artist.topSongs : []
        showPlayCount: true
        source: page.artist ? page.artist.name : ""
        onActivated: (i) => page.playTop(i)
        header: artistHeader
        footer: artistFooter
    }

    Component {
        id: artistHeader
        Item {
            width: body.view.width
            implicitHeight: Style.sp(70) + topHeadingWrap.implicitHeight + Style.sp(6)

            // photo hero
            Item {
                id: hero
                width: parent.width
                height: Style.sp(70)
                clip: true
                Image {
                    anchors.fill: parent
                    source: (page.artist && page.artist.thumbnail) ? Style.thumb(page.artist.thumbnail, 640) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    visible: !!(page.artist && page.artist.thumbnail)
                }
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, 0.25) }
                        GradientStop { position: 1.0; color: Tokens.paper }
                    }
                }
                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Style.sp(8)
                    anchors.rightMargin: Style.sp(8)
                    anchors.bottomMargin: Style.sp(6)
                    spacing: Style.sp(2)
                    Text {
                        Layout.fillWidth: true
                        text: (page.artist && page.artist.name) ? page.artist.name : ""
                        color: Tokens.ink
                        font.family: Tokens.display
                        font.pixelSize: Style.fs.hero
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: !!(page.artist && (page.artist.subscribers || page.artist.monthlyListeners))
                        text: {
                            var a = page.artist;
                            if (!a) return "";
                            var parts = [];
                            if (a.subscribers) parts.push(a.subscribers);
                            if (a.monthlyListeners) parts.push(a.monthlyListeners);
                            return parts.join("  ·  ");
                        }
                        color: Tokens.inkMuted
                        font.family: Style.fontUi
                        font.pixelSize: Style.fs.sm
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: !!(page.artist && page.artist.description)
                        spacing: Style.sp(1)
                        Text {
                            Layout.fillWidth: true
                            Layout.maximumWidth: Style.sp(150)
                            text: (page.artist && page.artist.description) ? page.artist.description : ""
                            color: Tokens.inkDim
                            font.family: Style.fontUi
                            font.pixelSize: Style.fs.sm
                            wrapMode: Text.WordWrap
                            maximumLineCount: page.expanded ? 999 : 2
                            elide: Text.ElideRight
                        }
                        Text {
                            text: page.expanded ? "LESS" : "MORE"
                            color: descHover.hovered ? Tokens.ink : Tokens.inkMuted
                            font.family: Style.fontMono
                            font.pixelSize: Style.fs.xs
                            HoverHandler { id: descHover }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.expanded = !page.expanded }
                        }
                    }
                    RowLayout {
                        Layout.topMargin: Style.sp(1)
                        spacing: Style.sp(3)
                        Pill {
                            label: "Shuffle"; icon: "shuffle"; primary: true
                            enabled: !!(page.artist && page.artist.topSongs && page.artist.topSongs.length)
                            onClicked: page.shuffle()
                        }
                        Pill { label: "Radio"; icon: "radio"; onClicked: page.radio() }
                        Pill {
                            label: !page.signedIn ? "Save to library" : (page.subscribed ? "Subscribed" : "Subscribe")
                            icon: page.subscribed ? "check-circle" : "add"
                            active: page.subscribed
                            enabled: !page.subBusy
                            onClicked: page.toggleSub()
                        }
                        Item {
                            id: artistMenuBtn
                            implicitWidth: Style.sp(10); implicitHeight: Style.sp(10)
                            Rectangle { anchors.fill: parent; radius: width / 2; color: aHover.hovered ? Tokens.tint5 : "transparent"; border.width: 1; border.color: Tokens.line }
                            Row {
                                anchors.centerIn: parent
                                spacing: Style.sp(0.75)
                                Repeater { model: 3; delegate: Rectangle { width: Math.max(2, Style.sp(0.75)); height: width; radius: width / 2; color: aHover.hovered ? Tokens.ink : Tokens.inkMuted } }
                            }
                            HoverHandler { id: aHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var p = artistMenuBtn.mapToItem(page, 0, artistMenuBtn.height);
                                    artistMenu.openAt(p.x, p.y);
                                }
                            }
                        }
                    }
                }
            }

            // "Top songs" heading (above the rows)
            Item {
                id: topHeadingWrap
                anchors.top: hero.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: Style.sp(5)
                implicitHeight: (page.artist && page.artist.topSongs && page.artist.topSongs.length) ? topHeading.implicitHeight : 0
                visible: !!(page.artist && page.artist.topSongs && page.artist.topSongs.length)
                SectionHeading {
                    id: topHeading
                    x: Style.sp(8)
                    width: parent.width - Style.sp(16)
                    title: "Top songs"
                    icon: "music"
                    more: !!(page.artist && page.artist.topSongsId)
                    onMoreClicked: page.seeAllTop()
                }
            }
        }
    }

    Component {
        id: artistFooter
        Item {
            width: body.view.width
            implicitHeight: page.sections.length ? (footerCol.implicitHeight + Style.sp(24)) : Style.sp(20)
            ColumnLayout {
                id: footerCol
                x: Style.sp(8)
                width: parent.width - Style.sp(16)
                y: Style.sp(9)
                spacing: Style.sp(9)
                visible: page.sections.length > 0
                Repeater {
                    model: page.sections
                    delegate: Shelf {
                        required property var modelData
                        Layout.fillWidth: true
                        section: {
                            return { title: page.displaySectionTitle(modelData.title), items: modelData.items,
                                moreBrowseId: modelData.moreBrowseId, moreParams: modelData.moreParams };
                        }
                    }
                }
            }
        }
    }

    Menu {
        id: artistMenu
        customItems: [
            { icon: "dashboard", label: "Add to shortcuts", danger: false, act: () => page.addArtistShortcut() },
            { icon: "link", label: "Share", danger: false, act: () => page.share() }
        ]
    }

    // Personal-store action (Task 4b): pin this artist to the Home shortcuts grid. Wired by PersonalStore.
    function addArtistShortcut() {
        Playback.toast(Personal.addPick(page.asItem()) ? "Added to shortcuts" : "Already in shortcuts", "success");
    }
}
