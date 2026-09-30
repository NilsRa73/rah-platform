import QtQuick 2.15
Rectangle {
    id: root
    property int stage
    color: "#050505"
    Image { anchors.fill: parent; source: "file:///usr/share/backgrounds/rah/rah-gold.svg"; fillMode: Image.PreserveAspectCrop; asynchronous: true }
    Rectangle { anchors.fill: parent; color: "#55000000" }
    Column {
        anchors.centerIn: parent
        spacing: 18
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "RAH OS"; color: "#F4D477"; font.pixelSize: 78; font.bold: true; font.letterSpacing: 12 }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "GOLD SHELL  //  RAVEN SYSTEM"; color: "#B49345"; font.pixelSize: 22; font.letterSpacing: 5 }
    }
}
