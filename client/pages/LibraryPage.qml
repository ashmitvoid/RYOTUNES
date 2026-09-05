pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Ryoku.Ui.Singletons
import "../"
import "../components"

// The library page, ported from ui/src/routes/library/+page.svelte. Account collections load in
// parallel on open (get_library / _albums / _artists) and fill the card tabs (All / Playlists /
// Albums / Artists); Songs, Local and Insights are the ported LibrarySongs / LocalMusic /
// ListeningInsights, loaded lazily the first time their tab is opened so an unopened tab costs
// nothing. The toolbar creates a playlist and imports one from a file (over the socket with a path).
Item {
    id: page

    property var playlists: []
    property var albums: []
    property var artists: []
    property bool loading: true
    property string errorMsg: ""
    property string tab: "all"
    property var opened: ["all"]
    property bool creating: false
    property string newName: ""

    readonly property var tabs: [
        { k: "all", l: "All" },
        { k: "playlists", l: "Playlists" },
        { k: "albums", l: "Albums" },
        { k: "artists", l: "Artists" },
        { k: "songs", l: "Songs" },
        { k: "local", l: "Local" },
        { k: "insights", l: "Insights" }
    ]
    readonly property var gridModel: {
        if (page.tab === "playlists") return page.playlists;
        if (page.tab === "albums") return page.albums;
        if (page.tab === "artists") return page.artists;
        return page.playlists.concat(page.albums).concat(page.artists);
    }

    Component.onCompleted: page.load()

    function selectTab(k) {
        page.tab = k;
        if (page.opened.indexOf(k) < 0)
            page.opened = page.opened.concat([k]);
    }
    function isOpened(k) { return page.opened.indexOf(k) >= 0; }

    function load() {
        page.loading = true;
        page.errorMsg = "";
        Promise.all([
            Daemon.call("get_library").catch(() => []),
            Daemon.call("get_library_albums").catch(() => []),
            Daemon.call("get_library_artists").catch(() => [])
        ]).then((res) => {
            page.playlists = res[0] || [];
            page.albums = res[1] || [];
            page.artists = res[2] || [];
            page.loading = false;
        }).catch((e) => {
            page.errorMsg = (e && e.message) ? e.message : String(e);
            page.loading = false;
        });
    }

    function createPlaylist() {
        var title = page.newName.trim();
        if (!title || page.creating)
            return;
        page.creating = true;
        Daemon.call("create_playlist", { title: title })
            .then(() => { page.creating = false; page.newName = ""; newDialog.visible = false; page.load(); Playback.toast("Playlist created", "success"); })
            .catch((e) => { page.creating = false; Playback.toast((e && e.message) ? e.message : "Could not create", "error"); });
    }

    // import: zenity file picker -> import_playlist_file(path) -> create_playlist + add each
    Process {
        id: importPicker
        command: ["zenity", "--file-selection", "--title=Import a playlist file"]
        stdout: StdioCollector {
            id: importOut
            onStreamFinished: { var p = importOut.text.trim(); if (p) page.doImport(p); }
        }
    }
    function doImport(path) {
        Daemon.call("import_playlist_file", { path: path })
            .then((transfer) => {
                if (!transfer || !transfer.items || !transfer.items.length)
                    return;
                return Daemon.call("create_playlist", { title: transfer.title }).then((id) => {
                    var chain = Promise.resolve();
                    for (var i = 0; i < transfer.items.length; i++) {
                        (function (song) {
                            chain = chain.then(() => Daemon.call("add_to_playlist", { playlistId: id, videoId: song.video_id }).catch(() => {}));
                        })(transfer.items[i]);
                    }
                    return chain.then(() => { page.load(); Playback.toast("Imported " + transfer.title, "success"); });
                });
            })
            .catch((e) => Playback.toast((e && e.message) ? e.message : "Could not import", "error"));
    }

    Rectangle { anchors.fill: parent; color: Tokens.paper }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // header: title + toolbar
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Style.sp(8)
            Layout.rightMargin: Style.sp(8)
            Layout.topMargin: Style.sp(6)
            spacing: Style.sp(3)
            ColumnLayout {
                spacing: Style.sp(0.5)
                Text {
                    text: "// COLLECTION"
                    color: Tokens.inkFaint
                    font.family: Style.fontMono
                    font.pixelSize: Style.fs.xs
                    font.letterSpacing: 1
                }
                Text {
                    text: "Library"
                    color: Tokens.ink
                    font.family: Tokens.display
                    font.pixelSize: Style.fs.xl
                }
            }
            Item { Layout.fillWidth: true }
            Pill { label: "Import"; icon: "add"; onClicked: importPicker.running = true }
            Pill { label: "New playlist"; icon: "playlist"; primary: true; onClicked: { page.newName = ""; newDialog.visible = true; } }
        }

        // tab bar
        Flickable {
            Layout.fillWidth: true
            Layout.leftMargin: Style.sp(8)
            Layout.rightMargin: Style.sp(8)
            Layout.topMargin: Style.sp(4)
            implicitHeight: tabRow.implicitHeight
            contentWidth: tabRow.implicitWidth
            contentHeight: tabRow.implicitHeight
            flickableDirection: Flickable.HorizontalFlick
            clip: true
            Row {
                id: tabRow
                spacing: Style.sp(2)
                Repeater {
                    model: page.tabs
                    delegate: Chip {
                        required property var modelData
                        text: modelData.l
                        active: page.tab === modelData.k
                        onClicked: page.selectTab(modelData.k)
                    }
                }
            }
        }

        Hairline { Layout.fillWidth: true; Layout.topMargin: Style.sp(3); Layout.leftMargin: Style.sp(8); Layout.rightMargin: Style.sp(8) }

        // content
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Text {
                anchors.centerIn: parent
                visible: page.loading && page.tab !== "local" && page.tab !== "insights"
                text: "Loading your library…"
                color: Tokens.inkMuted
                font.family: Style.fontUi
                font.pixelSize: Style.fs.md
            }

            CardGrid {
                anchors.fill: parent
                visible: page.tab === "all" || page.tab === "playlists" || page.tab === "albums" || page.tab === "artists"
                loading: page.loading
                model: page.gridModel
                emptyText: (Playback.auth && Playback.auth.signedIn) ? "Nothing saved yet." : "Sign in to see your library."
            }

            Loader {
                anchors.fill: parent
                active: page.isOpened("songs")
                visible: page.tab === "songs"
                sourceComponent: LibrarySongs {}
            }
            Loader {
                anchors.fill: parent
                active: page.isOpened("local")
                visible: page.tab === "local"
                sourceComponent: LocalMusic {}
            }
            Loader {
                anchors.fill: parent
                active: page.isOpened("insights")
                visible: page.tab === "insights"
                sourceComponent: ListeningInsights {}
            }
        }
    }

    // new-playlist dialog
    Item {
        id: newDialog
        anchors.fill: parent
        visible: false
        z: 210
        MouseArea { anchors.fill: parent; onClicked: newDialog.visible = false }
        Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.45 }
        Rectangle {
            anchors.centerIn: parent
            width: Style.sp(90)
            implicitHeight: ndCol.implicitHeight + Style.sp(8)
            height: implicitHeight
            radius: Style.radiusCard
            color: Tokens.paperLift
            border.width: 1
            border.color: Tokens.lineStrong
            MouseArea { anchors.fill: parent }
            ColumnLayout {
                id: ndCol
                anchors.fill: parent
                anchors.margins: Style.sp(4)
                spacing: Style.sp(3)
                Text { text: "New playlist"; color: Tokens.ink; font.family: Style.fontUi; font.pixelSize: Style.fs.lg; font.weight: Font.DemiBold }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Style.sp(10)
                    radius: Style.radius
                    color: Tokens.paper
                    border.width: 1
                    border.color: ndField.activeFocus ? Tokens.lineStrong : Tokens.line
                    TextInput {
                        id: ndField
                        anchors.fill: parent
                        anchors.leftMargin: Style.sp(2)
                        anchors.rightMargin: Style.sp(2)
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        color: Tokens.ink
                        font.family: Style.fontUi
                        font.pixelSize: Style.fs.md
                        text: page.newName
                        onTextChanged: page.newName = text
                        onAccepted: page.createPlaylist()
                        Component.onCompleted: if (newDialog.visible) ndField.forceActiveFocus()
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: ndField.text.length === 0
                            text: "Playlist name"
                            color: Tokens.inkFaint
                            font: ndField.font
                        }
                    }
                }
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: Style.sp(2)
                    Pill { label: "Cancel"; onClicked: newDialog.visible = false }
                    Pill { label: "Create"; primary: true; enabled: !page.creating && page.newName.trim().length > 0; onClicked: page.createPlaylist() }
                }
            }
        }
        onVisibleChanged: if (visible) ndField.forceActiveFocus()
    }
}
