import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NexStay

// Theme 6, Task 2: vista de solicitudes por prioridad (opcion B: lista
// unica con filtros).
//
// Pensada para el celular del personal de limpieza/mantenimiento y para
// la PC de recepcion/administracion: la lista se centra y limita su
// ancho en pantallas grandes. Cada rol ve solo lo que le corresponde
// (eso lo decide AlertasPersonal, no esta pantalla).
//
// Pantalla de prueba independiente, igual que PantallaBitacoraAcceso:
// se abre cambiando temporalmente el segundo argumento de
// engine.loadFromModule() en main.cpp a "PantallaSolicitudes". Toma la
// sesion guardada en Sesion_Actual, asi que primero hay que haber
// iniciado sesion desde PantallaLogin. La navegacion real por rol es
// trabajo de Theme 7.
ApplicationWindow {
    id: window
    width: 420
    height: 640
    minimumWidth: 320
    minimumHeight: 480
    visible: true
    title: qsTr("NexStay - Solicitudes")

    property color colorFondo: "#0d0d0d"
    property color colorTarjeta: "#1a1a1a"
    property color colorBorde: "#2a2a2a"
    property color colorDorado: "#D4AF37"
    property color colorTextoSecundario: "#8a8a8a"
    property color colorTextoClaro: "#f2f2f2"
    property color colorError: "#e05c5c"

    // "todas", "alta", "media" o "baja"
    property string filtro: "todas"
    // Solicitud abierta en el popup de detalle (mapa de AlertasPersonal).
    property var seleccionada: null
    property string mensajeError: ""
    // Task 4: "abiertas" o "historial" (solicitudes ya resueltas).
    property string vista: "abiertas"
    property var historial: []

    function cargarHistorial() {
        historial = alertas.historial(50)
    }
    function promedio(campo) {
        if (historial.length === 0) return 0
        let suma = 0
        for (let i = 0; i < historial.length; i++) suma += historial[i][campo]
        return suma / historial.length
    }
    function etiquetaDuracion(segundos) {
        if (segundos < 60) return qsTr("menos de 1 min")
        const minutos = Math.floor(segundos / 60)
        if (minutos < 60) return qsTr("%1 min").arg(minutos)
        const horas = Math.floor(minutos / 60)
        const resto = minutos % 60
        return resto === 0 ? qsTr("%1 h").arg(horas) : qsTr("%1 h %2 min").arg(horas).arg(resto)
    }

    Component.onCompleted: Sesion.restaurarSesionGuardada()

    AlertasPersonal {
        id: alertas
        onOperacionRechazada: function(motivo) {
            window.mensajeError = motivo
            temporizadorError.restart()
        }
        onSolicitudAtendida: function(idSolicitud) {
            window.mensajeError = ""
        }
    }

    // Si se resuelve una solicitud (aqui o desde otra pantalla), la lista
    // abierta cambia: se refresca tambien el historial si se esta viendo.
    Connections {
        target: alertas
        function onSolicitudesCambiaron() {
            if (window.vista === "historial") window.cargarHistorial()
        }
    }

    Timer {
        id: temporizadorError
        interval: 4000
        onTriggered: window.mensajeError = ""
    }

    // --- Utilidades de presentacion ---
    function contar(prioridad) {
        if (prioridad === "todas") {
            return alertas.solicitudes.length
        }
        return alertas.solicitudes.filter(s => s.prioridad === prioridad).length
    }

    function colorPrioridad(p) {
        if (p === "alta") return "#e05c5c"
        if (p === "media") return "#D4AF37"
        return "#6a9bd8"
    }
    function fondoPrioridad(p) {
        if (p === "alta") return "#3a1a1a"
        if (p === "media") return "#2e2610"
        return "#17263a"
    }
    function etiquetaPrioridad(p) {
        if (p === "alta") return qsTr("Alta")
        if (p === "media") return qsTr("Media")
        return qsTr("Baja")
    }
    function etiquetaTipo(t) {
        return t === "limpieza" ? qsTr("Limpieza") : qsTr("Mantenimiento")
    }
    function etiquetaOrigen(o) {
        if (o === "huesped") return qsTr("Huésped")
        if (o === "personal") return qsTr("Personal")
        return qsTr("Automática")
    }
    function etiquetaEspera(minutos) {
        if (minutos < 1) return qsTr("ahora")
        if (minutos < 60) return qsTr("hace %1 min").arg(minutos)
        if (minutos < 1440) return qsTr("hace %1 h").arg(Math.floor(minutos / 60))
        return qsTr("hace %1 d").arg(Math.floor(minutos / 1440))
    }

    Rectangle {
        anchors.fill: parent
        color: window.colorFondo

        // Contenedor con ancho maximo para pantallas grandes (PC).
        ColumnLayout {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.margins: 18
            width: Math.min(parent.width - 36, 560)
            spacing: 12

            // Encabezado
            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: qsTr("Solicitudes")
                    color: window.colorDorado
                    font.pixelSize: 18
                    font.weight: Font.Medium
                }
                Item { Layout.fillWidth: true }
                Label {
                    visible: Sesion.haySesion
                    text: Sesion.nombreRol + " · "
                          + qsTr("%1 abiertas").arg(alertas.solicitudes.length)
                    color: window.colorTextoSecundario
                    font.pixelSize: 11
                }
            }

            // Selector de vista: abiertas / historial (Task 4)
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: Sesion.haySesion

                Repeater {
                    model: [
                        { clave: "abiertas", texto: qsTr("Abiertas") },
                        { clave: "historial", texto: qsTr("Historial") }
                    ]

                    delegate: Rectangle {
                        id: pestana
                        required property var modelData
                        property bool activa: window.vista === modelData.clave

                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: 8
                        color: activa ? window.colorDorado : "transparent"
                        border.width: 1
                        border.color: activa ? window.colorDorado : "#444444"

                        Label {
                            anchors.centerIn: parent
                            text: pestana.modelData.texto
                            color: pestana.activa ? "#1a1400" : window.colorTextoSecundario
                            font.pixelSize: 12
                            font.weight: pestana.activa ? Font.Medium : Font.Normal
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                window.vista = pestana.modelData.clave
                                if (window.vista === "historial") window.cargarHistorial()
                            }
                        }
                    }
                }
            }

            // Chips de filtro por prioridad
            Flow {
                Layout.fillWidth: true
                spacing: 6
                visible: Sesion.haySesion && window.vista === "abiertas"

                Repeater {
                    model: [
                        { clave: "todas", texto: qsTr("Todas") },
                        { clave: "alta", texto: qsTr("Alta") },
                        { clave: "media", texto: qsTr("Media") },
                        { clave: "baja", texto: qsTr("Baja") }
                    ]

                    delegate: Rectangle {
                        id: chip
                        required property var modelData
                        property bool activo: window.filtro === modelData.clave

                        implicitWidth: textoChip.implicitWidth + 24
                        implicitHeight: 28
                        radius: 14
                        color: "transparent"
                        border.width: 1
                        border.color: activo ? window.colorDorado : "#444444"

                        Label {
                            id: textoChip
                            anchors.centerIn: parent
                            text: chip.modelData.texto + " " + window.contar(chip.modelData.clave)
                            color: chip.activo ? window.colorDorado : window.colorTextoSecundario
                            font.pixelSize: 12
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: window.filtro = chip.modelData.clave
                        }
                    }
                }
            }

            Label {
                visible: window.mensajeError.length > 0
                text: window.mensajeError
                color: window.colorError
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            // Mensajes de estado vacio
            Label {
                visible: !Sesion.haySesion
                text: qsTr("Inicia sesión en la pantalla de login para ver tus solicitudes.")
                color: window.colorTextoSecundario
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                Layout.topMargin: 30
            }
            Label {
                visible: Sesion.haySesion && window.vista === "abiertas"
                         && listaSolicitudes.count === 0
                text: window.filtro === "todas"
                      ? qsTr("Sin solicitudes pendientes.")
                      : qsTr("No hay solicitudes con esa prioridad.")
                color: window.colorTextoSecundario
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                Layout.topMargin: 30
            }

            // Lista (ya viene ordenada por prioridad y antiguedad)
            ListView {
                id: listaSolicitudes
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: Sesion.haySesion && window.vista === "abiertas"
                clip: true
                spacing: 8
                model: window.filtro === "todas"
                       ? alertas.solicitudes
                       : alertas.solicitudes.filter(s => s.prioridad === window.filtro)

                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view ? ListView.view.width : 0
                    height: 58
                    radius: 10
                    color: window.colorTarjeta
                    border.width: 1
                    border.color: window.colorBorde

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Label {
                                text: qsTr("Hab. %1 · %2").arg(modelData.numeroHabitacion)
                                          .arg(window.etiquetaTipo(modelData.tipo))
                                color: window.colorTextoClaro
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Label {
                                text: window.etiquetaOrigen(modelData.origen) + " · "
                                      + window.etiquetaEspera(modelData.minutosEspera)
                                      + (modelData.estado === "en_proceso"
                                         ? " · " + qsTr("En proceso: %1").arg(modelData.responsable)
                                         : "")
                                color: window.colorTextoSecundario
                                font.pixelSize: 11
                            }
                        }

                        Rectangle {
                            implicitWidth: textoPrioridad.implicitWidth + 18
                            implicitHeight: 22
                            radius: 11
                            color: window.fondoPrioridad(modelData.prioridad)

                            Label {
                                id: textoPrioridad
                                anchors.centerIn: parent
                                text: window.etiquetaPrioridad(modelData.prioridad)
                                color: window.colorPrioridad(modelData.prioridad)
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            window.seleccionada = modelData
                            detalle.open()
                        }
                    }
                }
            }

            // --- Historial (Task 4) ---
            Label {
                visible: Sesion.haySesion && window.vista === "historial"
                         && window.historial.length > 0
                text: qsTr("Promedio · respuesta %1 · resolución %2")
                          .arg(window.etiquetaDuracion(window.promedio("segundosRespuesta")))
                          .arg(window.etiquetaDuracion(window.promedio("segundosResolucion")))
                color: window.colorDorado
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            Label {
                visible: Sesion.haySesion && window.vista === "historial"
                         && window.historial.length === 0
                text: qsTr("Todavía no hay solicitudes atendidas.")
                color: window.colorTextoSecundario
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                Layout.topMargin: 30
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: Sesion.haySesion && window.vista === "historial"
                clip: true
                spacing: 8
                model: window.historial

                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view ? ListView.view.width : 0
                    height: 72
                    radius: 10
                    color: window.colorTarjeta
                    border.width: 1
                    border.color: window.colorBorde

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.topMargin: 8
                        anchors.bottomMargin: 8
                        spacing: 2

                        Label {
                            text: qsTr("Hab. %1 · %2").arg(modelData.numeroHabitacion)
                                      .arg(window.etiquetaTipo(modelData.tipo))
                            color: window.colorTextoClaro
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: qsTr("Respuesta %1 · Resolución %2")
                                      .arg(window.etiquetaDuracion(modelData.segundosRespuesta))
                                      .arg(window.etiquetaDuracion(modelData.segundosResolucion))
                            color: window.colorDorado
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: (modelData.responsable.length > 0 ? modelData.responsable + " · " : "")
                                  + modelData.fechaResolucion
                            color: window.colorTextoSecundario
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }

    // Detalle de la solicitud + accion de atender
    Popup {
        id: detalle
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        width: Math.min(window.width - 48, 340)
        padding: 16

        background: Rectangle {
            color: window.colorTarjeta
            radius: 12
            border.color: window.colorBorde
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 8

            Label {
                text: window.seleccionada
                      ? qsTr("Hab. %1 · %2").arg(window.seleccionada.numeroHabitacion)
                            .arg(window.etiquetaTipo(window.seleccionada.tipo))
                      : ""
                color: window.colorDorado
                font.pixelSize: 16
                font.weight: Font.Medium
            }

            Label {
                text: window.seleccionada
                      ? qsTr("Prioridad: %1").arg(window.etiquetaPrioridad(window.seleccionada.prioridad))
                      : ""
                color: window.seleccionada ? window.colorPrioridad(window.seleccionada.prioridad)
                                           : window.colorTextoClaro
                font.pixelSize: 13
            }
            Label {
                text: window.seleccionada
                      ? qsTr("Origen: %1").arg(window.etiquetaOrigen(window.seleccionada.origen))
                      : ""
                color: window.colorTextoClaro
                font.pixelSize: 13
            }
            Label {
                text: window.seleccionada
                      ? (window.seleccionada.estado === "en_proceso"
                         ? qsTr("Estado: en proceso (%1)").arg(window.seleccionada.responsable)
                         : qsTr("Estado: pendiente"))
                      : ""
                color: window.colorTextoClaro
                font.pixelSize: 13
            }
            Label {
                text: window.seleccionada
                      ? qsTr("Creada: %1 (%2)").arg(window.seleccionada.fechaCreacion)
                            .arg(window.etiquetaEspera(window.seleccionada.minutosEspera))
                      : ""
                color: window.colorTextoSecundario
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            // El motivo del rechazo tambien se muestra aqui, porque el
            // popup modal tapa el mensaje de la pantalla de atras.
            Label {
                visible: window.mensajeError.length > 0
                text: window.mensajeError
                color: window.colorError
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 8
                    color: "transparent"
                    border.width: 1
                    border.color: "#444444"
                    Label {
                        anchors.centerIn: parent
                        text: qsTr("Cerrar")
                        color: window.colorTextoClaro
                        font.pixelSize: 13
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: detalle.close()
                    }
                }

                // Task 3: pendiente -> "Tomar" (queda como responsable).
                // Referenciar Sesion.nombreRol hace que se reevalue al
                // cambiar de sesion; recepcion, por ejemplo, puede ver
                // solicitudes pero no atenderlas.
                Rectangle {
                    visible: Sesion.nombreRol.length > 0 && alertas.puedeAtender()
                             && window.seleccionada !== null
                             && window.seleccionada.estado === "pendiente"
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 8
                    color: window.colorDorado
                    Label {
                        anchors.centerIn: parent
                        text: qsTr("Tomar")
                        color: "#1a1400"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            // Si se rechaza (otra persona la tomo, no le
                            // corresponde a su rol...), el motivo sale
                            // por operacionRechazada.
                            if (alertas.tomarSolicitud(window.seleccionada.idSolicitud)) {
                                detalle.close()
                            }
                        }
                    }
                }

                // en proceso -> "Terminar": solo su responsable o un
                // administrador (la regla real la valida AlertasPersonal).
                Rectangle {
                    visible: Sesion.nombreRol.length > 0 && alertas.puedeAtender()
                             && window.seleccionada !== null
                             && window.seleccionada.estado === "en_proceso"
                             && (window.seleccionada.idResponsable === Sesion.idUsuario
                                 || Sesion.nombreRol === "administrador")
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 8
                    color: window.colorDorado
                    Label {
                        anchors.centerIn: parent
                        text: qsTr("Terminar")
                        color: "#1a1400"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (alertas.marcarAtendida(window.seleccionada.idSolicitud)) {
                                detalle.close()
                            }
                        }
                    }
                }
            }
        }
    }
}
