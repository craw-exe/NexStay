import QtQuick
import NexStay

// Theme 11: tinte suave sobre cualquier elemento clicable al pasar el
// mouse. Se pone como hijo de un MouseArea con hoverEnabled: true.
Rectangle {
    anchors.fill: parent
    radius: parent && parent.parent && parent.parent.radius !== undefined ? parent.parent.radius : 8
    color: Tema.primario
    opacity: parent && parent.containsMouse ? (parent.pressed ? 0.16 : 0.08) : 0
    visible: opacity > 0
}
