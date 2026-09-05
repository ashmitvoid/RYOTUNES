pragma Singleton
import QtQuick
import Quickshell
import Ryoku.Ui.Singletons
import "lib/style.js" as Fns

// The app's own scale, radii, type and motion, on top of Ryoku's Tokens (which supply the Follow
// System colours). Colours come from Tokens for the live theme; `light`/`dark` are the two local
// palettes ported from ui/src/lib/ryotunes.css --ryo-* variables, used when the theme mode pins a
// fixed palette (Task 7). thumb()/fmtTime() are re-exposed from lib/style.js so a QtTest process,
// which cannot load Quickshell, can test the same code.
Singleton {
    id: root

    // Follows whatever scale the active window pins on Tokens (Tokens.uiScaleFor(screen)); 1 until
    // a window sets it. sp(n) is the 4 px grid step scaled to match.
    readonly property real uiScale: Tokens.uiScale
    function sp(n) { return Math.round(n * 4 * root.uiScale); }

    readonly property int radius: Math.round(6 * root.uiScale)       // --ryo-radius
    readonly property int radiusCard: Math.round(10 * root.uiScale)

    readonly property string fontUi: "Space Grotesk"
    readonly property string fontMono: "SpaceMono Nerd Font"
    readonly property string fontCjk: "Noto Sans CJK JP"

    // Compact type scale (px), scaled with the UI. Metadata/eyebrow sizes at the low end, a page
    // hero at the top, matching the ryotunes.css font-size ladder.
    readonly property var fs: ({
        xs: Math.round(9 * root.uiScale),
        sm: Math.round(11 * root.uiScale),
        md: Math.round(13 * root.uiScale),
        lg: Math.round(16 * root.uiScale),
        xl: Math.round(22 * root.uiScale),
        hero: Math.round(34 * root.uiScale)
    })

    // Durations (ms). shell.services Perf (reduce-motion, power tiers) is not importable under
    // `qs -p client`, so these are constants; Task 3+ can gate them on Perf once App hosts the shell.
    readonly property var motion: ({ snap: 120, move: 170, slow: 260 })

    // The two local palettes, --ryo-* from ryotunes.css. Selected by the theme mode in Task 7; the
    // live Follow System palette is read straight from Tokens.
    readonly property var dark: ({
        paper: "#050505", paperLift: "#0d0d0c", panel: "#090908", card: "#0d0d0c",
        sidebar: "#070706", player: "#080807",
        ink: "#d7cfc6", inkDim: "#b6aea5", inkMuted: "#999188", inkFaint: "#817a72",
        bone: "#d7cfc6", inkOnBone: "#090807", sun: "#e2342a", alert: "#d33b32"
    })
    readonly property var light: ({
        paper: "#c8c4bc", paperLift: "#d5d0c7", panel: "#beb9b0", card: "#d0cbc2",
        sidebar: "#bbb6ad", player: "#c3beb5",
        ink: "#211f1c", inkDim: "#403b35", inkMuted: "#625c53", inkFaint: "#786f65",
        bone: "#292620", inkOnBone: "#eee8de", sun: "#e2342a", alert: "#d33b32"
    })

    function thumb(url, px) { return Fns.thumb(url, px); }
    function fmtTime(secs) { return Fns.fmtTime(secs); }
}
