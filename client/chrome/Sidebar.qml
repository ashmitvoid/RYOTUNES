pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Ryoku.Ui.Singletons
import "../"
import "../components"

// The navigation rail: the masthead register, then the three route groups (Discover / Collection /
// System) exactly as the Svelte +layout sidebar. The active route is read from Router.current.page;
// a click routes there. The playlist library list and the collapse toggle are later work — this is
// the structural rail Home and the transport sit against.
Rectangle {
    id: root

    // page-name -> Router route pushed on click. Matches the Svelte discover/collection/system nav.
    property var groups: [
        { label: "DISCOVER", num: "01", seal: "聴", items: [
            { page: "home", label: "Home", icon: "home", kana: "聴" },
            { page: "search", label: "Search", icon: "search", kana: "探" },
            { page: "radio", label: "Radio", icon: "radio", kana: "波" }
        ] },
        { label: "COLLECTION", num: "02", seal: "蔵", items: [
            { page: "library", label: "Library", icon: "library", kana: "蔵" }
        ] },
        { label: "SYSTEM", num: "03", seal: "設", items: [
            { page: "settings", label: "Settings", icon: "settings", kana: "設" }
        ] }
    ]

    readonly property string activePage: Router.current ? Router.current.page : "home"

    implicitWidth: Style.sp(50)
    color: Tokens.paper

    Hairline { anchors.right: parent.right; width: 1; height: parent.height }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.sp(2.5)
        spacing: Style.sp(1)

        // --- masthead register --------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Style.sp(2)
            spacing: Style.sp(2.5)
            Text {
                text: "力"
                color: Tokens.inkDim
                font.family: Tokens.jp
                font.pixelSize: Style.fs.xl
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: "RYOTUNES"
                    color: Tokens.ink
                    font.family: Style.fontUi
                    font.pixelSize: Style.fs.md
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2
                }
                Text {
                    text: "RYOKU // MUSIC"
                    color: Tokens.inkFaint
                    font.family: Style.fontMono
                    font.pixelSize: Style.fs.xs
                    font.letterSpacing: 1.2
                }
            }
        }

        // --- route groups -------------------------------------------------------------------
        Repeater {
            model: root.groups
            delegate: ColumnLayout {
                id: grp
                required property var modelData
                Layout.fillWidth: true
                Layout.topMargin: Style.sp(1.5)
                spacing: Style.sp(0.5)

                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: Style.sp(0.5)
                    spacing: Style.sp(2)
                    Text {
                        text: grp.modelData.num
                        color: Tokens.inkFaint
                        font.family: Style.fontMono
                        font.pixelSize: Style.fs.xs
                    }
                    Text {
                        text: grp.modelData.label
                        color: Tokens.inkMuted
                        font.family: Style.fontUi
                        font.pixelSize: Style.fs.xs
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.75
                    }
                    Hairline { Layout.fillWidth: true; soft: true }
                    Text {
                        text: grp.modelData.seal
                        color: Tokens.inkFaint
                        font.family: Tokens.jp
                        font.pixelSize: Style.fs.sm
                    }
                }

                Repeater {
                    model: grp.modelData.items
                    delegate: Rectangle {
                        id: navItem
                        required property var modelData
                        readonly property bool current: root.activePage === modelData.page
                        Layout.fillWidth: true
                        implicitHeight: Style.sp(8.5)
                        radius: Style.radius
                        color: current ? Tokens.bone : navHover.hovered ? Tokens.tint10 : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Style.sp(2.5)
                            anchors.rightMargin: Style.sp(2.5)
                            spacing: Style.sp(3)
                            Icon {
                                name: navItem.modelData.icon
                                size: Style.fs.lg
                                color: navItem.current ? Tokens.inkOnBone : Tokens.inkMuted
                            }
                            Text {
                                Layout.fillWidth: true
                                text: (navItem.current ? "// " : "") + navItem.modelData.label
                                color: navItem.current ? Tokens.inkOnBone : Tokens.inkDim
                                font.family: Style.fontUi
                                font.pixelSize: Style.fs.md
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                            Text {
                                text: navItem.modelData.kana
                                color: navItem.current ? Tokens.inkOnBone : Tokens.inkFaint
                                opacity: navItem.current ? 0.75 : 0.55
                                font.family: Tokens.jp
                                font.pixelSize: Style.fs.sm
                            }
                        }

                        HoverHandler { id: navHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (!navItem.current) Router.push(navItem.modelData.page)
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // --- edition register (dead-space ornament, per the design language) ----------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.sp(1.5)
            Hairline { Layout.fillWidth: true; soft: true }
            Text {
                text: "ED. 力 // NATIVE"
                color: Tokens.inkFaint
                font.family: Style.fontMono
                font.pixelSize: Style.fs.xs
                font.letterSpacing: 1.2
            }
        }
    }
}
