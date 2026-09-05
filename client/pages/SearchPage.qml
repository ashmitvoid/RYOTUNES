pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Ryoku.Ui.Singletons
import "../"
import "../components"
import "../chrome"
import "../lib/browse.js" as Browse

// The search page, ported from ui/src/routes/search/+page.svelte. The field runs one mixed page
// (search_all) plus one songs page (search_page) in parallel, then lays the result out as the same
// categorised sections the Svelte page has — Top (4), Songs (6), Albums (5), Artists (3), Playlists
// (5) — each with a "Show more" that expands that category in place (search_cards / search_page_more,
// the folded-in search-more route). The SearchSuggest typeahead handles quick keyboard navigation.
Item {
    id: page

    property string query: ""
    property var res: null
    property var songs: []
    property string searched: ""
    property bool searching: false
    property string errorMsg: ""
    property var history: []
    property string latest: ""

    // expanded category ("" = the sections view)
    property string expandedCat: ""
    property var expandedItems: []
    property string expandedCont: ""
    property bool expandedLoading: false

    // A ?q= arrival (the Ctrl+K palette's "All results", or a card's search intent) runs the search.
    readonly property var params: Router.current ? Router.current.params : ({})
    onParamsChanged: page.applyParams()
    Component.onCompleted: page.applyParams()
    function applyParams() {
        if (page.params && page.params.q && page.params.q !== page.searched) {
            page.query = page.params.q;
            page.runSearch();
        }
    }

    readonly property var songRows: {
        var s = page.songs.length ? page.songs : ((page.res && page.res.songs) ? page.res.songs.map(Browse.asSong) : []);
        return s.filter((song) => !song.is_video);
    }
    readonly property var sections: {
        if (!page.res)
            return [];
        var out = [
            { key: "top", label: "Top results", items: page.res.top, max: 4, more: false, list: false },
            { key: "songs", label: "Songs", items: page.res.songs, max: 6, more: true, list: true },
            { key: "albums", label: "Albums", items: page.res.albums, max: 5, more: true, list: false },
            { key: "artists", label: "Artists", items: page.res.artists, max: 3, more: true, list: false },
            { key: "playlists", label: "Playlists", items: page.res.playlists, max: 5, more: true, list: false }
        ];
        return out.filter((s) => s.list ? page.songRows.length : (s.items && s.items.length));
    }

    function rememberQuery(q) {
        if (!q)
            return;
        var next = [q];
        for (var i = 0; i < page.history.length; i++)
            if (page.history[i].toLowerCase() !== q.toLowerCase())
                next.push(page.history[i]);
        page.history = next.slice(0, 6);
    }

    function runSearch() {
        var q = page.query.trim().replace(/\s+/g, " ");
        if (!q)
            return;
        page.latest = q;
        page.searched = q;
        page.expandedCat = "";
        page.rememberQuery(q);
        if (!page.res || page.searched !== q)
            page.searching = true;
        page.errorMsg = "";
        Promise.all([
            Daemon.call("search_all", { query: q }),
            Daemon.call("search_page", { query: q }).catch(() => ({ items: [] }))
        ]).then((r) => {
            if (page.latest !== q)
                return;
            page.res = r[0];
            page.songs = r[1].items || [];
            page.searched = q;
            page.searching = false;
        }).catch((e) => {
            if (page.latest !== q)
                return;
            page.errorMsg = (e && e.message) ? e.message : String(e);
            page.searching = false;
        });
    }

    function playSong(song) {
        Playback.play(song).catch((e) => Playback.toast((e && e.message) ? e.message : "Could not play", "error"));
    }

    function showMore(sec) {
        page.expandedCat = sec.key;
        page.expandedItems = [];
        page.expandedCont = "";
        page.expandedLoading = true;
        if (sec.key === "songs") {
            Daemon.call("search_page", { query: page.searched })
                .then((r) => { page.expandedItems = (r.items || []).filter((s) => !s.is_video); page.expandedCont = r.continuation || ""; page.expandedLoading = false; })
                .catch(() => page.expandedLoading = false);
        } else {
            Daemon.call("search_cards", { query: page.searched, category: sec.key })
                .then((items) => { page.expandedItems = items || []; page.expandedLoading = false; })
                .catch(() => page.expandedLoading = false);
        }
    }
    function loadMoreExpanded() {
        if (page.expandedCat !== "songs" || !page.expandedCont || page.expandedLoading)
            return;
        page.expandedLoading = true;
        var token = page.expandedCont;
        Daemon.call("search_page_more", { token: token })
            .then((r) => {
                page.expandedItems = page.expandedItems.concat((r.items || []).filter((s) => !s.is_video));
                page.expandedCont = r.continuation || "";
                page.expandedLoading = false;
            })
            .catch(() => page.expandedLoading = false);
    }

    Rectangle { anchors.fill: parent; color: Tokens.paper }

    readonly property int pad: Style.sp(8)

    Flickable {
        id: scroll
        anchors.fill: parent
        anchors.leftMargin: page.pad
        anchors.rightMargin: page.pad
        topMargin: Style.sp(6)
        bottomMargin: Style.sp(20)
        clip: true
        contentWidth: width
        contentHeight: col.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        visible: page.expandedCat === ""

        ColumnLayout {
            id: col
            width: scroll.width
            spacing: Style.sp(6)

            // header
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.sp(1)
                Text { text: "// MUSIC / DISCOVERY"; color: Tokens.inkFaint; font.family: Style.fontMono; font.pixelSize: Style.fs.xs; font.letterSpacing: 1 }
                Text { text: "Search"; color: Tokens.ink; font.family: Tokens.display; font.pixelSize: Style.fs.hero }
            }

            SearchSuggest {
                id: suggest
                Layout.fillWidth: true
                Layout.maximumWidth: Style.sp(160)
                value: page.query
                onValueChanged: page.query = value
                onSubmitted: page.runSearch()
                onPicked: page.query = value
                z: 40
            }

            Text {
                visible: page.searching
                text: "Resolving songs, artists, albums and playlists…"
                color: Tokens.inkMuted
                font.family: Style.fontUi
                font.pixelSize: Style.fs.md
            }

            Text {
                visible: page.errorMsg !== ""
                text: page.errorMsg
                color: Tokens.alert
                font.family: Style.fontUi
                font.pixelSize: Style.fs.md
            }

            // idle: recent searches
            ColumnLayout {
                Layout.fillWidth: true
                visible: !page.searching && !page.res && page.errorMsg === ""
                spacing: Style.sp(2)
                Text { text: "// RECENT SEARCHES"; color: Tokens.inkFaint; font.family: Style.fontMono; font.pixelSize: Style.fs.xs; font.letterSpacing: 1 }
                Repeater {
                    model: page.history
                    delegate: Rectangle {
                        id: histRow
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: Style.sp(9)
                        radius: Style.radius
                        color: hHover.hovered ? Tokens.tint5 : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Style.sp(2)
                            anchors.rightMargin: Style.sp(2)
                            spacing: Style.sp(3)
                            Text { text: String(histRow.index + 1).padStart(2, "0"); color: Tokens.inkFaint; font.family: Style.fontMono; font.pixelSize: Style.fs.sm }
                            Text { Layout.fillWidth: true; text: histRow.modelData; color: Tokens.ink; font.family: Style.fontUi; font.pixelSize: Style.fs.md; elide: Text.ElideRight }
                        }
                        HoverHandler { id: hHover }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { page.query = histRow.modelData; page.runSearch(); } }
                    }
                }
                Text {
                    visible: page.history.length === 0
                    text: "Search songs, artists, albums and playlists. Press Ctrl K from anywhere."
                    color: Tokens.inkMuted
                    font.family: Style.fontUi
                    font.pixelSize: Style.fs.sm
                }
            }

            // no results
            Text {
                visible: !page.searching && !!page.res && page.sections.length === 0
                text: "No results for \u201C" + page.searched + "\u201D."
                color: Tokens.inkMuted
                font.family: Style.fontUi
                font.pixelSize: Style.fs.md
            }

            // sections
            Repeater {
                model: (!page.searching && page.res) ? page.sections : []
                delegate: ColumnLayout {
                    id: secCol
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Style.sp(3)

                    SectionHeading {
                        Layout.fillWidth: true
                        title: secCol.modelData.label
                        more: secCol.modelData.more
                        onMoreClicked: page.showMore(secCol.modelData)
                    }

                    // songs list
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: secCol.modelData.list
                        spacing: Style.sp(0.5)
                        Repeater {
                            model: secCol.modelData.list ? page.songRows.slice(0, secCol.modelData.max) : []
                            delegate: TrackRow {
                                id: sr
                                required property var modelData
                                Layout.fillWidth: true
                                song: sr.modelData
                                showPlayCount: true
                                menu: true
                                canAdd: true
                                active: !!(Playback.now && Playback.now.videoId === sr.modelData.video_id)
                                onPlay: page.playSong(sr.modelData)
                                onMenuRequested: (sx, sy) => {
                                    var p = searchMenu.mapFromItem(null, sx, sy);
                                    searchMenu.song = sr.modelData;
                                    searchMenu.openAt(p.x, p.y);
                                }
                            }
                        }
                    }

                    // card rail
                    Flickable {
                        Layout.fillWidth: true
                        visible: !secCol.modelData.list
                        implicitHeight: Style.sp(66)
                        contentWidth: cardRow.implicitWidth
                        contentHeight: height
                        flickableDirection: Flickable.HorizontalFlick
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        Row {
                            id: cardRow
                            spacing: Style.sp(3)
                            Repeater {
                                model: secCol.modelData.list ? [] : secCol.modelData.items.slice(0, secCol.modelData.max)
                                delegate: MediaCard {
                                    required property var modelData
                                    item: modelData
                                    cardWidth: Style.sp(40)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- expanded category view ------------------------------------------------------------
    Item {
        anchors.fill: parent
        visible: page.expandedCat !== ""

        // back bar
        RowLayout {
            id: backBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: page.pad
            anchors.rightMargin: page.pad
            anchors.topMargin: Style.sp(5)
            spacing: Style.sp(2)
            Item {
                implicitWidth: Style.sp(8); implicitHeight: Style.sp(8)
                Icon { anchors.centerIn: parent; name: "arrow-left"; size: Style.fs.lg; color: backHover.hovered ? Tokens.ink : Tokens.inkMuted }
                HoverHandler { id: backHover }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.expandedCat = "" }
            }
            Text {
                Layout.fillWidth: true
                text: page.expandedCat.toUpperCase() + " · \u201C" + page.searched + "\u201D"
                color: Tokens.ink
                font.family: Style.fontUi
                font.pixelSize: Style.fs.lg
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }

        // songs expanded
        TrackList {
            anchors.top: backBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.topMargin: Style.sp(3)
            visible: page.expandedCat === "songs"
            items: page.expandedItems
            showPlayCount: true
            canAdd: true
            onActivated: (i) => { if (page.expandedItems[i]) page.playSong(page.expandedItems[i]); }
            Component.onCompleted: view.contentYChanged.connect(page.loadMoreExpanded)
        }

        // cards expanded
        CardGrid {
            anchors.top: backBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.topMargin: Style.sp(3)
            visible: page.expandedCat !== "" && page.expandedCat !== "songs"
            pad: page.pad
            loading: page.expandedLoading && page.expandedItems.length === 0
            model: page.expandedItems
            emptyText: "No results."
        }
    }

    Menu { id: searchMenu }
}
