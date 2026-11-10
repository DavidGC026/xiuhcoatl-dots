import QtQuick
import QtQuick.Controls
import Quickshell.Wayland
import "../"

Rectangle {
    id: card
    required property var windowInfo
    property bool selected: false
    property bool capturing: false
    signal activated()
    signal moveRequested()
    signal selectedRequested()

    color: card.selected ? Qt.tint(ThemeBackend.mantle, Qt.alpha(DvgEstilo.carmin, 0.22)) : ThemeBackend.mantle
    radius: 12
    border.width: selected ? 2 : 1
    border.color: card.selected ? DvgEstilo.oro : Qt.alpha(DvgEstilo.oro, 0.25)
    Accessible.role: Accessible.Pane
    Accessible.name: windowInfo.title + ", escritorio " + windowInfo.workspaceLabel
    Accessible.onPressAction: card.activated()
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
            card.selectedRequested();
            if (mouse.button === Qt.LeftButton) card.activated();
        }
    }

    Item {
        id: previewArea
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 10 }
        height: Math.max(32, card.height - 88)
        clip: true

        ScreencopyView {
            id: preview
            property bool captureStopped: false
            onCaptureSourceChanged: captureStopped = false
            onStopped: captureStopped = true
            anchors.centerIn: parent
            constraintSize: Qt.size(previewArea.width, previewArea.height)
            captureSource: card.capturing && card.windowInfo.id.indexOf("hypr:") === 0 && card.windowInfo.native ? (card.windowInfo.native.wayland || null) : null
            live: card.capturing
            paintCursor: false
            visible: hasContent && !captureStopped
        }

        Column {
            anchors.centerIn: parent
            spacing: 8
            visible: !preview.hasContent || preview.captureStopped
            width: parent.width
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: card.windowInfo.appId.substring(0, 1).toLocaleUpperCase()
                color: DvgEstilo.oro
                font { family: DvgEstilo.tituloFont; pixelSize: 38 }
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "Vista previa no disponible"
                color: ThemeBackend.subtext0
                font { family: ThemeBackend.fontFamily; pixelSize: 11 }
                elide: Text.ElideRight
            }
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: function(mouse) {
                card.selectedRequested();
                if (mouse.button === Qt.LeftButton) card.activated();
            }
        }
    }

    Column {
        anchors { left: parent.left; right: moveButton.left; bottom: parent.bottom; leftMargin: 12; rightMargin: 8; bottomMargin: 12 }
        spacing: 4
        Text {
            width: parent.width
            text: card.windowInfo.title
            color: ThemeBackend.text
            font { family: ThemeBackend.fontFamily; pixelSize: 13; bold: true }
            elide: Text.ElideRight
            maximumLineCount: 1
        }
        Text {
            width: parent.width
            text: card.windowInfo.appId + " · " + (card.windowInfo.workspaceLabel || "Sin escritorio")
            color: card.selected ? DvgEstilo.oro : ThemeBackend.subtext0
            font { family: ThemeBackend.fontFamily; pixelSize: 11 }
            elide: Text.ElideRight
        }
    }
    Button {
        id: moveButton
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: 10; bottomMargin: 10 }
        width: 62; height: 30
        text: "Mover"
        enabled: card.windowInfo.id.indexOf("hypr:") === 0
        onClicked: { card.selectedRequested(); card.moveRequested(); }
        Accessible.name: "Mover " + card.windowInfo.title + " a otro escritorio"
        contentItem: Text {
            text: moveButton.text
            color: DvgEstilo.oro
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            font { family: ThemeBackend.fontFamily; pixelSize: 11 }
        }
        background: Rectangle {
            radius: 7
            color: moveButton.down ? DvgEstilo.carmin : Qt.alpha(DvgEstilo.carmin, 0.2)
            border.color: moveButton.activeFocus ? DvgEstilo.oro : Qt.alpha(DvgEstilo.oro, 0.4)
        }
    }
}
