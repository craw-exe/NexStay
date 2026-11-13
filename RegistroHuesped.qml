import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NexStay

// Theme 11: "Nueva reserva". Antes esta pantalla solo daba de alta al
// huesped y despues habia que ir al calendario a hacerle la reserva.
// Ahora todo se hace aqui en tres pasos:
//   1. Huesped: se busca (por nombre, documento o telefono) y, si es
//      nuevo, se registra en la misma pantalla.
//   2. Fechas: dia de llegada y numero de noches con botones.
//   3. Habitacion: solo se muestran las libres para esas fechas.
// Si la llegada es hoy se puede confirmar y hacer el check-in de una vez.
//
// El archivo conserva su nombre para no mover el CMake; la vista sigue
// pidiendo el permiso ('huespedes','crear') y los pasos 2 y 3 solo
// aparecen si el rol tambien puede crear reservas. Los permisos se
// vuelven a revisar en C++ (Recepcion, Reserva).
Item {
    id: vista

    // PantallaPrincipal la conecta para abrir el calendario.
    signal abrirCalendario()

    ControlAcceso { id: control }
    CalendarioReservas { id: calendario }

    Recepcion {
        id: recepcion
        onOperacionRechazada: function(motivo) { vista.error = motivo }
    }

    Reserva {
        id: reserva
        onReservaCreada: function(idReserva) { vista.idReservaCreada = idReserva }
        onReservaRechazada: function(motivo) { vista.error = motivo }
    }

    readonly property bool puedeReservar: control.tienePermiso("reservas", "crear")
    readonly property bool pantallaAncha: width >= 700
    readonly property string hoy: calendario.hoy()

    // --- Estado de la pantalla ---
    property var huesped: null          // { idHuesped, nombre, documento, telefono }
    property bool modoNuevo: false      // se esta llenando un huesped nuevo
    property var resultados: []
    property string entrada: hoy
    property int noches: 1
    readonly property string salida: calendario.sumarDias(entrada, noches)
    property var habitacionesLibres: []
    property var habitacionElegida: null
    property int idReservaCreada: -1
    property var resumen: null          // datos de la reserva terminada
    property string error: ""

    // --- Validacion del huesped nuevo ---
    readonly property var nombreSeparado: separarNombre(campoNombre.text)
    readonly property bool nombreOk: nombreSeparado !== null
    readonly property bool documentoOk: campoDocumento.text.trim().length >= 4
    readonly property bool telefonoOk: campoTelefono.text.length === 10
    readonly property bool correoOk: campoCorreo.text.trim().length === 0
                                     || /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(campoCorreo.text.trim())
    readonly property bool huespedListo: huesped !== null
                                         || (modoNuevo && nombreOk && documentoOk && telefonoOk && correoOk)
    readonly property bool listo: huespedListo && (!puedeReservar || habitacionElegida !== null)

    onEntradaChanged: actualizarHabitaciones()
    onNochesChanged: actualizarHabitaciones()
    Component.onCompleted: actualizarHabitaciones()

    // "Maria Fernanda Torres Lopez" -> nombre y apellidos. Con 3 palabras
    // se toma 1 nombre y 2 apellidos (lo comun en Mexico).
    function separarNombre(texto) {
        const p = texto.trim().split(/\s+/).filter(x => x.length > 0)
        if (p.length < 2) return null
        const nNombre = p.length === 2 ? 1 : (p.length === 3 ? 1 : p.length - 2)
        return { nombre: p.slice(0, nNombre).join(" "), apellido: p.slice(nNombre).join(" ") }
    }

    function aFecha(texto) {
        const p = texto.split("-")
        return new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]))
    }
    function fechaLarga(texto) {
        const t = Qt.locale("es_MX").toString(aFecha(texto), "dddd d 'de' MMMM")
        return t.charAt(0).toUpperCase() + t.slice(1)
    }
    function fechaCorta(texto) {
        return Qt.locale("es_MX").toString(aFecha(texto), "d MMM")
    }

    function actualizarHabitaciones() {
        if (!puedeReservar) {
            habitacionesLibres = []
            return
        }
        const todas = calendario.habitaciones()
        habitacionesLibres = todas.filter(h => h.estado !== "fuera de servicio"
                                          && !(entrada === hoy && h.estado === "ocupada")
                                          && reserva.habitacionDisponible(h.idHabitacion, entrada, salida))
        if (habitacionElegida !== null
                && !habitacionesLibres.some(h => h.idHabitacion === habitacionElegida.idHabitacion)) {
            habitacionElegida = null
        }
    }

    function buscar(texto) {
        resultados = texto.trim().length >= 2 ? recepcion.buscarHuespedes(texto, 6) : []
    }

    // Pasa lo que se escribio en la busqueda al campo que corresponde.
    function empezarNuevo() {
        const t = campoBuscar.text.trim()
        campoNombre.text = ""
        campoDocumento.text = ""
        campoTelefono.text = ""
        campoCorreo.text = ""
        if (/^[0-9 ]+$/.test(t)) {
            campoTelefono.text = t.replace(/\s/g, "").slice(0, 10)
        } else if (/[0-9]/.test(t)) {
            campoDocumento.text = t
        } else {
            campoNombre.text = t
        }
        modoNuevo = true
        error = ""
        campoNombre.enfocar()
    }

    function elegir(h) {
        huesped = h
        modoNuevo = false
        resultados = []
        error = ""
    }

    function confirmar(conCheckIn) {
        error = ""
        let h = huesped
        if (h === null) {
            const p = nombreSeparado
            const id = recepcion.registrarHuesped(p.nombre, p.apellido, campoDocumento.text,
                                                  campoTelefono.text, campoCorreo.text)
            if (id < 0) return          // el motivo ya quedo en vista.error
            h = { idHuesped: id, nombre: p.nombre + " " + p.apellido,
                  documento: campoDocumento.text.trim().toUpperCase(), telefono: campoTelefono.text }
            // Si la reserva fallara, el huesped ya queda elegido y no se
            // vuelve a registrar al reintentar.
            elegir(h)
        }
        if (!puedeReservar) {
            resumen = { nombre: h.nombre, soloRegistro: true }
            return
        }
        idReservaCreada = -1
        if (!reserva.crearReserva(h.idHuesped, habitacionElegida.idHabitacion, entrada, salida)) {
            actualizarHabitaciones()
            return
        }
        let checkIn = false
        let avisoCheckIn = ""
        if (conCheckIn && idReservaCreada > 0) {
            checkIn = recepcion.checkIn(idReservaCreada)
            if (!checkIn) avisoCheckIn = error
        }
        error = ""
        resumen = { nombre: h.nombre, soloRegistro: false, numero: habitacionElegida.numero,
                    entrada: entrada, salida: salida, noches: noches,
                    checkIn: checkIn, avisoCheckIn: avisoCheckIn }
    }

    function reiniciar() {
        huesped = null
        modoNuevo = false
        resultados = []
        campoBuscar.text = ""
        campoNombre.text = ""
        campoDocumento.text = ""
        campoTelefono.text = ""
        campoCorreo.text = ""
        habitacionElegida = null
        entrada = hoy
        noches = 1
        resumen = null
        error = ""
        actualizarHabitaciones()
        campoBuscar.forceActiveFocus()
    }

    // ================= Componentes de la pantalla =================

    // Tarjeta numerada de cada paso.
    component Seccion: Rectangle {
        id: seccion
        property int numero
        property string titulo
        property string subtitulo
        property bool completa: false
        default property alias contenido: cuerpo.data

        Layout.fillWidth: true
        implicitHeight: columna.implicitHeight + 44
        radius: Tema.radioGrande
        color: Tema.tarjeta
        border.width: 1
        border.color: Tema.borde

        ColumnLayout {
            id: columna
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 22
            spacing: 16

            RowLayout {
                spacing: 12
                Rectangle {
                    width: 34; height: 34; radius: 17
                    color: seccion.completa ? Tema.exito : Tema.primarioSuave
                    Label {
                        anchors.centerIn: parent
                        text: seccion.completa ? "✓" : seccion.numero
                        color: seccion.completa ? "#FFFFFF" : Tema.primario
                        font.pixelSize: 15
                        font.weight: Font.Bold
                    }
                }
                ColumnLayout {
                    spacing: 0
                    Label {
                        text: seccion.titulo
                        color: Tema.texto
                        font.pixelSize: 18
                        font.weight: Font.Bold
                    }
                    Label {
                        visible: seccion.subtitulo.length > 0
                        text: seccion.subtitulo
                        color: Tema.textoSecundario
                        font.pixelSize: 13
                    }
                }
            }
            ColumnLayout {
                id: cuerpo
                Layout.fillWidth: true
                spacing: 12
            }
        }
    }

    // Boton redondeado de opcion (fechas, noches).
    component Chip: Rectangle {
        id: chip
        property string texto
        property bool activo: false
        signal pulsado()
        implicitWidth: Math.max(48, etiquetaChip.implicitWidth + 30)
        implicitHeight: 44
        radius: 22
        color: activo ? Tema.primario : (areaChip.containsMouse ? Tema.suave : Tema.tarjeta)
        border.width: activo ? 0 : 1
        border.color: Tema.bordeFuerte
        Label {
            id: etiquetaChip
            anchors.centerIn: parent
            text: chip.texto
            color: chip.activo ? Tema.textoSobrePrimario : Tema.texto
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }
        MouseArea {
            id: areaChip
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.pulsado()
        }
    }

    // Campo de texto con etiqueta y palomita cuando esta bien.
    component Campo: ColumnLayout {
        id: campo
        property alias etiqueta: textoEtiqueta.text
        property alias text: entradaTexto.text
        property alias placeholder: entradaTexto.placeholderText
        property alias validator: entradaTexto.validator
        property alias inputMethodHints: entradaTexto.inputMethodHints
        property alias maximumLength: entradaTexto.maximumLength
        property bool valido: false
        property string ayuda: ""
        signal accepted()
        function enfocar() { entradaTexto.forceActiveFocus() }
        spacing: 6

        Label {
            id: textoEtiqueta
            color: Tema.texto
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
        TextField {
            id: entradaTexto
            Layout.fillWidth: true
            color: Tema.texto
            placeholderTextColor: Tema.placeholder
            font.pixelSize: 15
            leftPadding: 14
            rightPadding: 40
            topPadding: 12
            bottomPadding: 12
            onAccepted: campo.accepted()
            background: Rectangle {
                color: Tema.campo
                radius: Tema.radio
                border.width: entradaTexto.activeFocus ? 2 : 1
                border.color: entradaTexto.activeFocus ? Tema.primario
                              : (campo.valido ? Tema.exito : Tema.bordeFuerte)
            }
            Label {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                visible: campo.valido
                text: "✓"
                color: Tema.exito
                font.pixelSize: 16
                font.weight: Font.Bold
            }
        }
        Label {
            visible: campo.ayuda.length > 0
            text: campo.ayuda
            color: Tema.textoSecundario
            font.pixelSize: 12
        }
    }

    component BotonGrande: Rectangle {
        id: boton
        property string texto
        property bool principal: true
        property bool habilitado: true
        signal pulsado()
        implicitHeight: 52
        implicitWidth: etiquetaBoton.implicitWidth + 40
        radius: Tema.radio
        opacity: habilitado ? 1 : 0.5
        color: principal ? (areaBoton.containsMouse && habilitado ? Tema.primarioOscuro : Tema.primario)
                         : (areaBoton.containsMouse ? Tema.suave : Tema.tarjeta)
        border.width: principal ? 0 : 1
        border.color: Tema.bordeFuerte
        Label {
            id: etiquetaBoton
            anchors.centerIn: parent
            text: boton.texto
            color: boton.principal ? Tema.textoSobrePrimario : Tema.texto
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }
        MouseArea {
            id: areaBoton
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: boton.habilitado ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (boton.habilitado) boton.pulsado()
        }
    }

    SelectorFecha {
        id: selectorFecha
        minima: vista.hoy
        onElegida: function(fecha) { vista.entrada = fecha }
    }

    // ================= Pantalla =================

    Rectangle {
        anchors.fill: parent
        color: Tema.fondo
    }

    Flickable {
        id: desplazable
        anchors.fill: parent
        contentHeight: contenido.implicitHeight + 56
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: ScrollBar {}

        ColumnLayout {
            id: contenido
            width: Math.min(desplazable.width - 32, 860)
            x: (desplazable.width - width) / 2
            y: 24
            spacing: 18

            // ---------- Reserva terminada ----------
            Rectangle {
                visible: vista.resumen !== null
                Layout.fillWidth: true
                implicitHeight: exito.implicitHeight + 56
                radius: Tema.radioGrande
                color: Tema.tarjeta
                border.width: 2
                border.color: Tema.exito

                ColumnLayout {
                    id: exito
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 28
                    spacing: 10

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 72; height: 72; radius: 36
                        color: Tema.exitoSuave
                        Label {
                            anchors.centerIn: parent
                            text: "✓"
                            color: Tema.exito
                            font.pixelSize: 36
                            font.weight: Font.Bold
                        }
                    }
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: vista.resumen === null ? ""
                              : vista.resumen.soloRegistro ? qsTr("Huésped registrado")
                              : vista.resumen.checkIn ? qsTr("¡Listo! El huésped ya está hospedado")
                              : qsTr("¡Reserva confirmada!")
                        color: Tema.texto
                        font.pixelSize: 22
                        font.weight: Font.Bold
                    }
                    Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: vista.resumen === null ? ""
                              : vista.resumen.soloRegistro ? vista.resumen.nombre
                              : qsTr("%1 · Habitación %2\nDel %3 al %4 (%5 %6)")
                                .arg(vista.resumen.nombre).arg(vista.resumen.numero)
                                .arg(vista.fechaLarga(vista.resumen.entrada))
                                .arg(vista.fechaLarga(vista.resumen.salida))
                                .arg(vista.resumen.noches)
                                .arg(vista.resumen.noches === 1 ? qsTr("noche") : qsTr("noches"))
                        color: Tema.textoSecundario
                        font.pixelSize: 15
                    }
                    Rectangle {
                        visible: vista.resumen !== null && !vista.resumen.soloRegistro
                                 && vista.resumen.avisoCheckIn.length > 0
                        Layout.fillWidth: true
                        implicitHeight: avisoCheckIn.implicitHeight + 20
                        radius: Tema.radio
                        color: Tema.avisoSuave
                        Label {
                            id: avisoCheckIn
                            x: 12
                            width: parent.width - 24
                            anchors.verticalCenter: parent.verticalCenter
                            wrapMode: Text.WordWrap
                            color: "#92400E"
                            font.pixelSize: 13
                            text: vista.resumen === null || vista.resumen.soloRegistro ? ""
                                  : qsTr("La reserva quedó guardada, pero no se pudo hacer el check-in: %1")
                                    .arg(vista.resumen.avisoCheckIn)
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 10
                        columns: vista.pantallaAncha ? 2 : 1
                        columnSpacing: 12
                        rowSpacing: 10
                        BotonGrande {
                            Layout.fillWidth: true
                            texto: qsTr("Hacer otra reserva")
                            onPulsado: vista.reiniciar()
                        }
                        BotonGrande {
                            visible: vista.puedeReservar
                            Layout.fillWidth: true
                            principal: false
                            texto: qsTr("Ver en el calendario")
                            onPulsado: vista.abrirCalendario()
                        }
                    }
                }
            }

            // ---------- Paso 1: huesped ----------
            Seccion {
                visible: vista.resumen === null
                numero: 1
                titulo: qsTr("¿Quién se hospeda?")
                subtitulo: qsTr("Si ya vino antes, búscalo. Si es nuevo, regístralo aquí mismo.")
                completa: vista.huespedListo

                // Huesped ya elegido
                Rectangle {
                    visible: vista.huesped !== null
                    Layout.fillWidth: true
                    implicitHeight: 72
                    radius: Tema.radio
                    color: Tema.exitoSuave
                    border.width: 1
                    border.color: Tema.exito
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12
                        Rectangle {
                            width: 44; height: 44; radius: 22
                            color: Tema.exito
                            Label {
                                anchors.centerIn: parent
                                text: vista.huesped === null ? "" : vista.huesped.nombre.charAt(0).toUpperCase()
                                color: "#FFFFFF"
                                font.pixelSize: 18
                                font.weight: Font.Bold
                            }
                        }
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            Label {
                                text: vista.huesped === null ? "" : vista.huesped.nombre
                                color: Tema.texto
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Label {
                                text: vista.huesped === null ? ""
                                      : vista.huesped.documento
                                        + (vista.huesped.telefono ? " · " + vista.huesped.telefono : "")
                                color: Tema.textoSecundario
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                        BotonGrande {
                            implicitHeight: 40
                            principal: false
                            texto: qsTr("Cambiar")
                            onPulsado: {
                                vista.huesped = null
                                campoBuscar.text = ""
                                campoBuscar.forceActiveFocus()
                            }
                        }
                    }
                }

                // Busqueda
                TextField {
                    id: campoBuscar
                    visible: vista.huesped === null && !vista.modoNuevo
                    Layout.fillWidth: true
                    focus: true
                    placeholderText: qsTr("🔍  Escribe nombre, INE o teléfono del huésped")
                    color: Tema.texto
                    placeholderTextColor: Tema.placeholder
                    font.pixelSize: 16
                    leftPadding: 16
                    rightPadding: 16
                    topPadding: 14
                    bottomPadding: 14
                    background: Rectangle {
                        color: Tema.campo
                        radius: Tema.radio
                        border.width: campoBuscar.activeFocus ? 2 : 1
                        border.color: campoBuscar.activeFocus ? Tema.primario : Tema.bordeFuerte
                    }
                    onTextChanged: vista.buscar(text)
                    onAccepted: if (vista.resultados.length === 1) vista.elegir(vista.resultados[0])
                }

                // Resultados de la busqueda
                Repeater {
                    model: vista.huesped === null && !vista.modoNuevo ? vista.resultados : []
                    delegate: Rectangle {
                        id: fila
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 60
                        radius: Tema.radio
                        color: areaFila.containsMouse ? Tema.primarioSuave : Tema.suave
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 12
                            Rectangle {
                                width: 38; height: 38; radius: 19
                                color: Tema.primarioSuave
                                Label {
                                    anchors.centerIn: parent
                                    text: fila.modelData.nombre.charAt(0).toUpperCase()
                                    color: Tema.primario
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                }
                            }
                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true
                                Label {
                                    text: fila.modelData.nombre
                                    color: Tema.texto
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Label {
                                    text: fila.modelData.documento + " · " + fila.modelData.telefono
                                    color: Tema.textoSecundario
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                            Label {
                                text: qsTr("Elegir →")
                                color: Tema.primario
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                        }
                        MouseArea {
                            id: areaFila
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: vista.elegir(fila.modelData)
                        }
                    }
                }

                Label {
                    visible: vista.huesped === null && !vista.modoNuevo
                             && campoBuscar.text.trim().length >= 2 && vista.resultados.length === 0
                    text: qsTr("No encontramos a nadie con \"%1\". Parece que es un huésped nuevo.")
                          .arg(campoBuscar.text.trim())
                    color: Tema.textoSecundario
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                BotonGrande {
                    visible: vista.huesped === null && !vista.modoNuevo
                    Layout.fillWidth: true
                    principal: false
                    texto: qsTr("➕  Registrar huésped nuevo")
                    onPulsado: vista.empezarNuevo()
                }

                // Formulario de huesped nuevo
                GridLayout {
                    visible: vista.huesped === null && vista.modoNuevo
                    Layout.fillWidth: true
                    columns: vista.pantallaAncha ? 2 : 1
                    columnSpacing: 16
                    rowSpacing: 14

                    Campo {
                        id: campoNombre
                        Layout.fillWidth: true
                        Layout.columnSpan: vista.pantallaAncha ? 2 : 1
                        etiqueta: qsTr("Nombre completo")
                        placeholder: qsTr("Ej. María Torres López")
                        ayuda: vista.nombreOk || text.trim().length === 0 ? "" : qsTr("Escribe nombre y apellido")
                        valido: vista.nombreOk
                        onAccepted: campoDocumento.enfocar()
                    }
                    Campo {
                        id: campoDocumento
                        Layout.fillWidth: true
                        etiqueta: qsTr("INE o pasaporte")
                        placeholder: qsTr("Número del documento")
                        valido: vista.documentoOk
                        onAccepted: campoTelefono.enfocar()
                    }
                    Campo {
                        id: campoTelefono
                        Layout.fillWidth: true
                        etiqueta: qsTr("Teléfono")
                        placeholder: qsTr("10 dígitos")
                        maximumLength: 10
                        inputMethodHints: Qt.ImhDigitsOnly
                        validator: RegularExpressionValidator { regularExpression: /[0-9]{0,10}/ }
                        ayuda: text.length > 0 && !vista.telefonoOk ? qsTr("Faltan %1 dígitos").arg(10 - text.length) : ""
                        valido: vista.telefonoOk
                        onAccepted: campoCorreo.enfocar()
                    }
                    Campo {
                        id: campoCorreo
                        Layout.fillWidth: true
                        Layout.columnSpan: vista.pantallaAncha ? 2 : 1
                        etiqueta: qsTr("Correo (opcional)")
                        placeholder: qsTr("correo@ejemplo.com")
                        inputMethodHints: Qt.ImhEmailCharactersOnly
                        ayuda: vista.correoOk ? "" : qsTr("Revisa el correo o déjalo vacío")
                        valido: text.trim().length > 0 && vista.correoOk
                    }
                    Label {
                        Layout.columnSpan: vista.pantallaAncha ? 2 : 1
                        text: qsTr("← Volver a buscar")
                        color: Tema.primario
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                vista.modoNuevo = false
                                campoBuscar.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            // ---------- Paso 2: fechas ----------
            Seccion {
                visible: vista.resumen === null && vista.puedeReservar
                numero: 2
                titulo: qsTr("¿Cuándo?")
                subtitulo: qsTr("Elige el día de llegada y cuántas noches se queda.")
                completa: true

                Label {
                    text: qsTr("Llegada")
                    color: Tema.texto
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    Chip {
                        texto: qsTr("Hoy")
                        activo: vista.entrada === vista.hoy
                        onPulsado: vista.entrada = vista.hoy
                    }
                    Chip {
                        texto: qsTr("Mañana")
                        activo: vista.entrada === calendario.sumarDias(vista.hoy, 1)
                        onPulsado: vista.entrada = calendario.sumarDias(vista.hoy, 1)
                    }
                    // Otra fecha: se mueve de dia en dia (no antes de hoy)
                    Rectangle {
                        implicitWidth: filaFecha.implicitWidth + 12
                        implicitHeight: 44
                        radius: 22
                        color: Tema.tarjeta
                        border.width: 1
                        border.color: Tema.bordeFuerte
                        Row {
                            id: filaFecha
                            anchors.centerIn: parent
                            spacing: 4
                            Chip {
                                texto: "‹"
                                implicitHeight: 34
                                border.width: 0
                                opacity: vista.entrada > vista.hoy ? 1 : 0.3
                                onPulsado: if (vista.entrada > vista.hoy)
                                               vista.entrada = calendario.sumarDias(vista.entrada, -1)
                            }
                            // Theme 11: tocar la fecha abre un calendario del mes
                            // para saltar a meses o años sin ir dia por dia.
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 214
                                height: 34
                                radius: 17
                                color: areaFecha.containsMouse ? Tema.primarioSuave : "transparent"
                                Label {
                                    anchors.centerIn: parent
                                    text: "📅  " + vista.fechaLarga(vista.entrada)
                                    color: Tema.texto
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                }
                                MouseArea {
                                    id: areaFecha
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: selectorFecha.abrir(vista.entrada)
                                }
                            }
                            Chip {
                                texto: "›"
                                implicitHeight: 34
                                border.width: 0
                                onPulsado: vista.entrada = calendario.sumarDias(vista.entrada, 1)
                            }
                        }
                    }
                }

                Label {
                    Layout.topMargin: 4
                    text: qsTr("Noches")
                    color: Tema.texto
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: [1, 2, 3, 4, 5, 6, 7]
                        delegate: Chip {
                            required property int modelData
                            texto: modelData
                            activo: vista.noches === modelData
                            onPulsado: vista.noches = modelData
                        }
                    }
                    Chip {
                        texto: "−"
                        onPulsado: if (vista.noches > 1) vista.noches--
                    }
                    Chip {
                        texto: "+"
                        onPulsado: if (vista.noches < 30) vista.noches++
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: textoEstancia.implicitHeight + 24
                    radius: Tema.radio
                    color: Tema.primarioSuave
                    Label {
                        id: textoEstancia
                        x: 14
                        width: parent.width - 28
                        anchors.verticalCenter: parent.verticalCenter
                        wrapMode: Text.WordWrap
                        color: Tema.primarioOscuro
                        font.pixelSize: 14
                        text: qsTr("📅  Llega el <b>%1</b> y sale el <b>%2</b> · %3 %4")
                              .arg(vista.fechaLarga(vista.entrada).toLowerCase())
                              .arg(vista.fechaLarga(vista.salida).toLowerCase())
                              .arg(vista.noches)
                              .arg(vista.noches === 1 ? qsTr("noche") : qsTr("noches"))
                        textFormat: Text.StyledText
                    }
                }
            }

            // ---------- Paso 3: habitacion ----------
            Seccion {
                visible: vista.resumen === null && vista.puedeReservar
                numero: 3
                titulo: qsTr("Elige la habitación")
                subtitulo: qsTr("Solo aparecen las que están libres del %1 al %2.")
                           .arg(vista.fechaCorta(vista.entrada)).arg(vista.fechaCorta(vista.salida))
                completa: vista.habitacionElegida !== null

                Label {
                    visible: vista.habitacionesLibres.length === 0
                    text: qsTr("No hay habitaciones libres en esas fechas. Prueba con otro día o menos noches.")
                    color: Tema.error
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 10
                    Repeater {
                        model: vista.habitacionesLibres
                        delegate: Rectangle {
                            id: cuarto
                            required property var modelData
                            readonly property bool elegida: vista.habitacionElegida !== null
                                                            && vista.habitacionElegida.idHabitacion === modelData.idHabitacion
                            width: 124
                            height: 92
                            radius: Tema.radio
                            color: elegida ? Tema.primario : (areaCuarto.containsMouse ? Tema.primarioSuave : Tema.tarjeta)
                            border.width: elegida ? 0 : 1
                            border.color: Tema.bordeFuerte
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2
                                Label {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: cuarto.modelData.numero
                                    color: cuarto.elegida ? "#FFFFFF" : Tema.texto
                                    font.pixelSize: 24
                                    font.weight: Font.Bold
                                }
                                Label {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: cuarto.modelData.tipo
                                    color: cuarto.elegida ? "#DBEAFE" : Tema.textoSecundario
                                    font.pixelSize: 13
                                }
                            }
                            MouseArea {
                                id: areaCuarto
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: vista.habitacionElegida = cuarto.modelData
                            }
                        }
                    }
                }
            }

            // ---------- Error ----------
            Rectangle {
                visible: vista.resumen === null && vista.error.length > 0
                Layout.fillWidth: true
                implicitHeight: textoError.implicitHeight + 24
                radius: Tema.radio
                color: Tema.errorSuave
                Label {
                    id: textoError
                    x: 14
                    width: parent.width - 28
                    anchors.verticalCenter: parent.verticalCenter
                    wrapMode: Text.WordWrap
                    text: vista.error
                    color: Tema.error
                    font.pixelSize: 14
                }
            }

            // ---------- Confirmar ----------
            GridLayout {
                visible: vista.resumen === null
                Layout.fillWidth: true
                columns: vista.pantallaAncha ? 3 : 1
                columnSpacing: 12
                rowSpacing: 10

                BotonGrande {
                    Layout.fillWidth: true
                    principal: false
                    texto: qsTr("Empezar de nuevo")
                    onPulsado: vista.reiniciar()
                }
                BotonGrande {
                    Layout.fillWidth: true
                    Layout.columnSpan: vista.puedeReservar && vista.entrada === vista.hoy ? 1 : (vista.pantallaAncha ? 2 : 1)
                    habilitado: vista.listo
                    principal: !(vista.puedeReservar && vista.entrada === vista.hoy)
                    texto: vista.puedeReservar ? qsTr("Confirmar reserva") : qsTr("Registrar huésped")
                    onPulsado: vista.confirmar(false)
                }
                BotonGrande {
                    visible: vista.puedeReservar && vista.entrada === vista.hoy
                    Layout.fillWidth: true
                    habilitado: vista.listo
                    texto: qsTr("Confirmar y hacer check-in")
                    onPulsado: vista.confirmar(true)
                }
            }

            Label {
                visible: vista.resumen === null && !vista.listo
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: Tema.textoSecundario
                font.pixelSize: 13
                text: !vista.huespedListo ? qsTr("Falta elegir o registrar al huésped.")
                                          : qsTr("Falta elegir la habitación.")
            }
        }
    }
}
