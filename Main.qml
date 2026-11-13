import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NexStay

// Pantalla de la HABITACION (modo kiosko, se abre con --kiosko).
// Rediseño de interfaz (revisión 11/nov): fondo claro, color por estado
// y botones grandes con icono y texto para que el huesped entienda
// todo sin explicacion.
ApplicationWindow {
    id: window
    width: 480
    height: 760
    minimumWidth: 360
    minimumHeight: 600
    visible: true
    title: qsTr("NexStay - Habitación")
    font.family: "Segoe UI"

    // --- Theme 5 (Task 1: interfaz, Task 2: guardado) ---
    // La presencia viene de Estado_Presencia via SolicitudesHuesped.
    // Para cambiarla se llama a solicitudes.cambiarPresencia().
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
        interval: 3000
        onTriggered: avisoEnviado.opacity = 0
    }

    // Boton grande con icono y texto (fila inferior).
    component BotonAccion: Rectangle {
        id: raiz
        property string icono
        property string etiqueta
        property string detalle
        property bool resaltado: false
        property color tono: Tema.primario
        property color tonoSuave: Tema.primarioSuave
        signal tocado()

        implicitHeight: 128
        radius: Tema.radioGrande
        color: raiz.resaltado ? raiz.tonoSuave : Tema.tarjeta
        border.width: raiz.resaltado ? 2 : 1
        border.color: raiz.resaltado ? raiz.tono : Tema.borde
        scale: area.pressed ? 0.96 : 1.0
        Behavior on scale { NumberAnimation { duration: 90 } }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 16
            spacing: 4
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 50; height: 50; radius: 16
                color: raiz.tonoSuave
                Label {
                    anchors.centerIn: parent
                    text: raiz.icono
                    font.family: Tema.fuenteIconos
                    font.pixelSize: 24
                }
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: raiz.etiqueta
                color: Tema.texto
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: raiz.detalle
                color: Tema.textoSecundario
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
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
        interval: 4000
        onTriggered: mensajeError.visible = false
    }

    // Icono, texto y color por estado (circulo central y menu).
    function iconoPara(estado) {
        switch (estado) {
        case "ocupada": return "🛏️"
        case "libre": return "✅"
        case "en limpieza": return "🧹"
        case "reservada": return "⏳"
        case "fuera de servicio": return "⚠️"
        default: return "❔"
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

    function colorPara(estado) {
        switch (estado) {
        case "ocupada": return Tema.primario
        case "libre": return Tema.exito
        case "en limpieza": return Tema.aviso
        case "reservada": return Tema.neutro
        default: return Tema.error
        }
    }

    function colorSuavePara(estado) {
        switch (estado) {
        case "ocupada": return Tema.primarioSuave
        case "libre": return Tema.exitoSuave
        case "en limpieza": return Tema.avisoSuave
        case "reservada": return Tema.neutroSuave
        default: return Tema.errorSuave
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Tema.fondo
    }

    Flickable {
        anchors.fill: parent
        contentHeight: contenido.implicitHeight + 48
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: contenido
            width: Math.min(parent.width - 32, 520)
            x: (parent.width - width) / 2
            y: 24
            spacing: 18

            // Encabezado: marca y numero de habitacion
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 96
                radius: Tema.radioGrande
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Tema.barraLateral }
                    GradientStop { position: 1.0; color: Tema.primario }
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 22
                    anchors.rightMargin: 22
                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true
                        Label {
                            text: qsTr("Bienvenido a tu habitación")
                            color: "#E0E7FF"
                            font.pixelSize: 14
                        }
                        Label {
                            text: qsTr("Habitación %1").arg(habitacion.numero)
                            color: "#FFFFFF"
                            font.pixelSize: 28
                            font.weight: Font.Bold
                        }
                    }
                    Rectangle {
                        width: 46; height: 46; radius: 13
                        color: Tema.dorado
                        Label {
                            anchors.centerIn: parent
                            text: "N"
                            color: Tema.barraLateral
                            font.pixelSize: 24
                            font.weight: Font.Black
                        }
                    }
                }
            }

            // Estado actual (tocable)
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 250
                radius: Tema.radioGrande
                color: Tema.tarjeta
                border.width: 1
                border.color: Tema.borde

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    Rectangle {
                        id: circuloEstado
                        Layout.alignment: Qt.AlignHCenter
                        width: 150; height: 150
                        radius: width / 2
                        color: window.colorSuavePara(habitacion.estadoActual)
                        border.width: 5
                        border.color: window.colorPara(habitacion.estadoActual)
                        scale: areaEstado.pressed ? 0.96 : 1.0
                        Behavior on scale { NumberAnimation { duration: 90 } }
                        Behavior on border.color { ColorAnimation { duration: 250 } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Label {
                                Layout.alignment: Qt.AlignHCenter
                                text: window.iconoPara(habitacion.estadoActual)
                                font.family: Tema.fuenteIconos
                                font.pixelSize: 40
                            }
                            Label {
                                Layout.alignment: Qt.AlignHCenter
                                text: window.etiquetaPara(habitacion.estadoActual)
                                color: window.colorPara(habitacion.estadoActual)
                                font.pixelSize: 17
                                font.weight: Font.Bold
                            }
                        }

                        MouseArea {
                            id: areaEstado
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: menuEstados.open()
                        }
                    }

                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("👆 Toca el círculo para cambiar el estado")
                        color: Tema.textoSecundario
                        font.pixelSize: 13
                    }
                }
            }

            // Mensaje de error (p. ej. si falla el guardado en la BD)
            Rectangle {
                visible: mensajeError.visible
                Layout.fillWidth: true
                implicitHeight: mensajeError.implicitHeight + 20
                radius: Tema.radio
                color: Tema.errorSuave
                Label {
                    id: mensajeError
                    anchors.verticalCenter: parent.verticalCenter
                    x: 12
                    width: parent.width - 24
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    color: Tema.error
                    font.pixelSize: 13
                    visible: false
                }
            }

            Label {
                text: qsTr("¿Qué necesitas?")
                color: Tema.texto
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }

            // Presencia y solicitudes (Theme 5, Task 1)
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Alterna entre "dentro" y "fuera". Muestra el estado ACTUAL.
                BotonAccion {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    icono: window.estoyDentro ? "🏠" : "🚶"
                    etiqueta: window.estoyDentro ? qsTr("Estoy dentro") : qsTr("Salí")
                    detalle: qsTr("Toca para cambiar")
                    resaltado: window.estoyDentro
                    tono: Tema.exito
                    tonoSuave: Tema.exitoSuave
                    onTocado: {
                        const nuevo = window.estoyDentro ? "fuera" : "dentro"
                        if (solicitudes.cambiarPresencia(nuevo)) {
                            window.mostrarAviso(nuevo === "dentro"
                                                ? qsTr("Listo: estás dentro de la habitación")
                                                : qsTr("Listo: saliste de la habitación"))
                        }
                    }
                }

                // Las solicitudes piden confirmacion antes de enviarse.
                BotonAccion {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    icono: "🧹"
                    etiqueta: qsTr("Limpieza")
                    detalle: qsTr("Pedir limpieza")
                    tono: Tema.aviso
                    tonoSuave: Tema.avisoSuave
                    onTocado: {
                        window.solicitudPendiente = "limpieza"
                        confirmarSolicitud.open()
                    }
                }
                BotonAccion {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    icono: "🔧"
                    etiqueta: qsTr("Mantenimiento")
                    detalle: qsTr("Algo no funciona")
                    tono: Tema.neutro
                    tonoSuave: Tema.neutroSuave
                    onTocado: {
                        window.solicitudPendiente = "mantenimiento"
                        confirmarSolicitud.open()
                    }
                }
            }

            // Aviso breve de confirmacion. Ocupa siempre su espacio para
            // que la pantalla no salte cuando aparece o desaparece.
            Item {
                Layout.fillWidth: true
                implicitHeight: 48

                Rectangle {
                    id: avisoEnviado
                    anchors.fill: parent
                    radius: Tema.radio
                    color: Tema.exitoSuave
                    border.width: 1
                    border.color: Tema.exito
                    opacity: 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    Label {
                        id: textoAviso
                        anchors.centerIn: parent
                        width: parent.width - 24
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        color: "#166534"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }

    // Boton de los popups.
    component BotonPopup: Rectangle {
        id: bp
        property alias texto: etBp.text
        property bool principal: false
        signal pulsado()
        implicitHeight: Tema.alturaBoton
        radius: Tema.radio
        color: principal ? Tema.primario : "transparent"
        border.width: principal ? 0 : 1
        border.color: Tema.bordeFuerte
        Label {
            id: etBp
            anchors.centerIn: parent
            color: bp.principal ? Tema.textoSobrePrimario : Tema.texto
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: bp.pulsado()
        }
    }

    // Confirmacion antes de enviar una solicitud de limpieza/mantenimiento.
    Popup {
        id: confirmarSolicitud
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        width: Math.min(window.width - 40, 340)
        padding: 22

        background: Rectangle {
            color: Tema.tarjeta
            radius: Tema.radioGrande
        }

        contentItem: ColumnLayout {
            spacing: 16

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: window.solicitudPendiente === "limpieza" ? "🧹" : "🔧"
                font.family: Tema.fuenteIconos
                font.pixelSize: 36
            }
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: Tema.texto
                font.pixelSize: 17
                font.weight: Font.DemiBold
                text: window.solicitudPendiente === "limpieza"
                      ? qsTr("¿Pedir limpieza para tu habitación?")
                      : qsTr("¿Pedir mantenimiento para tu habitación?")
            }
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: Tema.textoSecundario
                font.pixelSize: 13
                text: qsTr("El personal del hotel recibirá tu solicitud al momento.")
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                BotonPopup {
                    Layout.fillWidth: true
                    texto: qsTr("Cancelar")
                    onPulsado: confirmarSolicitud.close()
                }
                BotonPopup {
                    Layout.fillWidth: true
                    principal: true
                    texto: qsTr("Sí, pedir")
                    onPulsado: {
                        // Guarda la Solicitud_Servicio en la BD. Si se
                        // rechaza, el motivo sale por operacionRechazada.
                        const tipo = window.solicitudPendiente
                        confirmarSolicitud.close()
                        if (solicitudes.crearSolicitud(tipo)) {
                            window.mostrarAviso(tipo === "limpieza"
                                                ? qsTr("✓ Solicitud de limpieza enviada")
                                                : qsTr("✓ Solicitud de mantenimiento enviada"))
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
        width: Math.min(window.width - 40, 320)
        padding: 14

        background: Rectangle {
            color: Tema.tarjeta
            radius: Tema.radioGrande
        }

        contentItem: ColumnLayout {
            spacing: 6

            Label {
                text: qsTr("Cambiar estado")
                color: Tema.texto
                font.pixelSize: 17
                font.weight: Font.Bold
                Layout.bottomMargin: 6
                Layout.leftMargin: 4
            }

            Repeater {
                model: habitacion.estadosDisponibles

                delegate: Rectangle {
                    id: opcion
                    required property string modelData
                    readonly property bool actual: modelData === habitacion.estadoActual
                    Layout.fillWidth: true
                    implicitHeight: 52
                    radius: Tema.radio
                    color: actual ? window.colorSuavePara(modelData) : "transparent"
                    border.width: actual ? 2 : 1
                    border.color: actual ? window.colorPara(modelData) : Tema.borde

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12
                        Label {
                            text: window.iconoPara(opcion.modelData)
                            font.family: Tema.fuenteIconos
                            font.pixelSize: 20
                        }
                        Label {
                            text: window.etiquetaPara(opcion.modelData)
                            color: Tema.texto
                            font.pixelSize: 15
                            font.weight: opcion.actual ? Font.DemiBold : Font.Normal
                            Layout.fillWidth: true
                        }
                        Label {
                            visible: opcion.actual
                            text: "✓"
                            color: window.colorPara(opcion.modelData)
                            font.pixelSize: 18
                            font.weight: Font.Bold
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            habitacion.cambiarEstado(opcion.modelData)
                            menuEstados.close()
                        }
                    }
                }
            }
        }
    }
}
