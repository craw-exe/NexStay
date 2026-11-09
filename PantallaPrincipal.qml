import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NexStay

// Theme 7, Task 2: control de vistas/funciones por rol.
//
// Esta es la ventana de la app del PERSONAL (el kiosco de la
// habitacion, Main.qml, es otra aplicacion que se abre con --kiosko).
// Todo ocurre dentro de esta misma ventana:
//
//   - Sin sesion: se muestra PantallaLogin.
//   - Con sesion: se muestra un menu con SOLO las vistas que el rol
//     tiene permitidas, y cada vista se abre dentro de esta ventana
//     (con boton de regreso), no en ventanas aparte.
//
// Que puede ver cada rol NO esta escrito aqui: sale de la tabla
// Permisos (matriz definida en Theme 7, Task 1) a traves de
// ControlAcceso.tienePermiso(modulo, accion). Para cambiar lo que ve
// un rol basta con cambiar sus permisos en la BD, sin tocar este archivo.
//
// Defensa en profundidad (mismo criterio que en el resto del
// proyecto): ocultar una entrada del menu NO es la unica proteccion.
// abrir() vuelve a revisar el permiso antes de mostrar la vista, y
// las propias vistas validan en C++ lo que hacen (AlertasPersonal,
// BitacoraAcceso).
ApplicationWindow {
    id: window
    width: 480
    height: 720
    minimumWidth: 320
    minimumHeight: 480
    visible: true
    title: qsTr("NexStay")

    property color colorFondo: "#0d0d0d"
    property color colorBarra: "#111111"
    property color colorTarjeta: "#1a1a1a"
    property color colorBorde: "#2a2a2a"
    property color colorDorado: "#D4AF37"
    property color colorTextoSecundario: "#8a8a8a"
    property color colorTextoClaro: "#f2f2f2"
    property color colorError: "#e05c5c"
    property color colorExito: "#6fcf97"

    // Titulo de la vista abierta ("" = estamos en el menu).
    property string vistaActual: ""
    property string textoBanner: ""
    property string textoPrueba: ""
    property bool pruebaConExito: false

    // Catalogo de vistas. "modulo" y "accion" son el permiso que pide
    // cada una; "mensaje" solo lo usan las que aun son marcador de lugar.
    readonly property var vistas: [
        { clave: "solicitudes", titulo: qsTr("Solicitudes"),
          descripcion: qsTr("Pendientes, en proceso e historial"),
          modulo: "solicitudes", accion: "ver" },
        { clave: "reservas", titulo: qsTr("Calendario de reservas"),
          descripcion: qsTr("Ocupación por habitación y día"),
          modulo: "reservas", accion: "ver" },
        { clave: "habitaciones", titulo: qsTr("Habitaciones"),
          descripcion: qsTr("Estado de cada habitación y huésped actual"),
          modulo: "habitaciones", accion: "ver" },
        { clave: "huespedes", titulo: qsTr("Registrar huésped"),
          descripcion: qsTr("Alta de un nuevo huésped"),
          modulo: "huespedes", accion: "crear" },
        { clave: "bitacora", titulo: qsTr("Bitácora de accesos"),
          descripcion: qsTr("Quién entró a cada habitación y cuándo"),
          modulo: "bitacora", accion: "ver" },
        { clave: "reportes", titulo: qsTr("Reportes"),
          descripcion: qsTr("Ocupación, limpieza y solicitudes"),
          modulo: "reportes", accion: "ver" },
        { clave: "usuarios", titulo: qsTr("Usuarios y roles"),
          descripcion: qsTr("Cuentas y permisos"),
          modulo: "usuarios", accion: "ver" }
    ]

    // Solo las vistas que el rol de la sesion actual puede abrir. Leer
    // Sesion.idUsuario hace que esto se recalcule al cambiar de sesion.
    // revisionPermisos sube cada vez que se regresa al menu, para que
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

    // --- Navegacion ---
    function abrir(vista) {
        // Se revisa de nuevo el permiso aunque la entrada ya estuviera
        // filtrada en el menu.
        if (!control.tienePermiso(vista.modulo, vista.accion)) {
            textoPrueba = ""
            textoBanner = qsTr("Tu rol no tiene permiso para abrir esta vista.")
            banner.visible = true
            temporizadorBanner.restart()
            return
        }

        window.vistaActual = vista.titulo
        switch (vista.clave) {
        case "solicitudes": pila.push(compSolicitudes); break
        case "reservas":    pila.push(compReservas); break
        case "huespedes":   pila.push(compHuespedes); break
        case "bitacora":    pila.push(compBitacora); break
        case "usuarios":    pila.push(compAdministracion); break
        case "reportes":    pila.push(compReportes); break
        case "habitaciones": pila.push(compHabitaciones); break
        default:            pila.push(compMarcador, { texto: vista.mensaje })
        }
    }

    function abrirPorClave(clave) {
        for (let i = 0; i < vistasPermitidas.length; i++) {
            if (vistasPermitidas[i].clave === clave) {
                if (window.vistaActual !== vistasPermitidas[i].titulo) {
                    abrir(vistasPermitidas[i])
                }
                return
            }
        }
    }

    function volver() {
        if (pila.depth > 1) {
            pila.pop()
            window.vistaActual = ""
            window.revisionPermisos++
        }
    }

    Component.onCompleted: Sesion.restaurarSesionGuardada()

    // Si la sesion se cierra, se regresa al menu (y se muestra el login).
    Connections {
        target: Sesion
        function onSesionCambio() {
            if (!Sesion.haySesion) {
                pila.pop(null)
                window.vistaActual = ""
                window.textoPrueba = ""
            }
        }
    }

    // Alerta global de solicitudes nuevas (Theme 5, Task 3): solo le
    // llega a quien tenga permiso para ver solicitudes, y solo de su tipo.
    AlertasPersonal {
        id: alertas
        onNuevaSolicitud: function(idSolicitud, tipo, numeroHabitacion, prioridad) {
            window.textoBanner = qsTr("Nueva solicitud de %1 · Hab. %2")
                                    .arg(tipo).arg(numeroHabitacion)
            banner.visible = true
            temporizadorBanner.restart()
        }
    }

    Timer {
        id: temporizadorBanner
        interval: 6000
        onTriggered: banner.visible = false
    }

    // --- Pruebas de desarrollo (quitar al terminar el proyecto) ---
    ControlAcceso {
        id: pruebaAcceso
        onAccesoConcedido: function(tipoActor, idHabitacion) {
            window.pruebaConExito = true
            window.textoPrueba = qsTr("Acceso concedido a la habitación.")
        }
        onAccesoDenegado: function(tipoActor, idHabitacion, motivo) {
            window.pruebaConExito = false
            window.textoPrueba = motivo
        }
    }
    SolicitudesHuesped {
        id: simulador
        onSolicitudCreada: function(tipo) {
            window.pruebaConExito = true
            window.textoPrueba = qsTr("Solicitud de %1 creada.").arg(tipo)
        }
        onOperacionRechazada: function(motivo) {
            window.pruebaConExito = false
            window.textoPrueba = motivo
        }
    }

    // Boton de texto reutilizable.
    component BotonTexto: Rectangle {
        id: boton
        property alias texto: etiqueta.text
        property bool principal: false
        signal pulsado()

        implicitHeight: 42
        radius: 8
        color: principal ? "#D4AF37" : "transparent"
        border.width: principal ? 0 : 1
        border.color: "#444444"

        Label {
            id: etiqueta
            anchors.centerIn: parent
            color: boton.principal ? "#1a1400" : "#f2f2f2"
            font.pixelSize: 13
            font.weight: boton.principal ? Font.Medium : Font.Normal
        }
        MouseArea {
            anchors.fill: parent
            onClicked: boton.pulsado()
        }
    }

    // --- Vistas dentro de la misma ventana ---
    Component { id: compSolicitudes; PantallaSolicitudes {} }
    Component { id: compReservas;    PantallaCalendarioReservas {} }
    Component { id: compHuespedes;   RegistroHuesped {} }
    Component { id: compBitacora;    PantallaBitacoraAcceso {} }
    Component { id: compAdministracion; PantallaAdministracion {} }
    Component { id: compReportes;    PantallaReportes {} }
    Component { id: compHabitaciones; PantallaHabitaciones {} }
    Component {
        id: compMarcador
        Item {
            property string texto: ""
            Label {
                anchors.centerIn: parent
                width: Math.min(parent.width - 48, 360)
                text: parent.texto
                color: window.colorTextoSecundario
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // Menu: una tarjeta por cada vista permitida.
    Component {
        id: menuInicio

        ListView {
            id: lista
            clip: true
            spacing: 10
            leftMargin: Math.max(18, (width - 560) / 2)
            rightMargin: leftMargin
            topMargin: 18
            bottomMargin: 18
            boundsBehavior: Flickable.StopAtBounds
            model: window.vistasPermitidas

            header: Item {
                width: lista.width - lista.leftMargin - lista.rightMargin
                height: saludo.implicitHeight + 16

                ColumnLayout {
                    id: saludo
                    width: parent.width
                    spacing: 2

                    Label {
                        text: qsTr("Hola, %1").arg(Sesion.nombreCompleto)
                        color: window.colorDorado
                        font.pixelSize: 18
                        font.weight: Font.Medium
                    }
                    Label {
                        text: window.vistasPermitidas.length > 0
                              ? qsTr("Elige una vista")
                              : qsTr("Tu rol todavía no tiene vistas asignadas. Pide a un administrador que revise tus permisos.")
                        color: window.colorTextoSecundario
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }

            delegate: Rectangle {
                required property var modelData
                width: lista.width - lista.leftMargin - lista.rightMargin
                height: 64
                radius: 10
                color: window.colorTarjeta
                border.width: 1
                border.color: window.colorBorde

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: modelData.titulo
                            color: window.colorTextoClaro
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        Label {
                            text: modelData.descripcion
                            color: window.colorTextoSecundario
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                    Label {
                        text: "›"
                        color: window.colorDorado
                        font.pixelSize: 22
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: window.abrir(modelData)
                }
            }

            // Pruebas de desarrollo: comprueban en vivo el acceso fisico
            // por rol (Theme 4) y la llegada de solicitudes (Theme 5).
            footer: Item {
                width: lista.width - lista.leftMargin - lista.rightMargin
                height: pruebas.implicitHeight + 24

                ColumnLayout {
                    id: pruebas
                    y: 24
                    width: parent.width
                    spacing: 8

                    Label {
                        text: qsTr("Pruebas de desarrollo (quitar al terminar)")
                        color: window.colorTextoSecundario
                        font.pixelSize: 11
                    }
                    BotonTexto {
                        Layout.fillWidth: true
                        texto: qsTr("Probar acceso a Habitación 204")
                        // La habitacion de demostracion siempre queda
                        // con id_habitacion = 1 (primera fila sembrada).
                        onPulsado: pruebaAcceso.intentarAccesoPersonal(1)
                    }
                    BotonTexto {
                        Layout.fillWidth: true
                        texto: qsTr("Simular solicitud de limpieza del huésped")
                        onPulsado: simulador.crearSolicitud("limpieza")
                    }
                    Label {
                        visible: window.textoPrueba.length > 0
                        text: window.textoPrueba
                        color: window.pruebaConExito ? window.colorExito : window.colorError
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }

    // --- Estructura de la ventana ---
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Barra superior: regreso, titulo y datos de la sesion.
        Rectangle {
            visible: Sesion.haySesion
            Layout.fillWidth: true
            implicitHeight: 52
            color: window.colorBarra

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                Label {
                    visible: pila.depth > 1
                    text: "‹"
                    color: window.colorDorado
                    font.pixelSize: 28
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -10
                        onClicked: window.volver()
                    }
                }

                Label {
                    text: window.vistaActual.length > 0 ? window.vistaActual : qsTr("NexStay")
                    color: window.colorDorado
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                ColumnLayout {
                    spacing: 0
                    visible: window.width >= 380
                    Label {
                        text: Sesion.nombreCompleto
                        color: window.colorTextoClaro
                        font.pixelSize: 11
                        Layout.alignment: Qt.AlignRight
                    }
                    Label {
                        text: Sesion.nombreRol
                        color: window.colorTextoSecundario
                        font.pixelSize: 10
                        Layout.alignment: Qt.AlignRight
                    }
                }

                BotonTexto {
                    implicitWidth: 72
                    implicitHeight: 32
                    texto: qsTr("Salir")
                    onPulsado: {
                        Sesion.cerrarSesion()
                        login.limpiarFormulario()
                    }
                }
            }
        }

        // Banner de solicitud nueva (toca para abrir Solicitudes).
        Rectangle {
            id: banner
            visible: false
            Layout.fillWidth: true
            implicitHeight: 38
            color: window.colorTarjeta
            border.width: 1
            border.color: window.colorDorado

            Label {
                anchors.centerIn: parent
                width: parent.width - 24
                text: window.textoBanner
                color: window.colorDorado
                font.pixelSize: 12
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    banner.visible = false
                    window.abrirPorClave("solicitudes")
                }
            }
        }

        // Contenido: login sin sesion; menu y vistas con sesion.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                anchors.fill: parent
                color: window.colorFondo
            }

            PantallaLogin {
                id: login
                anchors.fill: parent
                visible: !Sesion.haySesion
            }

            StackView {
                id: pila
                anchors.fill: parent
                visible: Sesion.haySesion
                initialItem: menuInicio
            }
        }
    }
}
