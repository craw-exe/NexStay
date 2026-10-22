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
    property color colorExito: "#6fcf97"

    // --- Theme 5 (Task 1: interfaz, Task 2: guardado) ---
    // La presencia YA NO vive solo en memoria: viene de Estado_Presencia
    // via SolicitudesHuesped (Task 2). Es un binding de solo lectura;
    // para cambiarla se llama a solicitudes.cambiarPresencia().
    property bool estoyDentro: solicitudes.presencia === "dentro"
    // "limpieza" o "mantenimiento" mientras se espera la confirmacion
    // del huesped en el popup; vacio si no hay ninguna pendiente.
    property string solicitudPendiente: ""

    function mostrarAviso(texto) {
        textoAviso.text = texto
        avisoEnviado.opacity = 1
        temporizadorAviso.restart()
    }

    Timer {
        id: temporizadorAviso
        interval: 2500
        onTriggered: avisoEnviado.opacity = 0
    }

    // Boton redondo con icono y etiqueta debajo, para la fila inferior.
    component BotonAccion: Item {
        id: raiz
        property string icono
        property string etiqueta
        property bool resaltado: false
        // Colores propios (en vez de leer los del window) para que el
        // componente no dependa de ids externos.
        property color colorActivo: "#6fcf97"
        property color colorTexto: "#f2f2f2"
        property color colorEtiqueta: "#8a8a8a"
        signal tocado()

        implicitWidth: 72
        implicitHeight: 70

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 5

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 46
                height: 46
                radius: 23
                color: area.pressed ? "#1f1f1f" : "transparent"
                border.width: 1
                border.color: raiz.resaltado ? raiz.colorActivo : "#444444"

                Label {
                    anchors.centerIn: parent
                    text: raiz.icono
                    color: raiz.resaltado ? raiz.colorActivo : raiz.colorTexto
                    font.pixelSize: 20
                }
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: raiz.etiqueta
                color: raiz.colorEtiqueta
                font.pixelSize: 11
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            onClicked: raiz.tocado()
        }
    }

    // Theme 5, Task 2: capa que guarda la presencia y crea las
    // solicitudes en la BD (ver SolicitudesHuesped.h).
    SolicitudesHuesped {
        id: solicitudes

        onOperacionRechazada: function(motivo) {
            mensajeError.text = motivo
            mensajeError.visible = true
            temporizadorError.restart()
        }

        // Theme 5, Task 4: el personal marco la solicitud como atendida.
        onSolicitudAtendida: function(tipo) {
            window.mostrarAviso(tipo === "limpieza"
                                ? qsTr("Tu solicitud de limpieza fue atendida")
                                : qsTr("Tu solicitud de mantenimiento fue atendida"))
        }
    }

    Habitacion {
        id: habitacion

        onCambioRechazado: function(motivo) {
            mensajeError.text = motivo
            mensajeError.visible = true
            temporizadorError.restart()
        }
    }

    Timer {
        id: temporizadorError
        interval: 3000
        onTriggered: mensajeError.visible = false
    }

    // Icono por estado, usado tanto en el círculo central como en el menú
    function iconoPara(estado) {
        switch (estado) {
        case "ocupada": return "■"
        case "libre": return "✓"
        case "en limpieza": return "✨"
        case "reservada": return "⧖"
        case "fuera de servicio": return "⚠"
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
                // Verde mientras el huesped esta dentro; dorado al salir.
                border.color: window.estoyDentro ? window.colorExito : window.colorDorado
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

            // Mensaje de error (p. ej. si falla el guardado en la BD)
            Label {
                id: mensajeError
                anchors.horizontalCenter: parent.horizontalCenter
                width: 280
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                color: "#e05c5c"
                font.pixelSize: 11
                visible: false
            }

            // Barra inferior (Theme 5, Task 1): presencia y solicitudes.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                topPadding: 6

                // Alterna entre "dentro" y "fuera". El icono y la
                // etiqueta muestran el estado ACTUAL del huesped.
                BotonAccion {
                    icono: window.estoyDentro ? "⌂" : "➜"
                    etiqueta: window.estoyDentro ? qsTr("Dentro") : qsTr("Fuera")
                    resaltado: window.estoyDentro
                    onTocado: {
                        // Si falla, SolicitudesHuesped emite
                        // operacionRechazada y se muestra el error.
                        const nuevo = window.estoyDentro ? "fuera" : "dentro"
                        if (solicitudes.cambiarPresencia(nuevo)) {
                            window.mostrarAviso(nuevo === "dentro"
                                                ? qsTr("Marcado como dentro de la habitación")
                                                : qsTr("Marcado como fuera de la habitación"))
                        }
                    }
                }

                // Las solicitudes piden confirmacion antes de enviarse,
                // para evitar envios por un toque accidental.
                BotonAccion {
                    icono: "✨"
                    etiqueta: qsTr("Limpieza")
                    onTocado: {
                        window.solicitudPendiente = "limpieza"
                        confirmarSolicitud.open()
                    }
                }
                BotonAccion {
                    icono: "⚒"
                    etiqueta: qsTr("Mant.")
                    onTocado: {
                        window.solicitudPendiente = "mantenimiento"
                        confirmarSolicitud.open()
                    }
                }
            }

            // Aviso breve de confirmacion. Ocupa siempre su espacio
            // (solo cambia la opacidad) para que el resto de la
            // pantalla no salte cuando aparece o desaparece.
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 300
                height: 32

                Rectangle {
                    id: avisoEnviado
                    anchors.centerIn: parent
                    width: Math.min(textoAviso.implicitWidth + 28, 300)
                    height: 30
                    radius: 15
                    color: window.colorTarjeta
                    border.width: 1
                    border.color: window.colorBorde
                    opacity: 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    Label {
                        id: textoAviso
                        anchors.centerIn: parent
                        width: parent.width - 20
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        color: window.colorExito
                        font.pixelSize: 11
                    }
                }
            }
        }
    }

    // Confirmacion antes de enviar una solicitud de limpieza/mantenimiento.
    Popup {
        id: confirmarSolicitud
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        width: 280
        padding: 16

        background: Rectangle {
            color: window.colorTarjeta
            radius: 12
            border.color: window.colorBorde
            border.width: 1
        }

        contentItem: Column {
            spacing: 14

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: window.colorTextoClaro
                font.pixelSize: 15
                font.weight: Font.Medium
                text: window.solicitudPendiente === "limpieza"
                      ? qsTr("¿Pedir limpieza para tu habitación?")
                      : qsTr("¿Pedir mantenimiento para tu habitación?")
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Rectangle {
                    width: 116
                    height: 40
                    radius: 8
                    color: "transparent"
                    border.width: 1
                    border.color: "#444444"
                    Label {
                        anchors.centerIn: parent
                        text: qsTr("Cancelar")
                        color: window.colorTextoClaro
                        font.pixelSize: 13
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: confirmarSolicitud.close()
                    }
                }

                Rectangle {
                    width: 116
                    height: 40
                    radius: 8
                    color: window.colorDorado
                    Label {
                        anchors.centerIn: parent
                        text: qsTr("Pedir")
                        color: "#1a1400"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            // Guarda la Solicitud_Servicio en la BD. Avisar
                            // al personal es el Task 3. Si se rechaza
                            // (sin estadia activa, duplicada...), el
                            // motivo sale por operacionRechazada.
                            const tipo = window.solicitudPendiente
                            confirmarSolicitud.close()
                            if (solicitudes.crearSolicitud(tipo)) {
                                window.mostrarAviso(tipo === "limpieza"
                                                    ? qsTr("Solicitud de limpieza enviada")
                                                    : qsTr("Solicitud de mantenimiento enviada"))
                            }
                        }
                    }
                }
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
