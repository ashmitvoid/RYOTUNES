import QtQuick
import QtQuick.Layouts
import Ryoku.Ui.Singletons
import "../"
import "../components"

// The top register: the product mark, history back/forward driven by Router, and the right cluster
// (account, Listen Together, Discord, mini) from the Svelte titlebar. Under Hyprland the compositor
// owns the window controls, so this bar carries no minimise/close. Listen Together and the mini
// window are later surfaces; their buttons raise signals the App routes once those exist. Discord
// is a plain setting toggle and is wired here.
Rectangle {
    id: root

    signal accountClicked(real gx, real gy)
    signal listenTogetherClicked()
    signal miniClicked()

    property bool discordOn: false

    implicitHeight: Style.sp(8.5)
    color: Tokens.paper

    Component.onCompleted: root.discordOn = !!(Playback.settings && Playback.settings.discord_rpc === "true")
    Connections {
        target: Playback
        function onSettingsChanged() {
            root.discordOn = !!(Playback.settings && Playback.settings.discord_rpc === "true");
        }
    }

    Hairline { anchors.bottom: parent.bottom; width: parent.width; height: 1 }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.sp(3)
        anchors.rightMargin: Style.sp(2)
        spacing: Style.sp(1)

        // --- product mark -------------------------------------------------------------------
        Rectangle { Layout.preferredWidth: Style.sp(4); Layout.preferredHeight: 1; Layout.alignment: Qt.AlignVCenter; color: Tokens.ink }
        Text {
            text: "力"
            color: Tokens.inkMuted
            font.family: Tokens.jp
            font.pixelSize: Style.fs.sm
        }
        Text {
            text: "RYOTUNES"
            color: Tokens.inkDim
            font.family: Style.fontUi
            font.pixelSize: Style.fs.xs
            font.weight: Font.DemiBold
            font.letterSpacing: 1.6
        }

        Item { Layout.preferredWidth: Style.sp(2) }

        // --- history ------------------------------------------------------------------------
        IconButton {
            icon: "arrow-left"
            iconSize: Style.fs.lg
            diameter: Style.sp(8)
            enabled: Router.canGoBack
            onClicked: Router.pop()
        }
        IconButton {
            icon: "arrow-right"
            iconSize: Style.fs.lg
            diameter: Style.sp(8)
            enabled: false
        }

        Item { Layout.fillWidth: true }

        // --- account ------------------------------------------------------------------------
        Item {
            id: account
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Style.sp(8)
            implicitHeight: Style.sp(8)

            Artwork {
                anchors.centerIn: parent
                visible: !!(Playback.auth && Playback.auth.signedIn && Playback.auth.avatar)
                url: (Playback.auth && Playback.auth.avatar) ? Playback.auth.avatar : ""
                px: Style.sp(6)
                round: true
                placeholderIcon: "account"
            }
            Icon {
                anchors.centerIn: parent
                visible: !(Playback.auth && Playback.auth.signedIn && Playback.auth.avatar)
                name: "account"
                size: Style.fs.lg
                color: (Playback.auth && Playback.auth.signedIn) ? Tokens.ink : Tokens.inkMuted
            }
            HoverHandler { id: accountHover }
            Rectangle {
                anchors.fill: parent
                radius: Style.radius
                z: -1
                color: accountHover.hovered ? Tokens.tint5 : "transparent"
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var p = account.mapToItem(null, 0, account.height);
                    root.accountClicked(p.x, p.y);
                }
            }
        }

        Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: Style.sp(4); Layout.alignment: Qt.AlignVCenter; color: Tokens.line }

        IconButton {
            icon: "group"
            iconSize: Style.fs.lg
            diameter: Style.sp(8)
            active: !!(Playback.lt && Playback.lt.role && Playback.lt.role !== "none")
            onClicked: root.listenTogetherClicked()
        }
        IconButton {
            icon: "discord"
            iconSize: Style.fs.lg
            diameter: Style.sp(8)
            active: root.discordOn
            onClicked: {
                root.discordOn = !root.discordOn;
                Daemon.call("set_setting", { key: "discord_rpc", value: root.discordOn ? "true" : "false" })
                    .catch(() => { root.discordOn = !root.discordOn; });
            }
        }
        IconButton {
            icon: "minimize"
            iconSize: Style.fs.lg
            diameter: Style.sp(8)
            onClicked: root.miniClicked()
        }
    }
}
