import QtQuick
import Ryoku.Ui.Singletons
import "../"

// A mood/filter pill from the Home chip rail. Outlined at rest, filled with the bone plate when the
// active filter, so the one selected chip is the only saturated thing above the feed (per the
// Svelte chipClass).
Rectangle {
    id: root

    property string text: ""
    property bool active: false
    signal clicked()

    implicitHeight: Style.sp(6.5)
    implicitWidth: label.implicitWidth + Style.sp(7)
    radius: Style.radius
    color: active ? Tokens.bone : chipHover.hovered ? Tokens.tint10 : "transparent"
    border.width: 1
    border.color: active ? Tokens.bone : chipHover.hovered ? Tokens.lineStrong : Tokens.line

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.active ? Tokens.inkOnBone : Tokens.inkMuted
        font.family: Style.fontUi
        font.pixelSize: Style.fs.md
        font.weight: Font.Medium
    }

    HoverHandler { id: chipHover }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
