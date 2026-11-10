import QtQuick
import QtQuick.Controls
import "../"

Button {
    id: root
    property bool active: false
    property bool prominent: false
    implicitHeight: Scaler.s(42)
    implicitWidth: Math.max(Scaler.s(100), label.implicitWidth + Scaler.s(32))
    font.family: ThemeBackend.fontFamily
    font.pixelSize: Scaler.s(13)
    Accessible.name: text
    contentItem: Text {
        id: label
        text: root.text
        font: root.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: ThemeBackend.text
        elide: Text.ElideRight
    }
    background: Rectangle {
        color: root.active || root.prominent ? DvgEstilo.carmin
            : root.hovered ? ThemeBackend.surface1 : ThemeBackend.surface0
        radius: Math.min(ThemeBackend.borderRadius, Scaler.s(8))
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus || root.active || root.prominent ? DvgEstilo.oro : ThemeBackend.surface2
    }
}
