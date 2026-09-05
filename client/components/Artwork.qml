import QtQuick
import QtQuick.Effects
import Ryoku.Ui.Singletons
import "../"

// Track/album/artist artwork with the neutral placeholder every absent or failed thumbnail lands
// on. The URL is rewritten by Style.thumb() to the exact pixel size drawn (2x for crispness) so the
// CDN returns a small image and the decode/cache stays bounded. A rounded-rectangle (or circle,
// for artists) mask keeps the corners honest to the design language without a per-image clip hack.
Item {
    id: root

    property string url: ""
    property int px: 48
    property bool round: false
    property string placeholderIcon: "music"
    property int glyphSize: Math.round(px * 0.42)

    width: px
    height: px

    Rectangle {
        id: plate
        anchors.fill: parent
        radius: root.round ? width / 2 : Style.radius
        color: Tokens.paperLift
        border.width: 1
        border.color: Tokens.lineSoft

        Icon {
            anchors.centerIn: parent
            visible: img.status !== Image.Ready
            name: root.placeholderIcon
            size: root.glyphSize
            color: Tokens.inkFaint
        }
    }

    Image {
        id: img
        anchors.fill: parent
        source: root.url ? Style.thumb(root.url, Math.round(root.px * 2)) : ""
        sourceSize: Qt.size(Math.round(root.px * 2), Math.round(root.px * 2))
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: false
        layer.enabled: true
    }

    Rectangle {
        id: mask
        anchors.fill: parent
        radius: plate.radius
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: parent
        source: img
        maskEnabled: true
        maskSource: mask
        visible: img.status === Image.Ready
    }
}
