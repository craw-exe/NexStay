import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// Theme 4, Task 1: pantalla de login (correo + contraseña).
// Por ahora es solo la interfaz, sin logica de autenticacion todavia
// (eso es el Task 2: "Implementar logica de autenticacion en C++").
//
// Una sola pantalla sirve tanto para el celular (limpieza,
// mantenimiento) como para la PC de recepcion/administracion: el
// RowLayout de correo/contrasena se apila en vertical en pantallas
// angostas y se acomoda en fila en pantallas anchas, con el mismo
// punto de quiebre (400px) que ya usaba el Main.qml original del
// proyecto. No hay dos pantallas distintas, es la misma adaptandose.
//
// Que vera cada quien DESPUES de iniciar sesion (recepcion ve el
// calendario/registro, limpieza ve sus solicitudes, etc.) todavia no
// esta resuelto aqui: eso depende de Theme 4 Task 3 ("logica de
// acceso validado por rol") y de Theme 7 ("control de vistas por
// rol"), no de esta pantalla.
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
                        mensajeValidacion.visible = true
                        return
                    }
                    mensajeValidacion.visible = false
                    // TODO (Theme 4, Task 2 - "Implementar logica de
                    // autenticacion en C++"): validar correo/contrasena
                    // contra la tabla Usuario y, si es correcto, abrir
                    // la vista que corresponda al rol de esa cuenta.
                    console.log("Intento de login:", campoCorreo.text)
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
