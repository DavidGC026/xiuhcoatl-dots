import QtQuick
import QtQuick.Effects
import "../../"

// Esquinas con nudo celta (las del login de DVG OS) sobre un panel. Va dentro del
// panel con anchors.fill: parent; no recibe clics. El adorno se tiñe con el oro del
// tema activo, así combina también con otros temas.
Item {
    id: root

    property real tam: 56
    property real margen: 6
    property real opacidad: 0.9
    property color color: DvgEstilo.oro

    readonly property url fuente: "file://" + Caching.serpantinumDir + "/assets/dvg/esquina-celta.png"

    z: 100
    enabled: false

    Repeater {
        // 0 arriba izquierda, 1 arriba derecha, 2 abajo derecha, 3 abajo izquierda:
        // el dibujo original es la esquina superior izquierda y se gira de 90 en 90.
        model: 4

        Item {
            required property int index
            width: root.tam
            height: root.tam
            x: (index === 1 || index === 2) ? root.width - width - root.margen : root.margen
            y: index >= 2 ? root.height - height - root.margen : root.margen
            rotation: index * 90

            Image {
                id: esquina
                anchors.fill: parent
                source: root.fuente
                sourceSize: Qt.size(width * 2, height * 2)
                smooth: true
                mipmap: true
                visible: false
            }

            MultiEffect {
                anchors.fill: esquina
                source: esquina
                colorization: 1.0
                colorizationColor: root.color
                opacity: root.opacidad
            }
        }
    }
}
