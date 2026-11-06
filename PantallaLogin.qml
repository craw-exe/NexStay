import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import NexStay

// Theme 4 (Tasks 1 y 2): formulario de inicio de sesion.
//
// Theme 7, Task 2: esta pantalla YA NO es una ventana propia ni
// muestra nada despues del login. Es una vista (Item) que
// PantallaPrincipal muestra mientras no haya sesion; en cuanto
// Sesion.haySesion pasa a true, PantallaPrincipal la oculta y lleva a
// cada rol a su menu de vistas segun sus permisos.
//
// Una sola pantalla sirve tanto para el celular (limpieza,
// mantenimiento) como para la PC de recepcion/administracion: los
// campos de correo/contrasena se apilan en vertical en pantallas
// angostas y se acomodan en fila en pantallas anchas, con el mismo
// punto de quiebre del Main.qml original del proyecto.
//
// "Sesion" (Sesion.h/.cpp) es un singleton QML: se usa por su nombre
// de tipo directamente ("Sesion.iniciarSesion(...)").
Item {
    id: window

    property color colorFondo: "#0d0d0d"
    property color colorCampo: "#1a1a1a"
    property color colorBorde: "#333333"
    property color colorDorado: "#D4AF37"
    property color colorTextoSecundario: "#8a8a8a"
    property color colorTextoClaro: "#f2f2f2"
    property color colorError: "#e05c5c"

    // Punto de quiebre: por debajo de esto, correo y contraseña se
    // apilan verticalmente (celular); por encima, van en una fila.
    property bool pantallaAngosta: width < 440

    property bool formularioValido: campoCorreo.text.trim().length > 0
                                     && campoContrasena.text.trim().length > 0

    function limpiarFormulario() {
        campoCorreo.text = ""
        campoContrasena.text = ""
        mensajeValidacion.visible = false
    }

    // Reacciona a los rechazos de login que emite Sesion (correo
    // inexistente, contrasena incorrecta, usuario inactivo, etc.).
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

        // Contenedor centrado, con ancho maximo para que en pantallas
        // muy anchas (PC) el formulario no se estire de borde a borde.
        ColumnLayout {
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
                        onAccepted: botonEntrar.clicked()
                    }
                }
            }

            // Mensaje de validación (campos vacíos o login rechazado)
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

                    // Si el login es correcto, Sesion.haySesion pasa a
                    // true y PantallaPrincipal cambia de vista sola. Si
                    // no, onSesionRechazada (arriba) muestra el motivo.
                    if (Sesion.iniciarSesion(campoCorreo.text, campoContrasena.text)) {
                        window.limpiarFormulario()
                    }
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
