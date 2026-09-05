pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Ryoku.Ui.Singletons
import "chrome"
import "pages"
import "components"

// The app frame: the title register on top, the navigation rail beside the routed page, the
// transport pinned to the foot while something is loaded, and a foreground layer for the account
// menu and toasts. The page is chosen from Router.current.page — Home is the only built route; the
// other nav destinations land on a clearly-marked placeholder until their tasks add them.
Item {
    id: app
    anchors.fill: parent

    // Surface toggles the transport raises. Their panels/windows are later tasks; the state is real
    // now so those surfaces bind to it when they arrive, and the toggle buttons already reflect it.
    property bool queueOpen: false
    property bool lyricsOpen: false
    property bool nowPlayingOpen: false

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TitleBar {
            Layout.fillWidth: true
            onAccountClicked: (gx, gy) => accountMenu.openAt(gx, gy)
            onListenTogetherClicked: Playback.toast("Listen Together arrives in a later build", "info")
            onMiniClicked: Playback.toast("Mini player arrives in a later build", "info")
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Sidebar { Layout.fillHeight: true }

            Loader {
                id: pageLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                readonly property string page: Router.current ? Router.current.page : "home"
                sourceComponent: page === "home" ? homePage : placeholder
            }
        }

        PlayerBar {
            Layout.fillWidth: true
            visible: !!Playback.now
            queueOpen: app.queueOpen
            lyricsOpen: app.lyricsOpen
            nowPlayingOpen: app.nowPlayingOpen
            onToggleQueue: app.queueOpen = !app.queueOpen
            onToggleLyrics: app.lyricsOpen = !app.lyricsOpen
            onToggleNowPlaying: app.nowPlayingOpen = !app.nowPlayingOpen
            onMiniClicked: Playback.toast("Mini player arrives in a later build", "info")
        }
    }

    Component { id: homePage; HomePage {} }
    Component {
        id: placeholder
        Rectangle {
            color: Tokens.paper
            ColumnLayout {
                anchors.centerIn: parent
                spacing: Style.sp(2)
                Icon {
                    Layout.alignment: Qt.AlignHCenter
                    name: "music"
                    size: Style.fs.hero
                    color: Tokens.inkFaint
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: (Router.current ? Router.current.page : "").toUpperCase()
                    color: Tokens.inkDim
                    font.family: Style.fontMono
                    font.pixelSize: Style.fs.sm
                    font.letterSpacing: 2
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "This surface arrives in a later build."
                    color: Tokens.inkMuted
                    font.family: Style.fontUi
                    font.pixelSize: Style.fs.md
                }
            }
        }
    }

    // ── foreground layer ────────────────────────────────────────────────────────────────
    Toast { }

    // Account menu (sign in / out via the daemon). A full-surface dismiss layer closes it.
    MouseArea {
        anchors.fill: parent
        visible: accountMenu.visible
        onClicked: accountMenu.visible = false
    }
    Rectangle {
        id: accountMenu
        visible: false
        width: Style.sp(56)
        implicitHeight: menuCol.implicitHeight + Style.sp(2)
        height: implicitHeight
        radius: Style.radius
        color: Tokens.paperLift
        border.width: 1
        border.color: Tokens.lineStrong

        function openAt(gx, gy) {
            x = Math.max(Style.sp(2), Math.min(gx - width, app.width - width - Style.sp(2)));
            y = gy + Style.sp(1);
            visible = true;
        }

        ColumnLayout {
            id: menuCol
            anchors.fill: parent
            anchors.margins: Style.sp(1)
            spacing: Style.sp(1)

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: Style.sp(1)
                spacing: Style.sp(2)
                Artwork {
                    visible: !!(Playback.auth && Playback.auth.signedIn && Playback.auth.avatar)
                    url: (Playback.auth && Playback.auth.avatar) ? Playback.auth.avatar : ""
                    px: Style.sp(8)
                    round: true
                    placeholderIcon: "account"
                }
                Icon {
                    visible: !(Playback.auth && Playback.auth.signedIn && Playback.auth.avatar)
                    name: "account"
                    size: Style.fs.lg
                    color: Tokens.inkMuted
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        text: (Playback.auth && Playback.auth.signedIn && Playback.auth.name)
                            ? Playback.auth.name : "Not signed in"
                        color: Tokens.ink
                        font.family: Style.fontUi
                        font.pixelSize: Style.fs.md
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: (Playback.auth && Playback.auth.signedIn) ? "YouTube Music" : "Sign in to sync your library"
                        color: Tokens.inkMuted
                        font.family: Style.fontUi
                        font.pixelSize: Style.fs.sm
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            Hairline { Layout.fillWidth: true }

            // action row
            Rectangle {
                id: signAction
                Layout.fillWidth: true
                implicitHeight: Style.sp(9)
                radius: Style.radius
                color: actHover.hovered ? Tokens.tint5 : "transparent"
                readonly property bool signedIn: !!(Playback.auth && Playback.auth.signedIn)
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.sp(2)
                    anchors.rightMargin: Style.sp(2)
                    spacing: Style.sp(2)
                    Icon {
                        name: signAction.signedIn ? "close" : "account"
                        size: Style.fs.md
                        color: signAction.signedIn ? Tokens.alert : Tokens.ink
                    }
                    Text {
                        Layout.fillWidth: true
                        text: signAction.signedIn ? "Sign out" : "Sign in with Google"
                        color: signAction.signedIn ? Tokens.alert : Tokens.ink
                        font.family: Style.fontUi
                        font.pixelSize: Style.fs.md
                    }
                }
                HoverHandler { id: actHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        accountMenu.visible = false;
                        Daemon.call(signAction.signedIn ? "sign_out" : "sign_in").catch(() => {});
                    }
                }
            }
        }
    }
}
