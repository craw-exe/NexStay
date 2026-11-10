import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NexStay

// Theme 3, Task 4: calendario de reservas estilo Gantt.
// Filas = habitaciones, columnas = dias. Cada celda ocupada muestra el
// nombre del huesped en el dia que inicia su reserva. Los datos vienen
// de la tabla Reserva real (solo reservas 'confirmada'); no hay nada
// de datos de ejemplo escrito aqui.
//
// IMPORTANTE: este archivo se llama "Pantalla..." (y no simplemente
// "CalendarioReservas.qml") a proposito, para no chocar de nombre con
// la clase C++ CalendarioReservas (definida en CalendarioReservas.h)
// que se usa aqui abajo como "modelo". Si un archivo QML y una clase
// C++ con QML_ELEMENT comparten el mismo nombre dentro del mismo
// modulo, Qt no sabe distinguir cual de los dos se debe crear al
// pedirlo por nombre, y termina instanciando el objeto equivocado
// (en este caso, la clase C++ en vez de la ventana) sin dar ningun
// error visible. No renombrar este archivo a "CalendarioReservas.qml".
// Theme 7, Task 2: esta pantalla ya no es una ventana propia, sino una
// vista (Item) que PantallaPrincipal abre dentro de su ventana, solo
// para los roles que tienen el permiso correspondiente.
Item {
    id: window

    property color colorFondo: "#0d0d0d"
    property color colorTarjeta: "#161616"
    property color colorBorde: "#2a2a2a"
    property color colorDorado: "#D4AF37"
    property color colorTextoSecundario: "#8a8a8a"
    property color colorTextoClaro: "#f2f2f2"

    property int totalDias: 14
    property int anchoColumnaEtiqueta: 90
    property int anchoCelda: 64
    property int altoFila: 40

    property string fechaInicio: ""
    property var dias: []
    property var listaHabitaciones: []
    property var listaReservas: []

    CalendarioReservas {
        id: modelo
    }

    // Theme 10: desde el calendario se hacen las reservas y el check-in /
    // check-out. Celda libre -> nueva reserva; celda dorada -> detalle.
    property var detalle: ({})
    property var nueva: ({ idHabitacion: -1, numero: "", entrada: "" })
    property var resultados: []
    property var huespedElegido: null
    property string aviso: ""
    property bool avisoEsError: false

    Reserva {
        id: reserva
        onReservaCreada: function(idReserva) {
            popupNueva.close()
            window.mostrarAviso(qsTr("Reserva creada para la habitación %1.").arg(window.nueva.numero), false)
            window.cargarDatos()
        }
        onReservaRechazada: function(motivo) {
            errorNueva.text = motivo
        }
    }

    Recepcion {
        id: recepcion
        onOperacionRealizada: function(mensaje) {
            popupDetalle.close()
            window.mostrarAviso(mensaje, false)
            window.cargarDatos()
        }
        onOperacionRechazada: function(motivo) {
            errorDetalle.text = motivo
        }
    }

    function mostrarAviso(texto, esError) {
        aviso = texto
        avisoEsError = esError
    }

    function abrirNueva(habitacion, fecha) {
        nueva = { idHabitacion: habitacion.idHabitacion, numero: habitacion.numero, entrada: fecha }
        huespedElegido = null
        errorNueva.text = ""
        campoNoches.value = 1
        campoBuscar.text = ""
        resultados = recepcion.buscarHuespedes("")
        popupNueva.open()
    }

    function abrirDetalle(idReserva) {
        detalle = recepcion.detalleReserva(idReserva)
        errorDetalle.text = ""
        if (detalle.idReserva !== undefined) {
            popupDetalle.open()
        }
    }

    function cargarDatos() {
        dias = modelo.rangoFechas(fechaInicio, window.totalDias)
        if (dias.length === 0) {
            return
        }
        // El ultimo dia visible es exclusivo en la consulta (igual que
        // el trigger de traslape: fecha_entrada < fin), asi que se pide
        // un dia extra como limite superior.
        var diaSiguienteAlUltimo = modelo.rangoFechas(dias[dias.length - 1], 2)[1]
        listaReservas = modelo.reservasEntre(dias[0], diaSiguienteAlUltimo)
    }

    function irAHoy() {
        fechaInicio = modelo.hoy()
        cargarDatos()
    }

    // delta en dias: positivo para avanzar, negativo para retroceder.
    function moverDias(delta) {
        fechaInicio = modelo.sumarDias(fechaInicio, delta)
        cargarDatos()
    }

    // Devuelve la reserva que ocupa esta habitacion en esta fecha,
    // o null si esta libre. Comparacion de cadenas "yyyy-MM-dd" es
    // segura porque ese formato ordena igual como texto que como fecha.
    function reservaEnCelda(idHabitacion, fecha) {
        for (var i = 0; i < listaReservas.length; i++) {
            var r = listaReservas[i]
            if (r.idHabitacion === idHabitacion
                    && fecha >= r.fechaEntrada && fecha < r.fechaSalida) {
                return r
            }
        }
        return null
    }

    function etiquetaDia(fechaIso) {
        // "2026-11-03" -> "03 nov"
        var meses = ["ene","feb","mar","abr","may","jun","jul","ago","sep","oct","nov","dic"]
        var partes = fechaIso.split("-")
        return partes[2] + " " + meses[parseInt(partes[1], 10) - 1]
    }

    Component.onCompleted: {
        listaHabitaciones = modelo.habitaciones()
        irAHoy()
    }

    Rectangle {
        anchors.fill: parent
        color: window.colorFondo

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            // Encabezado: título + navegación. Flow (y no RowLayout) para
            // que los botones bajen de renglon en ventanas angostas.
            Flow {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    spacing: 2
                    Label {
                        text: qsTr("Calendario de reservas")
                        color: window.colorDorado
                        font.pixelSize: 18
                        font.weight: Font.Medium
                    }
                    Label {
                        text: window.dias.length > 0
                              ? window.etiquetaDia(window.dias[0]) + " – " + window.etiquetaDia(window.dias[window.dias.length - 1])
                              : ""
                        color: window.colorTextoSecundario
                        font.pixelSize: 12
                    }
                }

                Row {
                    spacing: 6
                    Button {
                        text: qsTr("‹ Semana")
                        onClicked: window.moverDias(-7)
                    }
                    Button {
                        text: qsTr("Hoy")
                        onClicked: window.irAHoy()
                    }
                    Button {
                        text: qsTr("Semana ›")
                        onClicked: window.moverDias(7)
                    }
                }
            }

            // Leyenda
            RowLayout {
                spacing: 16
                Row {
                    spacing: 6
                    Rectangle { width: 14; height: 14; radius: 3; color: window.colorDorado; anchors.verticalCenter: parent.verticalCenter }
                    Label { text: qsTr("Reservada"); color: window.colorTextoSecundario; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                }
                Row {
                    spacing: 6
                    Rectangle { width: 14; height: 14; radius: 3; color: window.colorTarjeta; border.color: window.colorBorde; border.width: 1; anchors.verticalCenter: parent.verticalCenter }
                    Label { text: qsTr("Libre"); color: window.colorTextoSecundario; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            Label {
                visible: window.aviso.length > 0
                text: window.aviso
                color: window.avisoEsError ? "#e05c5c" : "#6fcf97"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            Label {
                text: qsTr("Toca una celda libre para reservar o una dorada para ver la reserva.")
                color: window.colorTextoSecundario
                font.pixelSize: 11
            }

            // Cuadrícula (con scroll horizontal y vertical)
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Column {
                    id: columnaCalendario

                    // Fila de encabezado: etiqueta vacía + un día por columna
                    Row {
                        Rectangle {
                            width: window.anchoColumnaEtiqueta
                            height: window.altoFila
                            color: window.colorFondo
                            Label {
                                anchors.centerIn: parent
                                text: qsTr("Habitación")
                                color: window.colorTextoSecundario
                                font.pixelSize: 11
                            }
                        }
                        Repeater {
                            model: window.dias
                            delegate: Rectangle {
                                required property string modelData
                                width: window.anchoCelda
                                height: window.altoFila
                                color: window.colorTarjeta
                                border.color: window.colorBorde
                                border.width: 1
                                Label {
                                    anchors.centerIn: parent
                                    text: window.etiquetaDia(modelData)
                                    color: window.colorTextoSecundario
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }

                    // Una fila por habitación
                    Repeater {
                        model: window.listaHabitaciones

                        delegate: Row {
                            id: filaHabitacion
                            required property var modelData

                            Rectangle {
                                width: window.anchoColumnaEtiqueta
                                height: window.altoFila
                                color: window.colorTarjeta
                                border.color: window.colorBorde
                                border.width: 1
                                Label {
                                    anchors.centerIn: parent
                                    text: modelData.numero
                                    color: window.colorTextoClaro
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                }
                            }

                            Repeater {
                                model: window.dias
                                delegate: Rectangle {
                                    required property string modelData
                                    property var reserva: window.reservaEnCelda(filaHabitacion.modelData.idHabitacion, modelData)
                                    property bool esInicioDeReserva: reserva !== null && reserva.fechaEntrada === modelData

                                    width: window.anchoCelda
                                    height: window.altoFila
                                    color: reserva !== null ? window.colorDorado : window.colorFondo
                                    border.color: window.colorBorde
                                    border.width: 1

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: parent.reserva !== null
                                                   ? window.abrirDetalle(parent.reserva.idReserva)
                                                   : window.abrirNueva(filaHabitacion.modelData, parent.modelData)
                                    }

                                    Label {
                                        visible: parent.esInicioDeReserva
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        text: parent.reserva ? parent.reserva.nombreHuesped : ""
                                        color: "#1a1400"
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- Nueva reserva ---
    Popup {
        id: popupNueva
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(parent.width - 32, 420)
        modal: true
        padding: 18
        background: Rectangle { color: "#1a1a1a"; radius: 12; border.color: window.colorDorado; border.width: 1 }

        ColumnLayout {
            width: parent.width
            spacing: 8
            Label {
                text: qsTr("Nueva reserva · Hab. %1").arg(window.nueva.numero)
                color: window.colorDorado
                font.pixelSize: 16
                font.weight: Font.Medium
            }
            RowLayout {
                spacing: 10
                Label { text: qsTr("Entrada: %1").arg(window.nueva.entrada); color: window.colorTextoClaro; font.pixelSize: 12 }
                Label { text: qsTr("Noches:"); color: window.colorTextoSecundario; font.pixelSize: 12 }
                SpinBox { id: campoNoches; from: 1; to: 30; value: 1 }
            }
            Label {
                text: window.nueva.entrada.length > 0
                      ? qsTr("Salida: %1").arg(modelo.sumarDias(window.nueva.entrada, campoNoches.value))
                      : ""
                color: window.colorTextoSecundario
                font.pixelSize: 12
            }
            TextField {
                id: campoBuscar
                Layout.fillWidth: true
                placeholderText: qsTr("Buscar huésped por nombre o documento")
                onTextChanged: window.resultados = recepcion.buscarHuespedes(text)
            }
            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                clip: true
                model: window.resultados
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: 34
                    color: window.huespedElegido && window.huespedElegido.idHuesped === modelData.idHuesped
                           ? "#3a3218" : "transparent"
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8
                        text: modelData.nombre + "  ·  " + modelData.documento
                        color: window.colorTextoClaro
                        font.pixelSize: 12
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: window.huespedElegido = parent.modelData
                    }
                }
            }
            Label {
                visible: window.resultados.length === 0
                text: qsTr("No hay huéspedes con ese dato. Regístralo primero en \"Registrar huésped\".")
                color: window.colorTextoSecundario
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            Label {
                id: errorNueva
                visible: text.length > 0
                color: "#e05c5c"
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Button { text: qsTr("Cancelar"); onClicked: popupNueva.close() }
                Button {
                    text: qsTr("Reservar")
                    enabled: window.huespedElegido !== null
                    onClicked: {
                        errorNueva.text = ""
                        reserva.crearReserva(window.huespedElegido.idHuesped, window.nueva.idHabitacion,
                                             window.nueva.entrada,
                                             modelo.sumarDias(window.nueva.entrada, campoNoches.value))
                    }
                }
            }
        }
    }

    // --- Detalle de una reserva: check-in, check-out o cancelar ---
    Popup {
        id: popupDetalle
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(parent.width - 32, 400)
        modal: true
        padding: 18
        background: Rectangle { color: "#1a1a1a"; radius: 12; border.color: window.colorDorado; border.width: 1 }

        ColumnLayout {
            width: parent.width
            spacing: 6
            Label {
                text: qsTr("Reserva #%1 · Hab. %2").arg(window.detalle.idReserva).arg(window.detalle.numero)
                color: window.colorDorado
                font.pixelSize: 16
                font.weight: Font.Medium
            }
            Label {
                text: qsTr("%1 (%2)").arg(window.detalle.huesped).arg(window.detalle.documento)
                color: window.colorTextoClaro
                font.pixelSize: 13
            }
            Label {
                text: qsTr("Del %1 al %2").arg(window.detalle.entrada).arg(window.detalle.salida)
                color: window.colorTextoSecundario
                font.pixelSize: 12
            }
            Label {
                text: window.detalle.enEstadia ? qsTr("Huésped hospedado (check-in hecho)")
                                               : qsTr("Estado: %1").arg(window.detalle.estado)
                color: window.detalle.enEstadia ? "#6fcf97" : window.colorTextoSecundario
                font.pixelSize: 12
            }
            Label {
                id: errorDetalle
                visible: text.length > 0
                color: "#e05c5c"
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 8
                Button {
                    visible: window.detalle.puedeCheckIn === true
                    text: qsTr("Check-in")
                    onClicked: recepcion.checkIn(window.detalle.idReserva)
                }
                Button {
                    visible: window.detalle.puedeCheckOut === true
                    text: qsTr("Check-out")
                    onClicked: recepcion.checkOut(window.detalle.idReserva)
                }
                Button {
                    visible: window.detalle.puedeCancelar === true
                    text: qsTr("Cancelar reserva")
                    onClicked: recepcion.cancelarReserva(window.detalle.idReserva)
                }
                Button {
                    text: qsTr("Cerrar")
                    onClicked: popupDetalle.close()
                }
            }
        }
    }
}
