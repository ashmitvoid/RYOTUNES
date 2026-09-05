pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Ryoku.Ui.Singletons
import "../"

// "Edit playlist" details, ported from EditPlaylistDialog.svelte: name, description and visibility.
// edit_playlist_details merges only the fields sent, so an untouched one is never overwritten; the
// page reloads on save to pick up whatever YouTube accepted.
Item {
    id: root

    anchors.fill: parent
    z: 210

    property string playlistId: ""
    property string initialName: ""
    property string initialDescription: ""
    property bool initialPublic: false
    property bool saving: false

    signal closed()
    signal saved()

    property string nameText: initialName
    property string descText: initialDescription
    property bool isPublic: initialPublic

    function submit() {
        if (root.saving || !root.nameText.trim())
            return;
        root.saving = true;
        Daemon.call("edit_playlist_details", {
            playlistId: root.playlistId,
            name: root.nameText.trim(),
            description: root.descText,
            public: root.isPublic
        }).then(() => { root.saving = false; root.saved(); })
            .catch((e) => { root.saving = false; Playback.toast((e && e.message) ? e.message : "Could not save", "error"); });
    }

    MouseArea { anchors.fill: parent; onClicked: root.closed() }
    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.45 }

    Rectangle {
        anchors.centerIn: parent
        width: Style.sp(100)
        implicitHeight: col.implicitHeight + Style.sp(8)
        height: implicitHeight
        radius: Style.radiusCard
        color: Tokens.paperLift
        border.width: 1
        border.color: Tokens.lineStrong
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: Style.sp(4)
            spacing: Style.sp(3)

            Text {
                text: "Edit playlist"
                color: Tokens.ink
                font.family: Style.fontUi
                font.pixelSize: Style.fs.lg
                font.weight: Font.DemiBold
            }

            // name
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Style.sp(10)
                radius: Style.radius
                color: Tokens.paper
                border.width: 1
                border.color: nameField.activeFocus ? Tokens.lineStrong : Tokens.line
                TextInput {
                    id: nameField
                    anchors.fill: parent
                    anchors.leftMargin: Style.sp(2)
                    anchors.rightMargin: Style.sp(2)
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: Tokens.ink
                    font.family: Style.fontUi
                    font.pixelSize: Style.fs.md
                    text: root.nameText
                    focus: true
                    Component.onCompleted: nameField.forceActiveFocus()
                    onTextChanged: root.nameText = text
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: nameField.text.length === 0
                        text: "Playlist name"
                        color: Tokens.inkFaint
                        font: nameField.font
                    }
                }
            }

            // description
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Style.sp(24)
                radius: Style.radius
                color: Tokens.paper
                border.width: 1
                border.color: descField.activeFocus ? Tokens.lineStrong : Tokens.line
                TextEdit {
                    id: descField
                    anchors.fill: parent
                    anchors.margins: Style.sp(2)
                    clip: true
                    wrapMode: TextEdit.Wrap
                    color: Tokens.ink
                    font.family: Style.fontUi
                    font.pixelSize: Style.fs.sm
                    text: root.descText
                    onTextChanged: root.descText = text
                    Text {
                        visible: descField.text.length === 0
                        text: "Description"
                        color: Tokens.inkFaint
                        font: descField.font
                    }
                }
            }

            // public toggle
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.sp(2)
                Rectangle {
                    implicitWidth: Style.sp(9)
                    implicitHeight: Style.sp(5)
                    radius: height / 2
                    color: root.isPublic ? Tokens.sun : Tokens.tint16
                    Rectangle {
                        width: Style.sp(4); height: Style.sp(4); radius: width / 2
                        color: Tokens.paper
                        y: Style.sp(0.5)
                        x: root.isPublic ? parent.width - width - Style.sp(0.5) : Style.sp(0.5)
                        Behavior on x { NumberAnimation { duration: Style.motion.snap } }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.isPublic = !root.isPublic }
                }
                Text {
                    Layout.fillWidth: true
                    text: root.isPublic ? "Public" : "Private"
                    color: Tokens.inkDim
                    font.family: Style.fontUi
                    font.pixelSize: Style.fs.md
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: Style.sp(2)
                Pill { label: "Cancel"; onClicked: root.closed() }
                Pill { label: "Save"; primary: true; enabled: !root.saving && root.nameText.trim().length > 0; onClicked: root.submit() }
            }
        }
    }
}
