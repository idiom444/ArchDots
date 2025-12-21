import QtQuick
import Quickshell.Widgets
import "../../../../lib" as Libs

WrapperRectangle {
    id: clockBubble
    margin: 4         // padding around the text
    radius: 10
    color: Libs.Theme.primary_container
    Text {
        color: Libs.Theme.on_primary_container
	    text: Time.time
	    font: Libs.Theme.uiFont
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
