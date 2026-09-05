import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Ui.Singletons

ShellRoot {
    // Ask for the version handshake, the event stream and its opening snapshot as soon as the
    // config is up. subscribeAll() is idempotent and re-subscribes on every reconnect, so a single
    // call here covers a daemon that is already up, one that starts later, and one that restarts.
    Component.onCompleted: Daemon.subscribeAll()

    FloatingWindow {
        id: win
        title: "Ryotunes"
        color: Tokens.paper
        minimumSize: Qt.size(900, 620)
        Text {
            anchors.centerIn: parent
            color: Tokens.ink
            font.family: "Space Grotesk"
            text: Daemon.connected ? ("ryotunesd " + Daemon.daemonVersion + " (protocol " + Daemon.protocol + ")") : "connecting to ryotunesd…"
        }
    }
    IpcHandler {
        target: "window"
        function show(): void { win.visible = true; }
    }
}
