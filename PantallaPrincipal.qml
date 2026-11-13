import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NexStay

// Theme 7, Task 2: control de vistas/funciones por rol.
// Rediseño de interfaz (revisión 11/nov): tablero con mosaicos grandes,
// barra lateral en pantallas anchas (PC de recepción) y barra superior
// sencilla en pantallas angostas (celular).
//
// Esta es la ventana de la app del PERSONAL (el kiosco de la
// habitacion, Main.qml, es otra aplicacion que se abre con --kiosko).
//
//   - Sin sesion: se muestra PantallaLogin.
//   - Con sesion: se muestran SOLO las vistas que el rol tiene
//     permitidas, y cada vista se abre dentro de esta ventana.
//
// Que puede ver cada rol NO esta escrito aqui: sale de la tabla
// Permisos a traves de ControlAcceso.tienePermiso(modulo, accion).
//
// Defensa en profundidad: ocultar una entrada del menu NO es la unica
// proteccion. abrir() vuelve a revisar el permiso antes de mostrar la
// vista, y las propias vistas validan en C++ lo que hacen.
ApplicationWindow {
    id: window
    width: 1100
    height: 720
    minimumWidth: 320
    minimumHeight: 480
    visible: true
    title: qsTr("NexStay")
    font.family: "Segoe UI"

    // Se dejan con los nombres de antes para no romper nada que los lea.
    property color colorFondo: Tema.fondo
    property color colorTarjeta: Tema.tarjeta
    property color colorBorde: Tema.borde
    property color colorDorado: Tema.primario
    property color colorTextoSecundario: Tema.textoSecundario
    property color colorTextoClaro: Tema.texto
    property color colorError: Tema.error
    property color colorExito: Tema.exito

    // Barra lateral solo en pantallas anchas.
    readonly property bool pantallaAncha: width >= 860

    // Titulo y clave de la vista abierta ("" = estamos en el inicio).
    property string vistaActual: ""
    property string claveActual: ""
    property string textoBanner: ""

    // Catalogo de vistas. "modulo" y "accion" son el permiso que pide
    // cada una; "icono" y "tono" solo son de presentacion.
    readonly property var vistas: [
        // Theme 11: "Nueva reserva" va primero porque es lo que mas se usa.
        { clave: "huespedes", titulo: qsTr("Nueva reserva"),
          descripcion: qsTr("Busca o registra al huésped y apártale habitación"),
          icono: "🧳", tono: Tema.neutro, tonoSuave: Tema.neutroSuave,
          modulo: "huespedes", accion: "crear" },
        { clave: "solicitudes", titulo: qsTr("Solicitudes"),
          descripcion: qsTr("Limpieza y mantenimiento que piden los huéspedes"),
          icono: "🛎️", tono: Tema.aviso, tonoSuave: Tema.avisoSuave,
          modulo: "solicitudes", accion: "ver" },
        { clave: "reservas", titulo: qsTr("Calendario"),
          descripcion: qsTr("Calendario: qué habitación está ocupada cada día"),
          icono: "📅", tono: Tema.primario, tonoSuave: Tema.primarioSuave,
          modulo: "reservas", accion: "ver" },
        { clave: "habitaciones", titulo: qsTr("Habitaciones"),
          descripcion: qsTr("Estado de cada habitación y quién está hospedado"),
          icono: "🛏️", tono: Tema.exito, tonoSuave: Tema.exitoSuave,
          modulo: "habitaciones", accion: "ver" },
        { clave: "bitacora", titulo: qsTr("Bitácora de accesos"),
          descripcion: qsTr("Quién entró a cada habitación y a qué hora"),
          icono: "🔑", tono: Tema.morado, tonoSuave: Tema.moradoSuave,
          modulo: "bitacora", accion: "ver" },
        { clave: "reportes", titulo: qsTr("Reportes"),
          descripcion: qsTr("Ocupación, limpieza y solicitudes en números"),
          icono: "📊", tono: Tema.rosa, tonoSuave: Tema.rosaSuave,
          modulo: "reportes", accion: "ver" },
        { clave: "usuarios", titulo: qsTr("Usuarios y roles"),
          descripcion: qsTr("Cuentas del personal y sus permisos"),
          icono: "👥", tono: Tema.textoSecundario, tonoSuave: Tema.suave,
          modulo: "usuarios", accion: "ver" }
    ]

    // Solo las vistas que el rol de la sesion actual puede abrir. Leer
    // Sesion.idUsuario hace que esto se recalcule al cambiar de sesion.
    // revisionPermisos sube cada vez que se regresa al inicio, para que
    // los cambios hechos en la pantalla de administracion se reflejen.
    property int revisionPermisos: 0
    property var vistasPermitidas: {
        const idUsuario = Sesion.idUsuario
        const revision = revisionPermisos
        if (idUsuario < 0) {
            return []
        }
        return vistas.filter(v => control.tienePermiso(v.modulo, v.accion))
    }

    ControlAcceso {
        id: control
    }

    // --- Utilidades de texto ---
    function saludo() {
        const hora = new Date().getHours()
        if (hora < 12) return qsTr("Buenos días")
        if (hora < 19) return qsTr("Buenas tardes")
        return qsTr("Buenas noches")
    }
    function fechaHoy() {
        const texto = Qt.locale("es_MX").toString(new Date(), "dddd d 'de' MMMM 'de' yyyy")
        return texto.charAt(0).toUpperCase() + texto.slice(1)
    }
    function iniciales(nombre) {
        const partes = nombre.trim().split(/\s+/)
        if (partes.length === 0 || partes[0] === "") return "?"
        return (partes[0].charAt(0) + (partes.length > 1 ? partes[1].charAt(0) : "")).toUpperCase()
    }

    // --- Navegacion ---
    function abrir(vista) {
        // Se revisa de nuevo el permiso aunque la entrada ya estuviera
        // filtrada en el menu.
        if (!control.tienePermiso(vista.modulo, vista.accion)) {
            mostrarBanner(qsTr("Tu rol no tiene permiso para abrir esta vista."))
            return
        }
        if (window.claveActual === vista.clave) {
            return
        }
        // Desde la barra lateral se puede saltar de una vista a otra:
        // primero se regresa al inicio y luego se abre la nueva.
        if (pila.depth > 1) {
            pila.pop(null, StackView.Immediate)
        }

        window.vistaActual = vista.titulo
        window.claveActual = vista.clave
        switch (vista.clave) {
        case "solicitudes": pila.push(compSolicitudes); break
        case "reservas":    pila.push(compReservas); break
        case "huespedes":   pila.push(compHuespedes); break
        case "bitacora":    pila.push(compBitacora); break
        case "usuarios":    pila.push(compAdministracion); break
        case "reportes":    pila.push(compReportes); break
        case "habitaciones": pila.push(compHabitaciones); break
        }
    }

    function abrirPorClave(clave) {
        for (let i = 0; i < vistasPermitidas.length; i++) {
            if (vistasPermitidas[i].clave === clave) {
                abrir(vistasPermitidas[i])
                return
            }
        }
    }

    function volver() {
        if (pila.depth > 1) {
            pila.pop(null)
        }
        window.vistaActual = ""
        window.claveActual = ""
        window.revisionPermisos++
    }

    function cerrarSesion() {
        Sesion.cerrarSesion()
        login.limpiarFormulario()
    }

    function mostrarBanner(texto) {
        window.textoBanner = texto
        banner.visible = true
        temporizadorBanner.restart()
    }

    // Theme 10: al abrir la app siempre se pide login.
    Component.onCompleted: Sesion.restaurarSesionGuardada()

    // Theme 10: cierre de sesion tras 15 minutos sin actividad.
    // shortcut: solo cuenta el movimiento del mouse y el cambio de vista.
    Timer {
        id: inactividad
        interval: 15 * 60 * 1000
        running: Sesion.haySesion
        onTriggered: window.cerrarSesion()
    }
    onVistaActualChanged: inactividad.restart()

    // Si la sesion se cierra, se regresa al inicio (y se muestra el login).
    Connections {
        target: Sesion
        function onSesionCambio() {
            if (!Sesion.haySesion) {
                pila.pop(null)
                window.vistaActual = ""
                window.claveActual = ""
            }
        }
    }

    // Alerta global de solicitudes nuevas (Theme 5, Task 3).
    AlertasPersonal {
        id: alertas
        onNuevaSolicitud: function(idSolicitud, tipo, numeroHabitacion, prioridad) {
            window.mostrarBanner(qsTr("Nueva solicitud de %1 en la habitación %2. Toca aquí para verla.")
                                 .arg(tipo).arg(numeroHabitacion))
        }
    }

    Timer {
        id: temporizadorBanner
        interval: 6000
        onTriggered: banner.visible = false
    }

    // Boton de texto reutilizable.
    component BotonTexto: Rectangle {
        id: boton
        property alias texto: etiqueta.text
        property bool principal: false
        property color colorTexto: principal ? Tema.textoSobrePrimario : Tema.texto
        signal pulsado()

        implicitHeight: Tema.alturaBoton
        implicitWidth: etiqueta.implicitWidth + 32
        radius: Tema.radio
        color: principal ? (areaBoton.containsMouse ? Tema.primarioOscuro : Tema.primario)
                         : (areaBoton.containsMouse ? Tema.suave : "transparent")
        border.width: principal ? 0 : 1
        border.color: Tema.bordeFuerte

        Label {
            id: etiqueta
            anchors.centerIn: parent
            color: boton.colorTexto
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
        MouseArea {
            id: areaBoton
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: boton.pulsado()
        }
    }

    // Circulo con el icono de una vista.
    component IconoVista: Rectangle {
        property string icono
        property color tono: Tema.primario
        property int tamano: 52
        width: tamano
        height: tamano
        radius: tamano / 2.6
        color: tono
        Label {
            anchors.centerIn: parent
            text: parent.icono
            font.family: Tema.fuenteIconos
            font.pixelSize: parent.tamano * 0.46
        }
    }

    // --- Vistas dentro de la misma ventana ---
    Component { id: compSolicitudes; PantallaSolicitudes {} }
    // Theme 11: la nueva reserva y el calendario se abren uno desde el otro.
    // Qt.callLater: la vista que avisa se destruye al cambiar de vista.
    Component {
        id: compReservas
        PantallaCalendarioReservas {
            onNuevaReserva: Qt.callLater(window.abrirPorClave, "huespedes")
        }
    }
    Component {
        id: compHuespedes
        RegistroHuesped {
            onAbrirCalendario: Qt.callLater(window.abrirPorClave, "reservas")
        }
    }
    Component { id: compBitacora;    PantallaBitacoraAcceso {} }
    Component { id: compAdministracion; PantallaAdministracion {} }
    Component { id: compReportes;    PantallaReportes {} }
    Component { id: compHabitaciones; PantallaHabitaciones {} }

    // Inicio: saludo y un mosaico grande por cada vista permitida.
    Component {
        id: menuInicio

        Flickable {
            id: inicio
            clip: true
            contentHeight: columnaInicio.implicitHeight + 48
            boundsBehavior: Flickable.StopAtBounds

            readonly property int margen: window.pantallaAncha ? 32 : 16
            readonly property int columnas: Math.max(1, Math.floor((width - 2 * margen) / 270))

            ColumnLayout {
                id: columnaInicio
                x: inicio.margen
                y: inicio.margen
                width: inicio.width - 2 * inicio.margen
                spacing: 22

                // Tarjeta de bienvenida
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: bienvenida.implicitHeight + 44
                    radius: Tema.radioGrande
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Tema.barraLateral }
                        GradientStop { position: 1.0; color: Tema.primario }
                    }

                    ColumnLayout {
                        id: bienvenida
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 24
                        anchors.rightMargin: 24
                        spacing: 4

                        Label {
                            text: window.fechaHoy()
                            color: "#C7D7FE"
                            font.pixelSize: 13
                        }
                        Label {
                            text: qsTr("%1, %2").arg(window.saludo()).arg(Sesion.nombreCompleto)
                            color: "#FFFFFF"
                            font.pixelSize: window.pantallaAncha ? 26 : 21
                            font.weight: Font.Bold
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        Label {
                            text: window.vistasPermitidas.length > 0
                                  ? qsTr("¿Qué quieres hacer hoy? Elige una opción.")
                                  : qsTr("Tu rol todavía no tiene opciones asignadas. Pide a un administrador que revise tus permisos.")
                            color: "#E0E7FF"
                            font.pixelSize: 14
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }

                Label {
                    visible: window.vistasPermitidas.length > 0
                    text: qsTr("Accesos rápidos")
                    color: Tema.texto
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: inicio.columnas
                    columnSpacing: 16
                    rowSpacing: 16

                    Repeater {
                        model: window.vistasPermitidas

                        delegate: Rectangle {
                            id: mosaico
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 150
                            radius: Tema.radioGrande
                            color: Tema.tarjeta
                            border.width: areaMosaico.containsMouse ? 2 : 1
                            border.color: areaMosaico.containsMouse ? modelData.tono : Tema.borde
                            scale: areaMosaico.pressed ? 0.98 : 1.0
                            Behavior on scale { NumberAnimation { duration: 90 } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 6

                                IconoVista {
                                    icono: mosaico.modelData.icono
                                    tono: mosaico.modelData.tonoSuave
                                    tamano: 48
                                }
                                Item { Layout.fillHeight: true }
                                Label {
                                    text: mosaico.modelData.titulo
                                    color: Tema.texto
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                }
                                Label {
                                    text: mosaico.modelData.descripcion
                                    color: Tema.textoSecundario
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Label {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 18
                                text: "→"
                                color: mosaico.modelData.tono
                                font.pixelSize: 20
                                opacity: areaMosaico.containsMouse ? 1 : 0.35
                            }

                            MouseArea {
                                id: areaMosaico
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.abrir(mosaico.modelData)
                            }
                        }
                    }
                }
            }

            ScrollBar.vertical: ScrollBar {}
        }
    }

    // --- Estructura de la ventana ---
    Rectangle {
        anchors.fill: parent
        color: Tema.fondo
    }

    // Login a pantalla completa mientras no hay sesion.
    PantallaLogin {
        id: login
        anchors.fill: parent
        visible: !Sesion.haySesion
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0
        visible: Sesion.haySesion

        // Barra lateral (solo pantallas anchas)
        Rectangle {
            visible: window.pantallaAncha
            z: 2
            Layout.fillHeight: true
            Layout.preferredWidth: 250
            color: Tema.barraLateral

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 4

                // Logo
                RowLayout {
                    Layout.bottomMargin: 20
                    Layout.topMargin: 6
                    spacing: 10
                    Rectangle {
                        width: 38; height: 38; radius: 10
                        color: Tema.dorado
                        Label {
                            anchors.centerIn: parent
                            text: "N"
                            color: Tema.barraLateral
                            font.pixelSize: 20
                            font.weight: Font.Black
                        }
                    }
                    ColumnLayout {
                        spacing: 0
                        Label {
                            text: "NexStay"
                            color: "#FFFFFF"
                            font.pixelSize: 19
                            font.weight: Font.Bold
                        }
                        Label {
                            text: qsTr("Gestión hotelera")
                            color: "#93A4C3"
                            font.pixelSize: 12
                        }
                    }
                }

                // Entrada fija: Inicio + una por cada vista permitida
                Repeater {
                    model: [{ clave: "", titulo: qsTr("Inicio"), icono: "🏠" }].concat(window.vistasPermitidas)

                    delegate: Rectangle {
                        id: entrada
                        required property var modelData
                        readonly property bool activa: window.claveActual === modelData.clave
                        Layout.fillWidth: true
                        implicitHeight: 46
                        radius: 10
                        color: activa ? Tema.primario
                                      : (areaEntrada.containsMouse ? "#1F3A66" : "transparent")

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12
                            Label {
                                text: entrada.modelData.icono
                                font.family: Tema.fuenteIconos
                                font.pixelSize: 18
                            }
                            Label {
                                text: entrada.modelData.titulo
                                color: entrada.activa ? "#FFFFFF" : "#D5DEEE"
                                font.pixelSize: 14
                                font.weight: entrada.activa ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                        MouseArea {
                            id: areaEntrada
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (entrada.modelData.clave === "") {
                                    window.volver()
                                } else {
                                    window.abrir(entrada.modelData)
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                // Usuario y salir
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 64
                    radius: 12
                    color: "#1B355F"
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10
                        Rectangle {
                            width: 40; height: 40; radius: 20
                            color: Tema.dorado
                            Label {
                                anchors.centerIn: parent
                                text: window.iniciales(Sesion.nombreCompleto)
                                color: Tema.barraLateral
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }
                        }
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            Label {
                                text: Sesion.nombreCompleto
                                color: "#FFFFFF"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Label {
                                text: Sesion.nombreRol
                                color: "#93A4C3"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
                BotonTexto {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    texto: qsTr("Cerrar sesión")
                    colorTexto: "#FFFFFF"
                    border.color: "#3B5A8C"
                    color: areaSalirHover.hovered ? "#1F3A66" : "transparent"
                    onPulsado: window.cerrarSesion()
                    HoverHandler { id: areaSalirHover }
                }
            }
        }

        // Columna principal
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Barra superior: regreso, titulo, fecha/usuario y salir
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: window.pantallaAncha ? 68 : 58
                color: Tema.tarjeta

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Tema.borde
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: window.pantallaAncha ? 28 : 12
                    anchors.rightMargin: window.pantallaAncha ? 28 : 12
                    spacing: 10

                    // Regresar (en celular es la unica forma de volver al inicio)
                    BotonTexto {
                        visible: pila.depth > 1
                        implicitHeight: 38
                        texto: window.pantallaAncha ? qsTr("← Inicio") : "←"
                        onPulsado: window.volver()
                    }

                    // Logo pequeño en celular cuando se esta en el inicio
                    Rectangle {
                        visible: !window.pantallaAncha && pila.depth <= 1
                        width: 32; height: 32; radius: 9
                        color: Tema.dorado
                        Label {
                            anchors.centerIn: parent
                            text: "N"
                            color: Tema.barraLateral
                            font.pixelSize: 17
                            font.weight: Font.Black
                        }
                    }

                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true
                        Label {
                            text: window.vistaActual.length > 0 ? window.vistaActual : qsTr("Inicio")
                            color: Tema.texto
                            font.pixelSize: window.pantallaAncha ? 21 : 18
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            visible: window.pantallaAncha
                            text: window.fechaHoy()
                            color: Tema.textoSecundario
                            font.pixelSize: 12
                        }
                    }

                    // En celular el usuario y "Salir" van aqui arriba
                    Rectangle {
                        visible: !window.pantallaAncha
                        width: 34; height: 34; radius: 17
                        color: Tema.primarioSuave
                        Label {
                            anchors.centerIn: parent
                            text: window.iniciales(Sesion.nombreCompleto)
                            color: Tema.primario
                            font.pixelSize: 12
                            font.weight: Font.Bold
                        }
                    }
                    BotonTexto {
                        visible: !window.pantallaAncha
                        implicitHeight: 38
                        texto: qsTr("Salir")
                        onPulsado: window.cerrarSesion()
                    }
                }
            }

            // Aviso de solicitud nueva (toca para abrir Solicitudes)
            Rectangle {
                id: banner
                visible: false
                Layout.fillWidth: true
                Layout.margins: 12
                implicitHeight: 48
                radius: Tema.radio
                color: Tema.avisoSuave
                border.width: 1
                border.color: Tema.aviso

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10
                    Label {
                        text: "🔔"
                        font.family: Tema.fuenteIconos
                        font.pixelSize: 18
                    }
                    Label {
                        text: window.textoBanner
                        color: "#92400E"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Label {
                        text: "✕"
                        color: "#92400E"
                        font.pixelSize: 14
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            onClicked: banner.visible = false
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.rightMargin: 40
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        banner.visible = false
                        window.abrirPorClave("solicitudes")
                    }
                }
            }

            // Contenido
            // clip: la animacion al cambiar de vista no se sale de aqui
            // (antes pasaba por encima de la barra lateral).
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                HoverHandler {
                    onPointChanged: inactividad.restart()
                }

                StackView {
                    id: pila
                    anchors.fill: parent
                    initialItem: menuInicio
                }
            }
        }
    }
}
