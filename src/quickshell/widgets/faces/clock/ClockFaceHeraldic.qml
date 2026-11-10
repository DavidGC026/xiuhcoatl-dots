pragma ComponentBehavior: Bound
import QtQuick
import "../../../"

// Esfera de sobremesa de DVG: marcas grabadas, agujas de oro y segundero carmín.
// Comparte el reloj y el formato del shell; no crea otro temporizador.
Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 180
    property real minHeight: 140
    property real maxWidth: 1400
    property real maxHeight: 1000
    property real minAspect: 0.85
    property real maxAspect: 2.8
    property bool isRound: false

    property date currentTime: DateTime.now
    readonly property bool showSeconds: DateTime.hasSeconds
    readonly property bool wide: width / Math.max(1, height) >= 1.7
    readonly property real inset: Math.max(7, Math.min(width, height) * 0.045)
    readonly property real dialSize: Math.max(1, wide
        ? Math.min(height - inset * 2, width * 0.47)
        : Math.min(width - inset * 2, height * 0.66))
    readonly property real hourAngle: (currentTime.getHours() % 12) * 30 + currentTime.getMinutes() * 0.5 + currentTime.getSeconds() / 120
    readonly property real minuteAngle: currentTime.getMinutes() * 6 + currentTime.getSeconds() * 0.1
    readonly property real secondAngle: currentTime.getSeconds() * 6
    readonly property var numerals: ["XII", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI"]

    Accessible.role: Accessible.Indicator
    Accessible.name: "Heráldico DVG · " + DateTime.time + " · " + DateTime.fullDate

    Rectangle {
        anchors.fill: parent
        radius: Math.min(18, Math.min(width, height) * 0.06)
        color: ThemeBackend.faded(ThemeBackend.base)
        border.width: 1
        border.color: Qt.alpha(DvgEstilo.oro, 0.65)
        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: Math.max(0, parent.radius - 3)
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(DvgEstilo.oro, 0.14)
        }
    }

    Item {
        id: dial
        x: root.wide ? root.inset : (root.width - width) / 2
        y: root.wide ? (root.height - height) / 2 : root.inset
        width: root.dialSize
        height: width

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: ThemeBackend.faded(ThemeBackend.mantle)
            border.width: Math.max(1, width * 0.005)
            border.color: DvgEstilo.oro
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: dial.width * 0.018
            radius: width / 2
            color: "transparent"
            border.width: Math.max(1, dial.width * 0.01)
            border.color: DvgEstilo.carmin
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: dial.width * 0.052
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(DvgEstilo.oro, 0.28)
        }

        Repeater {
            model: 60
            Item {
                required property int index
                anchors.fill: parent
                rotation: index * 6
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: dial.width * 0.066
                    width: Math.max(1, dial.width * (parent.index % 5 === 0 ? 0.008 : 0.003))
                    height: dial.width * (parent.index % 5 === 0 ? 0.031 : 0.012)
                    color: Qt.alpha(DvgEstilo.oro, parent.index % 5 === 0 ? 1 : 0.45)
                    radius: width / 2
                }
            }
        }

        Repeater {
            model: root.numerals
            Text {
                required property string modelData
                required property int index
                readonly property real angle: index * Math.PI / 6 - Math.PI / 2
                x: dial.width / 2 + Math.cos(angle) * dial.width * 0.365 - width / 2
                y: dial.height / 2 + Math.sin(angle) * dial.height * 0.365 - height / 2
                text: modelData
                color: DvgEstilo.oro
                font.family: DvgEstilo.tituloFont
                font.pixelSize: Math.max(7, dial.width * 0.066)
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: dial.height * 0.245
            text: "DVG"
            color: Qt.alpha(DvgEstilo.oro, 0.6)
            font.family: DvgEstilo.tituloFont
            font.pixelSize: Math.max(6, dial.width * 0.043)
            font.letterSpacing: dial.width * 0.008
            visible: dial.width >= 145
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: dial.height * 0.635
            text: "XIUHCÓATL"
            color: Qt.alpha(DvgEstilo.oro, 0.45)
            font.family: DvgEstilo.tituloFont
            font.pixelSize: Math.max(5, dial.width * 0.029)
            font.letterSpacing: dial.width * 0.006
            visible: dial.width >= 180
        }

        Item {
            anchors.fill: parent
            rotation: root.hourAngle
            Behavior on rotation {
                RotationAnimation { duration: DesktopModes.animationDuration(180); direction: RotationAnimation.Clockwise }
            }
            Rectangle {
                x: (dial.width - width) / 2
                y: dial.height * 0.275
                width: Math.max(3, dial.width * 0.025)
                height: dial.height * 0.265
                radius: width / 2
                color: DvgEstilo.oro
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.22
                    width: Math.max(1, parent.width * 0.26)
                    height: parent.height * 0.5
                    radius: width / 2
                    color: DvgEstilo.carmin
                }
            }
        }
        Item {
            anchors.fill: parent
            rotation: root.minuteAngle
            Behavior on rotation {
                RotationAnimation { duration: DesktopModes.animationDuration(180); direction: RotationAnimation.Clockwise }
            }
            Rectangle {
                x: (dial.width - width) / 2
                y: dial.height * 0.18
                width: Math.max(2, dial.width * 0.013)
                height: dial.height * 0.365
                radius: width / 2
                color: DvgEstilo.oro
            }
        }
        Item {
            anchors.fill: parent
            visible: root.showSeconds
            rotation: root.secondAngle
            Behavior on rotation {
                RotationAnimation { duration: DesktopModes.animationDuration(150); direction: RotationAnimation.Clockwise }
            }
            Rectangle {
                x: (dial.width - width) / 2
                y: dial.height * 0.155
                width: Math.max(1, dial.width * 0.006)
                height: dial.height * 0.43
                radius: width / 2
                color: DvgEstilo.carmin
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: dial.height * 0.565
                width: Math.max(3, dial.width * 0.026)
                height: width
                radius: width / 2
                color: ThemeBackend.mantle
                border.width: 1
                border.color: DvgEstilo.carmin
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: Math.max(6, dial.width * 0.045)
            height: width
            rotation: 45
            color: DvgEstilo.carmin
            border.width: Math.max(1, dial.width * 0.004)
            border.color: DvgEstilo.oro
        }
    }

    Item {
        id: inscription
        x: root.wide ? dial.x + dial.width + root.inset : root.inset
        y: root.wide ? root.inset : dial.y + dial.height + root.inset * 0.25
        width: Math.max(1, root.width - x - root.inset)
        height: Math.max(1, root.height - y - root.inset)

        Column {
            anchors.centerIn: parent
            width: parent.width
            spacing: Math.max(2, Math.min(6, inscription.height * 0.045))
            Text {
                width: parent.width
                visible: inscription.height >= 58
                text: DateTime.dayName.toLocaleUpperCase()
                color: root.currentTime.getDay() === 0 ? DvgEstilo.carmin : DvgEstilo.oro
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Math.max(8, Math.min(15, inscription.height * 0.14))
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                height: Math.max(16, Math.min(48, inscription.height * 0.4))
                text: DateTime.time
                color: ThemeBackend.text
                font.family: DvgEstilo.tituloFont
                font.pixelSize: height
                fontSizeMode: Text.Fit
                minimumPixelSize: 8
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            Item {
                width: parent.width * 0.72
                height: Math.max(3, Math.min(7, inscription.height * 0.06))
                anchors.horizontalCenter: parent.horizontalCenter
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 1; color: Qt.alpha(DvgEstilo.oro, 0.35) }
                Rectangle { anchors.centerIn: parent; width: parent.height * 0.7; height: width; rotation: 45; color: DvgEstilo.carmin; border.width: 1; border.color: DvgEstilo.oro }
            }
            Text {
                width: parent.width
                text: DateTime.shortDate + " · " + DateTime.year
                color: ThemeBackend.subtext1
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Math.max(8, Math.min(16, inscription.height * 0.15))
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
    }
}
