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

        // Honour this monitor's Interface scale through Tokens, the same way the Hub does; the app's
        // own sp()/type scale ride on it.
        Binding {
            target: Tokens
            property: "uiScale"
            value: Tokens.uiScaleFor(win.screen && win.screen.name ? win.screen.name : "")
        }

        App { anchors.fill: parent }
    }

    IpcHandler {
        target: "window"
        function show(): void { win.visible = true; }
    }
}
