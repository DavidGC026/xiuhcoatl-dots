pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../../"

// An engraved cartouche sized by the bar's cross-axis. The common DateTime
// singleton owns formatting and ticking; this face creates no polling timer.
Item {
    id: root
    property var widget: null
    readonly property bool isVertical: widget ? widget.orientation === "vertical" : false
    readonly property real crossExtent: {
        if (widget && widget.module && widget.module.thickness > 0) return widget.module.thickness;
        let extent = widget ? (isVertical ? widget.width : widget.height) : 0;
        return extent > 0 ? extent : s(40);
    }
    readonly property real inset: s(2)
    readonly property real frameThickness: Math.max(s(18), crossExtent - inset * 2)
    readonly property real timeFontSize: Math.max(s(11), Math.min(s(22), frameThickness * 0.58))
    readonly property real sideFontSize: Math.max(s(11), Math.min(s(20), frameThickness * 0.52))
    readonly property real dateFontSize: Math.max(s(8), Math.min(s(11), frameThickness * 0.30))
    readonly property real sidePadding: Math.max(s(3), Math.min(s(6), frameThickness * 0.14))

    readonly property string fullTime: widget && widget.timeStr !== undefined ? String(widget.timeStr) : DateTime.time
    readonly property string hours: widget && widget.hourStr !== undefined ? String(widget.hourStr) : DateTime.hour
    readonly property string minutes: widget && widget.minuteStr !== undefined ? String(widget.minuteStr) : DateTime.minute
    readonly property string seconds: widget && widget.secondStr !== undefined ? String(widget.secondStr) : DateTime.second
    readonly property string meridiem: widget && widget.timeAmPmStr !== undefined ? String(widget.timeAmPmStr || "") : DateTime.amPm
    readonly property bool hasMinutes: DateTime.timeFormat.indexOf("m") !== -1
    readonly property bool showDate: widget && widget.showDate !== undefined ? Boolean(widget.showDate) : true
    readonly property string shortDate: widget && widget.shortDateStr !== undefined ? String(widget.shortDateStr) : DateTime.shortDate
    readonly property string day: widget && widget.dayStr !== undefined && widget.dayStr !== null ? String(widget.dayStr) : DateTime.day
    readonly property string month: widget && widget.monthStr !== undefined && widget.monthStr !== null ? String(widget.monthStr) : DateTime.monthShort
    readonly property string fullDate: widget && widget.fullDateStr !== undefined ? String(widget.fullDateStr) : DateTime.fullDate

    function s(value) {
        return widget && typeof widget.s === "function" ? widget.s(value) : value;
    }
    function openCalendar() {
        if (Caching.serpantinumDir)
            Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "toggle", "calendar"]);
    }

    implicitWidth: isVertical ? frameThickness : horizontalContent.implicitWidth + sidePadding * 2
    implicitHeight: isVertical ? verticalContent.implicitHeight + sidePadding * 2 : frameThickness
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: fullTime + (showDate ? ", " + fullDate : "")
    Accessible.description: I18n.t("guide.bar.timedate.open_calendar", "Abrir calendario")
    Accessible.onPressAction: openCalendar()
    Keys.onReturnPressed: openCalendar()
    Keys.onEnterPressed: openCalendar()
    Keys.onSpacePressed: openCalendar()

    Rectangle {
        anchors.fill: parent
        radius: root.s(5)
        color: ThemeBackend.mantle
        border.width: 1
        border.color: root.activeFocus ? ThemeBackend.text : Qt.alpha(DvgEstilo.oro, 0.9)
        Rectangle {
            anchors.fill: parent
            anchors.margins: root.s(2)
            radius: root.s(3)
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(DvgEstilo.oro, 0.23)
        }
    }

    Row {
        id: horizontalContent
        anchors.centerIn: parent
        visible: !root.isVertical
        spacing: root.s(7)
        Diamond {
            anchors.verticalCenter: parent.verticalCenter
            size: root.s(4)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.fullTime
            textFormat: Text.PlainText
            color: DvgEstilo.oro
            font { family: DvgEstilo.tituloFont; pixelSize: root.timeFontSize; weight: Font.DemiBold }
            Accessible.ignored: true
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showDate
            width: 1
            height: Math.max(root.s(8), root.frameThickness - root.s(12))
            color: Qt.alpha(DvgEstilo.oro, 0.3)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showDate
            text: root.shortDate
            textFormat: Text.PlainText
            color: ThemeBackend.text
            font { family: ThemeBackend.fontFamily; pixelSize: root.dateFontSize }
            Accessible.ignored: true
        }
    }

    Column {
        id: verticalContent
        anchors.centerIn: parent
        visible: root.isVertical
        width: root.frameThickness - root.sidePadding * 2
        spacing: root.s(1)
        Diamond {
            anchors.horizontalCenter: parent.horizontalCenter
            size: root.s(3)
            height: root.s(6)
        }
        SideText { text: root.hours; color: DvgEstilo.oro; font.family: DvgEstilo.tituloFont; font.pixelSize: root.sideFontSize; font.weight: Font.DemiBold }
        SideText { text: root.minutes; visible: root.hasMinutes; font.pixelSize: root.sideFontSize }
        SideText { text: root.seconds; visible: root.seconds !== ""; color: Qt.lighter(DvgEstilo.carmin, 1.8); font.pixelSize: root.dateFontSize }
        SideText { text: root.meridiem; visible: root.meridiem !== ""; color: DvgEstilo.oro; font.pixelSize: root.dateFontSize }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.showDate
            width: Math.min(parent.width, root.s(18)); height: 1
            color: Qt.alpha(DvgEstilo.oro, 0.35)
        }
        SideText { text: root.day; visible: root.showDate; font.pixelSize: root.dateFontSize; font.bold: true }
        SideText { text: root.month; visible: root.showDate; color: DvgEstilo.oro; font.pixelSize: root.dateFontSize }
    }

    component SideText: Text {
        width: verticalContent.width
        horizontalAlignment: Text.AlignHCenter
        textFormat: Text.PlainText
        color: ThemeBackend.text
        font.family: ThemeBackend.fontFamily
        // Narrow 28px rails retain the full value by fitting the occasional
        // wider localized month or AM/PM string inside the engraved frame.
        fontSizeMode: Text.HorizontalFit
        minimumPixelSize: Math.max(6, root.s(7))
        Accessible.ignored: true
    }
    component Diamond: Item {
        property real size: root.s(4)
        width: size * 1.5
        height: width
        Rectangle {
            anchors.centerIn: parent
            width: parent.size; height: width
            rotation: 45
            color: DvgEstilo.carmin
            border.width: 1
            border.color: Qt.alpha(DvgEstilo.oro, 0.75)
        }
    }
}
