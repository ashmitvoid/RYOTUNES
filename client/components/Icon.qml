pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Ryoku.Ui.Singletons

// One icon renderer for the whole client. The SVGs in client/icons are the Hugeicons free set the
// Svelte UI imports, rewritten with white strokes so MultiEffect colorization can retint them to
// any Tokens colour (a black stroke would stay black). sourceSize bounds the raster; the tinted
// result caches, so a static icon costs nothing after first paint.
Image {
    id: root

    property string name: ""
    property color color: Tokens.ink
    property int size: 18

    width: size
    height: size
    source: name ? Qt.resolvedUrl("../icons/" + name + ".svg") : ""
    sourceSize: Qt.size(Math.round(size * 2), Math.round(size * 2))
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
    asynchronous: true
    cache: true
    layer.enabled: true
    layer.effect: MultiEffect {
        colorization: 1.0
        colorizationColor: root.color
    }
}
