import QtQuick
import "../../../"
import "../../../reusables"

Item {
    id: el

    property string variant: "round"
    property var ctx: null

    readonly property real side: Math.min(width, height)
    readonly property string avatarSource: {
        if (el.ctx && el.ctx.faceIconPath !== undefined && el.ctx.faceIconPath !== "") return el.ctx.faceIconPath;
        if (SystemInfo.avatarPath === "") return "";
        return SystemInfo.avatarPath.startsWith("file://") ? SystemInfo.avatarPath : "file://" + SystemInfo.avatarPath;
    }

    ImageBox {
        anchors.centerIn: parent
        size: Math.round(el.side)
        cornerRadius: el.variant === "rounded" ? Math.round(ThemeBackend.borderRadius * 1.5) : Math.round(el.side / 2)
        imageRadius: cornerRadius
        source: el.avatarSource
        backgroundColor: el.avatarSource === "" ? ThemeBackend.surface1 : "transparent"

        // DVG OS: sin foto de perfil va el emblema de DVG.
        Image {
            anchors.centerIn: parent
            visible: el.avatarSource === ""
            width: el.side * 0.72
            height: width
            source: "file://" + Caching.serpantinumDir + "/assets/dvg/emblema.png"
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }
    }

    // Anillo de oro alrededor del avatar.
    Rectangle {
        anchors.centerIn: parent
        width: Math.round(el.side) + 6
        height: width
        radius: el.variant === "rounded" ? Math.round(ThemeBackend.borderRadius * 1.5) + 3 : width / 2
        color: "transparent"
        border.width: 2
        border.color: Qt.alpha(DvgEstilo.oro, 0.85)
    }
}
