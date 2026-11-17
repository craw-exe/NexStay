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

    // Theme 11: boton "+ Nueva reserva" (PantallaPrincipal abre esa vista).
    signal nuevaReserva()

    // Theme 11: salto directo a cualquier fecha (mes o año).
    SelectorFecha {
        id: selectorFecha
        onElegida: function(fecha) {
            window.fechaInicio = fecha
            window.cargarDatos()
        }
    }

    property color colorFondo: Tema.fondo
    property color colorTarjeta: Tema.tarjeta
    property color colorBorde: Tema.borde
    property color colorDorado: Tema.primario
    property color colorTextoSecundario: Tema.textoSecundario
    property color colorTextoClaro: Tema.texto

    property int totalDias: 14
    property int anchoColumnaEtiqueta: angosta ? 64 : 90
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

    // Theme 11 Task 4: resumen de hoy (llegadas, salidas, hospedados, libres).
    readonly property string hoyTexto: modelo.hoy()
    // Theme 11 Task 5: diseño compacto en el celular.
    readonly property bool angosta: width < 600
    property var llegadasHoy: []
    property var salidasHoy: []
    property int hospedadosHoy: 0
    property int libresHoy: 0
    property string tituloListaHoy: ""
    property var listaHoy: []

    function calcularResumenHoy() {
        const cerca = modelo.reservasEntre(modelo.sumarDias(hoyTexto, -1), modelo.sumarDias(hoyTexto, 1))
        llegadasHoy = cerca.filter(r => r.fechaEntrada === hoyTexto && !r.enEstadia)
        salidasHoy = cerca.filter(r => r.fechaSalida === hoyTexto && r.enEstadia)
        hospedadosHoy = cerca.filter(r => r.enEstadia).length
        const ocupadas = {}
        cerca.forEach(r => {
            if (r.fechaEntrada <= hoyTexto && r.fechaSalida > hoyTexto) ocupadas[r.idHabitacion] = true
        })
        libresHoy = Math.max(0, listaHabitaciones.length - Object.keys(ocupadas).length)
    }

    function abrirListaHoy(titulo, lista) {
        tituloListaHoy = titulo
        listaHoy = lista
        popupHoy.open()
    }

    // Color de la barra segun la reserva.
    function colorReserva(r) {
        if (r.enEstadia) return Tema.exito
        if (r.fechaEntrada <= hoyTexto) return Tema.aviso     // ya debio llegar
        return Tema.primario
    }

    // Nombre de la habitacion por id (para la lista de hoy).
    function numeroHabitacion(id) {
        for (let i = 0; i < listaHabitaciones.length; i++) {
            if (listaHabitaciones[i].idHabitacion === id) return listaHabitaciones[i].numero
        }
        return ""
    }

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
        calcularResumenHoy()
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

    // "2026-11-13" -> "Vie" (dia de la semana para el encabezado)
    function diaSemana(fechaIso) {
        var p = fechaIso.split("-")
        var d = new Date(parseInt(p[0], 10), parseInt(p[1], 10) - 1, parseInt(p[2], 10))
        return ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"][d.getDay()]
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
                        visible: !window.angosta     // en celular ya lo dice la barra de arriba
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
                        font.pixelSize: 13
                    }
                }

                // Flow: en el celular los botones bajan de renglon y usan
                // textos cortos para que no se corten.
                Flow {
                    // En laptop: ancho de todos los botones juntos (una sola fila).
                    width: {
                        if (window.angosta) return parent.width
                        let total = 0
                        for (let i = 0; i < children.length; i++) total += children[i].implicitWidth + spacing
                        return total
                    }
                    spacing: 6
                    BotonApp {
                        text: window.angosta ? "‹" : qsTr("‹ Semana")
                        onClicked: window.moverDias(-7)
                    }
                    BotonApp {
                        text: qsTr("Hoy")
                        onClicked: window.irAHoy()
                    }
                    BotonApp {
                        text: window.angosta ? "›" : qsTr("Semana ›")
                        onClicked: window.moverDias(7)
                    }
                    BotonApp {
                        text: window.angosta ? "📅" : qsTr("📅 Ir a fecha")
                        onClicked: selectorFecha.abrir(window.fechaInicio)
                    }
                    BotonApp {
                        id: botonNueva
                        principal: true
                        text: window.angosta ? qsTr("+ Nueva") : qsTr("+ Nueva reserva")
                        onClicked: window.nuevaReserva()
                    }
                }
            }

            // Theme 11 Task 4: resumen de hoy. Llegadas y salidas se pueden
            // tocar para ver la lista y hacer el check-in / check-out.
            Flow {
                Layout.fillWidth: true
                spacing: 10

                Repeater {
                    model: [
                        { titulo: qsTr("Llegan hoy"), valor: window.llegadasHoy.length, icono: "🧳",
                          tono: Tema.aviso, suave: Tema.avisoSuave, lista: window.llegadasHoy,
                          ayuda: qsTr("Toca para check-in") },
                        { titulo: qsTr("Salen hoy"), valor: window.salidasHoy.length, icono: "👋",
                          tono: Tema.morado, suave: Tema.moradoSuave, lista: window.salidasHoy,
                          ayuda: qsTr("Toca para check-out") },
                        { titulo: qsTr("Hospedados"), valor: window.hospedadosHoy, icono: "🛏️",
                          tono: Tema.exito, suave: Tema.exitoSuave, lista: null, ayuda: "" },
                        { titulo: qsTr("Libres hoy"), valor: window.libresHoy, icono: "✅",
                          tono: Tema.primario, suave: Tema.primarioSuave, lista: null, ayuda: "" }
                    ]
                    delegate: Rectangle {
                        id: tarjetaHoy
                        required property var modelData
                        readonly property bool tocable: modelData.lista !== null && modelData.valor > 0
                        // En el celular: 2 tarjetas por renglon y mas bajitas.
                        width: window.angosta ? (parent.width - 10) / 2 : 190
                        height: window.angosta ? 60 : 76
                        radius: Tema.radio
                        color: Tema.tarjeta
                        border.width: areaHoy.containsMouse && tocable ? 2 : 1
                        border.color: areaHoy.containsMouse && tocable ? modelData.tono : Tema.borde

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10
                            Rectangle {
                                width: 42; height: 42; radius: 12
                                color: tarjetaHoy.modelData.suave
                                Label {
                                    anchors.centerIn: parent
                                    text: tarjetaHoy.modelData.icono
                                    font.family: Tema.fuenteIconos
                                    font.pixelSize: 20
                                }
                            }
                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true
                                Label {
                                    text: tarjetaHoy.modelData.valor
                                    color: tarjetaHoy.modelData.tono
                                    font.pixelSize: 22
                                    font.weight: Font.Bold
                                }
                                Label {
                                    text: tarjetaHoy.tocable ? tarjetaHoy.modelData.ayuda : tarjetaHoy.modelData.titulo
                                    color: Tema.textoSecundario
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                        Label {
                            visible: tarjetaHoy.tocable
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 8
                            text: tarjetaHoy.modelData.titulo
                            color: Tema.textoSecundario
                            font.pixelSize: 11
                        }
                        MouseArea {
                            id: areaHoy
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: tarjetaHoy.tocable
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.abrirListaHoy(tarjetaHoy.modelData.titulo, tarjetaHoy.modelData.lista)
                        }
                    }
                }
            }

            // Leyenda
            Flow {
                Layout.fillWidth: true
                spacing: 16
                Repeater {
                    model: [
                        { texto: qsTr("Hospedado"), color: Tema.exito },
                        { texto: qsTr("Reservada"), color: Tema.primario },
                        { texto: qsTr("Debe llegar / sin check-in"), color: Tema.aviso },
                        { texto: qsTr("Libre"), color: Tema.tarjeta }
                    ]
                    delegate: Row {
                        required property var modelData
                        spacing: 6
                        Rectangle {
                            width: 14; height: 14; radius: 4
                            color: modelData.color
                            border.width: 1
                            border.color: Tema.borde
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Label {
                            text: modelData.texto
                            color: Tema.textoSecundario
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            Label {
                visible: window.aviso.length > 0
                text: window.aviso
                color: window.avisoEsError ? Tema.error : Tema.exito
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            Label {
                visible: !window.angosta
                text: qsTr("Toca un espacio libre para reservar o una barra para ver la reserva.")
                color: window.colorTextoSecundario
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            // Cuadrícula (con scroll horizontal y vertical)
            // Theme 11 Task 5: la fila de fechas y la columna de habitaciones
            // quedan fijas al deslizar (se recorren lo mismo que se movio
            // la cuadricula), para que siempre se vea que cuarto y que dia es.
            ScrollView {
                id: vistaCuadricula
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 260
                clip: true
                readonly property real desplazX: contentItem.contentX
                readonly property real desplazY: contentItem.contentY

                Column {
                    id: columnaCalendario

                    // Fila de encabezado: etiqueta vacía + un día por columna
                    Row {
                        z: 3
                        transform: Translate { y: Math.max(0, vistaCuadricula.desplazY) }
                        Rectangle {
                            z: 2
                            transform: Translate { x: Math.max(0, vistaCuadricula.desplazX) }
                            width: window.anchoColumnaEtiqueta
                            height: window.altoFila + 6
                            color: window.colorFondo
                            Label {
                                anchors.centerIn: parent
                                text: qsTr("Habitación")
                                color: window.colorTextoSecundario
                                font.pixelSize: 12
                            }
                        }
                        Repeater {
                            model: window.dias
                            delegate: Rectangle {
                                id: cabeceraDia
                                required property string modelData
                                readonly property bool esHoy: modelData === window.hoyTexto
                                width: window.anchoCelda
                                height: window.altoFila + 6
                                color: esHoy ? Tema.primario : window.colorTarjeta
                                border.color: window.colorBorde
                                border.width: 1
                                Column {
                                    anchors.centerIn: parent
                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: cabeceraDia.esHoy ? qsTr("Hoy") : window.diaSemana(cabeceraDia.modelData)
                                        color: cabeceraDia.esHoy ? "#FFFFFF" : Tema.textoSecundario
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                    }
                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: window.etiquetaDia(cabeceraDia.modelData)
                                        color: cabeceraDia.esHoy ? "#FFFFFF" : Tema.texto
                                        font.pixelSize: 12
                                    }
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
                                z: 2
                                transform: Translate { x: Math.max(0, vistaCuadricula.desplazX) }
                                width: window.anchoColumnaEtiqueta
                                height: window.altoFila
                                color: window.colorTarjeta
                                border.color: window.colorBorde
                                border.width: 1
                                Column {
                                    anchors.centerIn: parent
                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: filaHabitacion.modelData.numero
                                        color: window.colorTextoClaro
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                    }
                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: filaHabitacion.modelData.tipo
                                        color: Tema.textoSecundario
                                        font.pixelSize: 10
                                    }
                                }
                            }

                            Repeater {
                                model: window.dias
                                // Theme 11 Task 4: cada reserva se dibuja como una barra de
                                // color continua (redondeada en su primer y ultimo dia) con
                                // el nombre del huesped encima.
                                delegate: Rectangle {
                                    id: celda
                                    required property string modelData
                                    property var reserva: window.reservaEnCelda(filaHabitacion.modelData.idHabitacion, modelData)
                                    readonly property bool esPrimera: reserva !== null
                                        && (reserva.fechaEntrada === modelData || modelData === window.dias[0])
                                    readonly property bool esUltima: reserva !== null
                                        && modelo.sumarDias(modelData, 1) === reserva.fechaSalida
                                    readonly property int nochesVisibles: {
                                        if (reserva === null) return 0
                                        let n = 0
                                        for (let k = window.dias.indexOf(modelData); k < window.dias.length; k++) {
                                            if (window.dias[k] >= reserva.fechaSalida) break
                                            n++
                                        }
                                        return n
                                    }

                                    z: esPrimera ? 1 : 0
                                    width: window.anchoCelda
                                    height: window.altoFila
                                    color: modelData === window.hoyTexto ? Tema.primarioSuave : window.colorFondo
                                    border.color: window.colorBorde
                                    border.width: 1

                                    Rectangle {
                                        visible: celda.reserva !== null
                                        anchors.fill: parent
                                        anchors.topMargin: 6
                                        anchors.bottomMargin: 6
                                        anchors.leftMargin: celda.esPrimera && celda.reserva.fechaEntrada === celda.modelData ? 4 : 0
                                        anchors.rightMargin: celda.esUltima ? 4 : 0
                                        topLeftRadius: anchors.leftMargin > 0 ? 8 : 0
                                        bottomLeftRadius: anchors.leftMargin > 0 ? 8 : 0
                                        topRightRadius: celda.esUltima ? 8 : 0
                                        bottomRightRadius: celda.esUltima ? 8 : 0
                                        color: celda.reserva !== null ? window.colorReserva(celda.reserva) : "transparent"
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        ResaltadoHover {}
                                        onClicked: celda.reserva !== null
                                                   ? window.abrirDetalle(celda.reserva.idReserva)
                                                   : window.abrirNueva(filaHabitacion.modelData, celda.modelData)
                                    }

                                    // Nombre a lo largo de toda la barra visible
                                    Label {
                                        visible: celda.esPrimera
                                        x: 10
                                        width: celda.nochesVisibles * window.anchoCelda - 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: celda.reserva ? celda.reserva.nombreHuesped : ""
                                        color: "#FFFFFF"
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- Lista de llegadas / salidas de hoy (Theme 11 Task 4) ---
    Popup {
        id: popupHoy
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(parent.width - 32, 420)
        modal: true
        padding: 18
        background: Rectangle { color: Tema.tarjeta; radius: Tema.radioGrande }

        contentItem: ColumnLayout {
            spacing: 8
            Label {
                text: window.tituloListaHoy
                color: Tema.texto
                font.pixelSize: 18
                font.weight: Font.Bold
            }
            Label {
                text: qsTr("Toca una para ver la reserva y hacer el check-in o check-out.")
                color: Tema.textoSecundario
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            Repeater {
                model: window.listaHoy
                delegate: Rectangle {
                    id: filaHoy
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 54
                    radius: Tema.radio
                    color: areaFilaHoy.containsMouse ? Tema.primarioSuave : Tema.suave
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        Label {
                            text: qsTr("Hab. %1").arg(window.numeroHabitacion(filaHoy.modelData.idHabitacion))
                            color: Tema.primario
                            font.pixelSize: 14
                            font.weight: Font.Bold
                        }
                        Label {
                            text: filaHoy.modelData.nombreHuesped
                            color: Tema.texto
                            font.pixelSize: 14
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label { text: "→"; color: Tema.primario; font.pixelSize: 16 }
                    }
                    MouseArea {
                        id: areaFilaHoy
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            popupHoy.close()
                            window.abrirDetalle(filaHoy.modelData.idReserva)
                        }
                    }
                }
            }
            BotonApp {
                Layout.alignment: Qt.AlignRight
                text: qsTr("Cerrar")
                onClicked: popupHoy.close()
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
        background: Rectangle { color: Tema.tarjeta; radius: 12; border.color: window.colorDorado; border.width: 1 }

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
                Label { text: qsTr("Entrada: %1").arg(window.nueva.entrada); color: window.colorTextoClaro; font.pixelSize: 13 }
                Label { text: qsTr("Noches:"); color: window.colorTextoSecundario; font.pixelSize: 13 }
                SpinBox { id: campoNoches; from: 1; to: 30; value: 1 }
            }
            Label {
                text: window.nueva.entrada.length > 0
                      ? qsTr("Salida: %1").arg(modelo.sumarDias(window.nueva.entrada, campoNoches.value))
                      : ""
                color: window.colorTextoSecundario
                font.pixelSize: 13
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
                           ? Tema.primarioSuave : "transparent"
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8
                        text: modelData.nombre + "  ·  " + modelData.documento
                        color: window.colorTextoClaro
                        font.pixelSize: 13
                    }
                    MouseArea {
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        ResaltadoHover {}
                        anchors.fill: parent
                        onClicked: window.huespedElegido = parent.modelData
                    }
                }
            }
            Label {
                visible: window.resultados.length === 0
                text: qsTr("No hay huéspedes con ese dato. Si es nuevo, usa \"+ Nueva reserva\" para registrarlo y reservar al mismo tiempo.")
                color: window.colorTextoSecundario
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            Label {
                id: errorNueva
                visible: text.length > 0
                color: Tema.error
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                BotonApp { text: qsTr("Cancelar"); onClicked: popupNueva.close() }
                BotonApp {
                    principal: true
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
        background: Rectangle { color: Tema.tarjeta; radius: 12; border.color: window.colorDorado; border.width: 1 }

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
                font.pixelSize: 13
            }
            Label {
                text: window.detalle.enEstadia ? qsTr("Huésped hospedado (check-in hecho)")
                                               : qsTr("Estado: %1").arg(window.detalle.estado)
                color: window.detalle.enEstadia ? Tema.exito : window.colorTextoSecundario
                font.pixelSize: 13
            }
            Label {
                id: errorDetalle
                visible: text.length > 0
                color: Tema.error
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 8
                BotonApp {
                    visible: window.detalle.puedeCheckIn === true
                    principal: true
                    text: qsTr("Check-in")
                    onClicked: recepcion.checkIn(window.detalle.idReserva)
                }
                BotonApp {
                    visible: window.detalle.puedeCheckOut === true
                    text: qsTr("Check-out")
                    onClicked: recepcion.checkOut(window.detalle.idReserva)
                }
                BotonApp {
                    visible: window.detalle.puedeCancelar === true
                    text: qsTr("Cancelar reserva")
                    onClicked: recepcion.cancelarReserva(window.detalle.idReserva)
                }
                BotonApp {
                    text: qsTr("Cerrar")
                    onClicked: popupDetalle.close()
                }
            }
        }
    }
}
