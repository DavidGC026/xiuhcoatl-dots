import QtQuick
import "../../"

// Filete carmín → oro → carmín: la firma heráldica de DVG OS bajo títulos y
// cabeceras. Se desvanece en los extremos para no cortar el vidrio del panel.
Rectangle {
    id: root
    property real grosor: 2
    implicitHeight: grosor
    radius: grosor / 2
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Qt.alpha(DvgEstilo.carmin, 0.0) }
        GradientStop { position: 0.2; color: DvgEstilo.carmin }
        GradientStop { position: 0.5; color: DvgEstilo.oro }
        GradientStop { position: 0.8; color: DvgEstilo.carmin }
        GradientStop { position: 1.0; color: Qt.alpha(DvgEstilo.carmin, 0.0) }
    }
}
