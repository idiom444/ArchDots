import Quickshell
import QtQuick
import "items/WorkspaceWidget" as WSWidget
import "items/ClockWidget" as Clock
import "../../lib" as Libs

Scope {
    id: barRoot
    property var primaryPanel: null
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: panel
            color: "transparent"
            required property var modelData
            screen: modelData
            anchors {
                top: true
                left: true
                right: true
            }
            Component.onCompleted: {
                if (barRoot.primaryPanel === null)
                    barRoot.primaryPanel = panel;
            }
            Component.onDestruction: {
                if (barRoot.primryPanel === panel)
                    barRoot.primaryPanel = null;
            }
            implicitHeight: Math.max(wsChild.implicitHeight, clockChild.implicitHeight) + 10
            Rectangle {
                anchors.fill: parent
                radius: 20
                color: Qt.rgba(Libs.Theme.barBg.r, Libs.Theme.barBg.g, Libs.Theme.barBg.b, Libs.Theme.barBg.a * Libs.Theme.barOpacity)
                WSWidget.WorkspaceWidget {
                    id: wsChild
                    screen: modelData
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                }
                Clock.ClockWidget {
                    id: clockChild
                    anchors.centerIn: parent
                }
            }
        }
    }
}
