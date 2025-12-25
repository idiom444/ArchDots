import Quickshell
import QtQuick
import Quickshell.Hyprland
import Quickshell.Widgets
import "../../../../lib" as Libs

WrapperRectangle {
    id: wsBubble

    property var screen
    readonly property var mon: screen ? Hyprland.monitorFor(screen) : null

    margin: 4
    radius: 10
    color: Libs.Theme.primary_container

    visible: mon !== null

    Row {
        spacing: 2
        Repeater {
            model: Hyprland.workspaces

            delegate: WrapperMouseArea {
                required property HyprlandWorkspace modelData

                visible: modelData.monitor === mon && !modelData.name.startsWith("special:")

                property string label: (modelData.id > 0 ? String(modelData.id) : modelData.name)

                onClicked: modelData.activate()

                WrapperRectangle {
                    property bool targettedWorkspace: modelData.active && modelData.focused
                    implicitWidth: implicitHeight

                    radius: 10
                    color: targettedWorkspace ? Libs.Theme.primary : Libs.Theme.surface_variant

                    Text {
                        id: child
                        text: label
                        color: targettedWorkspace ? Libs.Theme.on_primary : Libs.Theme.on_surface_variant
                        font: Libs.Theme.uiFont
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }
}
