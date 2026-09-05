pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Ryoku.Ui.Singletons
import "../"
import "../components"

// The settings surface, ported from ui/src/lib/components/SettingsDialog.svelte (plus the account,
// local-folder and playlist-transfer controls the Svelte app spreads across its titlebar and
// library). Every UI_SETTINGS key the daemon accepts round-trips through set_setting; the theme
// mode drives Style.themeMode, which pins Tokens to the local light/dark palette so the whole chrome
// re-renders. File choices use zenity (the same picker the library Local tab already adopted; the
// daemon dropped its Tauri dialogs for an explicit path). Nothing here polls: discord status is
// fetched on open and after a toggle, never on an interval, honouring the no-idle-timer rule.
Item {
    id: page

    property string section: "general"
    property var settings: ({})
    property var clients: []
    property bool loaded: false
    property string discordStatus: "disabled"
    property var folders: []
    property bool foldersLoaded: false
    property var identities: []
    property bool clearing: false
    property bool importing: false
    property bool exporting: false

    // Editable-field mirrors, seeded on load so typing never fights the settings binding.
    property string proxyInput: ""
    property string discordNameInput: "Ryotunes"

    readonly property var qualities: [
        { id: "LOW", l: "Low" },
        { id: "AUTO", l: "Auto" },
        { id: "HIGH", l: "High" }
    ]
    readonly property var uiScales: [80, 90, 100, 110, 120, 130, 140]
    readonly property var sections: [
        { k: "general", l: "General", jp: "全般" },
        { k: "playback", l: "Playback", jp: "再生" },
        { k: "data", l: "Data & storage", jp: "保存" },
        { k: "account", l: "Account", jp: "鍵" },
        { k: "local", l: "Local music", jp: "音源" },
        { k: "playlists", l: "Playlists", jp: "転送" },
        { k: "about", l: "About", jp: "力" }
    ]

    Component.onCompleted: page.load()

    // --- data ------------------------------------------------------------------------------
    function load() {
        Promise.all([
            Daemon.call("get_settings").catch(() => ({})),
            Daemon.call("get_stream_clients").catch(() => [])
        ]).then((res) => {
            page.settings = res[0] || ({});
            page.clients = res[1] || [];
            page.proxyInput = page.settings.proxy || "";
            page.discordNameInput = (page.settings.discord_presence_name || "").trim() || "Ryotunes";
            page.loaded = true;
            page.loadDiscord();
        }).catch((e) => { page.loaded = true; Playback.toast((e && e.message) ? e.message : String(e), "error"); });
    }

    function selectSection(k) {
        page.section = k;
        if (k === "local" && !page.foldersLoaded) page.scanFolders();
        if (k === "account") page.loadIdentities();
        if (k === "general") page.loadDiscord();
    }

    function applyLocal(key, value) {
        var s = ({});
        for (var k in page.settings) s[k] = page.settings[k];
        s[key] = value;
        page.settings = s;
        // Keep the chrome that binds Playback.settings (the titlebar's Discord light) coherent.
        var ps = ({});
        for (var k2 in Playback.settings) ps[k2] = Playback.settings[k2];
        ps[key] = value;
        Playback.settings = ps;
    }
    function setSetting(key, value) {
        page.applyLocal(key, value);
        return Daemon.call("set_setting", { key: key, value: value })
            .catch((e) => Playback.toast((e && e.message) ? e.message : "Could not save setting", "error"));
    }

    function loadDiscord() {
        Daemon.call("discord_status")
            .then((d) => { if (d && d.status) page.discordStatus = d.status; })
            .catch(() => {});
    }
    function setDiscord(on) {
        page.setSetting("discord_rpc", on ? "true" : "false").then(() => page.loadDiscord());
    }
    function saveDiscordName() {
        var value = page.discordNameInput.trim() || "Ryotunes";
        var n = value.length;
        if (n < 2 || n > 128) {
            Playback.toast("Discord presence title must be between 2 and 128 characters", "error");
            return;
        }
        page.discordNameInput = value;
        page.setSetting("discord_presence_name", value)
            .then(() => Playback.toast("Discord now shows “Listening to " + value + "”", "success"));
    }
    function setAutostart(on) {
        var prev = page.settings.autostart;
        page.applyLocal("autostart", on ? "true" : "false");
        Daemon.call("set_setting", { key: "autostart", value: on ? "true" : "false" })
            .catch((e) => { page.applyLocal("autostart", prev || "false"); Playback.toast((e && e.message) ? e.message : "Could not change autostart", "error"); });
    }
    function setQuality(q) {
        page.setSetting("quality", q)
            .then(() => Daemon.call("clear_caches").catch(() => {}))
            .then(() => Playback.toast("Audio quality updated", "success"));
    }
    function saveProxy() {
        var value = page.proxyInput.trim();
        page.setSetting("proxy", value)
            .then(() => { page.proxyInput = value; Playback.toast("Proxy saved — restart to apply", "success"); });
    }
    function clearCaches() {
        page.clearing = true;
        Daemon.call("clear_caches")
            .then(() => { page.clearing = false; Playback.toast("Caches cleared", "success"); })
            .catch((e) => { page.clearing = false; Playback.toast((e && e.message) ? e.message : String(e), "error"); });
    }

    function clientDisabled(name) {
        return (page.settings.disabled_stream_clients || "").split(",").map((s) => s.trim()).filter(Boolean).indexOf(name) >= 0;
    }
    function toggleClient(name) {
        var set = (page.settings.disabled_stream_clients || "").split(",").map((s) => s.trim()).filter(Boolean);
        var i = set.indexOf(name);
        if (i >= 0) set.splice(i, 1); else set.push(name);
        page.setSetting("disabled_stream_clients", set.join(","));
    }

    // --- account ---------------------------------------------------------------------------
    function loadIdentities() {
        Daemon.call("get_account_identities")
            .then((rows) => { page.identities = rows || []; })
            .catch(() => { page.identities = []; });
    }
    function switchAccount(key) {
        Daemon.call("switch_account", { selectionKey: key })
            .then(() => { page.loadIdentities(); Playback.toast("Account switched", "success"); })
            .catch((e) => Playback.toast((e && e.message) ? e.message : "Could not switch account", "error"));
    }

    // --- local folders ---------------------------------------------------------------------
    function scanFolders() {
        page.foldersLoaded = true;
        Daemon.call("get_local_library")
            .then((l) => { page.folders = (l && l.folders) ? l.folders : []; })
            .catch((e) => Playback.toast((e && e.message) ? e.message : "Could not scan local music", "error"));
    }
    function addFolder(path) {
        if (!path) return;
        Daemon.call("add_local_folder", { path: path })
            .then((l) => { if (l && l.folders) page.folders = l.folders; })
            .catch((e) => Playback.toast((e && e.message) ? e.message : "Could not add folder", "error"));
    }
    function removeFolder(path) {
        Daemon.call("remove_local_folder", { path: path })
            .then((l) => { page.folders = (l && l.folders) ? l.folders : []; })
            .catch((e) => Playback.toast((e && e.message) ? e.message : "Could not remove folder", "error"));
    }

    // --- playlist transfer -----------------------------------------------------------------
    function doImport(path) {
        page.importing = true;
        Daemon.call("import_playlist_file", { path: path })
            .then((transfer) => {
                if (!transfer || !transfer.items || !transfer.items.length) {
                    page.importing = false;
                    Playback.toast("That playlist file has no tracks.", "error");
                    return;
                }
                return Daemon.call("create_playlist", { title: transfer.title }).then((id) => {
                    var chain = Promise.resolve();
                    var added = 0;
                    for (var i = 0; i < transfer.items.length; i++) {
                        (function (song) {
                            chain = chain.then(() => Daemon.call("add_to_playlist", { playlistId: id, videoId: song.video_id })
                                .then((ok) => { if (ok) added++; })
                                .catch(() => {}));
                        })(transfer.items[i]);
                    }
                    return chain.then(() => {
                        page.importing = false;
                        Playback.toast("Imported " + added + (added === 1 ? " song" : " songs"), "success");
                    });
                });
            })
            .catch((e) => { page.importing = false; Playback.toast((e && e.message) ? e.message : "Could not import", "error"); });
    }
    function doExport(path) {
        var items = (Playback.queue && Playback.queue.items) ? Playback.queue.items : [];
        if (!items.length) return;
        var title = (Playback.queue && Playback.queue.sourceName) ? Playback.queue.sourceName : "Ryotunes Queue";
        page.exporting = true;
        Daemon.call("export_playlist_file", { title: title, items: items, path: path })
            .then(() => { page.exporting = false; Playback.toast("Queue exported", "success"); })
            .catch((e) => { page.exporting = false; Playback.toast((e && e.message) ? e.message : "Could not export", "error"); });
    }

    function discordLabel(s) {
        return s === "connected" ? "Connected"
            : s === "connecting" ? "Connecting…"
            : s === "unavailable" ? "Discord not running / unavailable"
            : "Disabled";
    }

    // --- pickers (zenity; the daemon expects an explicit path) ------------------------------
    Process {
        id: folderPicker
        command: ["zenity", "--file-selection", "--directory", "--title=Choose a music folder"]
        stdout: StdioCollector {
            id: folderOut
            onStreamFinished: { var p = folderOut.text.trim(); if (p) page.addFolder(p); }
        }
    }
    Process {
        id: importPicker
        command: ["zenity", "--file-selection", "--title=Import a playlist file"]
        stdout: StdioCollector {
            id: importOut
            onStreamFinished: { var p = importOut.text.trim(); if (p) page.doImport(p); }
        }
    }
    Process {
        id: exportPicker
        command: ["zenity", "--file-selection", "--save", "--confirm-overwrite", "--title=Export the queue", "--filename=ryotunes-queue.json"]
        stdout: StdioCollector {
            id: exportOut
            onStreamFinished: { var p = exportOut.text.trim(); if (p) page.doExport(p); }
        }
    }

    Rectangle { anchors.fill: parent; color: Tokens.paper }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // --- section rail -------------------------------------------------------------------
        Rectangle {
            Layout.preferredWidth: Style.sp(46)
            Layout.fillHeight: true
            color: Tokens.paper
            Hairline { anchors.right: parent.right; width: 1; height: parent.height }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Style.sp(3)
                spacing: Style.sp(1)

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: Style.sp(2)
                    spacing: 1
                    Text {
                        text: "力 // SETTINGS"
                        color: Tokens.inkDim
                        font.family: Style.fontUi
                        font.pixelSize: Style.fs.md
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                    }
                    Text {
                        text: "RYOTUNES // 設定"
                        color: Tokens.inkFaint
                        font.family: Style.fontMono
                        font.pixelSize: Style.fs.xs
                        font.letterSpacing: 1
                    }
                }

                Repeater {
                    model: page.sections
                    delegate: Rectangle {
                        id: railItem
                        required property var modelData
                        readonly property bool current: page.section === railItem.modelData.k
                        Layout.fillWidth: true
                        implicitHeight: Style.sp(9)
                        radius: Style.radius
                        color: railItem.current ? Tokens.bone : railHover.hovered ? Tokens.tint10 : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Style.sp(2.5)
                            anchors.rightMargin: Style.sp(2.5)
                            spacing: Style.sp(2)
                            Text {
                                Layout.fillWidth: true
                                text: (railItem.current ? "// " : "") + railItem.modelData.l
                                color: railItem.current ? Tokens.inkOnBone : Tokens.inkDim
                                font.family: Style.fontUi
                                font.pixelSize: Style.fs.md
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                            Text {
                                text: railItem.modelData.jp
                                color: railItem.current ? Tokens.inkOnBone : Tokens.inkFaint
                                opacity: railItem.current ? 0.8 : 0.55
                                font.family: Tokens.jp
                                font.pixelSize: Style.fs.sm
                            }
                        }
                        HoverHandler { id: railHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.selectSection(railItem.modelData.k)
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }

        // --- section body -------------------------------------------------------------------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Text {
                anchors.centerIn: parent
                visible: !page.loaded
                text: "Loading…"
                color: Tokens.inkMuted
                font.family: Style.fontUi
                font.pixelSize: Style.fs.md
            }

            Flickable {
                id: scroll
                anchors.fill: parent
                visible: page.loaded
                clip: true
                contentWidth: width
                boundsBehavior: Flickable.StopAtBounds
                contentHeight: {
                    var h = 0;
                    if (page.section === "general") h = generalCol.implicitHeight;
                    else if (page.section === "playback") h = playbackCol.implicitHeight;
                    else if (page.section === "data") h = dataCol.implicitHeight;
                    else if (page.section === "account") h = accountCol.implicitHeight;
                    else if (page.section === "local") h = localCol.implicitHeight;
                    else if (page.section === "playlists") h = playlistsCol.implicitHeight;
                    else h = aboutCol.implicitHeight;
                    return h + Style.sp(16);
                }

                // ─────────────────────────── GENERAL ───────────────────────────
                ColumnLayout {
                    id: generalCol
                    visible: page.section === "general"
                    anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: Style.sp(8); rightMargin: Style.sp(8); topMargin: Style.sp(6) }
                    spacing: Style.sp(1)

                    Text { text: "General"; color: Tokens.ink; font.family: Tokens.display; font.pixelSize: Style.fs.xl }
                    Text {
                        Layout.fillWidth: true
                        text: "Session behaviour, desktop integration and the theme."
                        color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; wrapMode: Text.WordWrap
                    }
                    Item { Layout.preferredHeight: Style.sp(2) }

                    // Appearance / theme
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.sp(1)
                        Text { text: "Appearance"; color: Tokens.ink; font.family: Style.fontUi; font.pixelSize: Style.fs.md; font.weight: Font.DemiBold }
                        Text {
                            Layout.fillWidth: true
                            text: "Follow the desktop automatically, or pin Ryotunes to its light or dark palette."
                            color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; wrapMode: Text.WordWrap
                        }
                        RowLayout {
                            Layout.topMargin: Style.sp(1)
                            spacing: Style.sp(2)
                            Repeater {
                                model: [ { m: "system", l: "Follow system" }, { m: "light", l: "Light" }, { m: "dark", l: "Dark" } ]
                                delegate: Chip {
                                    required property var modelData
                                    text: modelData.l
                                    active: Style.themeMode === modelData.m
                                    onClicked: Style.themeMode = modelData.m
                                }
                            }
                        }
                        Text {
                            text: "Currently " + (Tokens.light ? "light" : "dark") + ". Ryoku accent and reduced-motion preferences still apply."
                            color: Tokens.inkFaint; font.family: Style.fontMono; font.pixelSize: Style.fs.xs
                        }
                    }
                    Hairline { Layout.fillWidth: true; Layout.topMargin: Style.sp(3); Layout.bottomMargin: Style.sp(3) }

                    // Watch history
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.sp(4)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text { text: "Watch history"; color: Tokens.ink; font.family: Style.fontUi; font.pixelSize: Style.fs.md; font.weight: Font.Medium }
                            Text {
                                Layout.fillWidth: true
                                text: (Playback.auth && Playback.auth.signedIn) ? "Register completed plays in your YouTube Music history." : "Sign in to register completed plays in your YouTube Music history."
                                color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; wrapMode: Text.WordWrap
                            }
                        }
                        Toggle {
                            checked: page.settings.enable_history !== "false"
                            onToggled: (v) => page.setSetting("enable_history", v ? "true" : "false")
                        }
                    }
                    Hairline { Layout.fillWidth: true; Layout.topMargin: Style.sp(3); Layout.bottomMargin: Style.sp(3) }

                    // Discord rich presence
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.sp(4)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text { text: "Discord rich presence"; color: Tokens.ink; font.family: Style.fontUi; font.pixelSize: Style.fs.md; font.weight: Font.Medium }
                            Text {
                                Layout.fillWidth: true
                                text: "Show what you're listening to on your Discord profile through the local Discord client."
                                color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; wrapMode: Text.WordWrap
                            }
                            Text {
                                text: "Status: " + page.discordLabel(page.discordStatus)
                                color: Tokens.inkFaint; font.family: Style.fontMono; font.pixelSize: Style.fs.xs
                            }
                        }
                        Toggle {
                            checked: page.settings.discord_rpc === "true"
                            onToggled: (v) => page.setDiscord(v)
                        }
                    }
                    Hairline { Layout.fillWidth: true; Layout.topMargin: Style.sp(3); Layout.bottomMargin: Style.sp(3) }

                    // Discord presence title
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.sp(1)
                        Text { text: "Discord presence title"; color: Tokens.ink; font.family: Style.fontUi; font.pixelSize: Style.fs.md; font.weight: Font.DemiBold }
                        Text {
                            Layout.fillWidth: true
                            text: "The text Discord renders as “Listening to …”."
                            color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; wrapMode: Text.WordWrap
                        }
                        RowLayout {
                            Layout.topMargin: Style.sp(1)
                            Layout.fillWidth: true
                            spacing: Style.sp(2)
                            Rectangle {
                                Layout.preferredWidth: Style.sp(70)
                                implicitHeight: Style.sp(9)
                                radius: Style.radius
                                color: Tokens.paperLift
                                border.width: 1
                                border.color: discordField.activeFocus ? Tokens.lineStrong : Tokens.line
                                TextInput {
                                    id: discordField
                                    anchors.fill: parent
                                    anchors.leftMargin: Style.sp(2)
                                    anchors.rightMargin: Style.sp(2)
                                    verticalAlignment: TextInput.AlignVCenter
                                    clip: true
                                    maximumLength: 128
                                    color: Tokens.ink
                                    font.family: Style.fontUi
                                    font.pixelSize: Style.fs.md
                                    text: page.discordNameInput
                                    onTextChanged: page.discordNameInput = text
                                    onAccepted: page.saveDiscordName()
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: discordField.text.length === 0
                                        text: "Ryotunes"
                                        color: Tokens.inkFaint
                                        font: discordField.font
                                    }
                                }
                            }
                            Pill { label: "Save"; enabled: page.discordNameInput.trim().length > 0; onClicked: page.saveDiscordName() }
                            Pill { label: "Reset"; enabled: page.discordNameInput !== "Ryotunes"; onClicked: { page.discordNameInput = "Ryotunes"; page.saveDiscordName(); } }
                        }
                        Text {
                            text: "Preview: Listening to " + (page.discordNameInput.trim() || "Ryotunes")
                            color: Tokens.inkFaint; font.family: Style.fontUi; font.pixelSize: Style.fs.xs
                        }
                    }
                    Hairline { Layout.fillWidth: true; Layout.topMargin: Style.sp(3); Layout.bottomMargin: Style.sp(3) }

                    // Close to tray
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.sp(4)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text { text: "Close to tray"; color: Tokens.ink; font.family: Style.fontUi; font.pixelSize: Style.fs.md; font.weight: Font.Medium }
                            Text {
                                Layout.fillWidth: true
                                text: "Closing the window keeps music playing in the background."
                                color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; wrapMode: Text.WordWrap
                            }
                        }
                        Toggle {
                            checked: page.settings.close_to_tray !== "false"
                            onToggled: (v) => page.setSetting("close_to_tray", v ? "true" : "false")
                        }
                    }
                    Hairline { Layout.fillWidth: true; Layout.topMargin: Style.sp(3); Layout.bottomMargin: Style.sp(3) }

                    // Low resource mode
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.sp(4)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text { text: "Low resource mode"; color: Tokens.ink; font.family: Style.fontUi; font.pixelSize: Style.fs.md; font.weight: Font.Medium }
                            Text {
                                Layout.fillWidth: true
                                text: "Disable speculative stream warming and reduce automatic Home/network work and decorative motion."
                                color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; wrapMode: Text.WordWrap
                            }
                        }
                        Toggle {
                            checked: page.settings.low_resource_mode === "true"
                            onToggled: (v) => page.setSetting("low_resource_mode", v ? "true" : "false")
                        }
                    }
                    Hairline { Layout.fillWidth: true; Layout.topMargin: Style.sp(3); Layout.bottomMargin: Style.sp(3) }

                    // Start on login
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.sp(4)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text { text: "Start on login"; color: Tokens.ink; font.family: Style.fontUi; font.pixelSize: Style.fs.md; font.weight: Font.Medium }
                            Text {
                                Layout.fillWidth: true
                                text: "Launch Ryotunes automatically when you log in."
                                color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; wrapMode: Text.WordWrap
                            }
                        }
                        Toggle {
                            checked: page.settings.autostart === "true"
                            onToggled: (v) => page.setAutostart(v)
                        }
                    }
                    Hairline { Layout.fillWidth: true; Layout.topMargin: Style.sp(3); Layout.bottomMargin: Style.sp(3) }

                    // Interface scale
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.sp(1)
                        Text { text: "Interface scale"; color: Tokens.ink; font.family: Style.fontUi; font.pixelSize: Style.fs.md; font.weight: Font.DemiBold }
                        Text {
                            Layout.fillWidth: true
                            text: "Preferred renderer scale, persisted for every Ryotunes client on this account."
                            color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; wrapMode: Text.WordWrap
                        }
                        Flow {
                            Layout.fillWidth: true
                            Layout.topMargin: Style.sp(1)
                            spacing: Style.sp(2)
                            Repeater {
                                model: page.uiScales
                                delegate: Chip {
                                    required property var modelData
                                    text: modelData + "%"
                                    active: Number(page.settings.ui_scale || "110") === modelData
                                    onClicked: page.setSetting("ui_scale", String(modelData))
                                }
                            }
                        }
                    }
                }

                // ─────────────────────────── PLAYBACK ───────────────────────────
                ColumnLayout {
                    id: playbackCol
                    visible: page.section === "playback"
                    anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: Style.sp(8); rightMargin: Style.sp(8); topMargin: Style.sp(6) }
                    spacing: Style.sp(1)

                    Text { text: "Playback"; color: Tokens.ink; font.family: Tokens.display; font.pixelSize: Style.fs.xl }
                    Text {
                        Layout.fillWidth: true
                        text: "How the listening engine resolves, queues and carries a session forward."
                        color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; wrapMode: Text.WordWrap
                    }
                    Item { Layout.preferredHeight: Style.sp(2) }

                    // Audio quality
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.sp(1)
                        Text { text: "Audio quality"; color: Tokens.ink; font.family: Style.fontUi; font.pixelSize: Style.fs.md; font.weight: Font.DemiBold }
                        Text {
                            Layout.fillWidth: true
                            text: "Preferred stream quality when resolving a track. Changing it clears cached URLs."
                            color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; wrapMode: Text.WordWrap
                        }
                        RowLayout {
                            Layout.topMargin: Style.sp(1)
                            spacing: Style.sp(2)
                            Repeater {
                                model: page.qualities
                                delegate: Chip {
                                    required property var modelData
                                    text: modelData.l
                                    active: (page.settings.quality || "HIGH") === modelData.id
                                    onClicked: page.setQuality(modelData.id)
                                }
                            }
                        }
                    }
                    Hairline { Layout.fillWidth: true; Layout.topMargin: Style.sp(3); Layout.bottomMargin: Style.sp(3) }

                    // Autoplay
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.sp(4)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text { text: "Autoplay"; color: Tokens.ink; font.family: Style.fontUi; font.pixelSize: Style.fs.md; font.weight: Font.Medium }
                            Text {
                                Layout.fillWidth: true
                                text: "Keep the music going with similar songs when your queue ends."
                                color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; wrapMode: Text.WordWrap
                            }
                        }
                        Toggle {
                            checked: page.settings.autoplay !== "false"
                            onToggled: (v) => page.setSetting("autoplay", v ? "true" : "false")
                        }
                    }
                    Hairline { Layout.fillWidth: true; Layout.topMargin: Style.sp(3); Layout.bottomMargin: Style.sp(3) }

                    // Prevent duplicates
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.sp(4)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text { text: "Prevent duplicate tracks in queue"; color: Tokens.ink; font.family: Style.fontUi; font.pixelSize: Style.fs.md; font.weight: Font.Medium }
                            Text {
                                Layout.fillWidth: true
                                text: "Adding a track already queued moves it instead of adding a second copy."
                                color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; wrapMode: Text.WordWrap
                            }
                        }
                        Toggle {
                            checked: page.settings.prevent_duplicates === "true"
                            onToggled: (v) => page.setSetting("prevent_duplicates", v ? "true" : "false")
                        }
                    }
                    Hairline { Layout.fillWidth: true; Layout.topMargin: Style.sp(3); Layout.bottomMargin: Style.sp(3) }

                    // Word-by-word lyrics
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.sp(4)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text { text: "Word-by-word lyrics"; color: Tokens.ink; font.family: Style.fontUi; font.pixelSize: Style.fs.md; font.weight: Font.Medium }
                            Text {
                                Layout.fillWidth: true
                                text: "Ask lyrics-api.boidu.dev first for per-word timings. Turning this off keeps your listening off that service; line-by-line lyrics still work."
                                color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; wrapMode: Text.WordWrap
                            }
                        }
                        Toggle {
                            checked: page.settings.lyrics_boidu !== "false"
                            onToggled: (v) => page.setSetting("lyrics_boidu", v ? "true" : "false")
                        }
                    }
                    Hairline { Layout.fillWidth: true; Layout.topMargin: Style.sp(3); Layout.bottomMargin: Style.sp(3) }

                    // Stream clients
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.sp(1)
                        Text { text: "Stream clients"; color: Tokens.ink; font.family: Style.fontUi; font.pixelSize: Style.fs.md; font.weight: Font.DemiBold }
                        Text {
                            Layout.fillWidth: true
                            text: "Advanced — turn a client off to skip it when resolving streams."
                            color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; wrapMode: Text.WordWrap
                        }
                        Repeater {
                            model: page.clients
                            delegate: RowLayout {
                                id: clientRow
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.topMargin: Style.sp(1)
                                spacing: Style.sp(4)
                                Text {
                                    Layout.fillWidth: true
                                    text: clientRow.modelData
                                    color: Tokens.inkDim
                                    font.family: Style.fontMono
                                    font.pixelSize: Style.fs.sm
                                }
                                Toggle {
                                    checked: !page.clientDisabled(clientRow.modelData)
                                    onToggled: () => page.toggleClient(clientRow.modelData)
                                }
                            }
                        }
                    }
                }

                // ─────────────────────────── DATA ───────────────────────────
                ColumnLayout {
                    id: dataCol
                    visible: page.section === "data"
                    anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: Style.sp(8); rightMargin: Style.sp(8); topMargin: Style.sp(6) }
                    spacing: Style.sp(1)

                    Text { text: "Data & storage"; color: Tokens.ink; font.family: Tokens.display; font.pixelSize: Style.fs.xl }
                    Text {
                        Layout.fillWidth: true
                        text: "Network routing and local storage used to keep the instrument responsive."
                        color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; wrapMode: Text.WordWrap
                    }
                    Item { Layout.preferredHeight: Style.sp(2) }

                    // Proxy
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.sp(1)
                        Text { text: "Proxy"; color: Tokens.ink; font.family: Style.fontUi; font.pixelSize: Style.fs.md; font.weight: Font.DemiBold }
                        Text {
                            Layout.fillWidth: true
                            text: "HTTP or HTTPS proxy for all YouTube traffic. Takes effect on restart."
                            color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; wrapMode: Text.WordWrap
                        }
                        RowLayout {
                            Layout.topMargin: Style.sp(1)
                            Layout.fillWidth: true
                            spacing: Style.sp(2)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.maximumWidth: Style.sp(120)
                                implicitHeight: Style.sp(9)
                                radius: Style.radius
                                color: Tokens.paperLift
                                border.width: 1
                                border.color: proxyField.activeFocus ? Tokens.lineStrong : Tokens.line
                                TextInput {
                                    id: proxyField
                                    anchors.fill: parent
                                    anchors.leftMargin: Style.sp(2)
                                    anchors.rightMargin: Style.sp(2)
                                    verticalAlignment: TextInput.AlignVCenter
                                    clip: true
                                    color: Tokens.ink
                                    font.family: Style.fontUi
                                    font.pixelSize: Style.fs.md
                                    text: page.proxyInput
                                    onTextChanged: page.proxyInput = text
                                    onAccepted: page.saveProxy()
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: proxyField.text.length === 0
                                        text: "http://host:port (blank = none)"
                                        color: Tokens.inkFaint
                                        font: proxyField.font
                                    }
                                }
                            }
                            Pill { label: "Save"; onClicked: page.saveProxy() }
                        }
                    }
                    Hairline { Layout.fillWidth: true; Layout.topMargin: Style.sp(3); Layout.bottomMargin: Style.sp(3) }

                    // Cache
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.sp(1)
                        Text { text: "Cache"; color: Tokens.ink; font.family: Style.fontUi; font.pixelSize: Style.fs.md; font.weight: Font.DemiBold }
                        Text {
                            Layout.fillWidth: true
                            text: "Clear cached stream URLs and downloaded audio bytes."
                            color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; wrapMode: Text.WordWrap
                        }
                        Pill { Layout.topMargin: Style.sp(1); label: page.clearing ? "Clearing…" : "Clear caches"; icon: "close"; enabled: !page.clearing; onClicked: page.clearCaches() }
                    }
                }

                // ─────────────────────────── ACCOUNT ───────────────────────────
                ColumnLayout {
                    id: accountCol
                    visible: page.section === "account"
                    anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: Style.sp(8); rightMargin: Style.sp(8); topMargin: Style.sp(6) }
                    spacing: Style.sp(1)

                    Text { text: "Account"; color: Tokens.ink; font.family: Tokens.display; font.pixelSize: Style.fs.xl }
                    Text {
                        Layout.fillWidth: true
                        text: "Sign in only when your YouTube library needs it. Desktop services stay local."
                        color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; wrapMode: Text.WordWrap
                    }
                    Item { Layout.preferredHeight: Style.sp(2) }

                    // current identity
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.sp(3)
                        Artwork {
                            visible: !!(Playback.auth && Playback.auth.avatar)
                            url: (Playback.auth && Playback.auth.avatar) ? Playback.auth.avatar : ""
                            px: Style.sp(12)
                            round: true
                            placeholderIcon: "account"
                        }
                        Icon {
                            visible: !(Playback.auth && Playback.auth.avatar)
                            name: "account"; size: Style.fs.hero; color: Tokens.inkMuted
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: (Playback.auth && Playback.auth.signedIn && Playback.auth.name) ? Playback.auth.name : "Not signed in"
                                color: Tokens.ink; font.family: Style.fontUi; font.pixelSize: Style.fs.lg; font.weight: Font.DemiBold
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }
                            Text {
                                text: (Playback.auth && Playback.auth.signedIn) ? "YouTube Music" : "Sign in to sync your library"
                                color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm
                            }
                        }
                        Pill {
                            label: (Playback.auth && Playback.auth.signedIn) ? "Sign out" : "Sign in with Google"
                            icon: (Playback.auth && Playback.auth.signedIn) ? "close" : "account"
                            primary: !(Playback.auth && Playback.auth.signedIn)
                            onClicked: {
                                var out = !!(Playback.auth && Playback.auth.signedIn);
                                Daemon.call(out ? "sign_out" : "sign_in").catch((e) => Playback.toast((e && e.message) ? e.message : String(e), "error"));
                            }
                        }
                    }
                    Hairline { Layout.fillWidth: true; Layout.topMargin: Style.sp(3); Layout.bottomMargin: Style.sp(3) }

                    // switch account
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: page.identities.length > 0
                        spacing: Style.sp(1)
                        Text { text: "Switch channel"; color: Tokens.ink; font.family: Style.fontUi; font.pixelSize: Style.fs.md; font.weight: Font.DemiBold }
                        Text {
                            Layout.fillWidth: true
                            text: "Pick which YouTube channel or brand account this session acts as."
                            color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; wrapMode: Text.WordWrap
                        }
                        Repeater {
                            model: page.identities
                            delegate: RowLayout {
                                id: idRow
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.topMargin: Style.sp(1)
                                spacing: Style.sp(2)
                                Artwork {
                                    url: idRow.modelData.thumbnail || ""
                                    px: Style.sp(8)
                                    round: true
                                    placeholderIcon: "account"
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text {
                                        Layout.fillWidth: true
                                        text: idRow.modelData.name + (idRow.modelData.selected ? "  ·  CURRENT" : "")
                                        color: Tokens.ink; font.family: Style.fontUi; font.pixelSize: Style.fs.md; elide: Text.ElideRight
                                    }
                                    Text {
                                        visible: !!idRow.modelData.handle
                                        text: idRow.modelData.handle || ""
                                        color: Tokens.inkMuted; font.family: Style.fontMono; font.pixelSize: Style.fs.xs
                                    }
                                }
                                Pill {
                                    label: "Use"
                                    enabled: !idRow.modelData.selected
                                    onClicked: page.switchAccount(idRow.modelData.selectionKey)
                                }
                            }
                        }
                    }
                    Text {
                        visible: page.identities.length === 0
                        text: (Playback.auth && Playback.auth.signedIn) ? "This account has a single channel." : "Sign in to see the channels on this account."
                        color: Tokens.inkFaint; font.family: Style.fontUi; font.pixelSize: Style.fs.sm
                    }
                }

                // ─────────────────────────── LOCAL MUSIC ───────────────────────────
                ColumnLayout {
                    id: localCol
                    visible: page.section === "local"
                    anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: Style.sp(8); rightMargin: Style.sp(8); topMargin: Style.sp(6) }
                    spacing: Style.sp(1)

                    Text { text: "Local music"; color: Tokens.ink; font.family: Tokens.display; font.pixelSize: Style.fs.xl }
                    Text {
                        Layout.fillWidth: true
                        text: "Folders Ryotunes watches for files on disk. The daemon rescans them on demand."
                        color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; wrapMode: Text.WordWrap
                    }
                    Item { Layout.preferredHeight: Style.sp(2) }

                    RowLayout {
                        Layout.topMargin: Style.sp(1)
                        spacing: Style.sp(2)
                        Pill { label: "Add folder"; icon: "add"; primary: true; onClicked: folderPicker.running = true }
                        Pill { label: "Rescan"; icon: "on-repeat"; onClicked: page.scanFolders() }
                        Item { Layout.fillWidth: true }
                    }

                    Text {
                        visible: !page.folders.length
                        Layout.topMargin: Style.sp(2)
                        text: "No folders yet. Add the one your music sits in."
                        color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm
                    }

                    Repeater {
                        model: page.folders
                        delegate: RowLayout {
                            id: folderRow
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.topMargin: Style.sp(1)
                            spacing: Style.sp(2)
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: Style.sp(9)
                                radius: Style.radius
                                color: Tokens.paperLift
                                border.width: 1
                                border.color: Tokens.line
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Style.sp(2.5)
                                    anchors.rightMargin: Style.sp(1)
                                    spacing: Style.sp(2)
                                    Icon { name: "music"; size: Style.fs.sm; color: Tokens.inkMuted }
                                    Text {
                                        Layout.fillWidth: true
                                        text: folderRow.modelData
                                        color: Tokens.inkDim
                                        font.family: Style.fontMono
                                        font.pixelSize: Style.fs.sm
                                        elide: Text.ElideMiddle
                                    }
                                    IconButton {
                                        icon: "close"
                                        iconSize: Style.fs.sm
                                        diameter: Style.sp(7)
                                        onClicked: page.removeFolder(folderRow.modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                // ─────────────────────────── PLAYLISTS ───────────────────────────
                ColumnLayout {
                    id: playlistsCol
                    visible: page.section === "playlists"
                    anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: Style.sp(8); rightMargin: Style.sp(8); topMargin: Style.sp(6) }
                    spacing: Style.sp(1)

                    Text { text: "Playlists"; color: Tokens.ink; font.family: Tokens.display; font.pixelSize: Style.fs.xl }
                    Text {
                        Layout.fillWidth: true
                        text: "Move playlists between machines as portable .json files (YouTube Music tracks only)."
                        color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; wrapMode: Text.WordWrap
                    }
                    Item { Layout.preferredHeight: Style.sp(2) }

                    // Import
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.sp(1)
                        Text { text: "Import a playlist"; color: Tokens.ink; font.family: Style.fontUi; font.pixelSize: Style.fs.md; font.weight: Font.DemiBold }
                        Text {
                            Layout.fillWidth: true
                            text: "Choose a Ryotunes playlist file; its tracks land in a new library playlist. Sign in first."
                            color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; wrapMode: Text.WordWrap
                        }
                        Pill {
                            Layout.topMargin: Style.sp(1)
                            label: page.importing ? "Importing…" : "Import from file"
                            icon: "add"
                            enabled: !page.importing && !!(Playback.auth && Playback.auth.signedIn)
                            onClicked: importPicker.running = true
                        }
                    }
                    Hairline { Layout.fillWidth: true; Layout.topMargin: Style.sp(3); Layout.bottomMargin: Style.sp(3) }

                    // Export
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.sp(1)
                        Text { text: "Export the current queue"; color: Tokens.ink; font.family: Style.fontUi; font.pixelSize: Style.fs.md; font.weight: Font.DemiBold }
                        Text {
                            Layout.fillWidth: true
                            text: "Write the tracks now in your queue to a portable .json file."
                            color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; wrapMode: Text.WordWrap
                        }
                        Pill {
                            Layout.topMargin: Style.sp(1)
                            label: page.exporting ? "Exporting…" : "Export to file"
                            icon: "playlist"
                            enabled: !page.exporting && !!(Playback.queue && Playback.queue.items && Playback.queue.items.length)
                            onClicked: exportPicker.running = true
                        }
                    }
                }

                // ─────────────────────────── ABOUT ───────────────────────────
                ColumnLayout {
                    id: aboutCol
                    visible: page.section === "about"
                    anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: Style.sp(8); rightMargin: Style.sp(8); topMargin: Style.sp(6) }
                    spacing: Style.sp(2)

                    Text { text: "About"; color: Tokens.ink; font.family: Tokens.display; font.pixelSize: Style.fs.xl }
                    Text {
                        Layout.fillWidth: true
                        text: "A focused Ryoku desktop music instrument: your YouTube Music library, local media, queue, lyrics and playback engine in one paper-and-ink surface."
                        color: Tokens.inkMuted; font.family: Style.fontUi; font.pixelSize: Style.fs.md; wrapMode: Text.WordWrap
                    }
                    GridLayout {
                        Layout.topMargin: Style.sp(2)
                        columns: 2
                        columnSpacing: Style.sp(6)
                        rowSpacing: Style.sp(1)
                        Text { text: "RELEASE"; color: Tokens.inkFaint; font.family: Style.fontMono; font.pixelSize: Style.fs.xs }
                        Text { text: "v2.4"; color: Tokens.inkDim; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; font.weight: Font.Medium }
                        Text { text: "DAEMON"; color: Tokens.inkFaint; font.family: Style.fontMono; font.pixelSize: Style.fs.xs }
                        Text { text: Daemon.daemonVersion || "—"; color: Tokens.inkDim; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; font.weight: Font.Medium }
                        Text { text: "ENGINE"; color: Tokens.inkFaint; font.family: Style.fontMono; font.pixelSize: Style.fs.xs }
                        Text { text: "RUST + MPV"; color: Tokens.inkDim; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; font.weight: Font.Medium }
                        Text { text: "CLIENT"; color: Tokens.inkFaint; font.family: Style.fontMono; font.pixelSize: Style.fs.xs }
                        Text { text: "QUICKSHELL / QML"; color: Tokens.inkDim; font.family: Style.fontUi; font.pixelSize: Style.fs.sm; font.weight: Font.Medium }
                    }
                }
            }
        }
    }
}
