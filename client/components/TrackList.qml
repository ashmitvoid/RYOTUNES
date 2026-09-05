pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.Ui.Singletons
import "../"

// A reused ListView of TrackRow, the shared body of every track surface (playlist, album, library
// songs, queue). reuseItems keeps a long list to a couple of screenfuls of live delegates, and a
// bounded cacheBuffer keeps the scroll cheap. An optional header/footer scrolls with the rows, so a
// page's hero and its card carousels live in one scroller rather than nesting a second Flickable.
// When `reorderable`, a grip on each row drags it to a new index and commits with `moved(from,to)`
// (the queue wires that to move_in_queue); the daemon's queue-changed event repaints the result.
Item {
    id: root

    property var items: []
    property Component header: null
    property Component footer: null

    property bool reorderable: false
    property bool hideThumb: false
    property bool showPlayCount: false
    property bool menu: true
    property bool canAdd: true
    property bool canRemove: false
    property string removeLabel: "Remove from playlist"
    property string source: ""

    // Play-target and reorder/remove contracts the host owns.
    signal activated(int index)
    signal moved(int from, int to)
    signal removeAt(int index)

    readonly property int rowHeight: Style.sp(11)
    readonly property alias view: list

    // --- drag-reorder state -----------------------------------------------------------------
    property int dragFrom: -1
    property int dragTo: -1
    property real ghostY: 0
    property string ghostTitle: ""

    function headerHeight() { return list.headerItem ? list.headerItem.height : 0; }
    function indexAt(yInList) {
        var y = list.contentY + yInList - root.headerHeight();
        return Math.max(0, Math.min(root.items.length - 1, Math.floor(y / root.rowHeight)));
    }
    function beginDrag(from, yInList) {
        root.dragFrom = from;
        root.dragTo = from;
        root.ghostY = yInList;
        var it = root.items[from];
        root.ghostTitle = it ? it.title : "";
    }
    function updateDrag(yInList) {
        root.ghostY = yInList;
        root.dragTo = root.indexAt(yInList);
        // Edge auto-scroll when the pointer nears a boundary.
        var edge = Style.sp(12);
        if (yInList < edge)
            list.contentY = Math.max(list.originY, list.contentY - Style.sp(4));
        else if (yInList > list.height - edge)
            list.contentY = Math.min(list.originY + list.contentHeight - list.height, list.contentY + Style.sp(4));
    }
    function endDrag() {
        if (root.dragFrom >= 0 && root.dragTo >= 0 && root.dragFrom !== root.dragTo)
            root.moved(root.dragFrom, root.dragTo);
        root.dragFrom = -1;
        root.dragTo = -1;
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        reuseItems: true
        cacheBuffer: Math.max(0, Math.round(height * 1.5))
        boundsBehavior: Flickable.StopAtBounds
        model: root.items
        header: root.header
        footer: root.footer
        // A drag in progress must not also flick the list.
        interactive: root.dragFrom < 0

        delegate: Item {
            id: rowWrap
            required property var modelData
            required property int index
            width: list.width
            implicitHeight: root.rowHeight

            // The drop marker: a hairline where this row would land.
            Rectangle {
                visible: root.dragFrom >= 0 && root.dragTo === rowWrap.index
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 2
                color: Tokens.sun
            }

            TrackRow {
                id: rowItem
                anchors.left: parent.left
                anchors.right: parent.right
                index: -1
                song: rowWrap.modelData
                hideThumb: root.hideThumb
                showPlayCount: root.showPlayCount
                menu: root.menu
                canAdd: root.canAdd
                canRemove: root.canRemove
                removeLabel: root.removeLabel
                opacity: root.dragFrom === rowWrap.index ? 0.35 : 1
                active: !!(Playback.now && rowWrap.modelData
                    && Playback.now.videoId === rowWrap.modelData.video_id)
                onPlay: root.activated(rowWrap.index)
                onMenuRequested: (sx, sy) => {
                    var p = ctxMenu.mapFromItem(null, sx, sy);
                    ctxMenu.song = rowWrap.modelData;
                    ctxMenu.canAdd = root.canAdd;
                    ctxMenu.canRemove = root.canRemove;
                    ctxMenu.removeLabel = root.removeLabel;
                    ctxMenu.source = root.source;
                    ctxMenu._index = rowWrap.index;
                    ctxMenu.openAt(p.x, p.y);
                }
            }

            // Reorder grip (right edge). Vertical drag moves the row; the whole list stops flicking
            // while a grip is held (list.interactive above).
            Item {
                id: grip
                visible: root.reorderable
                width: root.reorderable ? Style.sp(9) : 0
                height: parent.height
                anchors.right: parent.right
                Column {
                    anchors.centerIn: parent
                    spacing: Style.sp(0.75)
                    Repeater {
                        model: 3
                        delegate: Rectangle {
                            width: Style.sp(4)
                            height: Math.max(1, Style.sp(0.5))
                            radius: height / 2
                            color: gripDrag.active ? Tokens.ink : Tokens.inkFaint
                        }
                    }
                }
                DragHandler {
                    id: gripDrag
                    target: null
                    onActiveChanged: {
                        if (active)
                            root.beginDrag(rowWrap.index, grip.mapToItem(list, 0, centroid.position.y).y);
                        else
                            root.endDrag();
                    }
                    onCentroidChanged: {
                        if (active)
                            root.updateDrag(grip.mapToItem(list, 0, centroid.position.y).y);
                    }
                }
            }
        }
    }

    // The floating row that follows the grip during a reorder.
    Rectangle {
        visible: root.dragFrom >= 0
        width: list.width - Style.sp(6)
        x: Style.sp(3)
        y: Math.max(0, Math.min(root.height - height, root.ghostY - height / 2))
        implicitHeight: root.rowHeight
        radius: Style.radius
        color: Tokens.paperLift
        border.width: 1
        border.color: Tokens.lineStrong
        opacity: 0.95
        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Style.sp(3)
            anchors.rightMargin: Style.sp(3)
            text: root.ghostTitle
            color: Tokens.ink
            font.family: Style.fontUi
            font.pixelSize: Style.fs.md
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
    }

    Menu {
        id: ctxMenu
        property int _index: -1
        onRemoveRequested: root.removeAt(ctxMenu._index)
    }
}
