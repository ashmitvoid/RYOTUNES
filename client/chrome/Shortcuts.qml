pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Ryoku.Ui.Singletons
import "../"
import "../components"
import "../lib/browse.js" as Browse

// The pinboard of manual shortcuts, ported from Shortcuts.svelte: a grid of the user's pinned items
// (each plays or opens, and a hover X removes it) plus the trailing "add" tile. `picks` comes from
// the shared Personal store (the daemon's personal blob), so a tile pinned in the Tauri app or a
// second client shows here too; `removed` drops it through Personal.removePick. The add tile routes
// into Search, where a card's menu pins it.
ColumnLayout {
    id: root

    property var picks: []
    signal removed(string id)

    spacing: Style.sp(3)

    SectionHeading {
        Layout.fillWidth: true
        title: "Shortcuts"
        icon: "dashboard"
    }

    Flow {
        Layout.fillWidth: true
        spacing: Style.sp(2)

        Repeater {
            model: root.picks
            delegate: Rectangle {
                id: pin
                required property var modelData
                readonly property bool round: modelData && modelData.kind === "artist"
                width: Style.sp(38)
                height: tileCol.implicitHeight + Style.sp(3)
                radius: Style.radius
                color: pinHover.hovered ? Tokens.tint5 : "transparent"

                RowLayout {
                    id: tileCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Style.sp(1.5)
                    anchors.rightMargin: Style.sp(1.5)
                    spacing: Style.sp(2)
                    Artwork {
                        url: pin.modelData && pin.modelData.thumbnail ? pin.modelData.thumbnail : ""
                        px: Style.sp(10)
                        round: pin.round
                        placeholderIcon: pin.round ? "user" : "music"
                    }
                    Text {
                        Layout.fillWidth: true
                        text: pin.modelData ? pin.modelData.title : ""
                        color: Tokens.ink
                        font.family: Style.fontUi
                        font.pixelSize: Style.fs.sm
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                }

                IconButton {
                    visible: pinHover.hovered
                    anchors.top: parent.top
                    anchors.right: parent.right
                    icon: "close"
                    iconSize: Style.fs.xs
                    diameter: Style.sp(5)
                    onClicked: root.removed(pin.modelData.id)
                }

                HoverHandler { id: pinHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var it = pin.modelData;
                        if (it.kind === "song")
                            Playback.play(Browse.asSong(it));
                        else
                            Router.push(it.kind, { id: it.id, title: it.title });
                    }
                }
            }
        }

        // add tile
        Rectangle {
            width: Style.sp(38)
            height: Style.sp(13)
            radius: Style.radius
            color: addHover.hovered ? Tokens.tint5 : "transparent"
            border.width: 1
            border.color: Tokens.line
            RowLayout {
                anchors.centerIn: parent
                spacing: Style.sp(2)
                Icon { name: "add"; size: Style.fs.md; color: Tokens.inkMuted }
                Text {
                    text: "Add a shortcut"
                    color: Tokens.inkMuted
                    font.family: Style.fontUi
                    font.pixelSize: Style.fs.sm
                }
            }
            HoverHandler { id: addHover }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Router.push("search")
            }
        }
    }
}
