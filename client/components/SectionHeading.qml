import QtQuick
import QtQuick.Layouts
import Ryoku.Ui.Singletons
import "../"

// A shelf's header, ported from SectionHeading.svelte: an optional kind icon, the "// title" mark,
// a hairline rule filling the dead space, and an optional "SEE ALL" affordance that routes to the
// section's list page.
RowLayout {
    id: root

    property string title: ""
    property string icon: ""
    property bool more: false
    signal moreClicked()

    spacing: Style.sp(3)

    Icon {
        visible: root.icon !== ""
        name: root.icon
        size: Style.fs.sm
        color: Tokens.inkMuted
    }

    Text {
        text: "//"
        color: Tokens.inkFaint
        font.family: Style.fontMono
        font.pixelSize: Style.fs.sm
    }
    Text {
        Layout.maximumWidth: Style.sp(90)
        text: root.title
        color: Tokens.inkDim
        font.family: Style.fontUi
        font.pixelSize: Style.fs.lg
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        Layout.maximumWidth: Style.sp(42)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Tokens.line }
            GradientStop { position: 0.65; color: Tokens.lineSoft }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Item { Layout.fillWidth: true }

    Item {
        visible: root.more
        implicitWidth: moreRow.implicitWidth
        implicitHeight: moreRow.implicitHeight
        Layout.alignment: Qt.AlignVCenter
        Row {
            id: moreRow
            spacing: Style.sp(1)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "SEE ALL"
                color: seeHover.hovered ? Tokens.ink : Tokens.inkMuted
                font.family: Style.fontUi
                font.pixelSize: Style.fs.xs
                font.weight: Font.Medium
                font.letterSpacing: 1
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "arrow-right"
                size: Style.fs.sm
                color: seeHover.hovered ? Tokens.ink : Tokens.inkMuted
            }
        }
        HoverHandler { id: seeHover }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.moreClicked() }
    }
}
