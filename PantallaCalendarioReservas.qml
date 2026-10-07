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
ApplicationWindow {
    id: window
    width: 920
    height: 560
    minimumWidth: 640
    minimumHeight: 420
    visible: true
    title: qsTr("NexStay - Calendario de reservas")

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

            // Encabezado: título + navegación
            RowLayout {
                Layout.fillWidth: true

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

                Item { Layout.fillWidth: true }

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
}
