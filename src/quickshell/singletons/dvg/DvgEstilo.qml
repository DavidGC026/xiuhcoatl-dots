pragma Singleton
import QtQuick
import Quickshell
import "../../"

// Estilo de DVG OS para Xiuhcóatl: Cinzel solo en títulos grandes (las etiquetas
// usan la fuente del tema) y los dos colores heráldicos de la marca. Los colores
// salen del tema activo: en DVG Carmín y Oro, maroon es el carmín (#A61B24) y
// mauve el oro (#E2A72E); con otro tema siguen combinando con él.
QtObject {
    id: root

    readonly property color carmin: ThemeBackend.maroon
    readonly property color oro: ThemeBackend.mauve

    readonly property FontLoader cinzel: FontLoader {
        source: (typeof Caching !== "undefined" && Caching.serpantinumDir)
            ? ("file://" + Caching.serpantinumDir + "/assets/fonts/Cinzel.ttf") : ""
    }

    readonly property string tituloFont: cinzel.status === FontLoader.Ready && cinzel.name !== ""
        ? cinzel.name : ThemeBackend.fontFamily
}
