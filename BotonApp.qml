import QtQuick
import QtQuick.Controls.Basic
import NexStay

// Theme 11: boton con el estilo de la app y efecto al pasar el mouse.
// principal: true lo pinta azul (accion principal de la ventana).
Button {
    id: control
    property bool principal: false
    hoverEnabled: true
    font.pixelSize: 14

    contentItem: Text {
        text: control.text
        font: control.font
        color: control.principal ? Tema.textoSobrePrimario : Tema.texto
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        implicitWidth: 90
        implicitHeight: 38
        radius: 10
        opacity: control.enabled ? 1 : 0.5
        color: control.principal
               ? ((control.hovered || control.down) ? Tema.primarioOscuro : Tema.primario)
               : (control.down ? Tema.bordeFuerte : (control.hovered ? Tema.primarioSuave : Tema.tarjeta))
        border.width: control.principal ? 0 : 1
        border.color: control.hovered ? Tema.primario : Tema.bordeFuerte
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
