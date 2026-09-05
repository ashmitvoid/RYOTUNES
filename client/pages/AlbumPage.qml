pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Ryoku.Ui.Singletons
import "../"
import "../components"
import "../lib/ids.js" as Ids

// The album page, ported from ui/src/routes/album/[id]/+page.svelte. get_album(id) once; the whole
// page is one TrackList scroller whose header carries the hero (cover, artist, controls, filter)
// and whose footer carries the card carousels YouTube hangs under the tracks. Play/Shuffle seed the
// queue with the full album (never just the filtered rows); a local album has no YouTube identity,
// so save/radio/share hide for it. The two personal actions are wired by the personal store.
Item {
    id: page

    readonly property var params: Router.current ? Router.current.params : ({})
    readonly property string albumId: page.params && page.params.id ? page.params.id : ""

    property var album: null
    property bool loading: true
    property string errorMsg: ""
    property string query: ""
    property bool expanded: false
    property bool savingLibrary: false

    readonly property bool isLocal: Ids.isLocalId(page.albumId)
    readonly property var shown: {
        if (!page.album || !page.album.items)
            return [];
        var q = page.query.trim().toLowerCase();
        if (!q)
            return page.album.items;
        return page.album.items.filter((t) => (
            (t.title && t.title.toLowerCase().indexOf(q) >= 0)
            || (t.artists && t.artists.toLowerCase().indexOf(q) >= 0)
            || (t.album && t.album.toLowerCase().indexOf(q) >= 0)));
    }
    readonly property bool inLibrary: !!(page.album && page.album.inLibrary)

    onParamsChanged: page.load()
    Component.onCompleted: page.load()

    function asItem() {
        return {
            kind: page.albumId.indexOf("LOCALARTIST:") === 0 ? "artist" : "album",
            id: page.albumId,
            title: page.album ? page.album.title : "Album",
            subtitle: page.album ? page.album.artist : "",
            thumbnail: page.album ? page.album.thumbnail : "",
            explicit: page.album ? page.album.explicit : false
        };
    }

    function load() {
        if (!page.albumId)
            return;
        page.loading = true;
        page.errorMsg = "";
        page.query = "";
        page.expanded = false;
        var reqId = page.albumId;
        Daemon.call("get_album", { id: page.albumId })
            .then((a) => {
                if (page.albumId !== reqId)
                    return;
                page.album = a;
                page.loading = false;
            })
            .catch((e) => {
                if (page.albumId !== reqId)
                    return;
                page.errorMsg = (e && e.message) ? e.message : String(e);
                page.loading = false;
            });
    }

    function playAll(start) {
        if (!page.album)
            return;
        var at = start === null ? null : page.album.items.indexOf(page.shown[start]);
        Daemon.call("play_playlist", {
            items: page.album.items,
            start: at === -1 ? null : at,
            sourceId: page.album.playlistId ? page.album.playlistId : undefined,
            sourceName: page.album.title
        }).catch((e) => Playback.toast((e && e.message) ? e.message : "Could not play", "error"));
    }
    function shuffle() {
        if (!page.album || !page.album.items.length)
            return;
        Daemon.call("play_playlist", {
            items: page.album.items,
            start: null,
            sourceId: page.album.playlistId ? page.album.playlistId : undefined,
            sourceName: page.album.title,
            shuffle: true
        }).catch((e) => Playback.toast((e && e.message) ? e.message : "Could not play", "error"));
    }
    function queueAlbum(next) {
        if (!page.album || !page.album.items.length)
            return;
        Daemon.call(next ? "play_next" : "add_to_queue", {
            items: page.album.items,
            from: page.album.title,
            continuation: page.album.continuation
        }).then(() => Playback.toast(next ? "Playing next" : "Added to queue", "success"))
            .catch((e) => Playback.toast((e && e.message) ? e.message : "Could not queue", "error"));
    }
    function radio() {
        if (!page.album || !page.album.playlistId)
            return;
        Playback.toast("Starting radio…", "info");
        Daemon.call("start_radio", { kind: "playlist", id: page.album.playlistId, name: page.album.title })
            .catch((e) => Playback.toast((e && e.message) ? e.message : "Could not start radio", "error"));
    }
    function toggleLibrary() {
        if (!page.album || page.savingLibrary || page.isLocal)
            return;
        if (!page.album.playlistId || !(Playback.auth && Playback.auth.signedIn)) {
            Playback.toast("Sign in to save albums to your library", "info");
            return;
        }
        var next = !page.inLibrary;
        page.album = Object.assign({}, page.album, { inLibrary: next });
        page.savingLibrary = true;
        Daemon.call("set_album_saved", { playlistId: page.album.playlistId, saved: next })
            .then(() => { page.savingLibrary = false; Playback.toast(next ? "Saved to library" : "Removed from library", "success"); })
            .catch((e) => {
                page.album = Object.assign({}, page.album, { inLibrary: !next });
                page.savingLibrary = false;
                Playback.toast((e && e.message) ? e.message : "Could not save", "error");
            });
    }
    function share() {
        var url = "https://music.youtube.com/browse/" + encodeURIComponent(page.albumId);
        Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy", "sh", url]);
        Playback.toast("Link copied", "success");
    }
    function showMore(section) {
        Router.push("list", { id: section.moreBrowseId, title: section.title, params: section.moreParams });
    }

    Rectangle { anchors.fill: parent; color: Tokens.paper }

    // loading / error
    Text {
        anchors.centerIn: parent
        visible: page.loading || page.errorMsg !== ""
        text: page.loading ? "Loading album…" : page.errorMsg
        color: Tokens.inkMuted
        font.family: Style.fontUi
        font.pixelSize: Style.fs.md
    }

    TrackList {
        id: body
        anchors.fill: parent
        visible: !page.loading && page.errorMsg === "" && page.album !== null
        items: page.shown
        hideThumb: true
        showPlayCount: true
        canAdd: !page.isLocal
        source: page.album ? page.album.title : ""
        onActivated: (i) => page.playAll(i)
        header: albumHeader
        footer: albumFooter
    }

    Component {
        id: albumHeader
        Item {
            width: body.view.width
            implicitHeight: headerCol.implicitHeight + Style.sp(10)

            // faint cover wash
            Image {
                anchors.fill: parent
                source: (page.album && page.album.thumbnail) ? Style.thumb(page.album.thumbnail, 96) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                opacity: 0.22
                visible: !!(page.album && page.album.thumbnail)
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Tokens.paper }
                }
            }

            // filter box (top-right)
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: Style.sp(8)
                anchors.topMargin: Style.sp(6)
                width: Style.sp(56)
                implicitHeight: Style.sp(9)
                radius: Style.radius
                color: Tokens.paperLift
                border.width: 1
                border.color: albumFilter.activeFocus ? Tokens.lineStrong : Tokens.line
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.sp(2)
                    anchors.rightMargin: Style.sp(2)
                    spacing: Style.sp(2)
                    Icon { name: "search"; size: Style.fs.sm; color: Tokens.inkMuted }
                    TextInput {
                        id: albumFilter
                        Layout.fillWidth: true
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        color: Tokens.ink
                        font.family: Style.fontUi
                        font.pixelSize: Style.fs.sm
                        text: page.query
                        onTextChanged: page.query = text
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: albumFilter.text.length === 0
                            text: "Search this album"
                            color: Tokens.inkFaint
                            font: albumFilter.font
                        }
                    }
                }
            }

            ColumnLayout {
                id: headerCol
                x: Style.sp(8)
                width: parent.width - Style.sp(16)
                y: Style.sp(9)
                spacing: Style.sp(4)

                // hero row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.sp(5)
                    Artwork {
                        url: (page.album && page.album.thumbnail) ? page.album.thumbnail : ""
                        px: Style.sp(28)
                        placeholderIcon: "cd"
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignBottom
                        spacing: Style.sp(1)
                        Text {
                            text: (page.album && page.album.subtitle) ? page.album.subtitle : "Album"
                            color: Tokens.inkMuted
                            font.family: Style.fontMono
                            font.pixelSize: Style.fs.xs
                            font.letterSpacing: 1
                        }
                        Text {
                            Layout.fillWidth: true
                            text: (page.album && page.album.title) ? page.album.title : "Album"
                            color: Tokens.ink
                            font.family: Tokens.display
                            font.pixelSize: Style.fs.hero
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.sp(2)
                            Rectangle {
                                visible: !!(page.album && page.album.explicit)
                                implicitWidth: Style.sp(4.5); implicitHeight: Style.sp(4.5)
                                radius: Style.sp(1); color: "transparent"
                                border.width: 1; border.color: Tokens.inkMuted
                                Text { anchors.centerIn: parent; text: "E"; color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.xs; font.weight: Font.DemiBold }
                            }
                            Text {
                                visible: !!(page.album && page.album.artist)
                                text: (page.album && page.album.artist) ? page.album.artist : ""
                                color: artistHover.hovered ? Tokens.ink : Tokens.inkDim
                                font.family: Style.fontUi
                                font.pixelSize: Style.fs.md
                                font.weight: Font.Medium
                                HoverHandler { id: artistHover; enabled: !!(page.album && page.album.artistId) }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !!(page.album && page.album.artistId)
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Router.push("artist", { id: page.album.artistId })
                                }
                            }
                            Text {
                                visible: !!(page.album && page.album.secondSubtitle)
                                text: (page.album && page.album.secondSubtitle) ? ("· " + page.album.secondSubtitle) : ""
                                color: Tokens.inkMuted
                                font.family: Style.fontUi
                                font.pixelSize: Style.fs.sm
                            }
                        }
                    }
                }

                // description
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: !!(page.album && page.album.description)
                    spacing: Style.sp(1)
                    Text {
                        Layout.fillWidth: true
                        Layout.maximumWidth: Style.sp(150)
                        text: (page.album && page.album.description) ? page.album.description : ""
                        color: Tokens.inkDim
                        font.family: Style.fontUi
                        font.pixelSize: Style.fs.sm
                        wrapMode: Text.WordWrap
                        maximumLineCount: page.expanded ? 999 : 2
                        elide: Text.ElideRight
                    }
                    Text {
                        text: page.expanded ? "LESS" : "MORE"
                        color: moreHover.hovered ? Tokens.ink : Tokens.inkMuted
                        font.family: Style.fontMono
                        font.pixelSize: Style.fs.xs
                        HoverHandler { id: moreHover }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.expanded = !page.expanded }
                    }
                }

                // controls
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.sp(3)
                    Pill {
                        label: "Play"; icon: "play"; primary: true
                        enabled: !!(page.album && page.album.items && page.album.items.length)
                        onClicked: page.playAll(null)
                    }
                    Pill {
                        label: "Shuffle"; icon: "shuffle"
                        enabled: !!(page.album && page.album.items && page.album.items.length)
                        onClicked: page.shuffle()
                    }
                    Pill {
                        visible: !page.isLocal
                        label: page.inLibrary ? "In library" : "Save to library"
                        icon: "add"
                        active: page.inLibrary
                        enabled: !page.savingLibrary
                        onClicked: page.toggleLibrary()
                    }
                    Item {
                        id: albumMenuBtn
                        implicitWidth: Style.sp(10); implicitHeight: Style.sp(10)
                        Rectangle { anchors.fill: parent; radius: width / 2; color: amHover.hovered ? Tokens.tint5 : "transparent"; border.width: 1; border.color: Tokens.line }
                        Row {
                            anchors.centerIn: parent
                            spacing: Style.sp(0.75)
                            Repeater { model: 3; delegate: Rectangle { width: Math.max(2, Style.sp(0.75)); height: width; radius: width / 2; color: amHover.hovered ? Tokens.ink : Tokens.inkMuted } }
                        }
                        HoverHandler { id: amHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var p = albumMenuBtn.mapToItem(page, 0, albumMenuBtn.height);
                                albumMenu.openAt(p.x, p.y);
                            }
                        }
                    }
                }

                Hairline { Layout.fillWidth: true; Layout.topMargin: Style.sp(2) }
            }
        }
    }

    Component {
        id: albumFooter
        Item {
            width: body.view.width
            implicitHeight: (page.album && page.album.sections && page.album.sections.length)
                ? (footerCol.implicitHeight + Style.sp(24)) : Style.sp(20)
            ColumnLayout {
                id: footerCol
                x: Style.sp(8)
                width: parent.width - Style.sp(16)
                y: Style.sp(6)
                spacing: Style.sp(9)
                visible: !!(page.album && page.album.sections && page.album.sections.length)
                Repeater {
                    model: (page.album && page.album.sections) ? page.album.sections : []
                    delegate: Shelf {
                        required property var modelData
                        Layout.fillWidth: true
                        section: modelData
                    }
                }
            }
        }
    }

    // header ⋯ menu (album-level). Custom items operate on the whole album; "Add to shortcuts" is
    // the personal-store pin the PersonalStore agent wires (Task 4b, Step 3).
    Menu {
        id: albumMenu
        customItems: page.buildAlbumMenu()
    }
    AddToPlaylist { id: albumPicker }

    function buildAlbumMenu() {
        var out = [];
        out.push({ icon: "arrow-up", label: "Play next", danger: false, act: () => page.queueAlbum(true) });
        out.push({ icon: "queue", label: "Add to queue", danger: false, act: () => page.queueAlbum(false) });
        if (!page.isLocal && page.album && page.album.playlistId)
            out.push({ icon: "radio", label: "Start radio", danger: false, act: () => page.radio() });
        if (!page.isLocal)
            out.push({ icon: "add", label: "Save to playlist", danger: false,
                act: () => albumPicker.openWith(page.album ? page.album.items : []) });
        out.push({ icon: "dashboard", label: "Add to shortcuts", danger: false, act: () => page.addAlbumShortcut() });
        if (!page.isLocal)
            out.push({ icon: "link", label: "Share", danger: false, act: () => page.share() });
        return out;
    }

    // Personal-store action (Task 4b): pin this album to the Home shortcuts grid. Wired by PersonalStore.
    function addAlbumShortcut() {
        Playback.toast(Personal.addPick(page.asItem()) ? "Added to shortcuts" : "Already in shortcuts", "success");
    }
}
