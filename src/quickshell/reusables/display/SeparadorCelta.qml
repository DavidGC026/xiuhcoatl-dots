import QtQuick
import QtQuick.Effects
import "../../"

// Separador de cordón entrelazado con nudo central (el del login de DVG OS),
// teñido con el oro del tema. Mantiene la proporción 10:1 del dibujo.
Item {
    id: root

    property real alto: 14
    property real opacidad: 0.9
    property color color: DvgEstilo.oro

    implicitHeight: alto
    implicitWidth: alto * 10

    Image {
        id: nudo
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height * 10)
        height: width / 10
        source: "file://" + Caching.serpantinumDir + "/assets/dvg/nudo-celta.png"
        sourceSize: Qt.size(width * 2, height * 2)
        smooth: true
        mipmap: true
        visible: false
    }

    MultiEffect {
        anchors.fill: nudo
        source: nudo
        colorization: 1.0
        colorizationColor: root.color
        opacity: root.opacidad
    }
}
