import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NexStay

// Theme 4, Task 1 (pantalla) + Task 2 (logica de autenticacion).
//
// Una sola pantalla sirve tanto para el celular (limpieza,
// mantenimiento) como para la PC de recepcion/administracion: el
// RowLayout de correo/contrasena se apila en vertical en pantallas
// angostas y se acomoda en fila en pantallas anchas, con el mismo
// punto de quiebre (400px) que ya usaba el Main.qml original del
// proyecto. No hay dos pantallas distintas, es la misma adaptandose.
//
// "Sesion" (Sesion.h/.cpp) es un singleton QML: se usa por su nombre
// de tipo directamente ("Sesion.iniciarSesion(...)"), sin instanciarlo
// con Sesion { } como a los demas objetos C++ del proyecto.
//
// Que vera cada quien DESPUES de iniciar sesion (recepcion ve el
// calendario/registro, limpieza ve sus solicitudes, etc.) todavia no
// esta resuelto aqui: eso depende de Theme 7 ("control de vistas por
// rol"), no de esta pantalla. Por eso, mientras tanto, esta pantalla
// se queda abierta despues de un login correcto y muestra un panel
// con los datos de la sesion activa, un boton para probar el acceso
// a una habitacion (Task 3, ver ControlAcceso.h/.cpp) y un boton para
// cerrar sesion.
ApplicationWindow {
    id: window
    width: 420
    height: 640
    minimumWidth: 300
    minimumHeight: 480
    visible: true
    title: qsTr("NexStay - Iniciar sesión")

    property color colorFondo: "#0d0d0d"
    property color colorCampo: "#1a1a1a"
    property color colorBorde: "#333333"
    property color colorDorado: "#D4AF37"
    property color colorTextoSecundario: "#8a8a8a"
    property color colorTextoClaro: "#f2f2f2"
    property color colorError: "#e05c5c"

    // Punto de quiebre: por debajo de esto, correo y contraseña se
    // apilan verticalmente (celular); por encima, van en una fila
    // (pantalla de recepcion/administracion en PC).
    property bool pantallaAngosta: width < 440

    property bool formularioValido: campoCorreo.text.trim().length > 0
                                     && campoContrasena.text.trim().length > 0

    function limpiarFormulario() {
        campoCorreo.text = ""
        campoContrasena.text = ""
        mensajeValidacion.visible = false
    }

    // Al abrir la pantalla, revisa si ya habia una sesion guardada en
    // Sesion_Actual (por ejemplo, la app se cerro sin cerrar sesion
    // explicitamente) y la recupera sin pedir contrasena de nuevo.
    Component.onCompleted: Sesion.restaurarSesionGuardada()

    // Reacciona a los rechazos de login que emite Sesion (correo
    // inexistente, contrasena incorrecta, usuario inactivo, etc.) y
    // los muestra en el mismo mensaje de error que ya usaba la
    // validacion de campos vacios.
    Connections {
        target: Sesion
        function onSesionRechazada(motivo) {
            mensajeValidacion.text = motivo
            mensajeValidacion.visible = true
        }
    }

    Rectangle {
        anchors.fill: parent
        color: window.colorFondo

        // Panel que se muestra en vez del formulario cuando ya hay una
        // sesion activa (prueba visual de que Sesion funciona). Tambien
        // incluye, ya aqui mismo, un boton para probar ControlAcceso
        // (Theme 4 Task 3): el usuario logueado intenta "entrar" a la
        // habitacion de demostracion (numero 204, id 1) y la pantalla
        // muestra si su rol tiene permiso o no, segun lo que haya
        // decidido el trigger de la base de datos.
        ColumnLayout {
            visible: Sesion.haySesion
            width: Math.min(parent.width - 48, 380)
            anchors.centerIn: parent
            spacing: 10

            Label {
                text: qsTr("Sesión iniciada")
                color: window.colorDorado
                font.pixelSize: 18
                font.weight: Font.Medium
                Layout.alignment: Qt.AlignHCenter
            }
            Label {
                text: Sesion.nombreCompleto
                color: window.colorTextoClaro
                font.pixelSize: 15
                Layout.alignment: Qt.AlignHCenter
            }
            Label {
                text: Sesion.correo + " · " + Sesion.nombreRol
                color: window.colorTextoSecundario
                font.pixelSize: 12
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 18
            }

            // --- Alertas de solicitudes (Theme 5, Task 3) ---
            // AlertasPersonal revisa la BD cada 2 s y avisa cuando llega
            // una solicitud nueva que le toca al rol de esta sesion
            // (limpieza solo ve limpieza, mantenimiento solo
            // mantenimiento, administrador/recepcion ven todo).
            AlertasPersonal {
                id: alertas
                onNuevaSolicitud: function(idSolicitud, tipo, numeroHabitacion, prioridad) {
                    textoAlerta.text = qsTr("Nueva solicitud de %1 · Hab. %2")
                                        .arg(tipo).arg(numeroHabitacion)
                    bannerAlerta.visible = true
                    temporizadorAlerta.restart()
                }
                // Task 4: confirmacion de que una solicitud fue atendida
                // (o el motivo por el que no se pudo).
                onSolicitudAtendida: function(idSolicitud) {
                    textoPrueba.text = ""
                }
                onOperacionRechazada: function(motivo) {
                    textoPrueba.text = motivo
                }
            }

            Timer {
                id: temporizadorAlerta
                interval: 6000
                onTriggered: bannerAlerta.visible = false
            }

            Rectangle {
                id: bannerAlerta
                visible: false
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 8
                color: window.colorCampo
                border.width: 1
                border.color: window.colorDorado

                Label {
                    id: textoAlerta
                    anchors.centerIn: parent
                    width: parent.width - 24
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    color: window.colorDorado
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }

            Label {
                text: alertas.solicitudes.length === 0
                      ? qsTr("Sin solicitudes pendientes")
                      : qsTr("Solicitudes pendientes: %1").arg(alertas.solicitudes.length)
                color: window.colorTextoSecundario
                font.pixelSize: 12
                Layout.alignment: Qt.AlignHCenter
            }

            // Vista rapida de las primeras 3 (la gestion completa de
            // solicitudes es del Theme 6). Task 4: cada una tiene un
            // boton "Atender" para confirmarla como atendida.
            Repeater {
                model: alertas.solicitudes.slice(0, 3)

                delegate: RowLayout {
                    required property var modelData
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10

                    Label {
                        text: "Hab. " + modelData.numeroHabitacion + " · " + modelData.tipo
                              + " · " + modelData.prioridad
                        color: modelData.prioridad === "alta" ? window.colorError : window.colorTextoClaro
                        font.pixelSize: 12
                    }

                    Button {
                        id: botonAtender
                        // Referenciar Sesion.nombreRol hace que se
                        // reevalue al cambiar de sesion; recepcion, por
                        // ejemplo, puede ver pero no atender.
                        visible: Sesion.nombreRol.length > 0 && alertas.puedeAtender()
                        text: qsTr("Atender")

                        contentItem: Text {
                            text: botonAtender.text
                            color: "#1a1400"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: window.colorDorado
                            radius: 6
                            implicitWidth: 64
                            implicitHeight: 26
                        }
                        onClicked: alertas.marcarAtendida(modelData.idSolicitud)
                    }
                }
            }

            // SOLO PRUEBA: genera una solicitud como si la pidiera el
            // huesped de demostracion, para ver llegar la alerta sin
            // abrir otra instancia de la app. Quitar cuando exista la
            // vista de solicitudes (Theme 6).
            SolicitudesHuesped {
                id: simuladorSolicitudes
                onOperacionRechazada: function(motivo) {
                    textoPrueba.text = motivo
                }
                onSolicitudCreada: function(tipo) {
                    textoPrueba.text = ""
                }
            }

            Button {
                id: botonSimular
                Layout.fillWidth: true
                Layout.topMargin: 8
                text: qsTr("Prueba: simular solicitud de limpieza")

                contentItem: Text {
                    text: botonSimular.text
                    color: window.colorTextoClaro
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: "transparent"
                    radius: 8
                    border.width: 1
                    border.color: "#444444"
                    implicitHeight: 36
                }
                onClicked: simuladorSolicitudes.crearSolicitud("limpieza")
            }

            Label {
                id: textoPrueba
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: window.colorError
                font.pixelSize: 11
                visible: text.length > 0
            }

            // --- Prueba de ControlAcceso (Theme 4, Task 3) ---
            ControlAcceso {
                id: controlAcceso
                onAccesoConcedido: function(tipoActor, idHabitacion) {
                    resultadoAcceso.text = qsTr("Acceso concedido a la habitación.")
                    resultadoAcceso.color = "#6fcf97"
                    resultadoAcceso.visible = true
                }
                onAccesoDenegado: function(tipoActor, idHabitacion, motivo) {
                    resultadoAcceso.text = motivo
                    resultadoAcceso.color = window.colorError
                    resultadoAcceso.visible = true
                }
            }

            Button {
                id: botonProbarAcceso
                Layout.fillWidth: true
                text: qsTr("Probar acceso a Habitación 204")

                contentItem: Text {
                    text: botonProbarAcceso.text
                    color: window.colorTextoClaro
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: "transparent"
                    radius: 8
                    border.width: 1
                    border.color: "#444444"
                    implicitHeight: 40
                }
                // La habitacion de demostracion sembrada por Database.cpp
                // siempre queda con id_habitacion = 1 (es la primera fila
                // insertada). Cuando exista una pantalla real de
                // habitacion con login, este id vendra de ahi en vez de
                // estar fijo.
                onClicked: controlAcceso.intentarAccesoPersonal(1)
            }

            Label {
                id: resultadoAcceso
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                width: parent.width
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 11
                visible: false
            }

            Button {
                id: botonCerrarSesion
                Layout.fillWidth: true
                Layout.topMargin: 8
                text: qsTr("Cerrar sesión")

                contentItem: Text {
                    text: botonCerrarSesion.text
                    color: window.colorTextoClaro
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: "transparent"
                    radius: 8
                    border.width: 1
                    border.color: "#444444"
                    implicitHeight: 44
                }
                onClicked: {
                    Sesion.cerrarSesion()
                    window.limpiarFormulario()
                    resultadoAcceso.visible = false
                }
            }
        }

        // Contenedor centrado, con ancho maximo para que en pantallas
        // muy anchas (PC) el formulario no se estire de borde a borde.
        ColumnLayout {
            visible: !Sesion.haySesion
            width: Math.min(parent.width - 48, 380)
            anchors.centerIn: parent
            spacing: 4

            // Encabezado
            ColumnLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 26
                spacing: 4

                Label {
                    text: qsTr("NexStay")
                    color: window.colorDorado
                    font.pixelSize: 20
                    font.weight: Font.Medium
                    Layout.alignment: Qt.AlignHCenter
                }
                Label {
                    text: qsTr("Inicia sesión para continuar")
                    color: window.colorTextoSecundario
                    font.pixelSize: 12
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            // Campos: apilados en celular, en fila en pantallas anchas
            GridLayout {
                Layout.fillWidth: true
                columns: window.pantallaAngosta ? 1 : 2
                columnSpacing: 14
                rowSpacing: 14

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    Label { text: qsTr("Correo"); color: window.colorTextoSecundario; font.pixelSize: 11 }
                    TextField {
                        id: campoCorreo
                        Layout.fillWidth: true
                        placeholderText: qsTr("correo@hotel.com")
                        inputMethodHints: Qt.ImhEmailCharactersOnly
                        color: window.colorTextoClaro
                        placeholderTextColor: "#555555"
                        background: Rectangle {
                            color: window.colorCampo
                            radius: 8
                            border.width: 1
                            border.color: window.colorBorde
                        }
                        leftPadding: 12
                        rightPadding: 12
                        topPadding: 11
                        bottomPadding: 11
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    Label { text: qsTr("Contraseña"); color: window.colorTextoSecundario; font.pixelSize: 11 }
                    TextField {
                        id: campoContrasena
                        Layout.fillWidth: true
                        placeholderText: qsTr("••••••••")
                        echoMode: TextInput.Password
                        color: window.colorTextoClaro
                        placeholderTextColor: "#555555"
                        background: Rectangle {
                            color: window.colorCampo
                            radius: 8
                            border.width: 1
                            border.color: window.colorBorde
                        }
                        leftPadding: 12
                        rightPadding: 12
                        topPadding: 11
                        bottomPadding: 11
                    }
                }
            }

            // Mensaje de validación (campos vacíos)
            Label {
                id: mensajeValidacion
                Layout.topMargin: 10
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Ingresa tu correo y contraseña.")
                color: window.colorError
                font.pixelSize: 11
                visible: false
            }

            // Botón Entrar
            Button {
                id: botonEntrar
                Layout.fillWidth: true
                Layout.topMargin: 18
                text: qsTr("Entrar")

                contentItem: Text {
                    text: botonEntrar.text
                    color: "#1a1400"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: window.colorDorado
                    radius: 8
                    implicitHeight: 44
                    opacity: window.formularioValido ? 1.0 : 0.5
                }
                onClicked: {
                    if (!window.formularioValido) {
                        mensajeValidacion.text = qsTr("Ingresa tu correo y contraseña.")
                        mensajeValidacion.visible = true
                        return
                    }
                    mensajeValidacion.visible = false

                    const exito = Sesion.iniciarSesion(campoCorreo.text, campoContrasena.text)
                    if (exito) {
                        // Sesion.haySesion pasa a true y el panel de
                        // "Sesion iniciada" de arriba se muestra solo.
                        // onSesionRechazada (Connections, arriba) ya
                        // se encarga del caso de error.
                        window.limpiarFormulario()
                    }
                    // TODO (Theme 7 - "control de vistas/funciones por
                    // rol"): en vez de quedarse en esta pantalla,
                    // navegar a la vista que corresponda a
                    // Sesion.nombreRol. El Task 3 de este Theme
                    // (ControlAcceso, boton "Probar acceso" de abajo)
                    // ya esta resuelto.
                }
            }

            // Pie: recordatorio de contraseña (sin funcionalidad todavia)
            Label {
                text: qsTr("¿Olvidaste tu contraseña?")
                color: window.colorTextoSecundario
                font.pixelSize: 11
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 14
            }
        }
    }
}
