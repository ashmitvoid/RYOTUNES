import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Ui.Singletons
import "mini"

ShellRoot {
    id: shellRoot
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
        App { id: appRoot; anchors.fill: parent }
    }

    // The mini player: its own compact toplevel, titled so the Hyprland rule can float it
    // independently. Visible follows App.miniOpen; a window-manager close syncs the flag back and
    // the maximize button returns to the full window. Geometry is session-local — the daemon has no
    // UI_SETTINGS key for the mini window, so it is not persisted across restarts (see Task 7 report).
    FloatingWindow {
        id: mini
        title: "Ryotunes Mini"
        color: Tokens.paper
        minimumSize: Qt.size(360, 520)
        visible: appRoot.miniOpen
        onClosed: appRoot.miniOpen = false

        MiniPlayer {
            anchors.fill: parent
            active: mini.visible
            onMaximize: { appRoot.miniOpen = false; win.visible = true; }
        }
    }

    // "Come back" from two directions: the daemon's `show` event (tray Show, a second `ryotunes` /
    // `ryotunesd` launch, the desktop keybind) and `qs -p ... ipc call window show`. A closed
    // FloatingWindow is hidden, not destroyed, so this process stays subscribed and the daemon's
    // show reaches it here rather than spawning a second client.
    function present(): void {
        // After a compositor close (Super+Q) the toplevel is gone but Quickshell leaves
        // `visible` at true, so assigning true again is a no-op; drop it first to remap.
        win.visible = false;
        win.visible = true;
    }
    Connections {
        target: Daemon
        function onEvent(name: string, data: var): void {
            if (name === "show")
                shellRoot.present();
        }
    }
    IpcHandler {
        target: "window"
        function show(): void { shellRoot.present(); }
    }
}
