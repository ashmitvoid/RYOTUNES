import QtQuick
import Ryoku.Ui.Singletons
import "../"

// A square icon button: hover and pressed tints from Tokens, a disabled dim, and an `active` state
// that pins the "on" ink like the Svelte transport toggles (shuffle/repeat/like). `primary` is the
// one filled control (play/pause), drawn on the bone plate so it keeps contrast on any palette.
Item {
    id: root

    property string icon: ""
    property int iconSize: 18
    property int diameter: Style.sp(8)
    property bool active: false
    property bool primary: false
    property string tip: ""
    property color iconColor: root.primary ? Tokens.inkOnBone
        : !root.enabled ? Tokens.inkFaint
        : root.active ? Tokens.ink
        : Tokens.inkMuted

    readonly property alias hovered: hover.hovered
    signal clicked()

    implicitWidth: diameter
    implicitHeight: diameter
    opacity: enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: Style.radius
        color: root.primary ? Tokens.bone
            : ma.pressed ? Tokens.tint16
            : hover.hovered ? Tokens.tint5
            : "transparent"
    }

    Icon {
        anchors.centerIn: parent
        name: root.icon
        size: root.iconSize
        color: root.iconColor
    }

    HoverHandler { id: hover; enabled: root.enabled }
    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
