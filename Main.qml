import QtQuick
import QtQuick.Controls.Basic
import NexStay

ApplicationWindow {
    id: window
    width: 420
    height: 640
    minimumWidth: 360
    minimumHeight: 560
    visible: true
    title: qsTr("NexStay - Habitación")

    // Paleta NexStay
    property color colorFondo: "#0d0d0d"
    property color colorTarjeta: "#161616"
    property color colorBorde: "#2a2a2a"
    property color colorDorado: "#D4AF37"
    property color colorTextoSecundario: "#8a8a8a"
    property color colorTextoClaro: "#f2f2f2"

    Habitacion {
        id: habitacion
    }

    // Icono por estado, usado tanto en el círculo central como en el menú
    function iconoPara(estado) {
        switch (estado) {
        case "ocupada": return "\u25A0"
        case "libre": return "\u2713"
        case "en limpieza": return "\u2728"
        case "reservada": return "\u29D6"
        case "fuera de servicio": return "\u26A0"
        default: return "?"
        }
    }

    function etiquetaPara(estado) {
        switch (estado) {
        case "ocupada": return qsTr("Ocupada")
        case "libre": return qsTr("Libre")
        case "en limpieza": return qsTr("En limpieza")
        case "reservada": return qsTr("Reservada")
        case "fuera de servicio": return qsTr("Fuera de servicio")
        default: return estado
        }
    }

    Rectangle {
        anchors.fill: parent
        color: window.colorFondo

        Column {
            anchors.centerIn: parent
            spacing: 18

            // Encabezado: número de habitación
            Column {
                width: parent.width
                spacing: 2
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("HABITACIÓN")
                    color: window.colorTextoSecundario
                    font.pixelSize: 13
                    font.letterSpacing: 1
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: habitacion.numero
                    color: window.colorDorado
                    font.pixelSize: 40
                    font.weight: Font.Medium
                }
            }

            // Círculo central de estado (tocable)
            Rectangle {
                id: circuloEstado
                width: 200
                height: 200
                radius: width / 2
                color: "transparent"
                border.color: window.colorDorado
                border.width: 3
                anchors.horizontalCenter: parent.horizontalCenter

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: window.iconoPara(habitacion.estadoActual)
                        color: window.colorDorado
                        font.pixelSize: 36
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: window.etiquetaPara(habitacion.estadoActual)
                        color: window.colorTextoClaro
                        font.pixelSize: 16
                        font.weight: Font.Medium
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: menuEstados.open()
                }
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Toca el círculo para cambiar el estado")
                color: window.colorTextoSecundario
                font.pixelSize: 11
            }

            // Barra inferior de accesos (placeholders para Themes 5 y 6)
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 28
                topPadding: 10

                Label { text: "\u26AA"; color: "#555555"; font.pixelSize: 18 }
                Label { text: "\u2709"; color: "#555555"; font.pixelSize: 18 }
                Label { text: "\u2692"; color: "#555555"; font.pixelSize: 18 }
            }
        }
    }

    // Popup con los 5 estados disponibles
    Popup {
        id: menuEstados
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        width: 260
        padding: 8

        background: Rectangle {
            color: window.colorTarjeta
            radius: 12
            border.color: window.colorBorde
            border.width: 1
        }

        contentItem: Column {
            spacing: 2

            Repeater {
                model: habitacion.estadosDisponibles

                delegate: Rectangle {
                    required property string modelData
                    width: menuEstados.width - 16
                    height: 46
                    radius: 8
                    color: modelData === habitacion.estadoActual ? window.colorDorado : "transparent"

                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: window.etiquetaPara(modelData)
                        color: modelData === habitacion.estadoActual ? "#1a1400" : window.colorTextoClaro
                        font.pixelSize: 14
                        font.weight: modelData === habitacion.estadoActual ? Font.Medium : Font.Normal
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            habitacion.cambiarEstado(modelData)
                            menuEstados.close()
                        }
                    }
                }
            }
        }
    }
}
