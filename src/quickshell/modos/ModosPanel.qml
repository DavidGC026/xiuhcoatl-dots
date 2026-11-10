import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../"

Item {
    id: root
    implicitWidth: Scaler.s(620)
    implicitHeight: Scaler.s(650)
    enabled: visible
    signal closeRequested()

    Rectangle {
        anchors.fill: parent
        color: ThemeBackend.base
        radius: ThemeBackend.borderRadius
        border.color: DvgEstilo.oro
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Scaler.s(24)
        spacing: Scaler.s(16)

        RowLayout {
            Layout.fillWidth: true
            spacing: Scaler.s(12)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Scaler.s(4)
                Text {
                    text: "Modos del escritorio"
                    font.family: DvgEstilo.tituloFont
                    font.pixelSize: Scaler.s(25)
                    color: DvgEstilo.oro
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
                Text {
                    text: "Xiuhcóatl · DVG OS"
                    color: ThemeBackend.subtext0
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: Scaler.s(12)
                }
            }
            ModeButton { text: "Cerrar"; onClicked: root.closeRequested() }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 2; color: DvgEstilo.carmin }

        ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: scroll.availableWidth
                spacing: Scaler.s(18)

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: presentationColumn.implicitHeight + Scaler.s(36)
                    radius: ThemeBackend.borderRadius
                    color: ThemeBackend.mantle
                    border.color: DesktopModes.presentationActive ? DvgEstilo.oro : ThemeBackend.surface1
                    ColumnLayout {
                        id: presentationColumn
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Scaler.s(18) }
                        spacing: Scaler.s(12)
                        Text {
                            text: "Presentación"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: Scaler.s(19)
                            font.bold: true
                            color: ThemeBackend.text
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "Silencia todos los avisos y sus sonidos. Mantiene la pantalla encendida y bloquea la suspensión mientras presentas."
                            wrapMode: Text.Wrap
                            color: ThemeBackend.subtext1
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: Scaler.s(13)
                        }
                        Text {
                            Layout.fillWidth: true
                            text: !DesktopModes.presentationActive ? "Desactivada"
                                : DesktopModes.inhibitorError ? "Avisos silenciados · suspensión sin protección"
                                : DesktopModes.sleepInhibited ? "Activa · avisos silenciados y suspensión protegida"
                                : "Activando protección contra suspensión…"
                            wrapMode: Text.Wrap
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: Scaler.s(12)
                            color: DesktopModes.inhibitorError ? ThemeBackend.red : DvgEstilo.oro
                            Accessible.role: Accessible.StaticText
                        }
                        Text {
                            visible: DesktopModes.presentationActive && DesktopModes.inhibitorError !== ""
                            Layout.fillWidth: true
                            text: DesktopModes.inhibitorError
                            wrapMode: Text.Wrap
                            color: ThemeBackend.subtext0
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: Scaler.s(11)
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: Scaler.s(8)
                            ModeButton {
                                text: DesktopModes.presentationActive ? "Terminar presentación" : "Iniciar presentación"
                                active: DesktopModes.presentationActive
                                onClicked: DesktopModes.togglePresentation()
                            }
                            ModeButton {
                                visible: DesktopModes.presentationActive && DesktopModes.inhibitorError !== ""
                                text: "Reintentar protección"
                                onClicked: DesktopModes.retryInhibitor()
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: lightweightColumn.implicitHeight + Scaler.s(36)
                    radius: ThemeBackend.borderRadius
                    color: ThemeBackend.mantle
                    border.color: DesktopModes.lightweightActive ? DvgEstilo.oro : ThemeBackend.surface1
                    ColumnLayout {
                        id: lightweightColumn
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Scaler.s(18) }
                        spacing: Scaler.s(12)
                        Text {
                            text: "Modo ligero"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: Scaler.s(19)
                            font.bold: true
                            color: ThemeBackend.text
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "Reduce animaciones, usa paneles opacos y pausa los fondos de video. Tus preferencias se recuperan al desactivarlo."
                            wrapMode: Text.Wrap
                            color: ThemeBackend.subtext1
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: Scaler.s(13)
                        }
                        Text {
                            Layout.fillWidth: true
                            text: DesktopModes.lightweightReason + " · " + (DesktopModes.onBattery ? "Usando batería" : "Sin descarga de batería")
                            wrapMode: Text.Wrap
                            color: DesktopModes.lightweightActive ? DvgEstilo.oro : ThemeBackend.subtext0
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: Scaler.s(12)
                        }
                        ModeButton {
                            text: DesktopModes.lightweightManual ? "Desactivar modo manual" : "Activar modo manual"
                            active: DesktopModes.lightweightManual
                            onClicked: DesktopModes.toggleLightweight()
                        }
                        CheckBox {
                            id: autoBattery
                            Layout.fillWidth: true
                            text: "Activar automáticamente con batería"
                            checked: DesktopModes.autoOnBattery
                            onClicked: DesktopModes.setAutoOnBattery(checked)
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: Scaler.s(13)
                            palette.text: ThemeBackend.text
                            palette.buttonText: ThemeBackend.text
                            palette.highlight: DvgEstilo.carmin
                            palette.highlightedText: ThemeBackend.text
                            Accessible.name: text
                        }
                        Text {
                            Layout.fillWidth: true
                            text: DesktopModes.autoOnBattery
                                ? (DesktopModes.onBattery ? "La opción automática está actuando ahora. Conecta la corriente para dejar de aplicarla."
                                    : "La opción automática está preparada; se aplicará al descargar la batería.")
                                : "La opción automática está desactivada."
                            wrapMode: Text.Wrap
                            color: ThemeBackend.subtext0
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: Scaler.s(11)
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Al terminar una presentación vuelven tu estado de No molestar y tus temporizadores. Reiniciar Xiuhcóatl también termina la presentación."
                    color: ThemeBackend.subtext0
                    wrapMode: Text.Wrap
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: Scaler.s(11)
                }
            }
        }
    }
}
