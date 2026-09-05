pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.Ui.Singletons
import "../"

// A reused grid of MediaCards — the library's card tabs and any browse grid. A GridView with
// reuseItems and a bounded cache keeps a long collection to a couple of screenfuls of delegates.
Item {
    id: root

    property var model: []
    property bool loading: false
    property string emptyText: "Nothing here."
    property int pad: Style.sp(8)

    GridView {
        id: grid
        anchors.fill: parent
        anchors.leftMargin: root.pad
        anchors.rightMargin: root.pad
        topMargin: Style.sp(4)
        bottomMargin: Style.sp(20)
        clip: true
        reuseItems: true
        cacheBuffer: Math.max(0, Math.round(height * 1.5))
        boundsBehavior: Flickable.StopAtBounds
        cellWidth: Math.floor((width - 1) / Math.max(1, Math.floor(width / Style.sp(48))))
        cellHeight: grid.cellWidth + Style.sp(16)
        model: root.loading ? [] : root.model

        delegate: Item {
            required property var modelData
            width: grid.cellWidth
            height: grid.cellHeight
            MediaCard {
                anchors.horizontalCenter: parent.horizontalCenter
                item: parent.modelData
                cardWidth: grid.cellWidth - Style.sp(4)
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.loading || (root.model.length === 0)
        text: root.loading ? "Loading…" : root.emptyText
        color: Tokens.inkMuted
        font.family: Style.fontUi
        font.pixelSize: Style.fs.md
    }
}
